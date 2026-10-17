// SPDX-License-Identifier: GPL-3.0-or-later
// Control Center buttons, also offered for the Action button. Their Live Activity intents run
// in the app without opening it. Without an App Group the controls cannot read the app's state,
// so their icons stay the same

import AppIntents
import MicYouShared
import SwiftUI
import WidgetKit

struct ConnectionControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.chouchiu.micyou.toggle") {
            ControlWidgetButton(action: ToggleConnectionIntent()) {
                Label(L10n.App.name, systemImage: "mic.fill")
            }
        }
        .displayName(L10n.Control.toggleName)
        .description(L10n.Control.toggleDescription)
    }
}

struct MuteControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.chouchiu.micyou.toggle-mute") {
            ControlWidgetButton(action: ToggleMuteIntent()) {
                Label(L10n.Common.mute, systemImage: "mic.slash.fill")
            }
        }
        .displayName(L10n.Intent.muteTitle)
        .description(L10n.Intent.muteDescription)
    }
}
