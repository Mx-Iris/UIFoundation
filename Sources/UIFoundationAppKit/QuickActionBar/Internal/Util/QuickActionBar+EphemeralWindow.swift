//
//  QuickActionBar+EphemeralWindow.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import AppKit
import Foundation
import QuartzCore

extension QuickActionBar {
    /// A panel that closes when it resigns focus (e.g. user clicks outside).
    internal class EphemeralWindow: NSPanel {
        private enum PresentationAnimationState {
            case idle
            case presenting
            case presented
            case dismissing
            case closed
        }

        private struct TransformAnimationValues {
            let horizontalScale: CGFloat
            let horizontalTranslation: CGFloat
            let verticalScale: CGFloat
            let verticalTranslation: CGFloat
        }

        private var presentationAnimationState: PresentationAnimationState = .idle
        private var nextAnimationIdentifier: UInt = 0

        override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
            super.init(
                contentRect: contentRect,
                styleMask: [.nonactivatingPanel, .titled, .borderless, .resizable, .closable, .fullSizeContentView],
                backing: backingStoreType,
                defer: flag
            )

            self.isFloatingPanel = true
            self.level = .floating

            self.titleVisibility = .hidden
            self.titlebarAppearsTransparent = true

            self.hasShadow = true
            self.invalidateShadow()

            self.hidesOnDeactivate = true

            self.animationBehavior = .none
        }

        /// Close automatically when out of focus (e.g. outside click).
        override func resignMain() {
            super.resignMain()
            self.close()
        }

        override func resignKey() {
            super.resignKey()
            self.close()
        }

        /// Close and toggle presentation.
        override func close() {
            guard
                self.presentationAnimationState != .dismissing,
                self.presentationAnimationState != .closed
            else { return }

            self.dismissWithAnimation()
        }

        private func performSuperClose() {
            super.close()
        }

        /// Called when the window closes.
        var didDetectClose: (() -> Void)?

        /// Called when the present animation finishes.
        var didFinishPresentAnimation: (() -> Void)?

        /// The layer to apply scale animation to (defaults to `contentView.layer`).
        var animationLayer: CALayer?

        /// `canBecomeKey` and `canBecomeMain` are both required so that text inputs can receive focus.
        override var canBecomeKey: Bool {
            return true
        }

        override var canBecomeMain: Bool {
            return true
        }

        // MARK: - Spotlight-style Animations

        private static let animationKey = "spotlight_scale"

        /// Spring scale + translation pair for one axis. Translation compensates
        /// for the (0,0) anchor point to simulate center-origin scaling.
        private static func makeAxisAnimations(
            scaleKeyPath: String,
            translationKeyPath: String,
            scaleFrom: CGFloat,
            scaleTo: CGFloat,
            translationFrom: CGFloat,
            translationTo: CGFloat,
            perceptualDuration: CGFloat,
            bounce: CGFloat
        ) -> (CASpringAnimation, CASpringAnimation) {
            let scaleAnimation: CASpringAnimation
            let translationAnimation: CASpringAnimation

            if #available(macOS 14.0, *) {
                scaleAnimation = CASpringAnimation(perceptualDuration: perceptualDuration, bounce: bounce)
                translationAnimation = CASpringAnimation(perceptualDuration: perceptualDuration, bounce: bounce)
            } else {
                scaleAnimation = CASpringAnimation(keyPath: scaleKeyPath)
                translationAnimation = CASpringAnimation(keyPath: translationKeyPath)
                let dampingValue: CGFloat = bounce > 0.2 ? 10 + (0.41 - bounce) * 20 : 20
                let stiffnessValue: CGFloat = bounce > 0.2 ? 300 : 150
                for animation in [scaleAnimation, translationAnimation] {
                    animation.damping = dampingValue
                    animation.stiffness = stiffnessValue
                    animation.mass = 1
                }
            }

            scaleAnimation.keyPath = scaleKeyPath
            scaleAnimation.fromValue = scaleFrom
            scaleAnimation.toValue = scaleTo
            scaleAnimation.duration = scaleAnimation.settlingDuration

            translationAnimation.keyPath = translationKeyPath
            translationAnimation.fromValue = translationFrom
            translationAnimation.toValue = translationTo
            translationAnimation.duration = translationAnimation.settlingDuration

            return (scaleAnimation, translationAnimation)
        }

        /// Present the window with a Spotlight-style spring scale + fade animation.
        func presentWithAnimation() {
            guard self.presentationAnimationState == .idle else { return }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.alphaValue = 0
            CATransaction.commit()

            self.makeKeyAndOrderFront(nil)
            self.presentWithAnimation(isInitialPresentation: true)
        }

        /// Reverse an in-progress dismissal without closing and recreating the panel.
        @discardableResult
        func resumePresentation() -> Bool {
            guard self.presentationAnimationState == .dismissing else { return false }

            if #available(macOS 14.0, *) {
                NSApp.activate()
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }

            self.makeKeyAndOrderFront(nil)
            self.presentWithAnimation(isInitialPresentation: false)
            return true
        }

        private func presentWithAnimation(isInitialPresentation: Bool) {
            self.presentationAnimationState = .presenting
            let animationIdentifier = self.beginAnimation()

            if let layer = self.animationLayer ?? self.contentView?.layer {
                let endingValues = Self.presentedTransformAnimationValues
                let startingValues = if isInitialPresentation {
                    Self.dismissedTransformAnimationValues(for: layer.bounds)
                } else {
                    Self.currentTransformAnimationValues(
                        from: layer,
                        defaultValues: Self.dismissedTransformAnimationValues(for: layer.bounds)
                    )
                }

                self.addTransformAnimation(
                    to: layer,
                    startingValues: startingValues,
                    endingValues: endingValues,
                    perceptualDuration: 0.28,
                    horizontalBounce: 0.41,
                    verticalBounce: 0.32,
                    keepsFinalState: false
                )
            }

            self.animateAlphaValue(to: 1.0) { [weak self] in
                guard
                    let self,
                    self.nextAnimationIdentifier == animationIdentifier,
                    self.presentationAnimationState == .presenting
                else { return }

                self.presentationAnimationState = .presented
                self.didFinishPresentAnimation?()
                self.didFinishPresentAnimation = nil
            }
        }

        /// Dismiss the window with a Spotlight-style spring scale + fade animation.
        private func dismissWithAnimation() {
            self.presentationAnimationState = .dismissing
            let animationIdentifier = self.beginAnimation()

            if let layer = self.animationLayer ?? self.contentView?.layer {
                let startingValues = Self.currentTransformAnimationValues(
                    from: layer,
                    defaultValues: Self.presentedTransformAnimationValues
                )
                let endingValues = Self.dismissedTransformAnimationValues(for: layer.bounds)

                self.addTransformAnimation(
                    to: layer,
                    startingValues: startingValues,
                    endingValues: endingValues,
                    perceptualDuration: 0.45,
                    horizontalBounce: 0.05,
                    verticalBounce: 0.05,
                    keepsFinalState: true
                )
            }

            self.animateAlphaValue(to: 0) { [weak self] in
                guard
                    let self,
                    self.nextAnimationIdentifier == animationIdentifier,
                    self.presentationAnimationState == .dismissing
                else { return }

                self.presentationAnimationState = .closed
                self.didFinishPresentAnimation = nil
                self.performSuperClose()
                self.didDetectClose?()
            }
        }

        private func beginAnimation() -> UInt {
            self.nextAnimationIdentifier &+= 1
            return self.nextAnimationIdentifier
        }

        private func animateAlphaValue(to alphaValue: CGFloat, completion: @escaping () -> Void) {
            if #available(macOS 14.0, *) {
                self.animations = ["alphaValue": CASpringAnimation(perceptualDuration: 0.28, bounce: 0.41)]
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.allowsImplicitAnimation = true
                self.animator().alphaValue = alphaValue
            }, completionHandler: completion)
        }

        private func addTransformAnimation(
            to layer: CALayer,
            startingValues: TransformAnimationValues,
            endingValues: TransformAnimationValues,
            perceptualDuration: CGFloat,
            horizontalBounce: CGFloat,
            verticalBounce: CGFloat,
            keepsFinalState: Bool
        ) {
            let (horizontalScaleAnimation, horizontalTranslationAnimation) = Self.makeAxisAnimations(
                scaleKeyPath: "transform.scale.x",
                translationKeyPath: "transform.translation.x",
                scaleFrom: startingValues.horizontalScale,
                scaleTo: endingValues.horizontalScale,
                translationFrom: startingValues.horizontalTranslation,
                translationTo: endingValues.horizontalTranslation,
                perceptualDuration: perceptualDuration,
                bounce: horizontalBounce
            )

            let (verticalScaleAnimation, verticalTranslationAnimation) = Self.makeAxisAnimations(
                scaleKeyPath: "transform.scale.y",
                translationKeyPath: "transform.translation.y",
                scaleFrom: startingValues.verticalScale,
                scaleTo: endingValues.verticalScale,
                translationFrom: startingValues.verticalTranslation,
                translationTo: endingValues.verticalTranslation,
                perceptualDuration: perceptualDuration,
                bounce: verticalBounce
            )

            let animationGroup = CAAnimationGroup()
            animationGroup.animations = [
                horizontalScaleAnimation,
                horizontalTranslationAnimation,
                verticalScaleAnimation,
                verticalTranslationAnimation,
            ]
            animationGroup.duration = [
                horizontalScaleAnimation,
                horizontalTranslationAnimation,
                verticalScaleAnimation,
                verticalTranslationAnimation,
            ].map(\.duration).max() ?? perceptualDuration

            if keepsFinalState {
                animationGroup.fillMode = .forwards
                animationGroup.isRemovedOnCompletion = false
            }

            layer.add(animationGroup, forKey: Self.animationKey)
        }

        private static var presentedTransformAnimationValues: TransformAnimationValues {
            TransformAnimationValues(
                horizontalScale: 1.0,
                horizontalTranslation: 0,
                verticalScale: 1.0,
                verticalTranslation: 0
            )
        }

        private static func dismissedTransformAnimationValues(for bounds: CGRect) -> TransformAnimationValues {
            let horizontalScale: CGFloat = 1.12
            let verticalScale: CGFloat = 0.95

            return TransformAnimationValues(
                horizontalScale: horizontalScale,
                horizontalTranslation: bounds.width * (1.0 - horizontalScale) / 2.0,
                verticalScale: verticalScale,
                verticalTranslation: bounds.height * (1.0 - verticalScale) / 2.0
            )
        }

        private static func currentTransformAnimationValues(
            from layer: CALayer,
            defaultValues: TransformAnimationValues
        ) -> TransformAnimationValues {
            guard let presentationLayer = layer.presentation() else { return defaultValues }

            return TransformAnimationValues(
                horizontalScale: Self.animationValue(
                    from: presentationLayer,
                    keyPath: "transform.scale.x",
                    defaultValue: defaultValues.horizontalScale
                ),
                horizontalTranslation: Self.animationValue(
                    from: presentationLayer,
                    keyPath: "transform.translation.x",
                    defaultValue: defaultValues.horizontalTranslation
                ),
                verticalScale: Self.animationValue(
                    from: presentationLayer,
                    keyPath: "transform.scale.y",
                    defaultValue: defaultValues.verticalScale
                ),
                verticalTranslation: Self.animationValue(
                    from: presentationLayer,
                    keyPath: "transform.translation.y",
                    defaultValue: defaultValues.verticalTranslation
                )
            )
        }

        private static func animationValue(
            from presentationLayer: CALayer,
            keyPath: String,
            defaultValue: CGFloat
        ) -> CGFloat {
            guard let number = presentationLayer.value(forKeyPath: keyPath) as? NSNumber else {
                return defaultValue
            }

            return CGFloat(number.doubleValue)
        }
    }
}

#endif
