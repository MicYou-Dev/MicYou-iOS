// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// The session in the iPad menu bar, also listed when holding Command on a hardware keyboard
struct StreamCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandMenu(L10n.Menu.stream) {
            Button(connectTitle) {
                model.toggleConnection()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!model.isActive && !model.canConnect)

            // Command M minimizes the window on iPadOS 26
            Button(model.isMuted ? L10n.Common.unmute : L10n.Common.mute) {
                model.toggleMute()
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            .disabled(!model.isActive)

            Button(L10n.Dim.button) {
                model.setDimmed(true)
            }
            .disabled(!model.isActive || model.isDimmed)
        }
    }

    private var connectTitle: String {
        if !model.isActive { return L10n.Common.connect }
        return model.phase == .streaming ? L10n.Common.disconnect : L10n.Common.cancel
    }
}
