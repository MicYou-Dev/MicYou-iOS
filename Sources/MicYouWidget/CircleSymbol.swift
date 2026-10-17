// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI
import WidgetKit

/// White glyph on a tinted circle, like the avatar in a call
/// Tinted and clear Home Screens drop colors and keep only opacity, which would merge the glyph
/// into a solid circle, so there the circle turns translucent and the glyph takes the accent
struct CircleSymbol: View {
    @Environment(\.widgetRenderingMode) private var renderingMode

    let symbol: String
    let tint: Color
    let size: CGFloat

    var body: some View {
        let fullColor = renderingMode == .fullColor
        Image(systemName: symbol)
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(fullColor ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .widgetAccentable()
            .frame(width: size, height: size)
            .background(fullColor ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(.fill.secondary), in: Circle())
            .accessibilityHidden(true)
    }
}
