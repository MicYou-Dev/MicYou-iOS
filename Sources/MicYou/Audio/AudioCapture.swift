// SPDX-License-Identifier: GPL-3.0-or-later

@preconcurrency import AVFoundation
import Foundation
import MicYouCore
import MicYouShared
import os

struct CaptureConfig: Equatable, Sendable {
    var sampleRate: Double
    var channels: AVAudioChannelCount
    var voiceProcessing: Bool
    /// Full bandwidth recording from AirPods that support it on iOS 26, the system ignores it for other routes
    var highQualityBluetooth: Bool
    var input: InputPreference
    /// How the device is held, so stereo from the built-in microphones keeps left on the left
    var stereoOrientation: AVAudioSession.StereoOrientation
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case noInput
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: L10n.Failure.micDenied
        case .noInput: L10n.Failure.noMicrophone
        case .converterUnavailable: L10n.Failure.formatUnsupported
        }
    }
}

/// Captures the microphone and delivers interleaved little-endian Int16 PCM in the requested format
/// Thread safety: session and engine work runs on a private serial queue, the tap on an AVAudioEngine thread,
/// and the two share the converter, gain and handler under a lock
final class AudioCapture: @unchecked Sendable {
    /// PCM bytes and the RMS level of the block in dBFS
    typealias Handler = @Sendable (_ pcm: Data, _ levelDB: Float) -> Void

    enum Event: Sendable {
        /// A call or another app took the microphone, no audio arrives until it is resumed
        case interrupted
        case resumed
        /// The engine could not be restarted, `resume()` tries again
        case resumeFailed
        /// The system input mute changed, for example with a press on the AirPods stem
        case systemMute(Bool)
    }

    typealias EventHandler = @Sendable (Event) -> Void

    private let log = Logger.micyou("capture")
    private let engine = AVAudioEngine()
    /// Activating the session and starting the engine block for a round trip to the audio server,
    /// often longer than an animation frame, so none of it runs on the main thread
    private let queue = DispatchQueue(label: "com.chouchiu.micyou.capture", qos: .userInitiated)
    private let notificationQueue = OperationQueue()
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var upmix = false
    private var gain: Float = 1
    // Only touched on the tap thread
    private var processor = SampleProcessor()
    /// Reused while the format and block size stay the same
    private var converted: AVAudioPCMBuffer?
    private var handler: Handler?
    // Only touched on queue
    private var config: CaptureConfig?
    private var onEvent: EventHandler?
    private var observers: [NSObjectProtocol] = []
    private var pendingRestart: DispatchWorkItem?
    /// The pending restart follows an interruption or a request, not an echo of our own restart
    private var restartForced = false
    private var lastRestart: Date?
    private var isRunning = false
    /// Stopped by an interruption or a failed restart, until a restart succeeds
    private var isInterrupted = false

    init() {
        notificationQueue.underlyingQueue = queue
        notificationQueue.maxConcurrentOperationCount = 1
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    /// Resumes once the engine runs, calls are applied in order with stop
    func start(_ config: CaptureConfig, handler: @escaping Handler, onEvent: @escaping EventHandler) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    try self.startOnQueue(config, handler: handler, onEvent: onEvent)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Returns at once, the engine stops on the capture queue after any start that is still running
    func stop() {
        queue.async { self.stopOnQueue() }
    }

    /// Switches the microphone, a running engine restarts on the new one
    func setInput(_ preference: InputPreference) {
        queue.async {
            guard self.isRunning, var config = self.config, config.input != preference else { return }
            config.input = preference
            self.config = config
            // An interrupted engine picks the new input up when it resumes
            if !self.isInterrupted { self.scheduleRestart(force: true) }
        }
    }

    /// Switches Bluetooth high quality recording, a running engine restarts with it
    func setHighQualityBluetooth(_ enabled: Bool) {
        queue.async {
            guard self.isRunning, var config = self.config, config.highQualityBluetooth != enabled else { return }
            config.highQualityBluetooth = enabled
            self.config = config
            if !self.isInterrupted { self.scheduleRestart(force: true) }
        }
    }

    /// Keeps the system input mute equal to the app's, so a press on the AirPods stem toggles from the right state
    /// The system zeroes the samples while muted, the stream is silent then anyway
    /// Set before capture starts it is stored and applied once the session is active
    func setSystemMuted(_ muted: Bool) {
        queue.async {
            guard AVAudioApplication.shared.isInputMuted != muted else { return }
            do {
                try AVAudioApplication.shared.setInputMuted(muted)
            } catch {
                self.log.notice("Setting the system input mute failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Follows the interface orientation, which only changes on iPad
    func setStereoOrientation(_ orientation: AVAudioSession.StereoOrientation) {
        queue.async {
            guard var config = self.config, config.stereoOrientation != orientation else { return }
            config.stereoOrientation = orientation
            self.config = config
            guard self.isRunning, config.channels == 2 else { return }
            do {
                try AVAudioSession.sharedInstance().setPreferredInputOrientation(orientation)
            } catch {
                self.log.notice("Setting the stereo orientation failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Microphones the user can pick from, read on the capture queue since the session may need its category first
    func inputPorts() async -> [InputPort] {
        await withCheckedContinuation { continuation in
            queue.async {
                let session = AVAudioSession.sharedInstance()
                // Only a recording category lists inputs, a running capture has set it already
                if !self.isRunning && session.category != .playAndRecord {
                    try? session.setCategory(.playAndRecord, mode: .default, options: Self.baseCategoryOptions)
                }
                continuation.resume(returning: (session.availableInputs ?? []).map(InputPort.init))
            }
        }
    }

    /// Tries again after an interruption that did not end cleanly, for example once the app is back in the foreground
    func resume() {
        queue.async {
            guard self.isRunning, self.isInterrupted else { return }
            self.scheduleRestart(force: true)
        }
    }

    // MARK: Lifecycle, always on queue

    private func startOnQueue(_ config: CaptureConfig, handler: @escaping Handler, onEvent: @escaping EventHandler) throws {
        stopOnQueue()
        guard AVAudioApplication.shared.recordPermission == .granted else { throw CaptureError.permissionDenied }
        self.config = config
        self.onEvent = onEvent
        lock.withLock { self.handler = handler }
        try configureSession(config)
        try startEngine(config)
        observeSession()
        isRunning = true
    }

    private func stopOnQueue() {
        if isRunning { log.info("Capture stopped") }
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        pendingRestart?.cancel()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.withLock {
            handler = nil
            converter = nil
        }
        // Also after a start that failed halfway, the session may already be active
        if config != nil {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            // The mute is stored for the next session otherwise
            try? AVAudioApplication.shared.setInputMuted(false)
        }
        isRunning = false
        isInterrupted = false
        restartForced = false
        config = nil
        onEvent = nil
    }

    // MARK: Session

    private func configureSession(_ config: CaptureConfig) throws {
        let session = AVAudioSession.sharedInstance()
        // voiceChat enables echo cancellation, noise suppression and AGC
        // measurement would bypass the system input gain and sounds far too quiet
        let mode: AVAudioSession.Mode = config.voiceProcessing ? .voiceChat : .default
        try session.setCategory(.playAndRecord, mode: mode, options: Self.categoryOptions(config))
        try? session.setPreferredSampleRate(config.sampleRate)
        try? session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)
        applyInput(config, session: session)
    }

    private static let baseCategoryOptions: AVAudioSession.CategoryOptions = [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers]

    /// High quality Bluetooth only works in the default mode, voice processing keeps the call quality link
    /// With HFP allowed as well, routes that cannot record in high quality fall back to it
    private static func categoryOptions(_ config: CaptureConfig) -> AVAudioSession.CategoryOptions {
        var options = baseCategoryOptions
        if #available(iOS 26, *), config.highQualityBluetooth, !config.voiceProcessing {
            options.insert(.bluetoothHighQualityRecording)
        }
        return options
    }

    /// Routes the chosen microphone, falling back to the system choice when it is not connected
    private func applyInput(_ config: CaptureConfig, session: AVAudioSession) {
        let inputs = session.availableInputs ?? []
        let builtIn = inputs.first { $0.portType == .builtInMic }
        do {
            switch config.input {
            case .external(let uid):
                try session.setPreferredInput(inputs.first { $0.uid == uid })
            case .builtIn(let position):
                guard let builtIn else { return try session.setPreferredInput(nil) }
                try preferBuiltIn(builtIn, position: position, config: config, session: session)
            case .automatic:
                // Stereo needs the built-in microphones, headsets record mono
                if config.channels == 2, let builtIn {
                    try preferBuiltIn(builtIn, position: nil, config: config, session: session)
                } else {
                    try session.setPreferredInput(nil)
                }
            }
        } catch {
            log.notice("Selecting the input failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// The built-in mic records stereo only when a data source with a stereo polar pattern is selected
    private func preferBuiltIn(_ port: AVAudioSessionPortDescription, position: MicrophonePosition?, config: CaptureConfig, session: AVAudioSession) throws {
        try session.setPreferredInput(port)
        let sources = port.dataSources ?? []
        let chosen = position.flatMap { position in sources.first { $0.orientation == position.orientation } }
        guard config.channels == 2 else {
            if let chosen { try port.setPreferredDataSource(chosen) }
            return
        }
        // The chosen position keeps priority, stereo only when it can record it, otherwise any data source that can
        let candidates = chosen.map { [$0] } ?? sources
        guard let source = candidates.first(where: { $0.supportedPolarPatterns?.contains(.stereo) == true }) else {
            if let chosen { try port.setPreferredDataSource(chosen) }
            // What the hardware offers in this mode, voice processing for one may leave out the stereo pattern
            let offered = sources.map { source in
                "\(source.dataSourceName) [\((source.supportedPolarPatterns ?? []).map(\.rawValue).joined(separator: ", "))]"
            }
            let place = position.map { " at the \($0.rawValue)" } ?? ""
            log.notice("No stereo data source\(place, privacy: .public), recording mono: mode \(session.mode.rawValue, privacy: .public), sources \(offered.joined(separator: "; "), privacy: .public)")
            return
        }
        do {
            try source.setPreferredPolarPattern(.stereo)
            try port.setPreferredDataSource(source)
            try session.setPreferredInputNumberOfChannels(min(2, session.maximumInputNumberOfChannels))
            try session.setPreferredInputOrientation(config.stereoOrientation)
            log.info("Recording stereo from the \(source.dataSourceName, privacy: .public) data source")
        } catch {
            log.notice("Setting up stereo failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: Engine

    private func startEngine(_ config: CaptureConfig) throws {
        let input = engine.inputNode
        if input.isVoiceProcessingEnabled != config.voiceProcessing {
            try input.setVoiceProcessingEnabled(config.voiceProcessing)
        }
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw CaptureError.noInput }

        // Convert at most the channels the hardware has, mono is duplicated by hand
        let convertChannels = min(config.channels, inputFormat.channelCount)
        guard
            let converted = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: config.sampleRate,
                                          channels: convertChannels, interleaved: true),
            let converter = AVAudioConverter(from: inputFormat, to: converted)
        else { throw CaptureError.converterUnavailable }
        converter.downmix = inputFormat.channelCount > convertChannels
        converter.sampleRateConverterQuality = AVAudioQuality.high.rawValue

        lock.withLock {
            self.converter = converter
            self.outputFormat = converted
            self.upmix = convertChannels < config.channels
        }

        let frames = AVAudioFrameCount(inputFormat.sampleRate / 50)
        input.installTap(onBus: 0, bufferSize: frames, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        engine.prepare()
        try engine.start()
        // The port type rather than the port name, Bluetooth names often carry the owner's name
        let route = AVAudioSession.sharedInstance().currentRoute.inputs.first
        var port = route?.portType.rawValue ?? "none"
        if #available(iOS 26, *), route?.bluetoothMicrophoneExtension?.highQualityRecording.isEnabled == true {
            port += " in high quality"
        }
        log.info("Capture started: \(port, privacy: .public) at \(Int(inputFormat.sampleRate)) Hz x\(inputFormat.channelCount), sending \(Int(config.sampleRate)) Hz x\(config.channels)")
    }

    /// Coalesces bursts of notifications and ignores the ones our own restart causes
    /// Forced restarts, after an interruption ends or on request, always run
    private func scheduleRestart(force: Bool = false) {
        // The microphone belongs to someone else until the interruption ends
        if isInterrupted && !force { return }
        restartForced = restartForced || force
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.restart() }
        pendingRestart = work
        queue.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func restart() {
        let forced = restartForced
        restartForced = false
        guard isRunning, let config else { return }
        if !forced, let last = lastRestart, Date().timeIntervalSince(last) < 1 { return }
        lastRestart = Date()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        do {
            try configureSession(config)
            try startEngine(config)
            if isInterrupted {
                isInterrupted = false
                log.info("Capture resumed")
                onEvent?(.resumed)
            }
        } catch {
            // Starting to record from the background is not allowed, the app tries again once it is opened
            log.error("Restarting capture failed: \(String(describing: error), privacy: .public)")
            isInterrupted = true
            onEvent?(.resumeFailed)
        }
    }

    private func interruptionBegan() {
        guard isRunning, !isInterrupted else { return }
        pendingRestart?.cancel()
        restartForced = false
        isInterrupted = true
        log.notice("Capture interrupted")
        onEvent?(.interrupted)
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        let (converter, format, upmix, handler, gain) = lock.withLock {
            (self.converter, self.outputFormat, self.upmix, self.handler, self.gain)
        }
        guard let converter, let format, let handler else { return }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let out = outputBuffer(format: format, capacity: capacity) else { return }

        var error: NSError?
        let status = converter.convert(to: out, feeding: buffer, error: &error)
        // Interleaved float, so channel 0 points at the whole buffer
        guard status != .error, out.frameLength > 0, let samples = out.floatChannelData?[0] else { return }

        let count = Int(out.frameLength) * Int(format.channelCount)
        let result = processor.process(UnsafeBufferPointer(start: samples, count: count), gain: gain, duplicate: upmix)
        handler(result.pcm, result.levelDB)
    }

    /// A converter output buffer, allocated again only when the format changes or a block is larger than before
    private func outputBuffer(format: AVAudioFormat, capacity: AVAudioFrameCount) -> AVAudioPCMBuffer? {
        if let converted, converted.format == format, converted.frameCapacity >= capacity {
            converted.frameLength = 0
            return converted
        }
        converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity)
        return converted
    }

    /// Software input gain in dB, applied before the limiter, safe to change while running
    func setGain(dB: Double) {
        let linear = SampleProcessor.linearGain(dB: dB)
        lock.withLock { gain = linear }
    }

    // MARK: Interruptions

    private func observeSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: notificationQueue) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }
            switch type {
            case .began: self?.interruptionBegan()
            // Recording resumes whether or not the system suggests it, that is what the user started
            case .ended: self?.scheduleRestart(force: true)
            @unknown default: break
            }
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: notificationQueue) { [weak self] _ in
            self?.scheduleRestart(force: true)
        })
        observers.append(center.addObserver(forName: AVAudioApplication.inputMuteStateChangeNotification, object: nil, queue: notificationQueue) { [weak self] note in
            guard let muted = note.userInfo?[AVAudioApplication.muteStateKey] as? Bool else { return }
            self?.onEvent?(.systemMute(muted))
        })
        // Fires when the input hardware changes, for example a headset is plugged in
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: notificationQueue) { [weak self] _ in
            self?.scheduleRestart()
        })
    }
}
