//
//  QuickActionBar+GlassPlatterView.swift
//  UIFoundation
//

#if QuickActionBar && os(macOS)

import AppKit
import CoreImage

extension QuickActionBar {
    /// The search platter's glass on macOS 26 and later, and the browse buttons that bud out of
    /// it the way Spotlight's do.
    ///
    /// `NSGlassEffectContainerView` draws its member glass views as one material over a smooth
    /// union of their shapes, and its `spacing` is the smoothing distance of that union — the
    /// value Spotlight animates as `mitosisSmoothness`. Three things about the container decide
    /// how this view moves (read off macOS 27.2 AppKit; see the guide):
    ///
    /// - It rebuilds each member's shape from the member's frame and corner radius on every layout
    ///   pass and never reads a layer transform, so a circle grows by its frame, not by scaling.
    /// - A new corner radius alone does not ask it to lay out again; every frame of the
    ///   animation marks it.
    /// - Inside an implicit-animation context AppKit animates frames and `spacing` by itself, so
    ///   the frames are always set outside one.
    ///
    /// The icons are not glass: they are buttons in an overlay above the container, where a layer
    /// transform and a blur filter work as usual — the same split as Spotlight's, whose glass is a
    /// background behind its buttons.
    @available(macOS 26.0, *)
    final class GlassPlatterView: NSView {
        /// The view inside the platter's glass; the search field and the results live in it.
        let platterContentView: NSView

        /// Called with a button's index when it is clicked.
        var browseButtonClickHandler: ((Int) -> Void)?

        /// Called whenever the browse buttons come to rest, out or back in the field.
        var browseButtonsDidSettle: (() -> Void)?

        /// The platter's corner radius: half of Spotlight's 56 pt collapsed height, kept when
        /// the results make the platter taller.
        static let platterCornerRadius: CGFloat = 28

        private let glassContainerView = NSGlassEffectContainerView()
        private let glassLayoutView = FlippedContainerView()
        private let platterGlassView = NSGlassEffectView()
        private let buttonOverlayView = BrowseButtonOverlayView()

        /// How far the platter's trailing edge sits in from the bar's: 0 at full width.
        ///
        /// The platter is laid out by constraints rather than by frame so that it is never zero
        /// wide, not even before the first layout pass — its content's minimum widths would then
        /// break the search row's constraints. Its edges are pinned to this view, not to the
        /// container's content view: the container holds that one with constraints below
        /// required, and results wanting the bar's full width would otherwise stretch it and widen
        /// the platter at once instead of along the animation.
        private lazy var platterTrailingConstraint = platterGlassView.trailingAnchor.constraint(equalTo: trailingAnchor)

        private var browseButtonGlassViews: [NSGlassEffectView] = []
        private var browseButtons: [BrowseButton] = []
        private var animation: MitosisAnimation?
        private var collapsedHeight: CGFloat = 56
        private var animationDisplayLink: CADisplayLink?

        /// Identifies the list the current buttons were made from; `nil` when there are none.
        private(set) var displayedBrowseItemsIdentifier: Int?

        init(platterContentView: NSView) {
            self.platterContentView = platterContentView
            super.init(frame: .zero)
            setup()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setup() {
            wantsLayer = true

            glassContainerView.translatesAutoresizingMaskIntoConstraints = false
            glassLayoutView.translatesAutoresizingMaskIntoConstraints = false
            glassContainerView.contentView = glassLayoutView
            addSubview(glassContainerView)

            platterGlassView.cornerRadius = Self.platterCornerRadius
            platterGlassView.contentView = platterContentView
            platterGlassView.translatesAutoresizingMaskIntoConstraints = false
            glassLayoutView.addSubview(platterGlassView)
            NSLayoutConstraint.activate([
                platterGlassView.topAnchor.constraint(equalTo: topAnchor),
                platterGlassView.leadingAnchor.constraint(equalTo: leadingAnchor),
                platterGlassView.bottomAnchor.constraint(equalTo: bottomAnchor),
                platterTrailingConstraint,
            ])

            buttonOverlayView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(buttonOverlayView)

            for pinnedView in [glassContainerView, glassLayoutView, buttonOverlayView] as [NSView] {
                NSLayoutConstraint.activate([
                    pinnedView.topAnchor.constraint(equalTo: topAnchor),
                    pinnedView.leadingAnchor.constraint(equalTo: leadingAnchor),
                    pinnedView.trailingAnchor.constraint(equalTo: trailingAnchor),
                    pinnedView.bottomAnchor.constraint(equalTo: bottomAnchor),
                ])
            }
        }

        /// The glass view drawing the platter, in the container's content view.
        var platterGlass: NSGlassEffectView {
            platterGlassView
        }

        /// The glass circles behind the browse buttons, in the order of the items.
        var browseButtonGlasses: [NSGlassEffectView] {
            browseButtonGlassViews
        }

        /// The browse buttons, in the order of the items.
        var browseButtonControls: [NSButton] {
            browseButtons
        }

        /// The glass container's smoothing distance.
        var glassSmoothness: CGFloat {
            glassContainerView.spacing
        }

        /// Whether the browse buttons are out, or on their way out.
        var isShowingBrowseButtons: Bool {
            animation?.isShown ?? false
        }

        /// Whether there are browse buttons at all, out or on their way in.
        var hasBrowseButtons: Bool {
            animation != nil
        }

        // MARK: - Showing and hiding

        /// Brings the buttons for `items` out of the field.
        ///
        /// Buttons for another list must be drawn back in first: the caller hides them and comes
        /// back once they have settled.
        func showBrowseButtons(_ items: [BrowseItem], identifier: Int, collapsedHeight: CGFloat, animated: Bool) {
            guard !items.isEmpty else { return }
            if displayedBrowseItemsIdentifier != identifier {
                // Another list is still out or drawing back in.
                guard animation == nil else { return }
                makeBrowseButtons(for: items)
                displayedBrowseItemsIdentifier = identifier
            }
            self.collapsedHeight = collapsedHeight
            guard var currentAnimation = animation, !currentAnimation.isShown else { return }

            if animated {
                currentAnimation.show(at: CACurrentMediaTime())
                animation = currentAnimation
                startDisplayLink()
            } else {
                currentAnimation.jump(toShown: true)
                animation = currentAnimation
                applyLayout(at: CACurrentMediaTime())
                didSettle()
            }
        }

        /// Draws the buttons back into the field. Once they settle there they are removed.
        func hideBrowseButtons(animated: Bool) {
            guard var currentAnimation = animation, currentAnimation.isShown else { return }

            if animated {
                currentAnimation.hide(at: CACurrentMediaTime())
                animation = currentAnimation
                startDisplayLink()
            } else {
                currentAnimation.jump(toShown: false)
                animation = currentAnimation
                applyLayout(at: CACurrentMediaTime())
                didSettle()
            }
        }

        /// Ends whatever the buttons are doing by putting them where they are heading. For tests,
        /// which cannot wait on a display link.
        func finishBrowseButtonAnimations() {
            guard var currentAnimation = animation else { return }
            currentAnimation.jump(toShown: currentAnimation.isShown)
            animation = currentAnimation
            applyLayout(at: CACurrentMediaTime())
            didSettle()
            layoutSubtreeIfNeeded()
        }

        private func makeBrowseButtons(for items: [BrowseItem]) {
            for (index, item) in items.enumerated() {
                let glassView = NSGlassEffectView()
                browseButtonGlassViews.append(glassView)

                let button = BrowseButton(item: item)
                button.tag = index
                button.target = self
                button.action = #selector(browseButtonClicked(_:))
                browseButtons.append(button)
                buttonOverlayView.addSubview(button)
            }
            // Below the platter, and the button nearest the field on top, as Spotlight stacks them.
            for glassView in browseButtonGlassViews.reversed() {
                glassLayoutView.addSubview(glassView, positioned: .below, relativeTo: platterGlassView)
            }
            animation = MitosisAnimation(buttonCount: items.count)
        }

        private func removeBrowseButtons() {
            stopDisplayLink()
            browseButtonGlassViews.forEach { $0.removeFromSuperview() }
            browseButtons.forEach { $0.removeFromSuperview() }
            browseButtonGlassViews = []
            browseButtons = []
            animation = nil
            displayedBrowseItemsIdentifier = nil
            performWithoutImplicitAnimation {
                glassContainerView.spacing = 0
            }
            needsLayout = true
        }

        @objc private func browseButtonClicked(_ sender: NSButton) {
            browseButtonClickHandler?(sender.tag)
        }

        // MARK: - Frames

        override func layout() {
            super.layout()
            applyLayout(at: CACurrentMediaTime())
        }

        private func applyLayout(at time: CFTimeInterval) {
            performWithoutImplicitAnimation {
                guard let animation else {
                    setPlatterTrailingInset(0)
                    return
                }
                let layout = animation.layout(at: time, barWidth: bounds.width, collapsedHeight: collapsedHeight)
                glassContainerView.spacing = layout.smoothness
                setPlatterTrailingInset(bounds.width - layout.fieldWidth)
                for (index, buttonLayout) in layout.buttons.enumerated() {
                    let glassFrame = buttonLayout.glassFrame
                    browseButtonGlassViews[index].frame = glassFrame
                    browseButtonGlassViews[index].cornerRadius = glassFrame.width / 2
                    browseButtons[index].apply(buttonLayout, isShown: animation.isShown)
                }
                glassContainerView.needsLayout = true
            }
        }

        /// Moves the platter's trailing edge, touching the constraint only when the inset changes:
        /// `layout()` calls this too, and a changed constant there would ask for another pass.
        private func setPlatterTrailingInset(_ inset: CGFloat) {
            guard platterTrailingConstraint.constant != -inset else { return }
            platterTrailingConstraint.constant = -inset
        }

        private func performWithoutImplicitAnimation(_ changes: () -> Void) {
            NSAnimationContext.beginGrouping()
            NSAnimationContext.current.allowsImplicitAnimation = false
            NSAnimationContext.current.duration = 0
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            changes()
            CATransaction.commit()
            NSAnimationContext.endGrouping()
        }

        // MARK: - Display link

        private func startDisplayLink() {
            guard animationDisplayLink == nil else { return }
            let link = displayLink(target: DisplayLinkTarget(owner: self), selector: #selector(DisplayLinkTarget.displayLinkDidFire(_:)))
            link.add(to: .main, forMode: .common)
            animationDisplayLink = link
        }

        private func stopDisplayLink() {
            animationDisplayLink?.invalidate()
            animationDisplayLink = nil
        }

        fileprivate func displayLinkDidFire(_ link: CADisplayLink) {
            guard let animation else {
                stopDisplayLink()
                return
            }
            let time = link.targetTimestamp
            applyLayout(at: time)
            if animation.isSettled(at: time) {
                didSettle()
            }
        }

        private func didSettle() {
            stopDisplayLink()
            if let animation, !animation.isShown {
                removeBrowseButtons()
                applyLayout(at: CACurrentMediaTime())
            }
            window?.invalidateShadow()
            browseButtonsDidSettle?()
        }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            if newWindow == nil {
                stopDisplayLink()
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window != nil, let animation, !animation.isSettled(at: CACurrentMediaTime()) {
                startDisplayLink()
            }
        }
    }

    /// Forwards a display link's ticks without the link keeping the view alive.
    @available(macOS 26.0, *)
    private final class DisplayLinkTarget: NSObject {
        weak var owner: GlassPlatterView?

        init(owner: GlassPlatterView) {
            self.owner = owner
        }

        @objc func displayLinkDidFire(_ link: CADisplayLink) {
            guard let owner else {
                link.invalidate()
                return
            }
            owner.displayLinkDidFire(link)
        }
    }

    /// Holds the browse buttons above the glass, passing every other click through to the
    /// search field underneath. Under the macOS 27 SDK a view that answers hit tests over a
    /// control takes its clicks away, so this one answers only over its buttons.
    @available(macOS 26.0, *)
    final class BrowseButtonOverlayView: NSView {
        override var isFlipped: Bool { true }

        override func hitTest(_ point: NSPoint) -> NSView? {
            let hitView = super.hitTest(point)
            return hitView === self ? nil : hitView
        }
    }

    /// One browse button: the icon of a ``QuickActionBar/BrowseItem`` over its glass circle.
    ///
    /// The icon grows, fades and sharpens with the circle, by a layer transform and a Core Image
    /// blur — this view is outside the glass, so both work as they would anywhere else.
    @available(macOS 26.0, *)
    final class BrowseButton: NSButton {
        init(item: BrowseItem) {
            super.init(frame: .zero)
            image = item.image
            imagePosition = .imageOnly
            imageScaling = .scaleNone
            isBordered = false
            setButtonType(.momentaryPushIn)
            symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .title1)
            toolTip = item.title
            setAccessibilityLabel(item.title)
            refusesFirstResponder = true
            wantsLayer = true
            layerUsesCoreImageFilters = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // The search field keeps the keyboard focus, as Spotlight's buttons are not focusable.
        override var acceptsFirstResponder: Bool { false }

        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        func apply(_ buttonLayout: MitosisLayout.Button, isShown: Bool) {
            frame = buttonLayout.buttonFrame
            alphaValue = buttonLayout.iconOpacity
            // Usable once it is on its way out, as Spotlight enables a button with its move.
            if isEnabled != isShown {
                isEnabled = isShown
                setAccessibilityElement(isShown)
            }
            applyIconScale(buttonLayout.scale)
            applyIconBlur(radius: buttonLayout.iconBlurRadius)
        }

        /// Scales around the centre, wherever AppKit put the layer's anchor point.
        private func applyIconScale(_ scale: CGFloat) {
            guard let layer else { return }
            let centerOffsetX = bounds.width * (0.5 - layer.anchorPoint.x)
            let centerOffsetY = bounds.height * (0.5 - layer.anchorPoint.y)
            var transform = CATransform3DMakeTranslation(centerOffsetX, centerOffsetY, 0)
            transform = CATransform3DScale(transform, scale, scale, 1)
            transform = CATransform3DTranslate(transform, -centerOffsetX, -centerOffsetY, 0)
            layer.transform = transform
        }

        private func applyIconBlur(radius: CGFloat) {
            guard radius > 0.01 else {
                if !contentFilters.isEmpty {
                    contentFilters = []
                }
                return
            }
            guard let blur = CIFilter(name: "CIGaussianBlur") else { return }
            blur.setValue(radius, forKey: kCIInputRadiusKey)
            contentFilters = [blur]
        }
    }
}

#endif
