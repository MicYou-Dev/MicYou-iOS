// SPDX-License-Identifier: GPL-3.0-or-later
// TCP control connection: handshake, connect, heartbeat, mute sync and link stats
// Behaviour follows the Android sender in MicYou-Dev/MicYou (AudioEngine.kt)
// Over USB the roles of the TCP connection flip: usbmuxd only lets the computer connect,
// so the phone listens on loopback and runs the same client protocol once the desktop is in

import Foundation
import MicYouProtocol
import Network
import os

final class ControlChannel: @unchecked Sendable {
    enum Event: Sendable {
        /// Handshake done, carries the resolved peer address and port for the UDP channel, nil over USB
        case ready(remote: NWEndpoint?)
        case remoteMute(Bool)
        case stats(StatsMessage)
        case failed(StreamError)
    }

    private let log = Logger.micyou("control")
    private let queue: DispatchQueue
    private let link: StreamLink
    private var connection: NWConnection?
    private var listener: NWListener?
    private let sessionId: Int64
    private let initialMute: Bool
    private let onEvent: @Sendable (Event) -> Void

    private var decoder = FrameDecoder()
    private var lastPing = DispatchTime.now()
    private var watchdog: DispatchSourceTimer?
    private var timeout: DispatchWorkItem?
    private var isReady = false
    private var isFinished = false
    /// Bytes handed to the connection but not yet processed, used to drop audio when TCP backs up
    private var inFlight = 0
    private static let maxAudioBacklog = 128 * 1024

    /// The desktop polls usbmuxd every second, so a longer wait means it is not in USB mode
    private static let usbWaitTimeout: TimeInterval = 15

    init(link: StreamLink, sessionId: Int64, initialMute: Bool,
         queue: DispatchQueue, onEvent: @escaping @Sendable (Event) -> Void) {
        self.link = link
        self.queue = queue
        self.sessionId = sessionId
        self.initialMute = initialMute
        self.onEvent = onEvent
    }

    /// Called on the session queue, like everything below
    func start() {
        switch link {
        case .network(let endpoint, let preferIPv4):
            adopt(NWConnection(to: endpoint, using: Self.parameters(preferIPv4: preferIPv4)))
            arm(timeout: 12, error: .connectTimeout)
        case .usb(let port):
            listen(on: port)
        }
    }

    func cancel() {
        queue.async { self.finish(nil) }
    }

    func send(_ message: MessageWrapper) {
        write(MicYouFrame.tcp(message))
    }

    /// Audio in TCP mode, dropped instead of queued when the link cannot keep up
    func sendAudio(_ message: MessageWrapper) {
        guard isReady, inFlight < Self.maxAudioBacklog else { return }
        write(MicYouFrame.tcp(message))
    }

    // MARK: Private, always on queue

    private static func parameters(preferIPv4: Bool) -> NWParameters {
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        tcp.enableKeepalive = true
        tcp.keepaliveIdle = 5
        tcp.connectionTimeout = 10
        let parameters = NWParameters(tls: nil, tcp: tcp)
        if preferIPv4, let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }
        parameters.serviceClass = .interactiveVoice
        return parameters
    }

    private func adopt(_ connection: NWConnection) {
        self.connection = connection
        connection.stateUpdateHandler = { [weak self] state in self?.handle(state) }
        connection.start(queue: queue)
    }

    /// usbmuxd delivers the desktop's connection on loopback, nothing on the network can reach this port
    private func listen(on port: NWEndpoint.Port) {
        let parameters = Self.parameters(preferIPv4: true)
        parameters.requiredInterfaceType = .loopback
        parameters.allowLocalEndpointReuse = true
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: port)
        } catch {
            return finish((error as? NWError).map(StreamError.from) ?? .unreachable(error.localizedDescription))
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready: self?.log.info("Waiting for the computer over USB on port \(port.rawValue)")
            case .failed(let error): self?.finish(.from(error))
            default: break
            }
        }
        listener.start(queue: queue)
        self.listener = listener
        arm(timeout: Self.usbWaitTimeout, error: .usbTimeout)
    }

    private func accept(_ incoming: NWConnection) {
        guard connection == nil, !isFinished else { return incoming.cancel() }
        log.info("Computer connected over USB")
        // One desktop per session, a reconnect listens again
        listener?.cancel()
        listener = nil
        adopt(incoming)
    }

    private func handle(_ state: NWConnection.State) {
        switch state {
        case .ready:
            beginHandshake()
        case .waiting(let error):
            finish(.from(error))
        case .failed(let error):
            finish(isReady ? .closedByPeer : .from(error))
        case .cancelled:
            finish(nil)
        default:
            break
        }
    }

    private func beginHandshake() {
        guard let connection else { return }
        log.info("TCP connected, sending handshake")
        arm(timeout: MicYouWire.handshakeTimeout, error: .handshakeFailed)
        connection.send(content: MicYouWire.handshakeClient, completion: .contentProcessed { [weak self] error in
            if let error { self?.finish(.from(error)) }
        })
        let length = MicYouWire.handshakeServer.count
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self] data, _, isComplete, error in
            guard let self, !self.isFinished else { return }
            if let error { return self.finish(.from(error)) }
            guard data == MicYouWire.handshakeServer else {
                return self.finish(isComplete && data == nil ? .closedByPeer : .handshakeFailed)
            }
            self.didHandshake()
        }
    }

    private func didHandshake() {
        timeout?.cancel()
        isReady = true
        // The desktop requires Connect as the first frame
        send(.connect(sessionId: sessionId))
        send(.mute(initialMute))
        lastPing = .now()
        startWatchdog()
        receiveLoop()
        // Over USB the peer is usbmuxd on loopback, not an address worth showing or sending UDP to
        let remote = link.isUSB ? nil : connection?.currentPath?.remoteEndpoint
        log.info("Handshake complete, session \(self.sessionId)")
        onEvent(.ready(remote: remote))
    }

    private func receiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self, !self.isFinished else { return }
            if let data {
                self.decoder.append(data)
                do {
                    while let message = try self.decoder.nextMessage() {
                        self.handle(message)
                    }
                } catch {
                    return self.finish(.protocolError(String(describing: error)))
                }
            }
            if let error { return self.finish(.from(error)) }
            if isComplete { return self.finish(.closedByPeer) }
            self.receiveLoop()
        }
    }

    private func handle(_ message: MessageWrapper) {
        if let ping = message.ping {
            lastPing = .now()
            send(.pong(ping.timestamp))
        }
        if let mute = message.mute {
            onEvent(.remoteMute(mute.isMuted ?? false))
        }
        if var stats = message.stats {
            // Shown as is, a misbehaving desktop must not put "NaN %" or a negative time on screen
            stats.rttMs = max(0, stats.rttMs)
            stats.packetLoss = stats.packetLoss.isFinite ? min(max(stats.packetLoss, 0), 1) : 0
            onEvent(.stats(stats))
        }
    }

    private func write(_ frame: Data) {
        guard !isFinished, let connection else { return }
        inFlight += frame.count
        connection.send(content: frame, completion: .contentProcessed { [weak self] error in
            guard let self else { return }
            self.inFlight -= frame.count
            if let error { self.finish(.from(error)) }
        })
    }

    private func startWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            let silence = Double(DispatchTime.now().uptimeNanoseconds - self.lastPing.uptimeNanoseconds) / 1e9
            if silence > MicYouWire.heartbeatTimeout {
                self.finish(.heartbeatTimeout)
            }
        }
        timer.resume()
        watchdog = timer
    }

    private func arm(timeout seconds: TimeInterval, error: StreamError) {
        timeout?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.finish(error) }
        timeout = work
        queue.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func finish(_ error: StreamError?) {
        guard !isFinished else { return }
        isFinished = true
        isReady = false
        timeout?.cancel()
        watchdog?.cancel()
        listener?.cancel()
        listener = nil
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        if let error {
            log.error("Control connection failed: \(String(describing: error), privacy: .public)")
            onEvent(.failed(error))
        }
    }
}
