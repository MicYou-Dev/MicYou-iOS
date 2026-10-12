// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import UIKit

/// The actions on a long press of the home screen icon, set from code so they follow the connection
/// Each one is a deep link, handled the same way as the Live Activity buttons and Shortcuts
@MainActor
enum QuickActions {
    static func update(isActive: Bool, isMuted: Bool, target: String?) {
        var items: [UIApplicationShortcutItem] = []
        if isActive {
            items.append(item(.disconnect, title: L10n.Common.disconnect, symbol: "stop.fill"))
            items.append(isMuted
                ? item(.unmute, title: L10n.Common.unmute, symbol: "mic.fill")
                : item(.mute, title: L10n.Common.mute, symbol: "mic.slash.fill"))
        } else if let target {
            items.append(item(.connect, title: L10n.Common.connect, subtitle: target, symbol: "mic.fill"))
        }
        let application = UIApplication.shared
        // Comparing the parts that matter, setting the same items again still makes SpringBoard update them
        let current = application.shortcutItems ?? []
        guard current.map(\.type) != items.map(\.type) || current.map(\.localizedSubtitle) != items.map(\.localizedSubtitle) else { return }
        application.shortcutItems = items
    }

    /// False for an item from an older version that is no longer a link
    @discardableResult
    static func perform(_ item: UIApplicationShortcutItem) -> Bool {
        guard let link = DeepLink(rawValue: item.type) else { return false }
        AppModel.shared.handle(link)
        return true
    }

    private static func item(_ link: DeepLink, title: String, subtitle: String? = nil, symbol: String) -> UIApplicationShortcutItem {
        UIApplicationShortcutItem(
            type: link.rawValue, localizedTitle: title, localizedSubtitle: subtitle,
            icon: UIApplicationShortcutIcon(systemImageName: symbol), userInfo: nil
        )
    }
}

/// SwiftUI has no hook for quick actions, the scene delegate receives them
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    /// Launched by a quick action
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem { QuickActions.perform(item) }
    }

    /// Already running
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        completionHandler(QuickActions.perform(shortcutItem))
    }
}
