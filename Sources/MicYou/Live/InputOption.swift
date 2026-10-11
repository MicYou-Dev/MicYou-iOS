// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import MicYouCore
import MicYouShared
import UIKit

extension MicrophonePosition {
    var orientation: AVAudioSession.Orientation {
        switch self {
        case .bottom: .bottom
        case .front: .front
        case .back: .back
        }
    }

    init?(_ orientation: AVAudioSession.Orientation?) {
        switch orientation {
        case .bottom?: self = .bottom
        case .front?: self = .front
        case .back?: self = .back
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .bottom: L10n.Input.bottom
        case .front: L10n.Input.front
        case .back: L10n.Input.back
        }
    }
}

/// What the capture queue reads about an input port, turned into options on the main actor
struct InputPort: Sendable {
    var uid: String
    var name: String
    var isBuiltIn: Bool
    /// Built-in microphones by position, empty when the hardware does not say
    var positions: [MicrophonePosition]
    /// SF Symbol of an external device
    var symbol: String

    init(_ port: AVAudioSessionPortDescription) {
        uid = port.uid
        name = port.portName
        isBuiltIn = port.portType == .builtInMic
        positions = (port.dataSources ?? []).compactMap { MicrophonePosition($0.orientation) }
        symbol = AudioInputInfo.externalSymbol(for: port)
    }
}

/// A microphone offered in the input pickers
struct InputOption: Identifiable, Hashable, Sendable {
    let preference: InputPreference
    let name: String
    /// SF Symbol for the device
    let symbol: String

    var id: String { preference.storageValue }

    static var automatic: InputOption {
        InputOption(preference: .automatic, name: L10n.Input.automatic, symbol: "wand.and.stars")
    }

    /// Automatic first, then each built-in position, then everything plugged in or paired
    @MainActor
    static func list(_ ports: [InputPort]) -> [InputOption] {
        var options = [automatic]
        for port in ports {
            if port.isBuiltIn {
                let symbol = AudioInputInfo.builtInSymbol
                if port.positions.isEmpty {
                    options.append(InputOption(preference: .builtIn(nil), name: AudioInputInfo.builtInName, symbol: symbol))
                } else {
                    // Listed in a fixed order rather than the order the hardware reports
                    for position in MicrophonePosition.allCases where port.positions.contains(position) {
                        options.append(InputOption(preference: .builtIn(position), name: position.title, symbol: symbol))
                    }
                }
            } else {
                options.append(InputOption(preference: .external(uid: port.uid), name: port.name, symbol: port.symbol))
            }
        }
        return options
    }

    /// Stands in for a saved device that is not connected, so pickers still show the selection
    static func unavailable(_ preference: InputPreference) -> InputOption {
        InputOption(preference: preference, name: L10n.Input.unavailable, symbol: "questionmark")
    }
}
