// SPDX-License-Identifier: GPL-3.0-or-later
// One connection to the desktop: control channel, optional UDP audio channel and the encode pipeline

import AVFoundation
import Foundation
import MicYouProtocol
import Network
import os

struct StreamConfig: Sendable {
    var endpoint: NWEndpoint
    var preferIPv4: Bool
    var transport: TransportMode
    var codec: CodecChoice
    var sampleRate: Int
    var channels: Int
    var opusBitrate: Int
    var fecEnabled: Bool
}

final class StreamSession: @unchecked Sendable {
    enum Event: Sendable {
        case streaming(remote: String?, format: AudioStreamFormat)
        case remoteMute(Bool)
        /// Payload bits per second over the last second
        case throughput(Int)
        case codecFallback
        case failed(StreamError)
    }

    private let log = Logger(subsystem: "com.chouchiu.micyou", category: "session")
    private let queue = DispatchQueue(label: "com.chouchiu.micyou.session", qos: .userInteractive)
    private let config: StreamConfig
    private let onEvent: @Sendable (Event) -> Void

    private var control: ControlChannel?
    private var udp: NWConnection?
    private var sequencer: AudioSequencer
    private var format: AudioStreamFormat
    private var opus: OpusEncoder?
    private var chunker: PCMChunker
    private var muted: Bool
    private var ready = false
    private var finished = false
    private var udpFailures = 0
    private var bytesThisSecond = 0
    private var statsTimer: DispatchSourceTimer?

    init(config: StreamConfig, muted: Bool, onEvent: @escaping @Sendable (Event) -> Void) {
        self.config = config
        self.muted = muted
        self.onEvent = onEvent
        var sessionId: Int64 = 0
        while sessionId == 0 { sessionId = Int64.random(in: Int64.min...Int64.max) }
        sequencer = AudioSequencer(sessionId: sessionId, fecEnabled: config.fecEnabled && config.transport == .tcpUDP)
        format = AudioStreamFormat(sampleRate: Int32(config.sampleRate), channelCount: Int32(config.channels), codec: .pcm)
        chunker = PCMChunker(frameBytes: config.channels * 2)
        setUpEncoder()
    }

    func start() {
        queue.async { [self] in
            let channel = ControlChannel(
                endpoint: config.endpoint, preferIPv4: config.preferIPv4,
                sessionId: sequencer.sessionId, initialMute: muted, queue: queue
            ) { [weak self] event in self?.handle(event) }
            control = channel
            channel.start()
        }
    }

    func stop() {
        queue.async { self.finish(nil) }
    }

    func setMuted(_ value: Bool, notifyPeer: Bool) {
        queue.async { [self] in
            guard muted != value else { return }
            muted = value
            if value { resetPipeline() }
            if notifyPeer { control?.send(.mute(value)) }
        }
    }

    /// Fed from the capture thread with PCM in the configured rate and channel count
    func push(_ pcm: Data) {
        queue.async { [self] in
            guard ready, !finished else { return }
            guard !muted else { return }
            for payload in encode(pcm) {
                let now = Int64(Date().timeIntervalSince1970 * 1000)
                for packet in sequencer.packets(for: payload, format: format, timestamp: now) {
                    deliver(.audio(packet))
                }
                bytesThisSecond += payload.count
            }
        }
    }

    // MARK: Private, always on queue

    private func setUpEncoder() {
        guard config.codec == .opus else { return }
        // The owner already picked an Opus compatible capture rate
        let rate = Double(config.sampleRate)
        do {
            opus = try OpusEncoder(sampleRate: rate, channels: AVAudioChannelCount(config.channels), bitrate: config.opusBitrate)
            format = AudioStreamFormat(sampleRate: Int32(rate), channelCount: Int32(config.channels), codec: .opus)
        } catch {
            log.error("Opus encoder unavailable, using PCM: \(String(describing: error))")
            onEvent(.codecFallback)
        }
    }

    private func encode(_ pcm: Data) -> [Data] {
        if let opus {
            do {
                return try opus.encode(pcm)
            } catch {
                log.error("Opus encode failed, switching to PCM: \(String(describing: error))")
                self.opus = nil
                format.codec = .pcm
                sequencer.resetFEC()
                onEvent(.codecFallback)
            }
        }
        return chunker.append(pcm)
    }

    private func resetPipeline() {
        opus?.reset()
        chunker.reset()
    }

    private func deliver(_ message: MessageWrapper) {
        if let udp {
            udp.send(content: MicYouFrame.udp(message), completion: .contentProcessed { [weak self] error in
                guard let self else { return }
                if error == nil {
                    self.udpFailures = 0
                } else {
                    self.udpFailures += 1
                    if self.udpFailures >= 500 { self.finish(.udpFailed) }
                }
            })
        } else {
            control?.sendAudio(message)
        }
    }

    private func handle(_ event: ControlChannel.Event) {
        guard !finished else { return }
        switch event {
        case .ready(let remote):
            var remoteHost: NWEndpoint.Host?
            if case .hostPort(let host, let tcpPort) = remote {
                remoteHost = host
                if config.transport == .tcpUDP { openUDP(host: host, tcpPort: tcpPort) }
            } else if config.transport == .tcpUDP {
                return finish(.protocolError("missing peer address"))
            }
            ready = true
            startStats()
            onEvent(.streaming(remote: remoteHost.map(Self.describe), format: format))
        case .remoteMute(let value):
            if muted != value {
                muted = value
                if value { resetPipeline() }
            }
            onEvent(.remoteMute(value))
        case .failed(let error):
            finish(error)
        }
    }

    static func describe(_ host: NWEndpoint.Host) -> String {
        let text = switch host {
        case .ipv4(let address): "\(address)"
        case .ipv6(let address): "\(address)"
        case .name(let name, _): name
        @unknown default: "\(host)"
        }
        // Drop the interface scope, for example "%en0"
        return String(text.split(separator: "%").first ?? Substring(text))
    }

    private func openUDP(host: NWEndpoint.Host, tcpPort: NWEndpoint.Port) {
        let port = NWEndpoint.Port(rawValue: MicYouWire.udpPort(forTCPPort: tcpPort.rawValue))!
        let parameters = NWParameters.udp
        parameters.serviceClass = .interactiveVoice
        let connection = NWConnection(host: host, port: port, using: parameters)
        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state { self?.finish(.udpFailed) }
        }
        connection.start(queue: queue)
        udp = connection
        log.info("UDP audio to \(String(describing: host)):\(port.rawValue)")
    }

    private func startStats() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.onEvent(.throughput(self.bytesThisSecond * 8))
            self.bytesThisSecond = 0
        }
        timer.resume()
        statsTimer = timer
    }

    private func finish(_ error: StreamError?) {
        guard !finished else { return }
        finished = true
        ready = false
        statsTimer?.cancel()
        control?.cancel()
        udp?.cancel()
        if let error { onEvent(.failed(error)) }
    }
}
