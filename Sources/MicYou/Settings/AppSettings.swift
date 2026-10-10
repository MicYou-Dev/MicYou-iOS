// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import MicYouProtocol
import Observation

enum TransportMode: String, CaseIterable, Identifiable, Sendable {
    /// Control over TCP, audio over UDP, the desktop default
    case tcpUDP
    /// Everything over the TCP connection
    case tcp

    var id: Self { self }
}

enum CodecChoice: String, CaseIterable, Identifiable, Sendable {
    case opus
    case pcm

    var id: Self { self }
}

/// Persistent user preferences, read when a stream starts
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    static let sampleRates = [48000, 44100, 16000]
    static let opusBitrates = [32000, 64000, 96000, 128000]

    @ObservationIgnored private let defaults: UserDefaults

    var host: String { didSet { save(host, "host") } }
    var port: Int { didSet { save(port, "port") } }
    var transport: TransportMode { didSet { save(transport.rawValue, "transport") } }
    var codec: CodecChoice { didSet { save(codec.rawValue, "codec") } }
    var opusBitrate: Int { didSet { save(opusBitrate, "opusBitrate") } }
    var sampleRate: Int { didSet { save(sampleRate, "sampleRate") } }
    var stereo: Bool { didSet { save(stereo, "stereo") } }
    var voiceProcessing: Bool { didSet { save(voiceProcessing, "voiceProcessing") } }
    /// Software gain in dB, 0...24
    var inputGainDB: Double { didSet { save(inputGainDB, "inputGainDB") } }
    var fecEnabled: Bool { didSet { save(fecEnabled, "fecEnabled") } }
    var autoReconnect: Bool { didSet { save(autoReconnect, "autoReconnect") } }
    var keepScreenOn: Bool { didSet { save(keepScreenOn, "keepScreenOn") } }
    var liveActivity: Bool { didSet { save(liveActivity, "liveActivity") } }
    var recentHosts: [String] { didSet { save(recentHosts, "recentHosts") } }
    /// Bonjour instance name of the last server picked from the list
    var lastServiceName: String? { didSet { save(lastServiceName, "lastServiceName") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        host = defaults.string(forKey: "host") ?? ""
        port = defaults.object(forKey: "port") as? Int ?? Int(MicYouWire.defaultPort)
        transport = defaults.string(forKey: "transport").flatMap(TransportMode.init) ?? .tcpUDP
        codec = defaults.string(forKey: "codec").flatMap(CodecChoice.init) ?? .opus
        opusBitrate = defaults.object(forKey: "opusBitrate") as? Int ?? 64000
        sampleRate = defaults.object(forKey: "sampleRate") as? Int ?? 48000
        stereo = defaults.object(forKey: "stereo") as? Bool ?? false
        voiceProcessing = defaults.object(forKey: "voiceProcessing") as? Bool ?? false
        inputGainDB = defaults.object(forKey: "inputGainDB") as? Double ?? 6
        fecEnabled = defaults.object(forKey: "fecEnabled") as? Bool ?? true
        autoReconnect = defaults.object(forKey: "autoReconnect") as? Bool ?? true
        keepScreenOn = defaults.object(forKey: "keepScreenOn") as? Bool ?? false
        liveActivity = defaults.object(forKey: "liveActivity") as? Bool ?? true
        recentHosts = defaults.stringArray(forKey: "recentHosts") ?? []
        lastServiceName = defaults.string(forKey: "lastServiceName")
    }

    func rememberHost(_ host: String) {
        var hosts = recentHosts.filter { $0 != host }
        hosts.insert(host, at: 0)
        recentHosts = Array(hosts.prefix(5))
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
    }
}
