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
                                .transition(.blurReplace)
                        } else {
                            Text(L10n.App.name)
                                .font(.largeTitle.bold())
                                .accessibilityAddTraits(.isHeader)
                                .transition(.blurReplace)
                        }
                    }
                }
                // Overlapping rather than stacked, so both never take space at once during the change
                ZStack {
                    if model.isActive {
                        SessionView()
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else {
                        IdleView(openPicker: { showPicker = true }, openSettings: { showSettings = true })
                            .transition(.opacity.combined(with: .scale(scale: 1.03)))
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if model.isActive {
                ControlBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.45), value: model.isActive)
        .background(Color(.systemGroupedBackground))
        .sensoryFeedback(.impact, trigger: model.isActive)
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
