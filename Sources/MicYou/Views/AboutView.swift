// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import MicYouShared
import SwiftUI

struct AboutView: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return L10n.About.versionValue(short, build: build)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent(L10n.About.version, value: version)
                LabeledContent(L10n.About.protocolLabel, value: L10n.About.protocolValue)
                LabeledContent(L10n.About.defaultPort, value: String(MicYouWire.defaultPort))
            }
            Section {
                Link(destination: URL(string: "https://github.com/MicYou-Dev/MicYou")!) {
                    Label(L10n.About.desktop, systemImage: "desktopcomputer")
                }
                Link(destination: URL(string: "https://github.com/MicYou-Dev/MicYou-iOS")!) {
                    Label(L10n.About.sourceCode, systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: URL(string: "https://www.gnu.org/licenses/gpl-3.0.html")!) {
                    Label(L10n.About.license, systemImage: "doc.text")
                }
            } footer: {
                Text(L10n.About.footer)
            }
        }
        .navigationTitle(L10n.About.title)
    }
}
