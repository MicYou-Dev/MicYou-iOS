// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MicYouCore
import MicYouProtocol
import Network
import Observation

/// Persistent user preferences, read when a stream starts
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    static let sampleRates = [48000, 44100, 16000]
    static let opusBitrates = [32000, 64000, 96000, 128000]
    static let inputGainRange = 0.0...24.0
    static let recentHostLimit = 5

    private enum Key: String {
        case host, port, transport, codec, opusBitrate, sampleRate, stereo, voiceProcessing, inputGainDB, input
        case fecEnabled, autoReconnect, autoConnect, pushToTalk, keepScreenOn, liveActivity, recentHosts, lastServiceName, welcomeShown, tourShown
    }

    @ObservationIgnored private let defaults: UserDefaults

    var host: String { didSet { save(host, .host) } }
    var port: Int { didSet { save(port, .port) } }
    var transport: TransportMode { didSet { save(transport.rawValue, .transport) } }
    var codec: CodecChoice { didSet { save(codec.rawValue, .codec) } }
    var opusBitrate: Int { didSet { save(opusBitrate, .opusBitrate) } }
    var sampleRate: Int { didSet { save(sampleRate, .sampleRate) } }
    var stereo: Bool { didSet { save(stereo, .stereo) } }
    var voiceProcessing: Bool { didSet { save(voiceProcessing, .voiceProcessing) } }
    /// Software gain in dB, within inputGainRange
    var inputGainDB: Double { didSet { save(inputGainDB, .inputGainDB) } }
    /// The microphone to record from, applies immediately
    var input: InputPreference { didSet { save(input.storageValue, .input) } }
    var fecEnabled: Bool { didSet { save(fecEnabled, .fecEnabled) } }
    var autoReconnect: Bool { didSet { save(autoReconnect, .autoReconnect) } }
    /// Connects to the selected computer when the app opens
    var autoConnect: Bool { didSet { save(autoConnect, .autoConnect) } }
    /// Muted unless the talk button is held
    var pushToTalk: Bool { didSet { save(pushToTalk, .pushToTalk) } }
    var keepScreenOn: Bool { didSet { save(keepScreenOn, .keepScreenOn) } }
    var liveActivity: Bool { didSet { save(liveActivity, .liveActivity) } }
    var recentHosts: [String] { didSet { save(recentHosts, .recentHosts) } }
    /// Bonjour instance name of the last server picked from the list
    var lastServiceName: String? { didSet { save(lastServiceName, .lastServiceName) } }
    /// The welcome sheet appears once, on the first launch
    var welcomeShown: Bool { didSet { save(welcomeShown, .welcomeShown) } }
    /// The spotlight tour of the home screen follows the welcome sheet, also once
    var tourShown: Bool { didSet { save(tourShown, .tourShown) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        func load<T>(_ key: Key) -> T? { defaults.object(forKey: key.rawValue) as? T }
        host = load(.host) ?? ""
        port = load(.port) ?? Int(MicYouWire.defaultPort)
        transport = load(.transport).flatMap(TransportMode.init) ?? .tcpUDP
        codec = load(.codec).flatMap(CodecChoice.init) ?? .opus
        opusBitrate = load(.opusBitrate) ?? 64000
        sampleRate = load(.sampleRate) ?? 48000
        stereo = load(.stereo) ?? false
        voiceProcessing = load(.voiceProcessing) ?? false
        inputGainDB = load(.inputGainDB) ?? 6
        input = load(.input).map(InputPreference.init(storageValue:)) ?? .automatic
        fecEnabled = load(.fecEnabled) ?? true
        autoReconnect = load(.autoReconnect) ?? true
        autoConnect = load(.autoConnect) ?? false
        pushToTalk = load(.pushToTalk) ?? false
        keepScreenOn = load(.keepScreenOn) ?? false
        liveActivity = load(.liveActivity) ?? true
        recentHosts = load(.recentHosts) ?? []
        lastServiceName = load(.lastServiceName)
        // Anyone who connected before this sheet existed has already found their way
        // Read again rather than through the properties, which are not all set yet
        let hosts: [String] = load(.recentHosts) ?? []
        let service: String? = load(.lastServiceName)
        welcomeShown = load(.welcomeShown) ?? (!hosts.isEmpty || service != nil)
        tourShown = load(.tourShown) ?? (!hosts.isEmpty || service != nil)
    }

    /// The manual fields as an address, nil while they are empty or invalid
    /// A port typed into the address field, as in "192.168.1.5:8554" or "[fe80::1]:8554", wins over the port field
    var manualTarget: ServerAddress? {
        ServerAddress(parsing: host, defaultPort: port)
    }

    /// True when something is typed but cannot be used, for an inline hint
    var manualInputInvalid: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && manualTarget == nil
    }

    /// Shows the welcome sheet and the tour again, from the about page
    func replayIntroduction() {
        welcomeShown = false
        tourShown = false
    }

    func rememberHost(_ host: String) {
        var hosts = recentHosts.filter { $0 != host }
        hosts.insert(host, at: 0)
        recentHosts = Array(hosts.prefix(Self.recentHostLimit))
    }

    private func save(_ value: Any?, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }
}

extension AppSettings {
    func apply(_ preset: StreamPreset) {
        transport = preset.transport
        codec = preset.codec
        if preset.codec == .opus { opusBitrate = preset.opusBitrate }
        sampleRate = preset.sampleRate
    }

    /// Rate actually sent, Opus maps 44.1 kHz to 48 kHz
    var streamSampleRate: Int {
        codec.streamRate(forCaptureRate: sampleRate)
    }

    /// The current audio and transport choices
    var streamOptions: StreamOptions {
        StreamOptions(
            transport: transport,
            codec: codec,
            sampleRate: streamSampleRate,
            channels: stereo ? 2 : 1,
            opusBitrate: opusBitrate,
            fecEnabled: fecEnabled
        )
    }

    /// Freezes the current choices for one stream
    func streamConfig(endpoint: NWEndpoint, preferIPv4: Bool) -> StreamConfig {
        StreamConfig(endpoint: endpoint, preferIPv4: preferIPv4, options: streamOptions)
    }

    /// The preset the current settings match, nil once something was changed by hand
    var matchingPreset: StreamPreset? {
        StreamPreset.matching(transport: transport, codec: codec, sampleRate: sampleRate, opusBitrate: opusBitrate)
    }
}
