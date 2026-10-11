// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import MicYouCore
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

/// Whether audio is reaching the stream while connected
enum CaptureStatus: Equatable {
    case running
    /// A call or another app has the microphone, capture restarts when it is done
    case interrupted
    /// Restarting failed, for example because recording cannot start in the background
    case resumeFailed
}

/// Where to connect: a Bonjour result, a typed address or the USB cable
enum ServerSelection: Hashable {
    case discovered(name: String)
    case manual
    /// The desktop in USB mode connects through usbmuxd
    case usb
}

/// App wide state, also used by intents and deep links
@MainActor @Observable
final class AppModel {
    static let shared = AppModel()
    static let reconnectPolicy = ReconnectPolicy.standard
    static var maxReconnectAttempts: Int { reconnectPolicy.maxAttempts }

    let settings = AppSettings.shared
    let browser = ServerBrowser()

    private(set) var phase: ConnectionPhase = .idle
    private(set) var isMuted = false
    /// Smoothed input level in dBFS
    private(set) var levelDB: Float = -160
    private(set) var throughput = 0
    /// Link quality reported by the desktop, nil until it sends some, older desktops never do
    private(set) var linkStats: StatsMessage?
    private(set) var remoteAddress: String?
    private(set) var activeFormat: AudioStreamFormat?
    private(set) var streamingSince: Date?
    private(set) var connectedName: String?
    /// The microphone in use, follows headsets coming and going
    private(set) var audioInput: AudioInputInfo?
    private(set) var captureStatus: CaptureStatus = .running
    /// A black screen covers the app while streaming, it keeps the display on but dark
    private(set) var isDimmed = false
    /// Microphones to pick from, refreshed when a picker appears and when devices come and go
    private(set) var inputOptions: [InputOption] = []
    /// One-off message, for example when Opus is not available
    var notice: String?
    var selection: ServerSelection {
        didSet {
            if case .discovered(let name) = selection { settings.lastServiceName = name } else { settings.lastServiceName = nil }
            settings.usbSelected = selection == .usb
            clearError()
        }
    }

    @ObservationIgnored private let log = Logger.micyou("model")
    @ObservationIgnored private let capture = AudioCapture()
    @ObservationIgnored private let sink = SessionSink()
    @ObservationIgnored private let liveActivity = LiveActivityController()
    @ObservationIgnored private var session: StreamSession?
    @ObservationIgnored private var sessionToken: UUID?
    @ObservationIgnored private var currentConfig: StreamConfig?
    @ObservationIgnored private var reconnectTask: Task<Void, Never>?
    @ObservationIgnored private var hasStreamed = false
    /// Set while capture is running or starting, a stale start that fails later is ignored
    @ObservationIgnored private var captureToken: UUID?
    /// Identifies the current connect, so one that waited on the permission prompt can tell it was superseded
    @ObservationIgnored private var connectToken: UUID?
    /// Connect on launch is considered once per process
    @ObservationIgnored private var launchHandled = false
    /// A link or shortcut opened the app, it decides whether to connect
    @ObservationIgnored private var openedByLink = false
    /// Voice processing of the running capture, which keeps going across reconnects
    private var captureVoiceProcessing: Bool?

    init() {
        selection = settings.usbSelected ? .usb : settings.lastServiceName.map { .discovered(name: $0) } ?? .manual
        liveActivity.endStale()
        // The Live Activity shows the microphone in use, so follow headsets coming and going
        NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.refreshSideEffects()
                // Only once a picker has asked, listing inputs sets the session category
                if !self.inputOptions.isEmpty { self.refreshInputOptions() }
            }
        }
        // Swiping the app away kills the process, the system keeps the activity unless it is ended first
        // Sent while streaming because the audio background mode keeps the app running rather than suspended
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            LiveActivityController.endAllBeforeExit()
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
            // Usable before the search finds it again, the connection resolves the name itself
            return DiscoveredServer.displayName(for: name)
        case .manual:
            return settings.manualTarget?.host
        case .usb:
            return L10n.Home.usbName
        }
    }

    var canConnect: Bool { selectedName != nil }

    /// Settings of the running stream, edits in AppSettings only apply to the next one
    var streamConfig: StreamConfig? { isActive ? currentConfig : nil }

    // MARK: Actions

    func toggleConnection() {
        if isActive { disconnect() } else { Task { await connect() } }
    }

    func connect() async {
        guard !isActive else { return }
        notice = nil
        // Claim the connecting state before awaiting so a second tap is ignored
        phase = .connecting
        await begin()
    }

    func disconnect() {
        if isActive { log.info("Disconnected") }
        stopStream()
        phase = .idle
        isDimmed = false
        refreshSideEffects()
    }

    func setDimmed(_ value: Bool) {
        isDimmed = value && isActive
        refreshSideEffects()
    }

    /// Starts over with the current settings, the session screen and the Live Activity stay up meanwhile
    func restart() {
        guard isActive else { return }
        log.info("Restarting with the current settings")
        stopStream()
        phase = .connecting
        refreshSideEffects()
        Task { await begin() }
    }

    /// The running capture uses voice processing, which is what system microphone modes apply to
    var isVoiceProcessingActive: Bool { captureVoiceProcessing == true }

    /// The running stream was started with settings that have changed since
    var hasPendingChanges: Bool {
        guard isActive, let config = currentConfig else { return false }
        let voiceProcessingChanged = captureVoiceProcessing.map { $0 != settings.voiceProcessing } ?? false
        return config.options.differs(from: settings.streamOptions(for: config.link)) || voiceProcessingChanged
    }

    private func begin() async {
        let token = UUID()
        connectToken = token
        // Push to talk starts silent, the session tells the computer right after the handshake
        if settings.pushToTalk { isMuted = true }
        guard await AudioCapture.requestPermission() else {
            if connectToken == token { phase = .failed(CaptureError.permissionDenied.localizedDescription) }
            return
        }
        // Disconnect or a restart may have happened while the permission prompt was up
        guard connectToken == token, phase == .connecting else { return }
        guard let target = resolveTarget() else {
            phase = .failed(L10n.Failure.chooseTarget)
            return
        }
        let config = settings.streamConfig(link: target.link)
        let kind = switch selection {
        case .discovered: "nearby computer"
        case .manual: "address"
        case .usb: "USB"
        }
        log.info("Connecting to \(kind, privacy: .public) \(target.name): \(config.options.summary, privacy: .public)")
        currentConfig = config
        connectedName = target.name
        hasStreamed = false
        refreshSideEffects()
        openSession()
    }

    /// Ends the session and capture and clears what they reported, the caller sets the phase
    private func stopStream() {
        connectToken = nil
        reconnectTask?.cancel()
        reconnectTask = nil
        tearDownSession()
        captureToken = nil
        captureVoiceProcessing = nil
        capture.stop()
        streamingSince = nil
        activeFormat = nil
        remoteAddress = nil
        throughput = 0
        linkStats = nil
        levelDB = -160
        captureStatus = .running
    }

    /// Asks capture to try again, for an interruption that never reported its end or a restart that failed
    func resumeCapture() {
        guard isActive, captureStatus != .running else { return }
        capture.resume()
    }

    /// The app came to the foreground
    func didBecomeActive() {
        browser.start()
        // Recording may not restart from the background, so a resume that failed there is tried again now
        // A running interruption is left alone, a call still holds the microphone and ends it by itself
        if captureStatus == .resumeFailed { resumeCapture() }
        connectOnLaunchIfNeeded()
    }

    private func connectOnLaunchIfNeeded() {
        guard !launchHandled else { return }
        launchHandled = true
        // Not before the introduction has been seen, the first connection is part of it
        guard settings.autoConnect, settings.welcomeShown, settings.tourShown else { return }
        Task {
            // A link from Shortcuts or the Live Activity arrives right after launch and wins
            try? await Task.sleep(for: .milliseconds(500))
            guard !openedByLink, phase == .idle, canConnect else { return }
            log.info("Connecting on launch")
            await connect()
        }
    }

    func setMuted(_ value: Bool) {
        guard isMuted != value else { return }
        log.info("\(value ? "Muted" : "Unmuted", privacy: .public)")
        isMuted = value
        session?.setMuted(value, notifyPeer: true)
        refreshSideEffects()
    }

    /// Applies immediately while streaming
    func setInputGain(_ dB: Double) {
        settings.inputGainDB = dB
        capture.setGain(dB: dB)
    }

    /// Applies immediately while streaming
    func setInput(_ preference: InputPreference) {
        log.info("Input set to \(preference.anonymized, privacy: .public)")
        settings.input = preference
        capture.setInput(preference)
    }

    /// The options for the input pickers, the saved choice included even while its device is away
    var inputChoices: [InputOption] {
        let options = inputOptions.isEmpty ? [.automatic] : inputOptions
        if options.contains(where: { $0.preference == settings.input }) { return options }
        return options + [.unavailable(settings.input)]
    }

    func refreshInputOptions() {
        let capture = self.capture
        Task {
            let ports = await capture.inputPorts()
            inputOptions = InputOption.list(ports)
        }
    }

    /// Turning push to talk on mutes a running stream until the talk button is held
    func setPushToTalk(_ value: Bool) {
        settings.pushToTalk = value
        if value && isActive { setMuted(true) }
    }

    /// The screen rotated, only iPad allows it
    func orientationChanged() {
        capture.setStereoOrientation(Self.stereoOrientation)
    }

    /// The interface orientation as a stereo orientation, the two enums share their raw values
    private static var stereoOrientation: AVAudioSession.StereoOrientation {
        let scene = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first
        let orientation = scene?.effectiveGeometry.interfaceOrientation ?? .portrait
        return AVAudioSession.StereoOrientation(rawValue: orientation.rawValue) ?? .portrait
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    func handle(_ link: DeepLink) {
        openedByLink = true
        switch link {
        case .connect: Task { await connect() }
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

    private struct Target {
        var link: StreamLink
        var name: String
    }

    private func resolveTarget() -> Target? {
        switch selection {
        case .discovered(let name):
            // Right after launch, for example from Shortcuts, the search has not found the computer yet
            let endpoint = browser.servers.first { $0.name == name }?.endpoint ?? DiscoveredServer.endpoint(for: name)
            return Target(link: .network(endpoint, preferIPv4: true), name: DiscoveredServer.displayName(for: name))
        case .manual:
            guard let address = settings.manualTarget, let port = NWEndpoint.Port(rawValue: address.port) else { return nil }
            settings.rememberHost(settings.host.trimmingCharacters(in: .whitespacesAndNewlines))
            let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(address.host), port: port)
            return Target(link: .network(endpoint, preferIPv4: false), name: address.host)
        case .usb:
            // The desktop connects to the port it serves on, the same one the manual fields use
            guard let port = NWEndpoint.Port(rawValue: UInt16(clamping: settings.port)), port.rawValue != 0 else { return nil }
            return Target(link: .usb(port: port), name: L10n.Home.usbName)
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
            let codec = format.codec == .opus ? "Opus" : "PCM"
            let reconnected = if case .reconnecting = phase { true } else { false }
            log.info("\(reconnected ? "Reconnected" : "Streaming", privacy: .public), sending \(codec, privacy: .public) \(format.sampleRate) Hz x\(format.channelCount)")
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
                log.info("\(value ? "Muted" : "Unmuted", privacy: .public) by the computer")
                isMuted = value
                refreshSideEffects()
            }
        case .throughput(let bits):
            throughput = bits
        case .linkStats(let stats):
            linkStats = stats
        case .codecFallback:
            notice = L10n.Failure.opusUnavailable
            activeFormat?.codec = .pcm
        case .failed(let error):
            log.error("Session failed: \(String(describing: error), privacy: .public)")
            tearDownSession()
            scheduleReconnectOrFail(error)
        }
    }

    private func startCaptureIfNeeded(_ config: StreamConfig) {
        guard captureToken == nil else { return }
        let token = UUID()
        captureToken = token
        captureVoiceProcessing = settings.voiceProcessing
        let sink = self.sink
        let captureConfig = CaptureConfig(
            sampleRate: Double(config.sampleRate),
            channels: AVAudioChannelCount(config.channels),
            voiceProcessing: settings.voiceProcessing,
            input: settings.input,
            stereoOrientation: Self.stereoOrientation
        )
        capture.setGain(dB: settings.inputGainDB)
        let handler: AudioCapture.Handler = { [weak self] pcm, level in
            if let smoothed = sink.push(pcm, level: level) {
                Task { @MainActor in
                    if self?.isActive == true { self?.levelDB = smoothed }
                }
            }
        }
        let onEvent: AudioCapture.EventHandler = { [weak self] event in
            Task { @MainActor in self?.handle(event, token: token) }
        }
        // Starts on the capture queue, the main thread stays free for the connect animation
        let capture = self.capture
        Task { [weak self] in
            do {
                try await capture.start(captureConfig, handler: handler, onEvent: onEvent)
            } catch {
                // Disconnected or restarted while the start was pending
                guard let self, captureToken == token else { return }
                disconnect()
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func handle(_ event: AudioCapture.Event, token: UUID) {
        guard captureToken == token, isActive else { return }
        switch event {
        case .interrupted:
            captureStatus = .interrupted
            levelDB = -160
        case .resumed:
            captureStatus = .running
        case .resumeFailed:
            captureStatus = .resumeFailed
            levelDB = -160
        }
        refreshSideEffects()
    }

    private func scheduleReconnectOrFail(_ error: StreamError) {
        let attempt: Int = if case .reconnecting(let n) = phase { n + 1 } else { 1 }
        let policy = Self.reconnectPolicy
        guard policy.shouldRetry(attempt: attempt, enabled: settings.autoReconnect, hasStreamed: hasStreamed, errorIsTransient: error.isTransient) else {
            log.notice("Not reconnecting, auto reconnect \(self.settings.autoReconnect ? "on" : "off", privacy: .public), attempt \(attempt)")
            disconnect()
            phase = .failed(error.localizedDescription)
            return
        }
        // Capture keeps running so the app stays alive in the background while retrying
        phase = .reconnecting(attempt: attempt)
        throughput = 0
        linkStats = nil
        refreshSideEffects()
        let delay = policy.delay(beforeAttempt: attempt)
        log.notice("Reconnecting in \(Int(delay)) s, attempt \(attempt) of \(policy.maxAttempts)")
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, case .reconnecting = self.phase else { return }
            self.openSession()
        }
    }

    // MARK: Side effects

    private func refreshSideEffects() {
        // A dimmed screen that turns itself off would only be a slower way to lock
        UIApplication.shared.isIdleTimerDisabled = (settings.keepScreenOn || isDimmed) && isActive
        audioInput = isActive ? AudioInputInfo.current() : nil

        guard settings.liveActivity, isActive, let name = connectedName else {
            liveActivity.end()
            return
        }
        let activityPhase: StreamActivityAttributes.Phase
        var attempt = 0
        switch phase {
        case .streaming: activityPhase = captureStatus == .running ? .streaming : .interrupted
        case .reconnecting(let n): activityPhase = .reconnecting; attempt = n
        default: activityPhase = .connecting
        }
        var detail = ""
        if let format = activeFormat, let config = currentConfig {
            detail = StreamText.activityDetail(format, opusBitrate: config.opusBitrate, transport: config.transport)
        }
        let input = audioInput
        liveActivity.update(serverName: name, state: .init(
            phase: activityPhase,
            isMuted: isMuted,
            startedAt: streamingSince ?? .now,
            detail: detail,
            input: input?.name ?? "",
            inputSymbol: input?.symbol ?? "mic.fill",
            attempt: attempt,
            maxAttempts: Self.maxReconnectAttempts
        ))
    }
}
