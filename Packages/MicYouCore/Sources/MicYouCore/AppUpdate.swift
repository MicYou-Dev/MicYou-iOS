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
public struct AppRelease: Equatable, Identifiable, Sendable {
    public let version: AppVersion
    /// The release page, where the IPA files are
    public let page: URL
    /// Nil when the release came from the website redirect, which carries no body
    public let notes: ReleaseNotes?

    public init(version: AppVersion, page: URL, notes: ReleaseNotes? = nil) {
        self.version = version
        self.page = page
        self.notes = notes
    }

    private struct Payload: Decodable {
        let tag_name: String
        let html_url: URL
        let body: String?
        let draft: Bool?
        let prerelease: Bool?
    }

    /// From the GitHub `releases/latest` API, which already skips drafts and prereleases
    public init(githubJSON data: Data) throws {
        let payload = try JSONDecoder().decode(Payload.self, from: data)
        guard payload.draft != true, payload.prerelease != true, let version = AppVersion(payload.tag_name) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Not an app release: \(payload.tag_name)"))
        }
        let notes = payload.body.map(ReleaseNotes.init(markdown:))
        self.init(version: version, page: payload.html_url, notes: notes?.isEmpty == false ? notes : nil)
    }

    /// From where `releases/latest` on the website redirects, ".../releases/tag/v1.2.0"
    /// The fallback when the API is rate limited, it needs no token
    public init?(redirectedTo url: URL) {
        let components = url.pathComponents
        guard let index = components.lastIndex(of: "tag"), index + 1 < components.count,
              let version = AppVersion(components[index + 1]) else { return nil }
        self.init(version: version, page: url)
    }

    public var id: AppVersion { version }

    public func isNewer(than current: AppVersion) -> Bool { version > current }
}

/// The changes listed in a release body, as written by `release.yml`
/// Only the block structure is parsed here, inline Markdown such as `code` is left to the view
public struct ReleaseNotes: Equatable, Sendable {
    public enum Block: Equatable, Sendable {
        case heading(String)
        /// A list item, with the commit type split off when it starts with one such as "feat: "
        case item(String, kind: ChangeKind? = nil)
        case paragraph(String)

        /// Without the commit type, so only the description goes to the translator
        public var text: String {
            switch self {
            case .heading(let text), .item(let text, _), .paragraph(let text): text
            }
        }
    }

    /// The commit types in the changes list, shown as a label of their own
    public enum ChangeKind: String, CaseIterable, Sendable {
        case feat, fix, refactor, style, docs, chore

        /// "feat(ui)!: text" gives feat and "text", anything else stays whole
        static func split(_ line: String) -> (kind: ChangeKind?, text: String) {
            guard let colon = line.firstIndex(of: ":") else { return (nil, line) }
            var type = line[..<colon]
            if type.last == "!" { type.removeLast() }
            if let scope = type.firstIndex(of: "("), type.last == ")" { type = type[..<scope] }
            let text = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            guard let kind = ChangeKind(rawValue: type.lowercased()), !text.isEmpty else { return (nil, line) }
            return (kind, text)
        }
    }

    public let blocks: [Block]

    /// Sections about the downloads themselves, the release page explains them next to the files
    static let hiddenSections: Set<String> = ["files"]

    public init(markdown: String) {
        var blocks: [Block] = []
        var paragraph: [String] = []
        var hidden = false

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: " "))) }
            paragraph = []
        }

        for raw in markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#") {
                flush()
                let title = line.drop { $0 == "#" }.trimmingCharacters(in: .whitespaces)
                hidden = Self.hiddenSections.contains(title.lowercased())
                if !hidden, !title.isEmpty { blocks.append(.heading(title)) }
            } else if hidden {
                continue
            } else if line.isEmpty {
                flush()
            } else if let marker = line.first, "-*+".contains(marker), line.dropFirst().first == " " {
                flush()
                let change = ChangeKind.split(line.dropFirst(2).trimmingCharacters(in: .whitespaces))
                blocks.append(.item(change.text, kind: change.kind))
            } else if raw.first?.isWhitespace == true, paragraph.isEmpty, case .item(let text, let kind) = blocks.last {
                // An indented line continues the item above it
                blocks[blocks.count - 1] = .item(text + " " + line, kind: kind)
            } else {
                paragraph.append(line)
            }
        }
        flush()

        // A single heading such as "Changes" only repeats what the sheet title says
        if blocks.count(where: { if case .heading = $0 { true } else { false } }) == 1, case .heading = blocks.first {
            blocks.removeFirst()
        }
        self.blocks = blocks
    }

    public var isEmpty: Bool { blocks.isEmpty }
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
