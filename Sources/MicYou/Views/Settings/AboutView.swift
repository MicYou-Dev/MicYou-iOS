// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouProtocol
import MicYouShared
import SwiftUI

enum ProjectLinks {
    static let repository = URL(string: "https://github.com/MicYou-Dev/MicYou-iOS")!
    static let releases = URL(string: "https://github.com/MicYou-Dev/MicYou-iOS/releases/latest")!
    static let desktop = URL(string: "https://github.com/MicYou-Dev/MicYou")!
    static let discussions = URL(string: "https://github.com/MicYou-Dev/MicYou/discussions")!
    static var website: URL { site("") }
    static var quickStart: URL { site("docs/quick-start") }
    static var faq: URL { site("docs/faq") }
    static let qqGroup = URL(string: "https://qm.qq.com/q/V16hPpWPKO")!
    static let qqGroupNumber = "995452107"
    static let telegram = URL(string: "https://t.me/MicYouChannel")!

    /// A page on the website in the app's language, which serves English under /en and Traditional Chinese under /zh-TW
    /// The www host directly, the bare domain only redirects there
    private static func site(_ path: String) -> URL {
        let prefix = switch Bundle.main.preferredLocalizations.first {
        case "zh-Hans": ""
        case "zh-Hant": "zh-TW/"
        default: "en/"
        }
        return URL(string: "https://www.micyou.top/\(prefix)\(path)")!
    }

    /// A new issue from one of the forms in .github/ISSUE_TEMPLATE, fields keyed by their id
    static func newIssue(template: String, fields: [String: String]) -> URL {
        // URLComponents leaves + and & alone in query values, GitHub would read them as a space and a new field
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&+=?#"))
        let query = (["template": template].merging(fields) { $1 })
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")" }
            .joined(separator: "&")
        return URL(string: "\(repository.absoluteString)/issues/new?\(query)")!
    }
}

struct AboutView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var copies = 0
    @State private var copied = false

    var body: some View {
        Form {
            Section {
                AboutHeader()
            }
            .listRowBackground(Color.clear)

            Section {
                LabeledContent(L10n.About.protocolLabel, value: L10n.About.protocolValue)
                LabeledContent(L10n.About.defaultPort, value: String(MicYouWire.defaultPort))
            }

            Section(L10n.About.help) {
                LinkRow(
                    title: L10n.About.quickStart, detail: "micyou.top",
                    systemImage: "book.fill", color: .teal,
                    url: ProjectLinks.quickStart
                )
                LinkRow(
                    title: L10n.About.faq, detail: "micyou.top",
                    systemImage: "questionmark", color: .orange,
                    url: ProjectLinks.faq
                )
                Button {
                    settings.replayIntroduction()
                } label: {
                    RowLabel(title: L10n.About.replayIntroduction, systemImage: "hand.wave.fill", color: .mint)
                }
            }

            Section {
                LinkRow(
                    title: L10n.About.reportBug, detail: "GitHub Issues",
                    systemImage: "ladybug.fill", color: .red,
                    url: IssueReport.bug(model: model)
                )
                LinkRow(
                    title: L10n.About.requestFeature, detail: "GitHub Issues",
                    systemImage: "lightbulb.fill", color: .yellow,
                    url: IssueReport.feature()
                )
                Button {
                    UIPasteboard.general.string = diagnostics
                    copies += 1
                    withAnimation(Motion.state) { copied = true }
                } label: {
                    RowLabel(
                        title: copied ? L10n.About.copied : L10n.About.copyDiagnostics,
                        detail: L10n.About.copyDiagnosticsDetail,
                        systemImage: copied ? "checkmark" : "doc.on.clipboard.fill",
                        color: copied ? .green : .gray
                    )
                }
                .sensoryFeedback(.success, trigger: copies)
                .task(id: copies) {
                    guard copies > 0 else { return }
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation(Motion.state) { copied = false }
                }
            } header: {
                Text(L10n.About.feedback)
            } footer: {
                Text(L10n.About.feedbackFooter)
            }

            Section(L10n.About.community) {
                LinkRow(
                    title: L10n.About.qqGroup, detail: ProjectLinks.qqGroupNumber,
                    systemImage: "person.2.fill", color: Color(red: 0.07, green: 0.72, blue: 0.96),
                    url: ProjectLinks.qqGroup
                )
                .contextMenu {
                    Button(L10n.About.copy, systemImage: "doc.on.doc") {
                        UIPasteboard.general.string = ProjectLinks.qqGroupNumber
                    }
                }
                LinkRow(
                    title: L10n.About.telegram, detail: "@MicYouChannel",
                    systemImage: "paperplane.fill", color: Color(red: 0.17, green: 0.65, blue: 0.88),
                    url: ProjectLinks.telegram
                )
                LinkRow(
                    title: L10n.About.discussions, detail: "github.com/MicYou-Dev/MicYou",
                    systemImage: "bubble.left.and.bubble.right.fill", color: .purple,
                    url: ProjectLinks.discussions
                )
                LinkRow(
                    title: L10n.About.website, detail: "micyou.top",
                    systemImage: "globe", color: .blue,
                    url: ProjectLinks.website
                )
            }

            Section(L10n.About.project) {
                LinkRow(
                    title: L10n.About.desktop, detail: "github.com/MicYou-Dev/MicYou",
                    systemImage: "desktopcomputer", color: .indigo,
                    url: ProjectLinks.desktop
                )
                LinkRow(
                    title: L10n.About.sourceCode, detail: "github.com/MicYou-Dev/MicYou-iOS",
                    systemImage: "chevron.left.forwardslash.chevron.right", color: Color(white: 0.25),
                    url: ProjectLinks.repository
                )
                LinkRow(
                    title: L10n.About.releases, detail: "GitHub Releases",
                    systemImage: "arrow.down.circle.fill", color: .green,
                    url: ProjectLinks.releases
                )
            }

            Section {
                NavigationLink {
                    AcknowledgementsView()
                } label: {
                    RowLabel(
                        title: L10n.About.acknowledgements, detail: "GPL-3.0-or-later",
                        systemImage: "heart.fill", color: .pink
                    )
                }
            } footer: {
                Text(verbatim: "© 2026 ChouChiu")
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .navigationTitle(L10n.About.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var diagnostics: String { Diagnostics.report(model: model) }
}

/// Icon, name and version at the top of the page, long press copies the version
private struct AboutHeader: View {
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 88

    private var version: String { L10n.About.versionValue(Diagnostics.version, build: Diagnostics.build) }

    var body: some View {
        VStack(spacing: 6) {
            AppIconView(size: iconSize)
                .padding(.bottom, 6)
            Text(L10n.App.name)
                .font(.title2.bold())
            Text(L10n.About.tagline)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(version)
                .font(.footnote.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.fill.tertiary, in: Capsule())
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .contextMenu {
            Button(L10n.About.copy, systemImage: "doc.on.doc") {
                UIPasteboard.general.string = "MicYou \(Diagnostics.version) (\(Diagnostics.build))"
            }
        }
    }
}

/// A colored glyph tile like the ones in the Settings app
struct RowIcon: View {
    let systemImage: String
    let color: Color
    @ScaledMetric(relativeTo: .body) private var size = 30

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: size, height: size)
            .background(color.gradient, in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Icon tile with a title and an optional secondary line
struct RowLabel: View {
    let title: String
    var detail: String?
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            RowIcon(systemImage: systemImage, color: color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}

/// Opens a page outside the app, marked with an arrow instead of a chevron
struct LinkRow: View {
    let title: String
    var detail: String?
    let systemImage: String
    let color: Color
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                RowLabel(title: title, detail: detail, systemImage: systemImage, color: color)
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
}
