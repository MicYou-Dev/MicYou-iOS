// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

extension ShapeStyle where Self == Color {
    /// Raised surface on the grouped background, the same as a form row
    static var card: Color { Color(.secondarySystemGroupedBackground) }
}

extension View {
    /// Liquid Glass on iOS 26, a bordered button before
    @ViewBuilder
    func glassButtonStyle() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glass)
        } else {
            buttonStyle(.bordered)
        }
    }

    /// Tinted Liquid Glass on iOS 26, a filled button before
    @ViewBuilder
    func glassProminentButtonStyle() -> some View {
        if #available(iOS 26, *) {
            buttonStyle(.glassProminent)
        } else {
            buttonStyle(.borderedProminent)
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
