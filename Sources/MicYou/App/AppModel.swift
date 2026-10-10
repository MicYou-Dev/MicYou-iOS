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
                phase = .failed(String(localized: "Choose a computer or enter its address first."))
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
            notice = String(localized: "Opus is not available on this device, streaming PCM instead.")
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
        let activityPhase: StreamActivityAttributes.Phase = switch phase {
        case .streaming: .streaming
        case .reconnecting: .reconnecting
        default: .connecting
        }
        liveActivity.update(serverName: name, state: .init(
            phase: activityPhase,
            isMuted: isMuted,
            startedAt: streamingSince ?? .now,
            detail: activeFormat.map(FormatText.short) ?? ""
        ))
    }
}

/// Hands PCM from the capture thread to the current session and throttles level updates
final class SessionSink: @unchecked Sendable {
    private let lock = NSLock()
    private var session: StreamSession?
    private var smoothed: Float = -160
    private var lastPost: TimeInterval = 0

    func set(_ session: StreamSession?) {
        lock.withLock { self.session = session }
    }

    /// Returns a level to publish about 15 times per second
    func push(_ pcm: Data, level: Float) -> Float? {
        let (session, value): (StreamSession?, Float?) = lock.withLock {
            // Fast attack, slow release, like a VU meter
            smoothed = level > smoothed ? level : smoothed * 0.8 + level * 0.2
            let now = ProcessInfo.processInfo.systemUptime
            var value: Float?
            if now - lastPost >= 1.0 / 15 {
                lastPost = now
                value = smoothed
            }
            return (self.session, value)
        }
        session?.push(pcm)
        return value
    }
}

enum FormatText {
    static func short(_ format: AudioStreamFormat) -> String {
        let codec = format.codec == .opus ? "Opus" : "PCM"
        let khz = Double(format.sampleRate) / 1000
        let rate = khz == khz.rounded() ? String(Int(khz)) : String(format: "%.1f", khz)
        return "\(codec) \(rate) kHz"
    }
}
