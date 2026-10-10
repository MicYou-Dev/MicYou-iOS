// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

extension ShapeStyle where Self == Color {
    /// Raised surface on the grouped background, the same as a form row
    static var card: Color { Color(.secondarySystemGroupedBackground) }
}

extension View {
    /// Liquid Glass on iOS 26, bordered buttons before
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(iOS 26, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}

extension View {
    /// Liquid Glass on iOS 26, tinted when given a color, interactive for tappable surfaces
    /// Before iOS 26 the tint or the fallback fills the shape instead
    /// Keeps one view for every state so tint changes animate rather than swap views
    func glassSurface(
        in shape: some Shape,
        tint: Color? = nil,
        interactive: Bool = true,
        fallback: some ShapeStyle = .card
    ) -> some View {
        modifier(GlassSurface(shape: shape, tint: tint, interactive: interactive, fallback: AnyShapeStyle(fallback)))
    }
}

private struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool
    let fallback: AnyShapeStyle

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular.tint(tint).interactive(interactive), in: shape)
        } else {
            content.background(tint.map { AnyShapeStyle($0) } ?? fallback, in: shape)
        }
    }
}

/// Title or status on the left and the settings button on the right
struct HomeHeader<Leading: View>: View {
    let openSettings: () -> Void
    @ViewBuilder var leading: Leading

    var body: some View {
        HStack {
            leading
            Spacer(minLength: 12)
            Button(action: openSettings) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 28, height: 28)
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .accessibilityLabel(L10n.Common.settings)
        }
        .frame(minHeight: 44)
    }
}

/// A dismissible message, for errors and one-off notices such as the Opus fallback
struct NoticeCard: View {
    enum Kind { case info, error }

    var title: String?
    let text: String
    let kind: Kind
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: kind == .error ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                if let title {
                    Text(title)
                        .fontWeight(.semibold)
                        .foregroundStyle(tint)
                }
                Text(text)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            Button(L10n.Common.dismiss, systemImage: "xmark", action: dismiss)
                .labelStyle(.iconOnly)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .buttonStyle(.borderless)
        }
        .padding(14)
        .background(tint.opacity(0.12), in: .rect(cornerRadius: 16))
    }

    private var tint: Color { kind == .error ? .red : .blue }
}
