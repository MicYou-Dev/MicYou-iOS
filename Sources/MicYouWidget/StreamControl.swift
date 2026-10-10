// SPDX-License-Identifier: GPL-3.0-or-later
// Control Center button, opens micyou://toggle through the system OpenURLIntent

import AppIntents
import MicYouShared
import SwiftUI
import WidgetKit

struct StreamControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.chouchiu.micyou.toggle") {
            ControlWidgetButton(action: OpenURLIntent(DeepLink.toggle.url)) {
                Label("MicYou", systemImage: "mic.fill")
            }
        }
        .displayName("MicYou")
        .description("Start or stop streaming to your computer.")
    }
}
