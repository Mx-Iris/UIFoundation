//
//  QuickActionBar+Mitosis.swift
//  UIFoundation
//

#if QuickActionBar && os(macOS)

import Foundation
import QuartzCore

extension QuickActionBar {
    /// Spotlight's browse buttons in numbers: how macOS 27.2 lays them out and moves them as they
    /// bud out of the search field and draw back into it.
    ///
    /// Read off SpotlightUIInternal in macOS 27.2 build 26B118 — `BrowseButton`,
    /// `MitosisButtonStack` and `BrowseButtonController`. The addresses are in
    /// `Researchs/Spotlight-Panel-Internals.md`, §11.
    enum Mitosis {
        /// The gap between the collapsed search field and the first button, and between buttons.
        static let buttonSpacing: CGFloat = 10

        /// A retracted button is a dot this fraction of its full size, centred on the collapsed
        /// field's trailing edge. Its icon shrinks with it.
        static let retractedScale: CGFloat = 0.1

        /// How blurred an icon is while it is hidden.
        static let hiddenIconBlurRadius: CGFloat = 10

        /// The smoothing distance of the glass union while the buttons are still part of the
        /// field. The union is smoothed less and less as they move out, until each is on its own.
        static let mergedSmoothness: CGFloat = 100

        /// How long after the bar starts to appear the buttons start to bud out. Measured on a 60 fps
        /// recording of Spotlight (28–29 frames); the binary starts them when the window reaches
        /// its invoking state, with no delay of its own on that path.
        static let presentationDelay: CFTimeInterval = 0.47

        /// A button is a circle 2 points smaller than the collapsed search field is tall.
        static func buttonDiameter(collapsedHeight: CGFloat) -> CGFloat {
            collapsedHeight >= 56 ? collapsedHeight - 2 : 54
        }

        /// The search field's width while the buttons are out: each button takes its diameter plus
        /// one gap.
        static func collapsedFieldWidth(barWidth: CGFloat, buttonDiameter: CGFloat, buttonCount: Int) -> CGFloat {
            barWidth - (buttonDiameter + buttonSpacing) * CGFloat(buttonCount)
        }

        /// How far past the collapsed field's trailing edge a button's centre ends up.
        static func translatedCenterOffset(index: Int, buttonDiameter: CGFloat) -> CGFloat {
            buttonSpacing + buttonDiameter / 2 + CGFloat(index) * (buttonDiameter + buttonSpacing)
        }

        /// The springs that bring the buttons out. All of them start together; only the icons wait.
        enum Show {
            /// The union's smoothing distance, from merged to apart.
            static let smoothness = Spring(duration: 0.71, bounce: 0.01)

            /// The search field narrowing to make room.
            static let field = Spring(duration: 0.39, bounce: 0.39)

            /// The icons sharpening and fading in, after ``visibilityDelay``.
            static let visibility = Spring(duration: 0.49, bounce: 0.15)

            static let visibilityDelay: CFTimeInterval = 0.17

            /// A button moving out to its place. The farther out, the slower and less bouncy.
            static func translation(index: Int) -> Spring {
                switch index {
                case 0: Spring(duration: 0.35, bounce: 0.43)
                case 1: Spring(duration: 0.45, bounce: 0.39)
                case 2: Spring(duration: 0.55, bounce: 0.35)
                case 3: Spring(duration: 0.60, bounce: 0.31)
                // Spotlight never shows a fifth button; this is the fallback its code has for one.
                default: Spring(duration: 0.45 + 0.1 * CGFloat(index), bounce: max(0.39 - 0.04 * CGFloat(index), 0))
                }
            }

            /// A button and its icon growing from a dot.
            static func scale(index: Int) -> Spring {
                switch index {
                case 0: Spring(duration: 0.41, bounce: 0.394)
                case 1: Spring(duration: 0.55, bounce: 0.35)
                case 2: Spring(duration: 0.65, bounce: 0.32)
                default: Spring(duration: 0.41 + 0.1 * CGFloat(index), bounce: max(0.394 - 0.04 * CGFloat(index), 0))
                }
            }
        }

        /// The springs that draw the buttons back into the field.
        enum Hide {
            /// The icons blurring out.
            static let visibility = Spring(duration: 0.20, bounce: 0.05)

            /// Everything else at once: the field widening, the buttons shrinking back to dots on
            /// its edge, and the union merging them into it.
            static let movement = Spring(duration: 0.41, bounce: 0.12)
        }
    }

    /// The browse buttons' animated state at any moment: whether they are out, and how far each
    /// part of the choreography has come.
    ///
    /// Every value is a progress from 0, the buttons drawn into the field, to 1, the buttons out,
    /// so springs can retarget mid-flight from any point. ``layout(at:barWidth:collapsedHeight:)``
    /// turns them into geometry.
    struct MitosisAnimation: Equatable {
        let buttonCount: Int

        /// Whether the buttons are out, or on their way out.
        private(set) var isShown = false

        private var separation = SpringAnimatedValue(0)
        private var fieldCollapse = SpringAnimatedValue(0)
        private var translations: [SpringAnimatedValue]
        private var scales: [SpringAnimatedValue]
        private var visibilities: [SpringAnimatedValue]

        init(buttonCount: Int) {
            self.buttonCount = buttonCount
            self.translations = Array(repeating: SpringAnimatedValue(0), count: buttonCount)
            self.scales = Array(repeating: SpringAnimatedValue(0), count: buttonCount)
            self.visibilities = Array(repeating: SpringAnimatedValue(0), count: buttonCount)
        }

        /// Brings the buttons out, the way `BrowseButtonController` shows them: the union
        /// jumps to fully merged, then every spring starts at `time`.
        mutating func show(at time: CFTimeInterval) {
            guard !isShown else { return }
            isShown = true
            separation.jump(to: 0)
            separation.animate(to: 1, with: Mitosis.Show.smoothness, at: time)
            fieldCollapse.animate(to: 1, with: Mitosis.Show.field, at: time)
            for index in 0..<buttonCount {
                translations[index].animate(to: 1, with: Mitosis.Show.translation(index: index), at: time)
                scales[index].animate(to: 1, with: Mitosis.Show.scale(index: index), at: time)
                visibilities[index].animate(to: 1, with: Mitosis.Show.visibility, delay: Mitosis.Show.visibilityDelay, at: time)
            }
        }

        /// Draws the buttons back into the field: the union jumps to fully apart and merges them
        /// in again as they shrink back. Nothing happens when they are already in.
        mutating func hide(at time: CFTimeInterval) {
            guard isShown else { return }
            isShown = false
            separation.jump(to: 1)
            separation.animate(to: 0, with: Mitosis.Hide.movement, at: time)
            fieldCollapse.animate(to: 0, with: Mitosis.Hide.movement, at: time)
            for index in 0..<buttonCount {
                visibilities[index].animate(to: 0, with: Mitosis.Hide.visibility, at: time)
                translations[index].animate(to: 0, with: Mitosis.Hide.movement, at: time)
                scales[index].animate(to: 0, with: Mitosis.Hide.movement, at: time)
            }
        }

        /// Puts the buttons straight out or straight in, with no animation — for Reduce Motion.
        mutating func jump(toShown shown: Bool) {
            isShown = shown
            let progress: CGFloat = shown ? 1 : 0
            separation.jump(to: progress)
            fieldCollapse.jump(to: progress)
            for index in 0..<buttonCount {
                translations[index].jump(to: progress)
                scales[index].jump(to: progress)
                visibilities[index].jump(to: progress)
            }
        }

        /// Whether every part has come to rest.
        func isSettled(at time: CFTimeInterval) -> Bool {
            separation.isSettled(at: time)
                && fieldCollapse.isSettled(at: time)
                && translations.allSatisfy { $0.isSettled(at: time) }
                && scales.allSatisfy { $0.isSettled(at: time) }
                && visibilities.allSatisfy { $0.isSettled(at: time) }
        }

        /// The geometry at `time`, in a top-left-origin space as wide as the bar.
        func layout(at time: CFTimeInterval, barWidth: CGFloat, collapsedHeight: CGFloat) -> MitosisLayout {
            let buttonDiameter = Mitosis.buttonDiameter(collapsedHeight: collapsedHeight)
            let collapsedFieldWidth = Mitosis.collapsedFieldWidth(barWidth: barWidth, buttonDiameter: buttonDiameter, buttonCount: buttonCount)
            let buttons = (0..<buttonCount).map { index in
                let translation = translations[index].value(at: time)
                let scale = Mitosis.retractedScale + (1 - Mitosis.retractedScale) * scales[index].value(at: time)
                let visibility = visibilities[index].value(at: time)
                return MitosisLayout.Button(
                    center: CGPoint(
                        x: collapsedFieldWidth + translation * Mitosis.translatedCenterOffset(index: index, buttonDiameter: buttonDiameter),
                        y: collapsedHeight / 2
                    ),
                    diameter: buttonDiameter,
                    scale: max(scale, 0),
                    iconOpacity: min(max(visibility, 0), 1),
                    iconBlurRadius: Mitosis.hiddenIconBlurRadius * min(max(1 - visibility, 0), 1)
                )
            }
            return MitosisLayout(
                smoothness: max(Mitosis.mergedSmoothness * (1 - separation.value(at: time)), 0),
                fieldWidth: barWidth - fieldCollapse.value(at: time) * (barWidth - collapsedFieldWidth),
                buttons: buttons
            )
        }
    }

    /// Where everything is at one moment of the browse buttons' animation.
    struct MitosisLayout: Equatable {
        struct Button: Equatable {
            /// The button's centre, in the bar's top-left-origin space.
            var center: CGPoint
            /// The button's full size, before ``scale``.
            var diameter: CGFloat
            /// How large the button's glass circle and its icon are drawn, 1 being full size.
            var scale: CGFloat
            var iconOpacity: CGFloat
            var iconBlurRadius: CGFloat

            /// The glass circle's frame: the button's size at its current scale, around its centre.
            var glassFrame: CGRect {
                let scaledDiameter = diameter * scale
                return CGRect(x: center.x - scaledDiameter / 2, y: center.y - scaledDiameter / 2, width: scaledDiameter, height: scaledDiameter)
            }

            /// The clickable frame: always the full size, around the centre.
            var buttonFrame: CGRect {
                CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
            }
        }

        /// The glass union's smoothing distance, in points.
        var smoothness: CGFloat
        /// The search field's width.
        var fieldWidth: CGFloat
        var buttons: [Button]
    }
}

#endif
