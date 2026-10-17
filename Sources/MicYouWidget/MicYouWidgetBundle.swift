// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WidgetKit

@main
struct MicYouWidgetBundle: WidgetBundle {
    var body: some Widget {
        StreamLiveActivity()
        ShortcutWidget()
        ConnectionControl()
        MuteControl()
    }
}
