// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// The app's license and the projects it builds on, matching NOTICE
struct AcknowledgementsView: View {
    var body: some View {
        Form {
            Section {
                LinkRow(
                    title: L10n.About.license, detail: "GPL-3.0-or-later",
                    systemImage: "doc.text.fill", color: .blue,
                    url: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!
                )
                LinkRow(
                    title: L10n.About.notice, detail: "NOTICE",
                    systemImage: "c.circle.fill", color: .gray,
                    url: ProjectLinks.repository.appending(path: "blob/HEAD/NOTICE")
                )
            } header: {
                Text(L10n.Credits.license)
            } footer: {
                Text(L10n.About.footer)
            }

            Section {
                ForEach(Credit.all) { credit in
                    CreditRow(credit: credit)
                }
            } header: {
                Text(L10n.Credits.thanks)
            } footer: {
                Text(L10n.Credits.footer)
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

    var id: String { url.absoluteString }

    static var all: [Credit] {
        [
            Credit(
                name: "MicYou", author: L10n.Credits.micyouAuthor, license: "GPL-3.0",
                role: L10n.Credits.micyouRole, url: ProjectLinks.desktop
            ),
            Credit(
                name: "MicYou-iOS", author: L10n.Credits.micyouIOSAuthor, license: "GPL-3.0",
                role: L10n.Credits.micyouIOSRole, url: ProjectLinks.repository
            ),
            Credit(
                name: L10n.Credits.iconName, author: "WhatDamon", license: "GPL-3.0",
                role: L10n.Credits.iconRole, url: ProjectLinks.desktop.appending(path: "pull/350")
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

private struct CreditRow: View {
    let credit: Credit

    var body: some View {
        Link(destination: credit.url) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(credit.name)
                        .font(.headline)
                    Text(credit.license)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary, in: Capsule())
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .accessibilityHidden(true)
                }
                Text(credit.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(credit.role)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isLink)
    }
}
