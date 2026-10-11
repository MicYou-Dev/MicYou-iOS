// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Mute and disconnect pinned above the home indicator while a session is active
struct ControlBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if #available(iOS 26, *) {
            // Floating Liquid Glass controls, no bar background
            GlassEffectContainer(spacing: 12) {
                buttons
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: HomeLayout.maxWidth)
            .padding(.bottom, 8)
        } else {
            buttons
                .padding(.horizontal, 20)
                .frame(maxWidth: HomeLayout.maxWidth)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                model.toggleMute()
            } label: {
                // Mic gets its slash drawn on rather than swapped
                Image(systemName: model.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.title2)
                    .contentTransition(.symbolEffect(.replace.magic(fallback: .replace)))
                    .foregroundStyle(model.isMuted ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                    .frame(width: 56, height: 56)
                    // One surface for both states, so the orange tint fades in instead of the button being replaced
                    .glassSurface(in: .circle, tint: model.isMuted ? .orange : nil, fallback: .fill.secondary)
                    .contentShape(.circle)
            }
            .buttonStyle(.surface)
            .accessibilityLabel(model.isMuted ? L10n.Common.unmute : L10n.Common.mute)
            .accessibilityAddTraits(model.isMuted ? .isSelected : [])
            .sensoryFeedback(.selection, trigger: model.isMuted)
            .animation(Motion.state, value: model.isMuted)

            Button(role: .destructive) {
                model.disconnect()
            } label: {
                Text(model.phase == .streaming ? L10n.Common.disconnect : L10n.Common.cancel)
                    .font(.headline)
                    .contentTransition(.opacity)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .glassSurface(in: .capsule, fallback: Color.red.opacity(0.15))
                    .contentShape(.capsule)
            }
            .buttonStyle(.surface)
            .animation(Motion.state, value: model.phase == .streaming)
        }
    }
}
