// SPDX-License-Identifier: GPL-3.0-or-later
// Shared by the app and the widget, whose buttons and controls perform these. Live Activity
// intents run in the app's process, launched in the background if needed, and the ones that
// connect open the app first, so perform hands the action to the app through IntentActions and
// never runs in the extension
//
// Tools/appintents-metadata.py indexes these from the compiler's const values, which only
// records literals: titles and descriptions are therefore string table keys written out here
// instead of L10n properties, and Tools/check-strings.py checks them. Keep them in this one
// file, the app links the archive member of the whole file as soon as it refers to one intent

import AppIntents

/// Runs intent actions in the app, which sets the handler at launch
@MainActor
public enum IntentActions {
    public static var handler: (@MainActor (DeepLink) async throws -> Void)?

    static func perform(_ link: DeepLink) async throws {
        // Only nil in the extension, which the system never runs these in
        guard let handler else { throw IntentActionError.notInApp }
        try await handler(link)
    }
}

enum IntentActionError: Error {
    case notInApp
}

/// The system refuses to start recording from the background, so connecting opens the app
public struct StartStreamingIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.start.title"
    public static let description = IntentDescription("intent.start.description")
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try await IntentActions.perform(.connect)
        return .result()
    }
}

public struct StopStreamingIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "intent.stop.title"
    public static let description = IntentDescription("intent.stop.description")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try await IntentActions.perform(.disconnect)
        return .result()
    }
}

public struct ToggleMuteIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "intent.mute.title"
    public static let description = IntentDescription("intent.mute.description")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try await IntentActions.perform(.toggleMute)
        return .result()
    }
}

/// For the Control Center button, which cannot show whether the app is connected. It opens the
/// app like StartStreamingIntent, disconnecting included, as one intent cannot do both
public struct ToggleConnectionIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.toggle.title"
    public static let description = IntentDescription("intent.toggle.description")
    // Shortcuts lists starting and stopping separately
    public static let isDiscoverable = false
    public static let openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        try await IntentActions.perform(.toggle)
        return .result()
    }
}
