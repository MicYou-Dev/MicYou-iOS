// SPDX-License-Identifier: GPL-3.0-or-later

import ActivityKit
import Foundation
import MicYouShared
import os

/// Drives the Lock Screen and Dynamic Island activity from the app process, no App Group needed
@MainActor
final class LiveActivityController {
    private let log = Logger.micyou("activity")
    private var activity: Activity<StreamActivityAttributes>?
    private var lastState: StreamActivityAttributes.ContentState?

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func update(serverName: String, state: StreamActivityAttributes.ContentState) {
        guard isAvailable else { return }
        if let activity, activity.attributes.serverName == serverName, activity.activityState == .active {
            guard state != lastState else { return }
            lastState = state
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

    /// Ends every activity before the process exits, for example when the app is swiped away
    /// The main thread is blocked here, so the requests run detached and the wait is bounded
    nonisolated static func endAllBeforeExit() {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            for activity in Activity<StreamActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2)
    }

    /// Clears activities left over from a run that ended without a termination notice, such as a crash
    func endStale() {
        for activity in Activity<StreamActivityAttributes>.activities {
            nonisolated(unsafe) let target = activity
            Task { await target.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
