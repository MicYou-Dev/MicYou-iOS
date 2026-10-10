// SPDX-License-Identifier: GPL-3.0-or-later

@preconcurrency import AVFoundation
import Foundation
import os

struct CaptureConfig: Equatable, Sendable {
    var sampleRate: Double
    var channels: AVAudioChannelCount
    var voiceProcessing: Bool
}

enum CaptureError: LocalizedError {
    case permissionDenied
    case noInput
    case converterUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied: String(localized: "Microphone access is off. Turn it on in Settings.")
        case .noInput: String(localized: "No microphone is available.")
        case .converterUnavailable: String(localized: "This audio format is not supported.")
        }
    }
}

/// Captures the microphone and delivers interleaved little-endian Int16 PCM in the requested format
/// Thread safety: public methods are called from the main actor, the tap runs on an AVAudioEngine thread
final class AudioCapture: @unchecked Sendable {
    /// PCM bytes and the RMS level of the block in dBFS
    typealias Handler = @Sendable (_ pcm: Data, _ levelDB: Float) -> Void

    private let log = Logger(subsystem: "com.chouchiu.micyou", category: "capture")
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var upmix = false
    private var handler: Handler?
    private var config: CaptureConfig?
    private var observers: [NSObjectProtocol] = []
    private var pendingRestart: DispatchWorkItem?
    private var lastRestart: Date?
    private(set) var isRunning = false

    init() {}

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    static func requestPermission() async -> Bool {
        await AVAudioApplication.requestRecordPermission()
    }

    func start(_ config: CaptureConfig, handler: @escaping Handler) throws {
        stop()
        guard AVAudioApplication.shared.recordPermission == .granted else { throw CaptureError.permissionDenied }
        self.config = config
        lock.withLock { self.handler = handler }
        try configureSession(config)
        try startEngine(config)
        observeSession()
        isRunning = true
    }

    func stop() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        pendingRestart?.cancel()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        lock.withLock {
            handler = nil
            converter = nil
        }
        if isRunning {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
        isRunning = false
        config = nil
    }

    // MARK: Session

    private func configureSession(_ config: CaptureConfig) throws {
        let session = AVAudioSession.sharedInstance()
        // measurement keeps the raw signal, voiceChat enables echo cancellation and noise suppression
        let mode: AVAudioSession.Mode = config.voiceProcessing ? .voiceChat : .measurement
        try session.setCategory(.playAndRecord, mode: mode, options: [.defaultToSpeaker, .allowBluetoothHFP, .mixWithOthers])
        try? session.setPreferredSampleRate(config.sampleRate)
        try? session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)
        if config.channels == 2 {
            preferStereoBuiltInMic(session)
        }
    }

    /// The built-in mic records stereo only when a data source with a stereo polar pattern is selected
    private func preferStereoBuiltInMic(_ session: AVAudioSession) {
        guard let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else { return }
        do {
            try session.setPreferredInput(builtIn)
            if let source = builtIn.dataSources?.first(where: { $0.supportedPolarPatterns?.contains(.stereo) == true }) {
                try source.setPreferredPolarPattern(.stereo)
                try builtIn.setPreferredDataSource(source)
            }
            try session.setPreferredInputNumberOfChannels(min(2, session.maximumInputNumberOfChannels))
            let orientation: AVAudioSession.StereoOrientation = .portrait
            try session.setPreferredInputOrientation(orientation)
        } catch {
            log.notice("Stereo capture unavailable: \(error.localizedDescription)")
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
            let converted = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: config.sampleRate,
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
        log.info("Capture started: \(inputFormat.sampleRate) Hz x\(inputFormat.channelCount) -> \(config.sampleRate) Hz x\(config.channels)")
    }

    /// Coalesces bursts of notifications and ignores the ones our own restart causes
    private func scheduleRestart() {
        pendingRestart?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.restart() }
        pendingRestart = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }

    private func restart() {
        guard isRunning, let config, let handler = lock.withLock({ self.handler }) else { return }
        if let last = lastRestart, Date().timeIntervalSince(last) < 1 { return }
        lastRestart = Date()
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        do {
            try configureSession(config)
            lock.withLock { self.handler = handler }
            try startEngine(config)
        } catch {
            log.error("Capture restart failed: \(error.localizedDescription)")
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        let level = Self.rmsDB(buffer)
        let (converter, format, upmix, handler) = lock.withLock { (self.converter, self.outputFormat, self.upmix, self.handler) }
        guard let converter, let format, let handler else { return }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }

        var consumed = false
        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, inputStatus in
            if consumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            inputStatus.pointee = .haveData
            return buffer
        }
        guard status != .error, out.frameLength > 0, let samples = out.int16ChannelData?[0] else { return }

        let count = Int(out.frameLength) * Int(format.channelCount)
        var data: Data
        if upmix {
            data = Data(count: count * 4)
            data.withUnsafeMutableBytes { raw in
                let dst = raw.bindMemory(to: Int16.self)
                for i in 0..<count {
                    dst[2 * i] = samples[i].littleEndian
                    dst[2 * i + 1] = samples[i].littleEndian
                }
            }
        } else {
            data = Data(bytes: samples, count: count * 2)
        }
        handler(data, level)
    }

    static func rmsDB(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return -160 }
        let n = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<n { sum += channel[i] * channel[i] }
        let rms = (sum / Float(n)).squareRoot()
        return rms > 0 ? max(-160, 20 * log10(rms)) : -160
    }

    // MARK: Interruptions

    private func observeSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification, object: session, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            self?.scheduleRestart()
        })
        observers.append(center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: session, queue: .main) { [weak self] _ in
            self?.scheduleRestart()
        })
        // Fires when the input hardware changes, for example a headset is plugged in
        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            self?.scheduleRestart()
        })
    }
}
