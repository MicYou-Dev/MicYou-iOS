// SPDX-License-Identifier: GPL-3.0-or-later

import ActivityKit
import Foundation
import MicYouShared
import os

/// Drives the Lock Screen and Dynamic Island activity from the app process, no App Group needed
@MainActor
final class LiveActivityController {
    private let log = Logger(subsystem: "com.chouchiu.micyou", category: "activity")
    private var activity: Activity<StreamActivityAttributes>?
    private var lastState: StreamActivityAttributes.ContentState?
    private var lastUpdate = Date.distantPast
    /// Level only changes are pushed at most this often to stay within the system update budget
    private let levelInterval: TimeInterval = 1

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func update(serverName: String, state: StreamActivityAttributes.ContentState) {
        guard isAvailable else { return }
        if let activity, activity.attributes.serverName == serverName, activity.activityState == .active {
            guard state != lastState else { return }
            if var levelOnly = lastState {
                levelOnly.level = state.level
                if levelOnly == state, Date().timeIntervalSince(lastUpdate) < levelInterval { return }
            }
            lastState = state
            lastUpdate = Date()
            // Activity is not Sendable but its methods are safe to call from any context
            nonisolated(unsafe) let target = activity
            Task { await target.update(ActivityContent(state: state, staleDate: nil)) }
            return
        }
        end()
        do {
            activity = try Activity.request(
                attributes: StreamActivityAttributes(serverName: serverName),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
            lastState = state
            lastUpdate = Date()
        } catch {
            log.error("Live Activity request failed: \(error.localizedDescription)")
        }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        nonisolated(unsafe) let target = activity
        Task { await target.end(nil, dismissalPolicy: .immediate) }
    }

    /// Clears activities left over from a previous run that was killed
    func endStale() {
        for activity in Activity<StreamActivityAttributes>.activities {
            nonisolated(unsafe) let target = activity
            Task { await target.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
