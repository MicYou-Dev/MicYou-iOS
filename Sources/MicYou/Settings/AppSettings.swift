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

/// A computer entered by hand
struct ManualTarget: Equatable {
    var host: String
    var port: UInt16
}

/// Persistent user preferences, read when a stream starts
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()

    static let sampleRates = [48000, 44100, 16000]
    static let opusBitrates = [32000, 64000, 96000, 128000]
    static let inputGainRange = 0.0...24.0
    static let portRange = 1...65535
    static let recentHostLimit = 5

    private enum Key: String {
        case host, port, transport, codec, opusBitrate, sampleRate, stereo, voiceProcessing, inputGainDB
        case fecEnabled, autoReconnect, keepScreenOn, liveActivity, recentHosts, lastServiceName
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
    var fecEnabled: Bool { didSet { save(fecEnabled, .fecEnabled) } }
    var autoReconnect: Bool { didSet { save(autoReconnect, .autoReconnect) } }
    var keepScreenOn: Bool { didSet { save(keepScreenOn, .keepScreenOn) } }
    var liveActivity: Bool { didSet { save(liveActivity, .liveActivity) } }
    var recentHosts: [String] { didSet { save(recentHosts, .recentHosts) } }
    /// Bonjour instance name of the last server picked from the list
    var lastServiceName: String? { didSet { save(lastServiceName, .lastServiceName) } }

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
        fecEnabled = load(.fecEnabled) ?? true
        autoReconnect = load(.autoReconnect) ?? true
        keepScreenOn = load(.keepScreenOn) ?? false
        liveActivity = load(.liveActivity) ?? true
        recentHosts = load(.recentHosts) ?? []
        lastServiceName = load(.lastServiceName)
    }

    /// The manual fields as a target, nil while they are empty or invalid
    /// A port typed into the address field, as in "192.168.1.5:8554" or "[fe80::1]:8554", wins over the port field
    var manualTarget: ManualTarget? {
        let text = host.trimmingCharacters(in: .whitespacesAndNewlines)
        var name = text
        var port = self.port
        if text.hasPrefix("["), let close = text.firstIndex(of: "]") {
            name = String(text[text.index(after: text.startIndex)..<close])
            let rest = text[text.index(after: close)...]
            if rest.hasPrefix(":") {
                guard let typed = Int(rest.dropFirst()) else { return nil }
                port = typed
            } else if !rest.isEmpty {
                return nil
            }
        } else if text.count(where: { $0 == ":" }) == 1, let colon = text.firstIndex(of: ":") {
            // More than one colon is a bare IPv6 address
            guard let typed = Int(text[text.index(after: colon)...]) else { return nil }
            name = String(text[..<colon])
            port = typed
        }
        guard !name.isEmpty, Self.portRange.contains(port) else { return nil }
        return ManualTarget(host: name, port: UInt16(port))
    }

    /// True when something is typed but cannot be used, for an inline hint
    var manualInputInvalid: Bool {
        !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && manualTarget == nil
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

/// One tap combinations of the connection and audio settings, channels and FEC stay as they are
enum StreamPreset: CaseIterable, Identifiable {
    case lowLatency
    case stable
    case lossless

    var id: Self { self }

    var transport: TransportMode {
        self == .stable ? .tcp : .tcpUDP
    }

    var codec: CodecChoice {
        self == .lossless ? .pcm : .opus
    }

    var opusBitrate: Int {
        self == .stable ? 96000 : 64000
    }

    var sampleRate: Int { 48000 }
}

extension AppSettings {
    func apply(_ preset: StreamPreset) {
        transport = preset.transport
        codec = preset.codec
        if preset.codec == .opus { opusBitrate = preset.opusBitrate }
        sampleRate = preset.sampleRate
    }

    /// The preset the current settings match, nil once something was changed by hand
    var matchingPreset: StreamPreset? {
        StreamPreset.allCases.first { preset in
            transport == preset.transport && codec == preset.codec && sampleRate == preset.sampleRate
                && (codec == .pcm || opusBitrate == preset.opusBitrate)
        }
    }
}
