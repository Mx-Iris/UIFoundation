//
//  TabBar+SystemDecoration.swift
//  UIFoundation
//
//  Control-level Liquid-Glass decoration for ``TabBar/SystemStyle`` (macOS 26 look).
//  These views are floated *behind* the tab buttons by ``TabBar`` so real glass can sit under
//  the cell-drawn titles without covering them.
//
//  To match the system window-tab bar exactly, this reproduces AppKit's own per-tab glass config
//  (-[NSTabBarViewButton _makeTabButtonGlassView] / -[NSTabButton setActive:]): every tab gets its
//  own NSGlassEffectView — a frosted `_variant == 13` for non-selected tabs and a lit
//  `_variant == 1` + `_subvariant == "tab"` for the selected tab, with content lensing on and an
//  `_interactionState == 2` hover highlight. Those knobs are private, so they are set through
//  guarded, `responds(to:)`-checked selector calls; anything unavailable degrades gracefully.
//

#if TabBar && os(macOS)

import AppKit

// MARK: - Appearance-correct layer drawing

private extension NSView {
    /// Runs `body` with the receiver's `effectiveAppearance` installed as the current drawing
    /// appearance so that dynamic `NSColor`s resolve to the correct light/dark `CGColor`.
    func withDrawingAppearance(_ body: () -> Void) {
        if #available(macOS 11.0, *) {
            effectiveAppearance.performAsCurrentDrawingAppearance { body() }
        } else {
            let saved = NSAppearance.current
            NSAppearance.current = effectiveAppearance
            body()
            NSAppearance.current = saved
        }
    }
}

// MARK: - Private NSGlassEffectView configuration (macOS 26)

@available(macOS 26.0, *)
private extension NSGlassEffectView {
    /// The system's internal glass variants for a window tab.
    enum TabVariant {
        static let selected = 1   // -[NSTabBarViewButton setActive:] uses `_active ? 1 : 13`
        static let normal = 13
    }

    /// The system's interaction states.
    enum InteractionState {
        static let none = 0
        static let hovered = 2    // set on -[NSTabBarViewButton setHasMouseOverHighlight:] in Solarium
    }

    func setPrivateVariant(_ variant: Int) {
        callSelector("set_variant:", int: variant)
    }

    func setPrivateInteractionState(_ state: Int) {
        callSelector("set_interactionState:", int: state)
    }

    func setPrivateContentLensing(_ enabled: Bool) {
        callSelector("set_contentLensing:", bool: enabled)
    }

    func setPrivateSubduedState(_ state: Int) {
        callSelector("set_subduedState:", int: state)
    }

    func setPrivateAdaptiveAppearance(_ appearance: Int) {
        callSelector("set_adaptiveAppearance:", int: appearance)
    }

    func setPrivateSubvariant(_ subvariant: String?) {
        let selector = Selector(("set_subvariant:"))
        guard responds(to: selector), let implementation = method(for: selector) else { return }
        typealias Function = @convention(c) (NSObject, Selector, NSString?) -> Void
        let function = unsafeBitCast(implementation, to: Function.self)
        function(self, selector, subvariant as NSString?)
    }

    private func callSelector(_ name: String, int value: Int) {
        let selector = Selector((name))
        guard responds(to: selector), let implementation = method(for: selector) else { return }
        typealias Function = @convention(c) (NSObject, Selector, Int) -> Void
        let function = unsafeBitCast(implementation, to: Function.self)
        function(self, selector, value)
    }

    private func callSelector(_ name: String, bool value: Bool) {
        let selector = Selector((name))
        guard responds(to: selector), let implementation = method(for: selector) else { return }
        typealias Function = @convention(c) (NSObject, Selector, Bool) -> Void
        let function = unsafeBitCast(implementation, to: Function.self)
        function(self, selector, value)
    }
}

extension TabBar {
    /// The per-tab glass background. On macOS 26 it hosts a real `NSGlassEffectView` configured with
    /// the system's private tab knobs; on earlier systems it degrades to `NSVisualEffectView` (only
    /// visible for the selected tab) and finally a plain rounded fill.
    final class TabGlassView: NSView {
        enum TabState {
            case normal
            case hovered
            case selected
        }

        var cornerRadius: CGFloat = 12.0 {
            didSet { applyCornerRadius() }
        }

        /// `NSGlassEffectView` on macOS 26; kept as `NSView` so the type stays available on older SDKs.
        private var glassEffectView: NSView?
        private var visualEffectView: NSVisualEffectView?
        private var currentState: TabState = .normal

        /// Whichever material view this system could provide, or `nil` when only the plain fill is left.
        private var effectView: NSView? { glassEffectView ?? visualEffectView }

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            commonInit()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func commonInit() {
            wantsLayer = true
            layer?.zPosition = -1
            translatesAutoresizingMaskIntoConstraints = true

            if #available(macOS 26.0, *) {
                let glass = NSGlassEffectView()
                glass.frame = bounds
                glass.cornerRadius = cornerRadius
                glass.setPrivateContentLensing(true)
                addSubview(glass)
                glassEffectView = glass
            } else if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
                let effect = NSVisualEffectView()
                effect.frame = bounds
                effect.material = .selection
                effect.isEmphasized = false
                effect.blendingMode = .withinWindow
                effect.state = .active
                effect.wantsLayer = true
                effect.layer?.cornerRadius = cornerRadius
                effect.layer?.masksToBounds = true
                addSubview(effect)
                visualEffectView = effect
            }
        }

        /// Moves the glass to `newFrame`, carrying the hosted material view with it.
        ///
        /// The material view is positioned explicitly rather than by `autoresizingMask`, and it is
        /// animated in its own right rather than riding along inside its container: sublayers do not
        /// scale with their superlayer's bounds, so a container-only animation would leave the glass
        /// at its final size throughout. ``layout()`` is the backstop that keeps the two in step for
        /// any resize that does not come through here.
        func apply(frame newFrame: NSRect, animated: Bool, growingFrom anchor: TabBar.GrowthAnchor) {
            // A glass that has never been placed is opened *out of nothing*, the same way its button
            // is (see ``TabBar/place(_:at:animated:)``): seeded to zero width on `anchor`, then
            // sprung out to full size. It cannot simply be dropped at its final frame — the pill is
            // the only part of a system tab anyone can actually see, so a glass that lands full-size
            // on the first frame reads as "the tab appeared with no animation" even while the button
            // underneath is growing correctly. AppKit never faces this: its `NSGlassEffectView` is a
            // *subview* of `NSTabButton`, so it cannot help but grow with it, whereas ours is floated
            // behind the button and has to be driven.
            guard animated, frame.isEmpty else {
                TabBar.setFrame(newFrame, of: self, animated: animated)
                if let effectView {
                    TabBar.setFrame(NSRect(origin: .zero, size: newFrame.size), of: effectView, animated: animated)
                }
                return
            }

            // Seeded and grown in one go, and — like the button it backs — never carried along with a
            // reveal scroll: it had no on-screen position before this pass to be carried from.
            TabBar.ignoringScrollTranslation {
                let seed = TabBar.collapsedFrame(for: newFrame, growingFrom: anchor)
                TabBar.setFrame(seed, of: self, animated: false)
                TabBar.setFrame(newFrame, of: self, animated: true)
                if let effectView {
                    TabBar.setFrame(NSRect(origin: .zero, size: seed.size), of: effectView, animated: false)
                    TabBar.setFrame(NSRect(origin: .zero, size: newFrame.size), of: effectView, animated: true)
                }
            }
        }

        override func layout() {
            super.layout()
            effectView?.frame = bounds
        }

        /// Applies the system glass configuration for the given tab state.
        func configure(state: TabState) {
            currentState = state

            if #available(macOS 26.0, *), let glass = glassEffectView as? NSGlassEffectView {
                // Every tab shows glass (matching the system's frosted non-selected tabs).
                isHidden = false
                switch state {
                case .selected:
                    glass.setPrivateVariant(NSGlassEffectView.TabVariant.selected)
                    glass.setPrivateSubvariant("tab")
                    glass.setPrivateInteractionState(NSGlassEffectView.InteractionState.none)
                case .hovered:
                    glass.setPrivateVariant(NSGlassEffectView.TabVariant.normal)
                    glass.setPrivateSubvariant(nil)
                    glass.setPrivateInteractionState(NSGlassEffectView.InteractionState.hovered)
                case .normal:
                    glass.setPrivateVariant(NSGlassEffectView.TabVariant.normal)
                    glass.setPrivateSubvariant(nil)
                    glass.setPrivateInteractionState(NSGlassEffectView.InteractionState.none)
                }
            } else if visualEffectView != nil {
                // Pre-26: only the selected tab shows a material; non-selected tabs stay clear.
                isHidden = (state == .normal)
                visualEffectView?.isEmphasized = (state == .selected)
            } else {
                // Deepest fallback: a plain fill for the selected tab only.
                isHidden = (state == .normal)
                needsDisplay = true
            }
        }

        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            guard glassEffectView == nil, visualEffectView == nil, let layer = layer else { return }
            layer.cornerRadius = cornerRadius
            let color: NSColor = currentState == .hovered
                ? NSColor.secondaryLabelColor.withAlphaComponent(0.10)
                : NSColor.unemphasizedSelectedContentBackgroundColor
            withDrawingAppearance { layer.backgroundColor = color.cgColor }
        }

        private func applyCornerRadius() {
            if #available(macOS 26.0, *), let glass = glassEffectView as? NSGlassEffectView {
                glass.cornerRadius = cornerRadius
            }
            visualEffectView?.layer?.cornerRadius = cornerRadius
            if glassEffectView == nil, visualEffectView == nil {
                needsDisplay = true
            }
        }
    }

    /// The capsule-shaped Liquid-Glass background behind the whole tab bar, reproducing AppKit's
    /// `NSTabBarTrackView` glass (`sub_184F644B8`): `_variant == 1`, `_subvariant == "track"`,
    /// `_subduedState == 1`, content lensing on, `_adaptiveAppearance == 2`, and a corner radius of
    /// `min(width, height) / 2` so it reads as a pill keyed to the bar height.
    final class SystemBarTrackView: NSView {
        private var glassEffectView: NSView?
        private var visualEffectView: NSVisualEffectView?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            commonInit()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func commonInit() {
            wantsLayer = true
            translatesAutoresizingMaskIntoConstraints = true

            if #available(macOS 26.0, *) {
                let glass = NSGlassEffectView()
                glass.frame = bounds
                glass.autoresizingMask = [.width, .height]
                glass.setPrivateVariant(1)
                glass.setPrivateSubvariant("track")
                glass.setPrivateSubduedState(1)
                glass.setPrivateContentLensing(true)
                glass.setPrivateAdaptiveAppearance(2)
                addSubview(glass)
                glassEffectView = glass
            } else if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
                let effect = NSVisualEffectView()
                effect.frame = bounds
                effect.autoresizingMask = [.width, .height]
                effect.material = .headerView
                effect.blendingMode = .withinWindow
                effect.state = .active
                effect.wantsLayer = true
                effect.layer?.masksToBounds = true
                addSubview(effect)
                visualEffectView = effect
            }
        }

        override func layout() {
            super.layout()
            // Sized explicitly for the same reason as `TabGlassView`: autoresizing is skipped when a
            // frame change comes through an animator, and a material view left at zero size renders
            // nothing at all.
            glassEffectView?.frame = bounds
            visualEffectView?.frame = bounds

            let radius = min(bounds.width, bounds.height) / 2.0
            if #available(macOS 26.0, *), let glass = glassEffectView as? NSGlassEffectView {
                glass.cornerRadius = radius
            }
            visualEffectView?.layer?.cornerRadius = radius
            if glassEffectView == nil, visualEffectView == nil {
                layer?.cornerRadius = radius
            }
        }

        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            guard glassEffectView == nil, visualEffectView == nil, let layer = layer else { return }
            layer.cornerRadius = min(bounds.width, bounds.height) / 2.0
            withDrawingAppearance {
                layer.backgroundColor = NSColor.windowBackgroundColor.cgColor
            }
        }
    }

    /// A 1 pt hairline separator drawn between adjacent tabs, tinted with the system separator colour.
    final class TabSeparatorView: NSView {
        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            layer?.zPosition = -1
            // Starts hidden so its first placement is never animated: `updateSeparators` animates a
            // separator only from a position it was actually seen at, and a visible-by-default view
            // would make that guard pass on the very first pass, flying the hairline in from the origin.
            isHidden = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override var wantsUpdateLayer: Bool { true }

        override func updateLayer() {
            guard let layer = layer else { return }
            withDrawingAppearance {
                layer.backgroundColor = NSColor.separatorColor.cgColor
            }
        }
    }

    /// What the layout pass decided for a single tab.
    ///
    /// The decoration is driven from these values rather than by reading the buttons back, because a
    /// button's `frame` and `alphaValue` are mid-flight while an animation runs — sampling them would
    /// strand the glass and separators at whatever positions happened to be current.
    struct TabLayoutInfo {
        var frame: NSRect
        var isCollapsed: Bool
        var zPosition: CGFloat

        /// The tab this describes, used to key its decoration.
        ///
        /// Decoration has to be keyed by *identity*, never by position. Keyed by position, closing a
        /// tab in the middle hands every decoration view to its right-hand neighbour, so the glass
        /// animates one slot to the *right* while the buttons animate one slot to the *left* and the
        /// two cross — with the lit pill teleporting a whole tab backwards on the first frame. AppKit
        /// keys the same way, off the tab bar item: `_tabBarViewItemsToTabButtons` and
        /// `_tabBarViewItemsToTabSeparators` are both `NSMapTable`s, and `-_layOutButtonsAnimated:`
        /// looks a button and its separator up under one key so the pair can never separate.
        weak var button: TabButton?
    }

    /// Owns and positions the per-tab Liquid-Glass backgrounds and the inter-tab separators that
    /// stand in for per-button bezel drawing when a ``TabBar/Style`` opts into
    /// ``TabBar/Style/controlDecoration``.
    ///
    /// Decoration views sit just behind their own tab button, so overlapping stacked tabs read correctly.
    final class SystemTabDecorator {
        private unowned let container: NSView

        /// Decoration keyed by the tab that owns it — see ``TabBar/TabLayoutInfo/button``.
        private var tabGlasses: [ObjectIdentifier: TabGlassView] = [:]
        private var separators: [ObjectIdentifier: TabSeparatorView] = [:]

        init(container: NSView) {
            self.container = container
        }

        /// Removes every decoration view from the container. Call when switching away from a
        /// decorating style.
        func remove() {
            tabGlasses.values.forEach { $0.removeFromSuperview() }
            tabGlasses.removeAll()
            separators.values.forEach { $0.removeFromSuperview() }
            separators.removeAll()
        }

        /// Repositions and reconfigures all decoration to match the layout the control just computed.
        ///
        /// Decoration is moved with the same ``TabBar/setFrame(_:of:animated:)`` the tab buttons
        /// use, so the two travel in lockstep instead of one snapping ahead of the other.
        func update(
            layouts: [TabLayoutInfo],
            selectedIndex: Int?,
            hoveredIndex: Int?,
            decoration: TabBar.ControlDecoration,
            animated: Bool
        ) {
            updateTabGlasses(layouts: layouts, selectedIndex: selectedIndex, hoveredIndex: hoveredIndex, decoration: decoration, animated: animated)
            updateSeparators(layouts: layouts, selectedIndex: selectedIndex, hoveredIndex: hoveredIndex, decoration: decoration, animated: animated)
        }

        // MARK: - Per-tab glass

        private func updateTabGlasses(
            layouts: [TabLayoutInfo],
            selectedIndex: Int?,
            hoveredIndex: Int?,
            decoration: TabBar.ControlDecoration,
            animated: Bool
        ) {
            var liveKeys: Set<ObjectIdentifier> = []

            for (index, info) in layouts.enumerated() {
                guard let button = info.button else { continue }
                let key = ObjectIdentifier(button)
                liveKeys.insert(key)

                let glass: TabGlassView
                if let existing = tabGlasses[key] {
                    glass = existing
                } else {
                    let created = TabGlassView(frame: .zero)
                    container.addSubview(created)
                    tabGlasses[key] = created
                    glass = created
                }

                glass.cornerRadius = decoration.cornerRadius

                let pill = pillFrame(for: info.frame, insets: decoration.selectionInsets)
                glass.apply(
                    frame: pill,
                    animated: animated && !glass.isHidden,
                    growingFrom: index >= layouts.count - 1 ? .trailingEdge : .midpoint
                )

                // Keep each tab's glass immediately behind its own button. When tabs stack they
                // overlap, so a single shared depth would let a lower tab's title draw over a higher
                // tab's glass.
                glass.layer?.zPosition = info.zPosition - 0.5

                let state: TabGlassView.TabState
                if index == selectedIndex {
                    state = .selected
                } else if decoration.highlightsHover && index == hoveredIndex {
                    state = .hovered
                } else {
                    state = .normal
                }
                glass.configure(state: state)

                // A tab that has collapsed into a pile carries no glass.
                if info.isCollapsed || pill.width <= 0.0 {
                    glass.isHidden = true
                }
            }

            for (key, glass) in tabGlasses where !liveKeys.contains(key) {
                glass.removeFromSuperview()
                tabGlasses.removeValue(forKey: key)
            }
        }

        // MARK: - Separators

        private func updateSeparators(
            layouts: [TabLayoutInfo],
            selectedIndex: Int?,
            hoveredIndex: Int?,
            decoration: TabBar.ControlDecoration,
            animated: Bool
        ) {
            guard decoration.drawsSeparators, layouts.count > 1 else {
                separators.values.forEach { $0.isHidden = true }
                return
            }

            var liveKeys: Set<ObjectIdentifier> = []

            // One separator per tab, owned by that tab and sitting at its trailing edge — the shape
            // AppKit uses (`_tabBarViewItemsToTabSeparators`, positioned by
            // -[NSTabBar _separatorFrameForButtonFrame:]). The trailing-most one is always hidden,
            // which leaves the same count on screen as a separator-between-tabs model would, while
            // keeping every separator tied to a tab that can be removed from the middle.
            for (index, leading) in layouts.enumerated() {
                guard let button = leading.button else { continue }
                let key = ObjectIdentifier(button)
                liveKeys.insert(key)

                let separator: TabSeparatorView
                if let existing = separators[key] {
                    separator = existing
                } else {
                    let created = TabSeparatorView(frame: .zero)
                    container.addSubview(created)
                    separators[key] = created
                    separator = created
                }

                // A separator is hidden when it borders the selected or the hovered tab (matching
                // -[NSTabBar _updateSeparatorVisibility]). It also drops out once the tabs start
                // piling up: a collapsed neighbour, or two tabs overlapping, leaves no gap for a
                // hairline to sit in.
                let isHidden: Bool
                if let trailing = layouts[safe: index + 1] {
                    isHidden =
                        selectedIndex == index || selectedIndex == index + 1 ||
                        hoveredIndex == index || hoveredIndex == index + 1 ||
                        leading.isCollapsed || trailing.isCollapsed ||
                        leading.frame.maxX > trailing.frame.minX
                } else {
                    isHidden = true
                }

                let separatorFrame = NSRect(
                    x: leading.frame.maxX - 0.5,
                    y: leading.frame.minY + decoration.separatorVerticalInset,
                    width: 1.0,
                    height: max(0.0, leading.frame.height - 2.0 * decoration.separatorVerticalInset)
                )
                // Moved before the visibility change, and only animated from a position it was
                // actually seen at: a separator revealed for the first time would otherwise fly in
                // from the origin.
                TabBar.setFrame(separatorFrame, of: separator, animated: animated && !separator.isHidden)
                separator.isHidden = isHidden
            }

            for (key, separator) in separators where !liveKeys.contains(key) {
                separator.removeFromSuperview()
                separators.removeValue(forKey: key)
            }
        }

        // MARK: - Helpers

        private func pillFrame(for buttonFrame: NSRect, insets: NSEdgeInsets) -> NSRect {
            NSRect(
                x: buttonFrame.minX + insets.left,
                y: buttonFrame.minY + insets.top,
                width: max(0.0, buttonFrame.width - insets.left - insets.right),
                height: max(0.0, buttonFrame.height - insets.top - insets.bottom)
            )
        }
    }
}

#endif
