// SPDX-License-Identifier: GPL-3.0-or-later

import AVFoundation
import MicYouShared
import SwiftUI

extension AVCaptureDevice.MicrophoneMode {
    /// Nil for modes newer than the SDK, rather than naming them wrongly
    var title: String? {
        switch self {
        case .standard: L10n.Settings.micModeStandard
        case .wideSpectrum: L10n.Settings.micModeWideSpectrum
        case .voiceIsolation: L10n.Settings.micModeVoiceIsolation
        @unknown default: nil
        }
    }
}

extension View {
    /// Keeps `mode` on the active system microphone mode, which only the system sheet can change
    /// The sheet sits over the app, so the mode is read again whenever the app becomes active
    func trackingMicrophoneMode(_ mode: Binding<AVCaptureDevice.MicrophoneMode>, while isActive: Bool) -> some View {
        modifier(MicrophoneModeTracker(mode: mode, isActive: isActive))
    }
}

private struct MicrophoneModeTracker: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var mode: AVCaptureDevice.MicrophoneMode
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { mode = AVCaptureDevice.activeMicrophoneMode }
            }
            .task(id: isActive) { mode = AVCaptureDevice.activeMicrophoneMode }
    }
}
