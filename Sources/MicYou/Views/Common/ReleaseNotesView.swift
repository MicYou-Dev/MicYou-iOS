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
    /// Set on the first tap, the translation task runs whenever it changes
    @State private var translation: TranslationSession.Configuration?
    /// Translated text by block index, kept so switching back and forth does not translate again
    @State private var translated: [Int: String] = [:]
    @State private var showsTranslation = false
    @State private var isTranslating = false
    private let log = Logger.micyou("update")

    /// The app's language when it is not English, nil hides the translate button
    private static let targetLanguage: Locale.Language? = {
        guard let language = Bundle.main.preferredLocalizations.first, !language.hasPrefix("en") else { return nil }
        return Locale.Language(identifier: language)
    }()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(notes.blocks.enumerated()), id: \.offset) { index, block in
                        blockView(block, text: showsTranslation ? translated[index] ?? block.text : block.text)
                            .padding(.top, index > 0 && block.isHeading ? 12 : 0)
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
            .translationTask(translation) { session in
                await translate(with: session)
            }
            .animation(Motion.state, value: showsTranslation)
        }
        .presentationDetents([.medium, .large])
    }

    private func toggleTranslation() {
        if !translated.isEmpty {
            showsTranslation.toggle()
        } else if translation == nil {
            translation = .init(source: Locale.Language(identifier: "en"), target: Self.targetLanguage)
        } else {
            // Runs the task again after a failed or cancelled attempt
            translation?.invalidate()
        }
    }

    /// The system asks to download the languages first when they are missing
    private func translate(with session: TranslationSession) async {
        isTranslating = true
        defer { isTranslating = false }
        do {
            // One string at a time, a batch of requests cannot be sent to the session from the main actor
            var results: [Int: String] = [:]
            for (index, block) in notes.blocks.enumerated() {
                results[index] = try await session.translate(block.text).targetText
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
        case .paragraph:
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
    private static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private extension ReleaseNotes.Block {
    var isHeading: Bool {
        if case .heading = self { true } else { false }
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

