// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

@main
struct MicYouApp: App {
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(model)
                .environment(model.settings)
                .onOpenURL { url in
                    if let link = DeepLink(url: url) { model.handle(link) }
                }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // Browsing only matters while the list is visible
            if phase == .active { model.didBecomeActive() } else if phase == .background { model.browser.stop() }
        }
    }
}
