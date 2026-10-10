// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import MicYouProtocol
import MicYouShared
import Network
import Observation
import UIKit
import os

enum ConnectionPhase: Equatable {
    case idle
    case connecting
    case streaming
    case reconnecting(attempt: Int)
    case failed(String)
}

/// Where to connect: a Bonjour result or a typed address
enum ServerSelection: Hashable {
    case discovered(name: String)
    case manual
}

/// App wide state, also used by intents and deep links
@MainActor @Observable
final class AppModel {
    static let shared = AppModel()
    static let maxReconnectAttempts = 6

    let settings = AppSettings.shared
    let browser = ServerBrowser()

    private(set) var phase: ConnectionPhase = .idle
    private(set) var isMuted = false
    /// Smoothed input level in dBFS
    private(set) var levelDB: Float = -160
    private(set) var throughput = 0
    private(set) var remoteAddress: String?
    private(set) var activeFormat: AudioStreamFormat?
    private(set) var streamingSince: Date?
    private(set) var connectedName: String?
    /// One-off message, for example when Opus is not available
    var notice: String?
    var selection: ServerSelection {
        didSet {
            if case .discovered(let name) = selection { settings.lastServiceName = name } else { settings.lastServiceName = nil }
            clearError()
        }
    }

    @ObservationIgnored private let log = Logger(subsystem: "com.chouchiu.micyou", category: "model")
    @ObservationIgnored private let capture = AudioCapture()
    @ObservationIgnored private let sink = SessionSink()
    @ObservationIgnored private let liveActivity = LiveActivityController()
    @ObservationIgnored private var session: StreamSession?
    @ObservationIgnored private var sessionToken: UUID?
    @ObservationIgnored private var currentConfig: StreamConfig?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var hasStreamed = false

    init() {
        selection = AppSettings.shared.lastServiceName.map { .discovered(name: $0) } ?? .manual
        liveActivity.endStale()
        // The Live Activity shows the microphone in use, so follow headsets coming and going
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { AppModel.shared.refreshSideEffects() }
        }
    }

    var isActive: Bool {
        switch phase {
        case .connecting, .streaming, .reconnecting: true
        case .idle, .failed: false
        }
    }

    /// Display name of the current selection, nil when nothing usable is selected
    var selectedName: String? {
        switch selection {
        case .discovered(let name):
            return browser.servers.first { $0.name == name }?.displayName
        case .manual:
            let host = settings.host.trimmingCharacters(in: .whitespaces)
            return host.isEmpty ? nil : host
        }
    }

    var canConnect: Bool {
        switch selection {
        case .discovered(let name): browser.servers.contains { $0.name == name }
        case .manual: !settings.host.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // MARK: Actions

    func toggleConnection() {
        if isActive { disconnect() } else { Task { await connect() } }
    }

    func connect() async {
        guard !isActive else { return }
        notice = nil
        // Claim the connecting state before awaiting so a second tap is ignored
        phase = .connecting
        guard await AudioCapture.requestPermission() else {
            phase = .failed(CaptureError.permissionDenied.localizedDescription)
            return
        }
        guard phase == .connecting, let (endpoint, name, preferIPv4) = resolveTarget() else {
            if phase == .connecting {
                phase = .failed(L10n.Failure.chooseTarget)
            }
            return
        }
        var sampleRate = settings.sampleRate
        if settings.codec == .opus {
            sampleRate = Int(OpusEncoder.opusRate(for: Double(sampleRate)))
        }
        currentConfig = StreamConfig(
            endpoint: endpoint,
            preferIPv4: preferIPv4,
            transport: settings.transport,
            codec: settings.codec,
            sampleRate: sampleRate,
            channels: settings.stereo ? 2 : 1,
            opusBitrate: settings.opusBitrate,
            fecEnabled: settings.fecEnabled
        )
        connectedName = name
        hasStreamed = false
        refreshSideEffects()
        openSession()
    }

    func disconnect() {
        reconnectTask?.cancel()
        reconnectTask = nil
        tearDownSession()
        capture.stop()
        phase = .idle
        streamingSince = nil
        activeFormat = nil
        remoteAddress = nil
        throughput = 0
        levelDB = -160
        refreshSideEffects()
    }

    func setMuted(_ value: Bool) {
        guard isMuted != value else { return }
        isMuted = value
        session?.setMuted(value, notifyPeer: true)
        refreshSideEffects()
    }

    /// Applies immediately while streaming
    func setInputGain(_ dB: Double) {
        settings.inputGainDB = dB
        capture.setGain(dB: dB)
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    func handle(_ link: DeepLink) {
        switch link {
        case .connect: if !isActive { Task { await connect() } }
        case .disconnect: disconnect()
        case .toggle: toggleConnection()
        case .mute: setMuted(true)
        case .unmute: setMuted(false)
        case .toggleMute: toggleMute()
        }
    }

    func clearError() {
        if case .failed = phase { phase = .idle }
    }

    // MARK: Session lifecycle

    private func resolveTarget() -> (NWEndpoint, String, Bool)? {
        switch selection {
        case .discovered(let name):
            guard let server = browser.servers.first(where: { $0.name == name }) else { return nil }
            return (server.endpoint, server.displayName, true)
        case .manual:
            let host = settings.host.trimmingCharacters(in: .whitespaces)
            guard !host.isEmpty, let port = NWEndpoint.Port(rawValue: UInt16(clamping: settings.port)) else { return nil }
            settings.rememberHost(host)
            return (.hostPort(host: NWEndpoint.Host(host), port: port), host, false)
        }
    }

    private func openSession() {
        guard let config = currentConfig else { return }
        let token = UUID()
        sessionToken = token
        let session = StreamSession(config: config, muted: isMuted) { [weak self] event in
            Task { @MainActor in self?.handle(event, config: config, token: token) }
        }
        self.session = session
        sink.set(session)
        session.start()
    }

    private func tearDownSession() {
        sessionToken = nil
        sink.set(nil)
        session?.stop()
        session = nil
    }

    private func handle(_ event: StreamSession.Event, config: StreamConfig, token: UUID) {
        // Ignore late events from a session that was already replaced
        guard session != nil, token == sessionToken else { return }
        switch event {
        case .streaming(let remote, let format):
            reconnectTask = nil
            hasStreamed = true
            remoteAddress = remote
            activeFormat = format
            if streamingSince == nil { streamingSince = .now }
            phase = .streaming
            startCaptureIfNeeded(config)
            refreshSideEffects()
        case .remoteMute(let value):
            if isMuted != value {
                isMuted = value
                refreshSideEffects()
            }
        case .throughput(let bits):
            throughput = bits
        case .codecFallback:
            notice = L10n.Failure.opusUnavailable
            activeFormat?.codec = .pcm
        case .failed(let error):
            log.error("Session failed: \(error.localizedDescription)")
            tearDownSession()
            scheduleReconnectOrFail(error)
        }
    }

    private func startCaptureIfNeeded(_ config: StreamConfig) {
        guard !capture.isRunning else { return }
        let sink = self.sink
        let captureConfig = CaptureConfig(
            sampleRate: Double(config.sampleRate),
            channels: AVAudioChannelCount(config.channels),
            voiceProcessing: settings.voiceProcessing
        )
        capture.setGain(dB: settings.inputGainDB)
        do {
            try capture.start(captureConfig) { [weak self] pcm, level in
                if let smoothed = sink.push(pcm, level: level) {
                    Task { @MainActor in
                        if self?.isActive == true { self?.levelDB = smoothed }
                    }
                }
            }
        } catch {
            disconnect()
            phase = .failed(error.localizedDescription)
        }
    }

    private func scheduleReconnectOrFail(_ error: StreamError) {
        let attempt: Int = if case .reconnecting(let n) = phase { n + 1 } else { 1 }
        guard settings.autoReconnect, hasStreamed, error.isTransient, attempt <= Self.maxReconnectAttempts else {
            disconnect()
            phase = .failed(error.localizedDescription)
            return
        }
        // Capture keeps running so the app stays alive in the background while retrying
        phase = .reconnecting(attempt: attempt)
        throughput = 0
        refreshSideEffects()
        let delay = min(pow(2, Double(attempt - 1)), 15)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, case .reconnecting = self.phase else { return }
            self.openSession()
        }
    }

    // MARK: Side effects

    private func refreshSideEffects() {
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenOn && isActive

        guard settings.liveActivity, isActive, let name = connectedName else {
            liveActivity.end()
            return
        }
        let activityPhase: StreamActivityAttributes.Phase
        var attempt = 0
        switch phase {
        case .streaming: activityPhase = .streaming
        case .reconnecting(let n): activityPhase = .reconnecting; attempt = n
        default: activityPhase = .connecting
        }
        let input = InputText.current()
        liveActivity.update(serverName: name, state: .init(
            phase: activityPhase,
            isMuted: isMuted,
            startedAt: streamingSince ?? .now,
            detail: activityDetail,
            input: input?.name ?? "",
            inputSymbol: input?.symbol ?? "mic.fill",
            attempt: attempt,
            maxAttempts: Self.maxReconnectAttempts
        ))
    }

    /// Codec with its bitrate or sample rate, channels and transport
    private var activityDetail: String {
        guard let format = activeFormat, let config = currentConfig else { return "" }
        let codec = format.codec == .opus
            ? L10n.Common.codecAndRate(L10n.Settings.opus, L10n.Unit.kbps(config.opusBitrate / 1000))
            : L10n.Common.codecAndRate(L10n.Settings.pcmShort, L10n.Unit.kHz(Int(format.sampleRate)))
        return L10n.Common.joined([
            codec,
            format.channelCount == 2 ? L10n.Common.stereo : L10n.Common.mono,
            config.transport == .tcpUDP ? L10n.Activity.udp : L10n.Activity.tcp,
        ])
    }
}

/// Describes the active audio input for the Live Activity
enum InputText {
    static func current() -> (name: String, symbol: String)? {
        guard let port = AVAudioSession.sharedInstance().currentRoute.inputs.first else { return nil }
        switch port.portType {
        case .builtInMic:
            let isPad = UIDevice.current.userInterfaceIdiom == .pad
            return (L10n.Activity.builtInInput(UIDevice.current.model), isPad ? "ipad" : "iphone")
        case .bluetoothHFP, .bluetoothLE:
            let name = port.portName
            let symbol = name.contains("AirPods Pro") ? "airpodspro"
                : name.contains("AirPods Max") ? "airpodsmax"
                : name.contains("AirPods") ? "airpods" : "headphones"
            return (name, symbol)
        case .headsetMic: return (port.portName, "headphones")
        case .usbAudio: return (port.portName, "cable.connector")
        case .carAudio: return (port.portName, "car.fill")
        default: return (port.portName, "mic.fill")
        }
    }
}

/// Hands PCM from the capture thread to the current session and throttles level updates
final class SessionSink: @unchecked Sendable {
    private let lock = NSLock()
    private var session: StreamSession?
    private var peak: Float = -160
    private var lastPost: TimeInterval = 0

    func set(_ session: StreamSession?) {
        lock.withLock { self.session = session }
    }

    /// Returns the loudest block level about 30 times per second, the meter view smooths it per frame
    func push(_ pcm: Data, level: Float) -> Float? {
        let (session, value): (StreamSession?, Float?) = lock.withLock {
            peak = max(peak, level)
            let now = ProcessInfo.processInfo.systemUptime
            var value: Float?
            if now - lastPost >= 1.0 / 30 {
                lastPost = now
                value = peak
                peak = -160
            }
            return (self.session, value)
        }
        session?.push(pcm)
        return value
    }
}

enum FormatText {
    static func short(_ format: AudioStreamFormat) -> String {
        let codec = format.codec == .opus ? L10n.Settings.opus : L10n.Settings.pcmShort
        return L10n.Common.codecAndRate(codec, L10n.Unit.kHz(Int(format.sampleRate)))
    }
}
