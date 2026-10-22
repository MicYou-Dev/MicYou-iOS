// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Shared timing so every screen moves with the same feel
enum Motion {
    /// Idle to session and back
    static let screen: Animation = .smooth(duration: 0.4)
    /// Changes inside a screen: phase, mute, notices, list rows
    static let state: Animation = .smooth(duration: 0.3)
    /// Leaving content clears out quickly so two layers of glass are never half visible at once
    static let exit: Animation = .easeOut(duration: 0.15)
    /// Controls sliding in from an edge
    static let slide: Animation = .spring(duration: 0.45, bounce: 0.12)
}

extension AnyTransition {
    /// Replaces content in place: the old content fades out fast, the new one fades in while settling from a slight scale
    static func swap(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: scale, anchor: anchor)).animation(Motion.screen.delay(0.05)),
            removal: .opacity.animation(Motion.exit)
        )
    }

    /// Cards that appear in a stack, unfolding from their top edge
    static var notice: AnyTransition {
        .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
    }

    /// Bars pinned to the bottom edge
    static var bottomBar: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity).animation(Motion.slide),
            removal: .move(edge: .bottom).combined(with: .opacity).animation(.easeIn(duration: 0.2))
        )
    }
}

extension ContentTransition {
    /// Symbols that share a shape morph into each other, such as a slash drawn on, from iOS 18;
    /// a plain replace before that and between unrelated symbols
    static var magicReplace: ContentTransition {
        if #available(iOS 18, *) {
            .symbolEffect(.replace.magic(fallback: .replace))
        } else {
            .symbolEffect(.replace)
        }
    }
}

extension View {
    /// The transition, or a plain fade when Reduce Motion is on
    func adaptiveTransition(_ transition: AnyTransition, reduced: AnyTransition = .opacity) -> some View {
        modifier(AdaptiveTransition(full: transition, reduced: reduced))
    }

    /// Animates changes of `value`, or applies them at once when Reduce Motion is on
    func adaptiveAnimation(_ animation: Animation = Motion.state, value: some Equatable) -> some View {
        modifier(AdaptiveAnimation(animation: animation, value: value))
    }
}

private struct AdaptiveTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let full: AnyTransition
    let reduced: AnyTransition

    func body(content: Content) -> some View {
        content.transition(reduceMotion ? reduced : full)
    }
}

private struct AdaptiveAnimation<Value: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: Value

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Plain buttons on custom surfaces: Liquid Glass reacts to touch by itself on iOS 26,
/// before that the surface dips slightly while pressed
struct SurfaceButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, *) {
            configuration.label
        } else {
            configuration.label
                .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
                .opacity(configuration.isPressed ? 0.8 : 1)
                .animation(.spring(duration: 0.25), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == SurfaceButtonStyle {
    static var surface: SurfaceButtonStyle { SurfaceButtonStyle() }
}
