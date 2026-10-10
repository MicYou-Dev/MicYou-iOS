// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// Mute and connect buttons pinned above the home indicator
struct ControlBar: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if #available(iOS 26, *) {
            // Floating Liquid Glass controls, no bar background
            GlassEffectContainer(spacing: 12) {
                buttons(muteStyle: .glass, connectStyle: .glassProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        } else {
            buttons(muteStyle: .bordered, connectStyle: .borderedProminent)
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(.bar)
        }
    }

    private func buttons(muteStyle: some PrimitiveButtonStyle, connectStyle: some PrimitiveButtonStyle) -> some View {
        HStack(spacing: 12) {
            Button {
                model.toggleMute()
            } label: {
                Image(systemName: model.isMuted ? "mic.slash.fill" : "mic.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(muteStyle)
            .tint(model.isMuted ? .red : nil)
            .accessibilityLabel(model.isMuted ? L10n.Common.unmute : L10n.Common.mute)
            .sensoryFeedback(.selection, trigger: model.isMuted)

            Button {
                model.toggleConnection()
            } label: {
                Text(connectTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 28)
            }
            .buttonStyle(connectStyle)
            .tint(model.isActive ? .red : .accentColor)
            .disabled(!model.isActive && !model.canConnect)
            .sensoryFeedback(.impact, trigger: model.isActive)
        }
        .buttonBorderShape(.capsule)
        .controlSize(.large)
        .animation(.default, value: model.phase)
    }

    private var connectTitle: String {
        switch model.phase {
        case .connecting, .reconnecting: L10n.Common.cancel
        case .streaming: L10n.Common.disconnect
        case .failed: L10n.Common.retry
        case .idle: L10n.Common.connect
        }
    }
}
