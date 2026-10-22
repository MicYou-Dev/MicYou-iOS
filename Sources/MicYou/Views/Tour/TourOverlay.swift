// SPDX-License-Identifier: GPL-3.0-or-later

import MicYouShared
import SwiftUI

/// The guided tour after the welcome sheet: the home screen dims and a spotlight moves
/// from one control to the next, with a card explaining each
enum TourStep: Int, CaseIterable {
    case computer, connect, format, settings

    var title: String {
        switch self {
        case .computer: L10n.Tour.computerTitle
        case .connect: L10n.Tour.connectTitle
        case .format: L10n.Tour.formatTitle
        case .settings: L10n.Tour.settingsTitle
        }
    }

    var text: String {
        switch self {
        case .computer: L10n.Tour.computerText
        case .connect: L10n.Tour.connectText
        case .format: L10n.Tour.formatText
        case .settings: L10n.Tour.settingsText
        }
    }

    /// Round controls get a round spotlight, cards one that follows their corners
    var isRound: Bool { self == .connect || self == .settings }

    var next: TourStep? { TourStep(rawValue: rawValue + 1) }
}

/// Where each highlighted control is, collected from the views marked with tourTarget
struct TourAnchorKey: PreferenceKey {
    static let defaultValue: [TourStep: Anchor<CGRect>] = [:]

    static func reduce(value: inout [TourStep: Anchor<CGRect>], nextValue: () -> [TourStep: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Marks the control the spotlight moves to on this step
    func tourTarget(_ step: TourStep) -> some View {
        anchorPreference(key: TourAnchorKey.self, value: .bounds) { [step: $0] }
    }
}

struct TourOverlay: View {
    let anchors: [TourStep: Anchor<CGRect>]
    @Binding var step: TourStep?
    let finish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Room between the control and the edge of the spotlight
    private static let padding: CGFloat = 8
    /// Corner radius of the cards on the home screen
    private static let cardRadius: CGFloat = 22
    /// Widest the explanation card gets
    private static let cardWidth: CGFloat = 400
    /// Room between the card and the screen edges
    private static let margin: CGFloat = 16

    var body: some View {
        GeometryReader { proxy in
            if let step, let anchor = anchors[step] {
                let rect = proxy[anchor].insetBy(dx: -Self.padding, dy: -Self.padding)
                let radius = step.isRound ? min(rect.width, rect.height) / 2 : Self.cardRadius + Self.padding
                // The card goes on whichever side of the spotlight has more room
                let below = proxy.size.height - rect.maxY >= rect.minY
                // Centered under the control as far as the screen allows, which matters with two columns on iPad
                let room = max(0, (proxy.size.width - 2 * Self.margin - Self.cardWidth) / 2)
                let shift = min(max(rect.midX - proxy.size.width / 2, -room), room)

                ZStack(alignment: .top) {
                    Spotlight(rect: rect, cornerRadius: radius)
                        .contentShape(Rectangle())
                        .onTapGesture(perform: advance)
                        .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        if below {
                            Color.clear.frame(height: rect.maxY + 14)
                            card(step, shift: shift)
                            Spacer(minLength: 0)
                        } else {
                            Spacer(minLength: 0)
                            card(step, shift: shift)
                            Color.clear.frame(height: proxy.size.height - rect.minY + 14)
                        }
                    }
                    .padding(.horizontal, Self.margin)
                }
            }
        }
        .ignoresSafeArea()
    }

    private func card(_ step: TourStep, shift: CGFloat) -> some View {
        TourCard(step: step, skip: finish, advance: advance)
            .frame(maxWidth: Self.cardWidth)
            .offset(x: shift)
            .id(step)
            .transition(.opacity)
    }

    private func advance() {
        guard let next = step?.next else { return finish() }
        withAnimation(reduceMotion ? nil : Motion.slide) { step = next }
    }
}

/// The dimmed screen with a hole over the highlighted control, and a soft ring around it
/// Built from a frame and a position rather than a path so the hole glides from step to step
private struct Spotlight: View {
    let rect: CGRect
    let cornerRadius: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .mask {
                    Rectangle()
                        .overlay { hole.blendMode(.destinationOut) }
                        .compositingGroup()
                }
            // Grows by a fixed distance rather than a scale, so wide cards do not push it off screen
            RoundedRectangle(cornerRadius: cornerRadius + (pulse ? 6 : 0), style: .continuous)
                .strokeBorder(.white.opacity(pulse ? 0 : 0.5), lineWidth: 2)
                .frame(width: rect.width + (pulse ? 12 : 0), height: rect.height + (pulse ? 12 : 0))
                .position(x: rect.midX, y: rect.midY)
                .allowsHitTesting(false)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false)) { pulse = true }
        }
    }

    private var hole: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

private struct TourCard: View {
    let step: TourStep
    let skip: () -> Void
    let advance: () -> Void

    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.Tour.progress(step.rawValue + 1, of: TourStep.allCases.count))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                if step.next != nil {
                    Button(L10n.Tour.skip, action: skip)
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                }
            }
            Text(step.title)
                .font(.headline)
                .accessibilityFocused($focused)
            Text(step.text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(action: advance) {
                    Text(step.next == nil ? L10n.Common.done : L10n.Tour.next)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 8)
                }
                .glassProminentButtonStyle()
                .buttonBorderShape(.capsule)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .glassSurface(in: .rect(cornerRadius: 24, style: .continuous), interactive: false, fallback: .regularMaterial)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear { focused = true }
    }
}
