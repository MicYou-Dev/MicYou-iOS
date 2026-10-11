// SPDX-License-Identifier: GPL-3.0-or-later
// Looks for a newer release on GitHub, the same source the Android and desktop apps use
// A sideloaded app cannot install updates itself, so a new release only links to its page

import Foundation
import MicYouCore
import Observation
import os

@MainActor @Observable
final class UpdateChecker {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case failed
    }

    private(set) var state: State = .idle

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let log = Logger.micyou("update")
    private nonisolated static let api = URL(string: "https://api.github.com/repos/MicYou-Dev/MicYou-iOS/releases/latest")!

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// The release the home screen points at, until it is dismissed
    var notice: AppRelease? {
        guard case .available(let release) = state, settings.dismissedUpdate != release.version.description else { return nil }
        return release
    }

    func dismissNotice() {
        guard let release = notice else { return }
        settings.dismissedUpdate = release.version.description
    }

    /// On opening the app, at most once a day and only while automatic checks are on
    func checkIfDue() {
        guard settings.autoCheckUpdates, UpdateSchedule.isDue(lastCheck: settings.lastUpdateCheck) else { return }
        check()
    }

    func check() {
        guard state != .checking, let current = AppVersion(Diagnostics.version) else { return }
        state = .checking
        let userAgent = "MicYou-iOS/\(current)"
        Task {
            do {
                let release = try await Self.latestRelease(userAgent: userAgent)
                settings.lastUpdateCheck = .now
                if release.isNewer(than: current) {
                    log.info("Version \(release.version.description, privacy: .public) is available, running \(current.description, privacy: .public)")
                    state = .available(release)
                } else {
                    state = .upToDate
                }
            } catch {
                log.error("Update check failed: \(String(describing: error), privacy: .public)")
                state = .failed
            }
        }
    }

    private nonisolated static func latestRelease(userAgent: String) async throws -> AppRelease {
        var request = URLRequest(url: api, timeoutInterval: 10)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if (response as? HTTPURLResponse)?.statusCode == 200, let release = try? AppRelease(githubJSON: data) {
            return release
        }
        // The API allows 60 requests an hour per address, the website redirect has no such limit
        var page = URLRequest(url: ProjectLinks.releases, timeoutInterval: 10)
        page.httpMethod = "HEAD"
        page.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let (_, redirected) = try await URLSession.shared.data(for: page)
        guard let url = redirected.url, let release = AppRelease(redirectedTo: url) else {
            throw URLError(.badServerResponse)
        }
        return release
    }
}
