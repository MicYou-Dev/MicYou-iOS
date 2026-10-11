// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import MicYouCore
import MicYouShared
import UIKit

/// The microphone in use, shown in the Live Activity and the session stats
struct AudioInputInfo {
    var name: String
    /// SF Symbol for the device
    var symbol: String

    @MainActor
    static func current() -> AudioInputInfo? {
        guard let port = AVAudioSession.sharedInstance().currentRoute.inputs.first else { return nil }
        guard port.portType == .builtInMic else { return .init(name: port.portName, symbol: externalSymbol(for: port)) }
        // The front and back microphones are named, the bottom one is the usual case and keeps the device name
        let position = MicrophonePosition(port.selectedDataSource?.orientation)
        let name = position == .front || position == .back ? position!.title : builtInName
        return .init(name: name, symbol: builtInSymbol)
    }

    /// For example "iPhone Microphone"
    @MainActor
    static var builtInName: String {
        L10n.Activity.builtInInput(UIDevice.current.model)
    }

    @MainActor
    static var builtInSymbol: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
    }

    /// SF Symbol for anything but the built-in microphone
    static func externalSymbol(for port: AVAudioSessionPortDescription) -> String {
        switch port.portType {
        case .bluetoothHFP, .bluetoothLE:
            let name = port.portName
            return name.contains("AirPods Pro") ? "airpodspro"
                : name.contains("AirPods Max") ? "airpodsmax"
                : name.contains("AirPods") ? "airpods" : "headphones"
        case .headsetMic: return "headphones"
        case .usbAudio: return "cable.connector"
        case .carAudio: return "car.fill"
        default: return "mic.fill"
        }
    }
}
