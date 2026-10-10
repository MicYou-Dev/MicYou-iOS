// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// One screen that changes in place between idle and the live session
/// The header and scroll view stay put so only the content and the control bar animate
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showPicker = false
    @State private var showSettings = false

    var body: some View {
        FillingScrollView {
            VStack(spacing: 20) {
                HomeHeader(openSettings: { showSettings = true }) {
                    ZStack(alignment: .leading) {
                        if model.isActive {
                            StatusPill()
                                // Grows out of where the title starts, no blur so the glass is not rendered offscreen
                                .adaptiveTransition(.swap(scale: 0.85, anchor: .leading))
                        } else {
                            Text(L10n.App.name)
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                                .adaptiveTransition(.swap(scale: 0.95, anchor: .leading))
                        }
                    }
                }
                // Overlapping rather than stacked, so both never take space at once during the change
                // The leaving side fades out first, so the glass of both screens is never blended for long
                ZStack {
                    if model.isActive {
                        SessionView()
                            .adaptiveTransition(.swap(scale: 0.96))
                    } else {
                        IdleView(openPicker: { showPicker = true }, openSettings: { showSettings = true })
                            .adaptiveTransition(.swap(scale: 1.04))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if model.isActive {
                ControlBar()
                    .adaptiveTransition(.bottomBar)
            }
        }
        .animation(Motion.screen, value: model.isActive)
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(trigger: model.phase, Self.feedback)
        .onChange(of: model.isActive) { _, active in
            // A shortcut or URL may start streaming while the picker is open
            if active { showPicker = false }
        }
        .sheet(isPresented: $showPicker) {
            ServerPickerView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    /// A tap when a stream starts or is stopped, a warning when the link drops and an error when it gives up
    private static func feedback(from old: ConnectionPhase, to new: ConnectionPhase) -> SensoryFeedback? {
        switch (old, new) {
        case (_, .failed): .error
        case (.streaming, .reconnecting): .warning
        case (.idle, .connecting), (.failed, .connecting): .impact(weight: .medium)
        case (.connecting, .idle), (.streaming, .idle), (.reconnecting, .idle): .impact(weight: .light)
        default: nil
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

/// Fills the screen when the content is short and scrolls when it is not, such as on small phones or at large text sizes
struct FillingScrollView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .frame(minHeight: proxy.size.height)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
