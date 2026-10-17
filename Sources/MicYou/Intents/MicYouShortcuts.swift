// SPDX-License-Identifier: GPL-3.0-or-later
// The intents live in MicYouShared so the widget can perform them too. Phrases and short
// titles stay literals for Tools/appintents-metadata.py, like the intents' own strings

import AppIntents
import MicYouShared

struct MicYouShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartStreamingIntent(),
            phrases: ["Start \(.applicationName)", "Connect \(.applicationName)"],
            shortTitle: "intent.start.title",
            systemImageName: "mic.fill"
        )
        AppShortcut(
            intent: StopStreamingIntent(),
            phrases: ["Stop \(.applicationName)"],
            shortTitle: "intent.stop.title",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: ToggleMuteIntent(),
            phrases: ["Mute \(.applicationName)"],
            shortTitle: "intent.mute.title",
            systemImageName: "mic.slash.fill"
        )
    }
}
