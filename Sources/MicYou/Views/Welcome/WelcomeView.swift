// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Shown once on the first launch: the three things needed before the first stream,
/// with the quick start guide and FAQ on the website for the details
struct WelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize = 84

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                VStack(spacing: 14) {
                    AppIconView(size: iconSize)
                        .padding(.bottom, 4)
                    Text(L10n.Welcome.title)
                        .font(.largeTitle.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(L10n.Welcome.subtitle(UIDevice.current.model))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 26) {
                    WelcomeStep(
                        systemImage: "desktopcomputer", color: .indigo,
                        title: L10n.Welcome.desktopTitle, text: L10n.Welcome.desktopText
                    )
                    WelcomeStep(
                        systemImage: "wifi", color: .blue,
                        title: L10n.Welcome.networkTitle, text: L10n.Welcome.networkText
                    )
                    WelcomeStep(
                        systemImage: "waveform", color: .orange,
                        title: L10n.Welcome.appsTitle, text: L10n.Welcome.appsText
                    )
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)
            .padding(.bottom, 24)
            .frame(maxWidth: Self.maxWidth)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    DocButton(title: L10n.About.quickStart, systemImage: "book", url: ProjectLinks.quickStart)
                    DocButton(title: L10n.About.faq, systemImage: "questionmark.circle", url: ProjectLinks.faq)
                }
                Button {
                    dismiss()
                } label: {
                    Text(L10n.Welcome.start)
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
            // As wide as the steps above, not the whole sheet on iPad
            .frame(maxWidth: Self.maxWidth)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .welcomeSheetSizing()
    }

    /// Widest the steps and buttons get
    private static let maxWidth: CGFloat = 520
}

private extension View {
    /// The larger page sheet on iPad, the default form sheet is too short for all three steps in landscape
    /// Same full height sheet as before on iPhone
    @ViewBuilder
    func welcomeSheetSizing() -> some View {
        if #available(iOS 18, *) {
            presentationSizing(.page)
        } else {
            self
        }
    }
}

/// An icon beside a short title and one or two sentences
private struct WelcomeStep: View {
    let systemImage: String
    let color: Color
    let title: String
    let text: String
    @ScaledMetric(relativeTo: .title) private var iconWidth = 44

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: systemImage)
                .font(.title.weight(.medium))
                .foregroundStyle(color.gradient)
                .frame(width: iconWidth)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One of the two links to the website above the main button
private struct DocButton: View {
    let title: String
    let systemImage: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .glassButtonStyle()
        .buttonBorderShape(.capsule)
    }
}
