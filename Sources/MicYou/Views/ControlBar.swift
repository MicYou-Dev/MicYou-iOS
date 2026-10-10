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
            .padding(.bottom, 8)
        } else {
            buttons
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button {
                model.toggleMute()
            } label: {
                Image(systemName: model.isMuted ? "mic.slash.fill" : "mic.fill")
                    .font(.title2)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 40, height: 40)
            }
            .glassButtonStyle(prominent: model.isMuted)
            .buttonBorderShape(.circle)
            .tint(model.isMuted ? .orange : nil)
            .accessibilityLabel(model.isMuted ? L10n.Common.unmute : L10n.Common.mute)
            .sensoryFeedback(.selection, trigger: model.isMuted)

            Button(role: .destructive) {
                model.disconnect()
            } label: {
                Text(model.phase == .streaming ? L10n.Common.disconnect : L10n.Common.cancel)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
            .glassButtonStyle()
            .buttonBorderShape(.capsule)
            .tint(.red)
        }
        .controlSize(.large)
    }
}
