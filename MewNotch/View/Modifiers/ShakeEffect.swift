//
//  ShakeEffect.swift
//  MewNotch
//

import SwiftUI

/// Horizontal oscillation used to draw attention to the notch.
///
/// Driven by a counter rather than a boolean so that repeated triggers each
/// start a fresh shake instead of cancelling one another.
struct ShakeEffect: GeometryEffect {

    /// Peak travel from centre, in points.
    var amplitude: CGFloat = 4

    /// Complete back-and-forth cycles per trigger.
    var cycles: CGFloat = 3

    /// The trigger counter. SwiftUI interpolates it across the animation, so
    /// its fractional part is the progress through a single shake.
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let progress = animatableData.truncatingRemainder(dividingBy: 1)

        // Taper the travel so the shake settles rather than stopping mid-swing.
        let decay = 1 - progress
        let offset = amplitude * decay * sin(progress * .pi * 2 * cycles)

        return ProjectionTransform(
            CGAffineTransform(translationX: offset, y: 0)
        )
    }
}

extension View {

    /// Shakes the view each time `trigger` changes.
    func shakes(
        on trigger: Int,
        amplitude: CGFloat = 4,
        cycles: CGFloat = 3,
        duration: TimeInterval = 0.4
    ) -> some View {
        modifier(
            ShakeEffect(
                amplitude: amplitude,
                cycles: cycles,
                animatableData: CGFloat(trigger)
            )
        )
        .animation(.linear(duration: duration), value: trigger)
    }
}
