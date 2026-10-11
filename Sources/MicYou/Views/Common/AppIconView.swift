// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// The home screen icon at any size, for the welcome sheet and the about page
struct AppIconView: View {
    var size: CGFloat

    var body: some View {
        icon
            .frame(width: size, height: size)
            .clipShape(shape)
            .overlay { shape.strokeBorder(.separator, lineWidth: 0.5) }
            .shadow(color: .black.opacity(0.12), radius: size / 11, y: size / 22)
            .accessibilityHidden(true)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
    }

    /// The bundled 60 pt icon, a plain glyph if it is missing
    @ViewBuilder
    private var icon: some View {
        if let image = UIImage(named: "MicYou60x60") {
            Image(uiImage: image).resizable()
        } else {
            Image(systemName: "mic.fill")
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.accentColor.gradient)
        }
    }
}
