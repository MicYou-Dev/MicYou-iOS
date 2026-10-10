// SPDX-License-Identifier: GPL-3.0-or-later
// Note: xtool cannot run Apple's appintentsmetadataprocessor, so the system may not list
// these intents. micyou:// URLs (see DeepLink) are the fallback for Shortcuts.

import AppIntents
import MicYouShared

struct StartStreamingIntent: AppIntent {
    static let title = L10n.Intent.startTitle
    static let description = IntentDescription(L10n.Intent.startDescription)
    // Recording can only start while the app is in the foreground
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppModel.shared.connect()
        return .result()
    }
}

struct StopStreamingIntent: AppIntent {
    static let title = L10n.Intent.stopTitle
    static let description = IntentDescription(L10n.Intent.stopDescription)

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.disconnect()
        return .result()
    }
}

struct ToggleMuteIntent: AppIntent {
    static let title = L10n.Intent.muteTitle
    static let description = IntentDescription(L10n.Intent.muteDescription)

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.toggleMute()
        return .result()
    }
}

struct MicYouShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStreamingIntent(),
            phrases: ["Start \(.applicationName)", "Connect \(.applicationName)"],
            shortTitle: L10n.Intent.startTitle,
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopStreamingIntent(),
            phrases: ["Stop \(.applicationName)"],
            shortTitle: L10n.Intent.stopTitle,
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: ToggleMuteIntent(),
            phrases: ["Mute \(.applicationName)"],
            shortTitle: L10n.Intent.muteTitle,
            systemImageName: "mic.slash.fill"
        )
    }
}
