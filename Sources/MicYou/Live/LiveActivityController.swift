// SPDX-License-Identifier: GPL-3.0-or-later

import ActivityKit
import Foundation
import MicYouShared
import os

/// Drives the Lock Screen and Dynamic Island activity from the app process, no App Group needed
@MainActor
final class LiveActivityController {
    private typealias State = StreamActivityAttributes.ContentState

    private let log = Logger.micyou("activity")
    private var activity: Activity<StreamActivityAttributes>?
    /// Server of the shown or requested activity
    private var serverName: String?
    private var lastState: State?
    private var request: Task<Void, Never>?

    private var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func update(serverName: String, state: StreamActivityAttributes.ContentState) {
        guard isAvailable else { return }
        // The user can swipe the activity away while streaming, request a new one then
        let dismissed = activity.map { $0.activityState != .active } ?? false
        if serverName == self.serverName, !dismissed {
            guard state != lastState else { return }
            lastState = state
            // While a request is in flight it sends the latest state once it lands
            if let activity { Self.push(state, to: activity) }
            return
        }
        end()
        self.serverName = serverName
        lastState = state
        request = Task { [weak self] in
            // Requesting blocks on a round trip to the system, off the main thread it cannot stall the connect animation
            let result = await Task.detached(priority: .userInitiated) {
                Result {
                    Unchecked(try Activity.request(
                        attributes: StreamActivityAttributes(serverName: serverName),
                        content: ActivityContent(state: state, staleDate: nil),
                        pushType: nil
                    ))
                }
            }.value
            self?.finishRequest(result, requested: state)
        }
    }

    func end() {
        request?.cancel()
        request = nil
        serverName = nil
        lastState = nil
        guard let activity else { return }
        self.activity = nil
        Self.dismiss(activity)
    }

    private func finishRequest(_ result: Result<Unchecked<Activity<StreamActivityAttributes>>, any Error>, requested: State) {
        switch result {
        case .success(let box):
            // Ended or replaced while waiting
            guard !Task.isCancelled else { return Self.dismiss(box.value) }
            activity = box.value
            if let lastState, lastState != requested { Self.push(lastState, to: box.value) }
        case .failure(let error):
            log.error("Live Activity request failed: \(String(describing: error), privacy: .public)")
            guard !Task.isCancelled else { return }
            // The next update tries again
            serverName = nil
            lastState = nil
        }
        request = nil
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
        Activity<StreamActivityAttributes>.activities.forEach(Self.dismiss)
    }

    // Activity is not Sendable but its methods are safe to call from any context

    private static func push(_ state: State, to activity: Activity<StreamActivityAttributes>) {
        nonisolated(unsafe) let target = activity
        Task { await target.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private static func dismiss(_ activity: Activity<StreamActivityAttributes>) {
        nonisolated(unsafe) let target = activity
        Task { await target.end(nil, dismissalPolicy: .immediate) }
    }
}

/// Carries a non Sendable value whose methods are thread safe across an isolation boundary
private struct Unchecked<Value>: @unchecked Sendable {
    let value: Value

    init(_ value: Value) { self.value = value }
}
