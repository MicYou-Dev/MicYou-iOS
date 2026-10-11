// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// One screen that changes in place between idle and the live session
/// The header and scroll view stay put so only the content and the control bar animate
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @State private var showPicker = false
    @State private var showSettings = false
    @State private var showWelcome = false
    @State private var tourStep: TourStep?

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
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            if tourStep != nil {
                TourOverlay(anchors: anchors, step: $tourStep, finish: finishTour)
                    .transition(.opacity)
            }
        }
        .animation(Motion.state, value: tourStep == nil)
        .task(id: tourReady) {
            guard tourReady else { return }
            // Let the welcome sheet slide away before the screen dims
            try? await Task.sleep(for: .seconds(0.4))
            guard tourReady, !Task.isCancelled else { return }
            tourStep = Self.firstTourStep
        }
        .onChange(of: model.isActive) { _, active in
            // A shortcut or URL may start streaming while the picker, the welcome sheet or the tour is open
            if active {
                showPicker = false
                showWelcome = false
                model.settings.welcomeShown = true
                if tourStep != nil { finishTour() }
            }
        }
        .sheet(isPresented: $showPicker) {
            ServerPickerView()
        }
        // After the settings close, in case the introduction was replayed from the about page
        // Presenting while the settings sheet is still sliding away would be dropped
        .sheet(isPresented: $showSettings, onDismiss: presentWelcomeIfNeeded) {
            SettingsView()
        }
        .sheet(isPresented: $showWelcome, onDismiss: { model.settings.welcomeShown = true }) {
            WelcomeView()
        }
        .onAppear(perform: presentWelcomeIfNeeded)
    }

    /// The idle screen is showing with nothing on top of it, and the tour has not been seen yet
    private var tourReady: Bool {
        let settings = model.settings
        return settings.welcomeShown && !settings.tourShown && !model.isActive
            && !showPicker && !showSettings && !showWelcome && tourStep == nil
    }

    #if DEBUG
    /// For screenshots, since a connected device cannot be tapped from the computer:
    /// launch with -tourShown NO -MicYouTourStep 3 to open the tour on its third step
    private static var firstTourStep: TourStep {
        TourStep(rawValue: UserDefaults.standard.integer(forKey: "MicYouTourStep") - 1) ?? .computer
    }
    #else
    private static let firstTourStep = TourStep.computer
    #endif

    private func finishTour() {
        tourStep = nil
        model.settings.tourShown = true
    }

    private func presentWelcomeIfNeeded() {
        if !model.settings.welcomeShown && !model.isActive { showWelcome = true }
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
            .tourTarget(.settings)
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
