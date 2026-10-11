// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// A dotted release number such as "1.2.0", tags may carry a leading "v"
public struct AppVersion: Comparable, Hashable, Sendable, CustomStringConvertible {
    public let parts: [Int]

    /// Nil for anything that is not dot separated numbers, such as "Protocol-2.0.0-1"
    public init?(_ text: String) {
        var text = text.trimmingCharacters(in: .whitespaces)
        if text.first == "v" || text.first == "V" { text.removeFirst() }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        self.parts = parts.map { $0! }
    }

    public var description: String { parts.map(String.init).joined(separator: ".") }

    /// Missing parts count as zero, so "1.2" equals "1.2.0"
    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        for i in 0..<max(lhs.parts.count, rhs.parts.count) {
            let a = i < lhs.parts.count ? lhs.parts[i] : 0
            let b = i < rhs.parts.count ? rhs.parts[i] : 0
            if a != b { return a < b }
        }
        return false
    }

    public static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public func hash(into hasher: inout Hasher) {
        var trimmed = parts
        while trimmed.last == 0 { trimmed.removeLast() }
        hasher.combine(trimmed)
    }
}

/// The latest published release of the app
public struct AppRelease: Equatable, Sendable {
    public let version: AppVersion
    /// The release page, where the IPA files are
    public let page: URL

    public init(version: AppVersion, page: URL) {
        self.version = version
        self.page = page
    }

    private struct Payload: Decodable {
        let tag_name: String
        let html_url: URL
        let draft: Bool?
        let prerelease: Bool?
    }

    /// From the GitHub `releases/latest` API, which already skips drafts and prereleases
    public init(githubJSON data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.draft != true, payload.prerelease != true, let version = AppVersion(payload.tag_name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not an app release: \(payload.tag_name)"))
        }
        self.init(version: version, page: payload.html_url)
    }

    /// From where `releases/latest` on the website redirects, ".../releases/tag/v1.2.0"
    /// The fallback when the API is rate limited, it needs no token
    public init?(redirectedTo url: URL) {
        let components = url.pathComponents
        guard let index = components.lastIndex(of: "tag"), index + 1 < components.count,
              let version = AppVersion(components[index + 1]) else { return nil }
        self.init(version: version, page: url)
    }

    public func isNewer(than current: AppVersion) -> Bool { version > current }
}

/// How often the app looks for a new release on its own
public enum UpdateSchedule {
    public static let interval: TimeInterval = 24 * 60 * 60

    public static func isDue(lastCheck: Date?, now: Date = .now) -> Bool {
        guard let lastCheck else { return true }
        // A clock set backwards should not block checks until it catches up
        return now.timeIntervalSince(lastCheck) >= interval || now < lastCheck
    }
}
