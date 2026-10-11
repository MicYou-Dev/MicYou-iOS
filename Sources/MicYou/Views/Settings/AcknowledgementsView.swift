// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Open source components in the app with their full license text, like Flutter's license page
/// The app bundles no third party libraries, system frameworks come with iOS and are not listed
struct AcknowledgementsView: View {
    var body: some View {
        Form {
            Section {
                ForEach(Credit.included) { credit in
                    NavigationLink {
                        LicenseTextView(title: credit.name, file: "LICENSE", heading: L10n.About.license, credit: credit)
                    } label: {
                        CreditLabel(credit: credit)
                    }
                }
            } header: {
                Text(L10n.Credits.included)
            } footer: {
                Text(L10n.Credits.includedFooter)
            }

            Section {
                NavigationLink {
                    LicenseTextView(title: L10n.About.notice, file: "NOTICE")
                } label: {
                    RowLabel(title: L10n.About.notice, detail: "NOTICE", systemImage: "c.circle.fill", color: .gray)
                }
            } footer: {
                Text(L10n.About.footer)
            }

            Section {
                ForEach(Credit.references) { credit in
                    Link(destination: credit.url) {
                        HStack {
                            CreditLabel(credit: credit)
                            Spacer(minLength: 8)
                            Image(systemName: "arrow.up.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isLink)
                }
            } header: {
                Text(L10n.Credits.references)
            } footer: {
                Text(L10n.Credits.referencesFooter)
            }
        }
        .navigationTitle(L10n.About.acknowledgements)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Credit: Identifiable {
    let name: String
    let author: String
    let license: String
    let role: String
    let url: URL

    var id: String { name }

    /// Everything that ends up in the app, matching NOTICE
    static var included: [Credit] {
        [
            Credit(
                name: "MicYou for iOS", author: "ChouChiu", license: "GPL-3.0-or-later",
                role: L10n.Credits.appRole, url: ProjectLinks.repository
            ),
            Credit(
                name: "MicYouProtocol", author: "ChouChiu", license: "GPL-3.0-or-later",
                role: L10n.Credits.protocolRole,
                url: ProjectLinks.repository.appending(path: "tree/HEAD/Packages/MicYouProtocol")
            ),
            Credit(
                name: "MicYou", author: L10n.Credits.micyouAuthor, license: "GPL-3.0",
                role: L10n.Credits.micyouRole, url: ProjectLinks.desktop
            ),
            Credit(
                name: L10n.Credits.iconName, author: "WhatDamon", license: "GPL-3.0",
                role: L10n.Credits.iconRole, url: ProjectLinks.desktop.appending(path: "pull/350")
            ),
        ]
    }

    /// Projects and tools referenced or used during development
    static var references: [Credit] {
        [
            Credit(
                name: "MicYou-iOS (v2)", author: L10n.Credits.micyouIOSAuthor, license: "GPL-3.0",
                role: L10n.Credits.micyouIOSRole, url: ProjectLinks.repository.appending(path: "tree/v2")
            ),
            Credit(
                name: "MicWisp", author: "TimmySheep", license: "MIT",
                role: L10n.Credits.micwispRole, url: URL(string: "https://github.com/TimmySheep/MicWisp")!
            ),
            Credit(
                name: "xtool", author: "xtool-org", license: "MIT",
                role: L10n.Credits.xtoolRole, url: URL(string: "https://github.com/xtool-org/xtool")!
            ),
        ]
    }
}

private struct CreditLabel: View {
    let credit: Credit

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(credit.name)
                    .font(.headline)
                LicenseBadge(license: credit.license)
            }
            Text(verbatim: "© \(credit.author)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(credit.role)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(.primary)
        .padding(.vertical, 4)
    }
}

private struct LicenseBadge: View {
    let license: String

    var body: some View {
        Text(license)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.fill.tertiary, in: Capsule())
    }
}

/// A bundled text file such as LICENSE or NOTICE, reflowed to the screen width
private struct LicenseTextView: View {
    let title: String
    let file: String
    var heading: String?
    var credit: Credit?

    @State private var paragraphs: [LicenseParagraph]?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let credit {
                    VStack(alignment: .leading, spacing: 8) {
                        CreditLabel(credit: credit)
                        Link(destination: credit.url) {
                            Label(L10n.Credits.viewSource, systemImage: "arrow.up.right")
                                .font(.subheadline.weight(.medium))
                        }
                    }
                    Divider()
                }
                if let heading {
                    Text(heading)
                        .font(.headline)
                }
                switch paragraphs {
                case nil:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                case let paragraphs? where paragraphs.isEmpty:
                    Text(L10n.Credits.textUnavailable)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                case let paragraphs?:
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(paragraphs) { paragraph in
                            paragraph.view
                        }
                    }
                    .textSelection(.enabled)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let file = file
            paragraphs = await Task.detached(priority: .userInitiated) {
                guard let url = Bundle.main.url(forResource: file, withExtension: nil),
                      let text = try? String(contentsOf: url, encoding: .utf8)
                else { return [] }
                return LicenseParagraph.parse(text)
            }.value
        }
    }
}

/// One paragraph of a plain text license, which wraps its lines at about 76 columns
private struct LicenseParagraph: Identifiable, Sendable {
    enum Style: Sendable {
        /// Centered title lines such as the GPL heading, kept as they are
        case heading
        /// Numbered section titles
        case section
        /// Indented examples, joined but kept indented
        case indented
        case body
    }

    let id: Int
    let text: String
    let style: Style

    @ViewBuilder
    var view: some View {
        switch style {
        case .heading:
            Text(text)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        case .section:
            Text(text)
                .font(.footnote.weight(.semibold))
                .padding(.top, 8)
        case .indented:
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.leading, 16)
        case .body:
            Text(text)
                .font(.footnote)
        }
    }

    static func parse(_ text: String) -> [LicenseParagraph] {
        var blocks: [[Substring]] = [[]]
        for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.allSatisfy(\.isWhitespace) {
                if !(blocks.last?.isEmpty ?? true) { blocks.append([]) }
            } else {
                blocks[blocks.count - 1].append(line)
            }
        }
        return blocks.filter { !$0.isEmpty }.enumerated().map { index, lines in
            let indents = lines.map { $0.prefix { $0 == " " }.count }
            // The GPL puts two spaces after a sentence, which looks like a gap once reflowed
            let trimmed = lines.map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".  ", with: ". ") }
            if indents.allSatisfy({ $0 >= 10 }) {
                return LicenseParagraph(id: index, text: trimmed.joined(separator: "\n"), style: .heading)
            }
            // Numbered section titles of the GPL such as "0. Definitions."
            if trimmed.count == 1, trimmed[0].count < 48, trimmed[0].first?.isNumber == true {
                return LicenseParagraph(id: index, text: trimmed[0], style: .section)
            }
            // Short lines such as a name above its copyright line were broken on purpose
            if trimmed.allSatisfy({ $0.count < 48 }) {
                return LicenseParagraph(id: index, text: trimmed.joined(separator: "\n"), style: .body)
            }
            if indents.allSatisfy({ $0 >= 4 }) {
                return LicenseParagraph(id: index, text: trimmed.joined(separator: " "), style: .indented)
            }
            // A list item keeps its first line, the indented lines under it read as one sentence
            if trimmed[0].hasPrefix("- ") && trimmed.count > 1 {
                let rest = trimmed.dropFirst().joined(separator: " ")
                return LicenseParagraph(id: index, text: "\(trimmed[0])\n\(rest)", style: .body)
            }
            return LicenseParagraph(id: index, text: trimmed.joined(separator: " "), style: .body)
        }
    }
}
