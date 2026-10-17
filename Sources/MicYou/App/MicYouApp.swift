// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

@main
struct MicYouApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Intents from the widget, Control Center and Shortcuts run here, also when the system
        // launched the app in the background for them
        IntentActions.handler = { link in AppModel.shared.handle(link) }
        // The app and MicYouShared are linked as static archives and nothing else refers to the
        // shortcuts, so this call is also what keeps them and the intents in the binary
        MicYouShortcuts.updateAppShortcutParameters()
    }

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
            if phase == .active {
                model.didBecomeActive()
            } else if phase == .background {
                model.browser.stop()
                // The icon's actions offer the computer selected last
                model.refreshQuickActions()
            }
        }
    }
}
