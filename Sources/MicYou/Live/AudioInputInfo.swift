// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import MicYouShared
import UIKit

/// The microphone in use, shown in the Live Activity
struct AudioInputInfo {
    var name: String
    /// SF Symbol for the device
    var symbol: String

    @MainActor
    static func current() -> AudioInputInfo? {
        guard let port = AVAudioSession.sharedInstance().currentRoute.inputs.first else { return nil }
        switch port.portType {
        case .builtInMic:
            let device = UIDevice.current
            return .init(name: L10n.Activity.builtInInput(device.model),
                         symbol: device.userInterfaceIdiom == .pad ? "ipad" : "iphone")
        case .bluetoothHFP, .bluetoothLE:
            let name = port.portName
            let symbol = name.contains("AirPods Pro") ? "airpodspro"
                : name.contains("AirPods Max") ? "airpodsmax"
                : name.contains("AirPods") ? "airpods" : "headphones"
            return .init(name: name, symbol: symbol)
        case .headsetMic: return .init(name: port.portName, symbol: "headphones")
        case .usbAudio: return .init(name: port.portName, symbol: "cable.connector")
        case .carAudio: return .init(name: port.portName, symbol: "car.fill")
        default: return .init(name: port.portName, symbol: "mic.fill")
        }
    }
}
