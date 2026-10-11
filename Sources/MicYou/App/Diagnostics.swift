// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import Foundation
import UIKit

/// Facts about the app, device and settings that help with a bug report
/// Always English so reports read the same whatever the language, never contains addresses or device names
enum Diagnostics {
    static var version: String { info("CFBundleShortVersionString") }
    static var build: String { info("CFBundleVersion") }

    /// App, system and device on one line, for reports that do not need the settings
    @MainActor
    static var summary: String {
        let device = UIDevice.current
        return "MicYou \(version) (\(build)), \(device.systemName) \(device.systemVersion), \(machine)"
    }

    @MainActor
    static func report(model: AppModel) -> String {
        let settings = model.settings
        let device = UIDevice.current
        let transport = settings.transport == .tcpUDP ? "TCP + UDP" : "TCP"
        let codec = settings.codec == .opus ? "Opus \(settings.opusBitrate / 1000) kbps" : "PCM"
        let selection = switch model.selection {
        case .discovered: "Bonjour"
        case .manual: "manual address"
        }
        // The port type rather than the port name, Bluetooth names often carry the owner's name
        let input = AVAudioSession.sharedInstance().currentRoute.inputs.first?.portType.rawValue ?? "none"
        var lines = [
            "MicYou \(version) (\(build))\(hasExtensions ? "" : ", without extensions")",
            "\(device.systemName) \(device.systemVersion), \(machine)",
            "Language: \(Locale.preferredLanguages.first ?? "?")",
            "Connection: \(selection), \(phase(model.phase))\(model.captureStatus == .running ? "" : ", microphone interrupted")",
            "Transport: \(transport), FEC \(onOff(settings.fecEnabled)), auto reconnect \(onOff(settings.autoReconnect))",
            "Audio: \(codec), \(settings.sampleRate) Hz, \(settings.stereo ? "stereo" : "mono")",
            "Microphone: \(input), gain +\(Int(settings.inputGainDB)) dB, voice processing \(onOff(settings.voiceProcessing))",
        ]
        if case .failed(let message) = model.phase {
            lines.append("Last error: \(message)")
        }
        return lines.joined(separator: "\n")
    }

    private static func info(_ key: String) -> String {
        Bundle.main.infoDictionary?[key] as? String ?? "?"
    }

    private static func onOff(_ value: Bool) -> String { value ? "on" : "off" }

    @MainActor
    private static func phase(_ phase: ConnectionPhase) -> String {
        switch phase {
        case .idle: "idle"
        case .connecting: "connecting"
        case .streaming: "streaming"
        case .reconnecting(let attempt): "reconnecting \(attempt)/\(AppModel.maxReconnectAttempts)"
        case .failed: "failed"
        }
    }

    /// Model identifier such as iPhone17,1, UIDevice only says iPhone
    private static var machine: String {
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: system.machine) { bytes in
            String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// False for the LiveContainer build, which has the widget extension removed
    private static var hasExtensions: Bool {
        guard let plugins = Bundle.main.builtInPlugInsURL,
              let contents = try? FileManager.default.contentsOfDirectory(atPath: plugins.path)
        else { return false }
        return !contents.isEmpty
    }
}

/// New GitHub issues from the forms in .github/ISSUE_TEMPLATE, with the environment field filled in
/// The keys are field ids in those forms, GitHub only prefills text inputs and text areas
enum IssueReport {
    @MainActor
    static func bug(model: AppModel) -> URL {
        ProjectLinks.newIssue(template: "bug_report.yml", fields: ["environment": Diagnostics.report(model: model)])
    }

    @MainActor
    static func feature() -> URL {
        ProjectLinks.newIssue(template: "feature_request.yml", fields: ["environment": Diagnostics.summary])
    }
}
