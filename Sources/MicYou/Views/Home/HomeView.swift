// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouCore
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
    /// Sample notes from -MicYouReleaseNotesPreview, debug builds only
    @State private var previewRelease: AppRelease?

    var body: some View {
        FillingScrollView { isWide in
            VStack(spacing: 20) {
                HomeHeader(openSettings: { showSettings = true }, dim: model.isActive ? { model.setDimmed(true) } : nil) {
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
                        SessionView(isWide: isWide)
                            .adaptiveTransition(.swap(scale: 0.96))
                    } else {
                        IdleView(isWide: isWide, openPicker: { showPicker = true }, openSettings: { showSettings = true })
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
        // Rotating changes the size, stereo capture follows the new orientation
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height } action: { _ in
            model.orientationChanged()
        }
        .sensoryFeedback(trigger: model.phase, Self.feedback)
        .overlay {
            if model.isDimmed {
                DimOverlay()
                    .transition(.opacity)
            }
        }
        .animation(Motion.screen, value: model.isDimmed)
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
        #if DEBUG
        .releaseNotesSheet($previewRelease)
        .onAppear { previewRelease = Self.releaseNotesPreview }
        #endif
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

    #if DEBUG
    /// For checking the notes sheet on a device, which only appears for a newer release:
    /// launch with -MicYouReleaseNotesPreview YES to open it with notes shaped like release.yml writes them
    private static var releaseNotesPreview: AppRelease? {
        guard UserDefaults.standard.bool(forKey: "MicYouReleaseNotesPreview") else { return nil }
        let markdown = """
        ## Changes

        - feat: suggest lowering or raising the input gain
        - fix: clamp the round trip and packet loss the desktop reports
        - style: polish widgets for tinted Home Screens
        - refactor: drop redundant state and pass-through helpers

        ## Acknowledgements

        - Thanks to [@ShirazuNagisa](https://github.com/ShirazuNagisa) for bringing MicYou to TestFlight with their paid Apple Developer account

        ## Files

        - `MicYou-*.ipa` unsigned
        """
        return AppRelease(version: AppVersion("9.9.9")!, page: ProjectLinks.releases, notes: ReleaseNotes(markdown: markdown))
    }
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

enum HomeLayout {
    /// Widest the home screen content gets, about a large phone in portrait
    static let maxWidth: CGFloat = 520
    /// Widest the two column layout gets
    static let wideMaxWidth: CGFloat = 1040
    /// Room between the two columns
    static let columnSpacing: CGFloat = 40
    /// Room between the content and the sides of the window, more with two columns
    static func margin(isWide: Bool) -> CGFloat { isWide ? 32 : 20 }

    /// Landscape windows with room for two phone like columns, such as an iPad in landscape
    /// Narrow windows in Split View or Stage Manager keep the single column
    static func isWide(_ size: CGSize) -> Bool {
        size.width > size.height && size.width >= 860
    }
}

/// Title or status on the left and the settings button on the right
struct HomeHeader<Leading: View>: View {
    let openSettings: () -> Void
    /// Turns the screen black, offered while a session is active
    var dim: (() -> Void)?
    @ViewBuilder var leading: Leading

    var body: some View {
        HStack {
            leading
            Spacer(minLength: 12)
            if let dim {
                Button(action: dim) {
                    icon(L10n.Dim.button, systemImage: "moon.fill")
                }
                .glassButtonStyle()
                .buttonBorderShape(.circle)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            Button(action: openSettings) {
                icon(L10n.Common.settings, systemImage: "gearshape")
            }
            .glassButtonStyle()
            .buttonBorderShape(.circle)
            .tourTarget(.settings)
            .keyboardShortcut(",", modifiers: .command)
        }
        .frame(minHeight: 44)
    }

    /// The title stays in the label for VoiceOver and the list of keyboard shortcuts
    private func icon(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.title3)
            .frame(width: 28, height: 28)
    }
}

/// Fills the screen when the content is short and scrolls when it is not, such as on small phones or at large text sizes
/// On iPad the content keeps a phone like width in the middle instead of stretching, or splits into two columns in landscape
struct FillingScrollView<Content: View>: View {
    @ViewBuilder var content: (_ isWide: Bool) -> Content

    var body: some View {
        GeometryReader { proxy in
            let isWide = HomeLayout.isWide(proxy.size)
            ScrollView {
                content(isWide)
                    .padding(.horizontal, HomeLayout.margin(isWide: isWide))
                    .padding(.vertical, 8)
                    .frame(maxWidth: isWide ? HomeLayout.wideMaxWidth : HomeLayout.maxWidth, minHeight: proxy.size.height)
                    .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
