//
//  EphemeralWindow.swift
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
        private var hasClosed = false

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
            if self.hasClosed == false {
                self.hasClosed = true
                self.didFinishPresentAnimation = nil
                self.animationLayer?.removeAnimation(forKey: Self.animationKey)
                dismissWithAnimation { [weak self] in
                    guard let self = self else { return }
                    self.performSuperClose()
                    self.didDetectClose?()
                }
            }
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
            axisLength: CGFloat,
            perceptualDuration: CGFloat,
            bounce: CGFloat,
            fillForwards: Bool
        ) -> (CASpringAnimation, CASpringAnimation) {
            let scaleAnim: CASpringAnimation
            let transAnim: CASpringAnimation

            if #available(macOS 14.0, *) {
                scaleAnim = CASpringAnimation(perceptualDuration: perceptualDuration, bounce: bounce)
                transAnim = CASpringAnimation(perceptualDuration: perceptualDuration, bounce: bounce)
            } else {
                scaleAnim = CASpringAnimation(keyPath: scaleKeyPath)
                transAnim = CASpringAnimation(keyPath: translationKeyPath)
                let dampingValue: CGFloat = bounce > 0.2 ? 10 + (0.41 - bounce) * 20 : 20
                let stiffnessValue: CGFloat = bounce > 0.2 ? 300 : 150
                for animation in [scaleAnim, transAnim] {
                    animation.damping = dampingValue
                    animation.stiffness = stiffnessValue
                    animation.mass = 1
                }
            }

            scaleAnim.keyPath = scaleKeyPath
            scaleAnim.fromValue = scaleFrom
            scaleAnim.toValue = scaleTo
            scaleAnim.duration = scaleAnim.settlingDuration

            // Translation = axisLength * (1 - scale) / 2 keeps scaling visually centered.
            transAnim.keyPath = translationKeyPath
            transAnim.fromValue = axisLength * (1.0 - scaleFrom) / 2.0
            transAnim.toValue = axisLength * (1.0 - scaleTo) / 2.0
            transAnim.duration = transAnim.settlingDuration

            if fillForwards {
                for animation in [scaleAnim, transAnim] {
                    animation.fillMode = .forwards
                    animation.isRemovedOnCompletion = false
                }
            }

            return (scaleAnim, transAnim)
        }

        /// Present the window with a Spotlight-style spring scale + fade animation.
        func presentWithAnimation() {
            let layer = self.animationLayer ?? self.contentView?.layer
            guard let layer = layer else {
                self.makeKeyAndOrderFront(nil)
                self.didFinishPresentAnimation?()
                self.didFinishPresentAnimation = nil
                return
            }

            CATransaction.begin()
            CATransaction.setDisableActions(true)
            self.alphaValue = 0
            CATransaction.commit()

            self.makeKeyAndOrderFront(nil)

            let bounds = layer.bounds

            let (sxAnim, txAnim) = Self.makeAxisAnimations(
                scaleKeyPath: "transform.scale.x", translationKeyPath: "transform.translation.x",
                scaleFrom: 1.12, scaleTo: 1.0, axisLength: bounds.width,
                perceptualDuration: 0.28, bounce: 0.41, fillForwards: false
            )

            let (syAnim, tyAnim) = Self.makeAxisAnimations(
                scaleKeyPath: "transform.scale.y", translationKeyPath: "transform.translation.y",
                scaleFrom: 0.95, scaleTo: 1.0, axisLength: bounds.height,
                perceptualDuration: 0.28, bounce: 0.32, fillForwards: false
            )

            let group = CAAnimationGroup()
            group.animations = [sxAnim, txAnim, syAnim, tyAnim]
            group.duration = [sxAnim, txAnim, syAnim, tyAnim].map(\.duration).max() ?? 0.3
            layer.add(group, forKey: Self.animationKey)

            if #available(macOS 14.0, *) {
                self.animations = ["alphaValue": CASpringAnimation(perceptualDuration: 0.28, bounce: 0.41)]
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.allowsImplicitAnimation = true
                self.animator().alphaValue = 1.0
            }, completionHandler: { [weak self] in
                self?.didFinishPresentAnimation?()
                self?.didFinishPresentAnimation = nil
            })
        }

        /// Dismiss the window with a Spotlight-style spring scale + fade animation.
        private func dismissWithAnimation(completion: @escaping () -> Void) {
            let layer = self.animationLayer ?? self.contentView?.layer
            guard let layer = layer else {
                completion()
                return
            }

            let bounds = layer.bounds

            let (sxAnim, txAnim) = Self.makeAxisAnimations(
                scaleKeyPath: "transform.scale.x", translationKeyPath: "transform.translation.x",
                scaleFrom: 1.0, scaleTo: 1.12, axisLength: bounds.width,
                perceptualDuration: 0.45, bounce: 0.05, fillForwards: true
            )

            let (syAnim, tyAnim) = Self.makeAxisAnimations(
                scaleKeyPath: "transform.scale.y", translationKeyPath: "transform.translation.y",
                scaleFrom: 1.0, scaleTo: 0.95, axisLength: bounds.height,
                perceptualDuration: 0.45, bounce: 0.05, fillForwards: true
            )

            let group = CAAnimationGroup()
            group.animations = [sxAnim, txAnim, syAnim, tyAnim]
            group.duration = [sxAnim, txAnim, syAnim, tyAnim].map(\.duration).max() ?? 0.3
            group.fillMode = .forwards
            group.isRemovedOnCompletion = false
            layer.add(group, forKey: Self.animationKey)

            if #available(macOS 14.0, *) {
                self.animations = ["alphaValue": CASpringAnimation(perceptualDuration: 0.28, bounce: 0.41)]
            }

            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.25
                context.allowsImplicitAnimation = true
                self.animator().alphaValue = 0
            }, completionHandler: completion)
        }
    }
}

#endif
