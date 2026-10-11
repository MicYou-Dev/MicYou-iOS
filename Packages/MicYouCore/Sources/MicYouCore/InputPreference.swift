// SPDX-License-Identifier: GPL-3.0-or-later

/// Where a built-in microphone sits, matching the data source orientations iOS reports
public enum MicrophonePosition: String, CaseIterable, Sendable {
    case bottom
    case front
    case back
}

/// The microphone to record from, kept in the settings
public enum InputPreference: Hashable, Sendable {
    /// Whatever the system routes to, headsets take over when they connect
    case automatic
    /// The built-in microphone, at a given position or wherever the system picks
    case builtIn(MicrophonePosition?)
    /// A headset, USB or Bluetooth device by its port UID, automatic while it is not connected
    case external(uid: String)

    /// For UserDefaults, unknown values read back as automatic
    public var storageValue: String {
        switch self {
        case .automatic: "automatic"
        case .builtIn(nil): "builtIn"
        case .builtIn(let position?): "builtIn.\(position.rawValue)"
        case .external(let uid): "external.\(uid)"
        }
    }

    public init(storageValue: String) {
        if storageValue == "builtIn" {
            self = .builtIn(nil)
        } else if storageValue.hasPrefix("builtIn."), let position = MicrophonePosition(rawValue: String(storageValue.dropFirst("builtIn.".count))) {
            self = .builtIn(position)
        } else if storageValue.hasPrefix("external."), storageValue.count > "external.".count {
            self = .external(uid: String(storageValue.dropFirst("external.".count)))
        } else {
            self = .automatic
        }
    }
}
