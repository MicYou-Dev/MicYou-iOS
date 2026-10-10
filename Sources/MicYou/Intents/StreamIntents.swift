// SPDX-License-Identifier: GPL-3.0-or-later
// Note: xtool cannot run Apple's appintentsmetadataprocessor, so the system may not list
// these intents. micyou:// URLs (see DeepLink) are the fallback for Shortcuts.

import AppIntents

struct StartStreamingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Streaming"
    static let description = IntentDescription("Connects to the last used computer and starts streaming the microphone.")
    // Recording can only start while the app is in the foreground
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        await AppModel.shared.connect()
        return .result()
    }
}

struct StopStreamingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Streaming"
    static let description = IntentDescription("Disconnects from the computer.")

    @MainActor
    func perform() async throws -> some IntentResult {
        AppModel.shared.disconnect()
        return .result()
    }
}

struct ToggleMuteIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Mute"
    static let description = IntentDescription("Mutes or unmutes the microphone while streaming.")

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
            shortTitle: "Start Streaming",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopStreamingIntent(),
            phrases: ["Stop \(.applicationName)"],
            shortTitle: "Stop Streaming",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: ToggleMuteIntent(),
            phrases: ["Mute \(.applicationName)"],
            shortTitle: "Toggle Mute",
            systemImageName: "mic.slash.fill"
        )
    }
}
