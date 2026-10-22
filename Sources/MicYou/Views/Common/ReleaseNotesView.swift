// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouCore
import MicYouShared
import os
import SwiftUI
// TranslationSession is not Sendable, yet SwiftUI hands it to a task on the main actor
@preconcurrency import Translation
// The cross-import overlay is not applied automatically when building on Linux
import _Translation_SwiftUI

/// The changes in a new release, with a button to its page where the IPA files are
/// The notes are written in English, the system translator turns them into the app's language in place
struct ReleaseNotesView: View {
    let release: AppRelease
    let notes: ReleaseNotes
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Bumped on each tap that asks for a translation, the translation task runs again on every change
    @State private var translationRequests = 0
    /// Translated text by block index, kept so switching back and forth does not translate again
    @State private var translated: [Int: String] = [:]
    @State private var showsTranslation = false
    @State private var isTranslating = false
    private let log = Logger.micyou("update")

    /// The app's language when it is not English and the system translator exists, nil hides the translate button
    private static let targetLanguage: Locale.Language? = {
        guard #available(iOS 18, *), let language = Bundle.main.preferredLocalizations.first, !language.hasPrefix("en") else { return nil }
        return Locale.Language(identifier: language)
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // All lines of the section in one card, above the changes so it is seen first
                    if !thanksIndices.isEmpty {
                        ThanksCard(lines: thanksIndices.map(text(at:)))
                            .padding(.bottom, 4)
                    }
                    ForEach(Array(notes.blocks.enumerated()), id: \.offset) { index, block in
                        if !block.isThanks {
                            blockView(block, text: text(at: index))
                                .padding(.top, index > 0 && block.isHeading ? 12 : 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 12) {
                    Text(L10n.Home.updateText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button {
                        openURL(release.page)
                    } label: {
                        Text(L10n.Home.downloadUpdate)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .glassProminentButtonStyle()
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)
                .padding(.bottom, 8)
                .background(.bar)
            }
            .navigationTitle(L10n.Home.updateNotesTitle(release.version.description))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if Self.targetLanguage != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(showsTranslation ? L10n.Home.showOriginalNotes : L10n.Home.translateNotes, action: toggleTranslation)
                            .disabled(isTranslating)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Common.done) { dismiss() }
                }
            }
            .notesTranslation(requests: translationRequests, target: Self.targetLanguage) { translator in
                await translate(with: translator)
            }
            .animation(Motion.state, value: showsTranslation)
        }
        .presentationDetents([.medium, .large])
    }

    private func text(at index: Int) -> String {
        showsTranslation ? translated[index] ?? notes.blocks[index].text : notes.blocks[index].text
    }

    private var thanksIndices: [Int] {
        notes.blocks.indices.filter { notes.blocks[$0].isThanks }
    }

    private func toggleTranslation() {
        if !translated.isEmpty {
            showsTranslation.toggle()
        } else {
            translationRequests += 1
        }
    }

    /// The system asks to download the languages first when they are missing
    private func translate(with translator: (String) async throws -> String) async {
        isTranslating = true
        defer { isTranslating = false }
        do {
            // One string at a time, a batch of requests cannot be sent to the session from the main actor
            var results: [Int: String] = [:]
            for (index, block) in notes.blocks.enumerated() {
                results[index] = try await translator(block.text)
            }
            translated = results
            showsTranslation = true
        } catch {
            log.error("Release notes translation failed: \(String(describing: error), privacy: .public)")
        }
    }

    @ViewBuilder
    private func blockView(_ block: ReleaseNotes.Block, text: String) -> some View {
        switch block {
        case .heading:
            Text(Self.inline(text))
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
        case .item(_, let kind):
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(verbatim: "•")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text(kind.map { Self.label($0) + Self.inline(text) } ?? Self.inline(text))
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .paragraph, .thanks:
            Text(Self.inline(text))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// The commit type ahead of the description, in the app's language rather than through the translator
    private static func label(_ kind: ReleaseNotes.ChangeKind) -> AttributedString {
        let (title, color): (String, Color) = switch kind {
        case .feat: (L10n.Home.newFeature, .green)
        case .fix: (L10n.Home.bugFix, .orange)
        case .refactor: (L10n.Home.refactor, .secondary)
        case .style: (L10n.Home.design, .purple)
        case .docs: (L10n.Home.documentation, .secondary)
        case .chore: (L10n.Home.otherChange, .secondary)
        }
        var label = AttributedString(title)
        label.foregroundColor = color
        label.font = .body.weight(.semibold)
        return label + AttributedString("  ")
    }

    /// Code spans, emphasis and links inside a line, the raw text if it is not valid Markdown
    static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private extension ReleaseNotes.Block {
    var isHeading: Bool {
        if case .heading = self { true } else { false }
    }

    var isThanks: Bool {
        if case .thanks = self { true } else { false }
    }
}

/// The acknowledgements of a release, set apart from the changes in a tinted card
private struct ThanksCard: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // In the app's language, the translator only sees the lines below
            Label(L10n.Home.releaseThanks, systemImage: "heart.fill")
                .font(.headline)
                .foregroundStyle(.pink)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(ReleaseNotesView.inline(line))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.pink)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pink.opacity(0.12), in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .contain)
    }
}

/// Runs the system translator for the notes, which only exists from iOS 18
@available(iOS 18, *)
private struct NotesTranslation: ViewModifier {
    let requests: Int
    let target: Locale.Language?
    /// Handed a function that translates one string with the session
    let translate: @MainActor ((String) async throws -> String) async -> Void
    /// Set on the first request, the translation task runs whenever it changes
    @State private var configuration: TranslationSession.Configuration?

    func body(content: Content) -> some View {
        content
            .translationTask(configuration) { session in
                await run(session)
            }
            .onChange(of: requests) {
                if configuration == nil {
                    configuration = .init(source: Locale.Language(identifier: "en"), target: target)
                } else {
                    // Runs the task again after a failed or cancelled attempt
                    configuration?.invalidate()
                }
            }
    }

    private func run(_ session: TranslationSession) async {
        await translate { try await session.translate($0).targetText }
    }
}

private extension View {
    /// Leaves the view as it is before iOS 18, the translate button is hidden there
    @ViewBuilder
    func notesTranslation(
        requests: Int,
        target: Locale.Language?,
        translate: @escaping @MainActor ((String) async throws -> String) async -> Void
    ) -> some View {
        if #available(iOS 18, *) {
            modifier(NotesTranslation(requests: requests, target: target, translate: translate))
        } else {
            self
        }
    }
}

extension View {
    /// Presents the notes of the release set in `release`, cleared again when the sheet closes
    /// Only set releases with notes, the website fallback has none and opens the release page instead
    func releaseNotesSheet(_ release: Binding<AppRelease?>) -> some View {
        sheet(item: release) { shown in
            if let notes = shown.notes {
                ReleaseNotesView(release: shown, notes: notes)
            }
        }
    }
}

extension AppRelease {
    /// Its notes in the sheet that `releaseNotesSheet` presents, or the release page when it has none
    @MainActor
    func show(notes sheet: Binding<AppRelease?>, openURL: OpenURLAction) {
        if notes != nil { sheet.wrappedValue = self } else { openURL(page) }
    }
}
