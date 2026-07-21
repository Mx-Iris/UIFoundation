//
//  TabsControl+SystemDecoration.swift
//  UIFoundation
//
//  Control-level Liquid-Glass decoration for ``TabsControl/SystemStyle`` (macOS 26 look).
//  These views are floated *behind* the tab buttons by ``TabsControl`` so real glass can sit under
//  the cell-drawn titles without covering them.
//
//  To match the system window-tab bar exactly, this reproduces AppKit's own per-tab glass config
//  (-[NSTabBarViewButton _makeTabButtonGlassView] / -[NSTabButton setActive:]): every tab gets its
//  own NSGlassEffectView — a frosted `_variant == 13` for non-selected tabs and a lit
//  `_variant == 1` + `_subvariant == "tab"` for the selected tab, with content lensing on and an
//  `_interactionState == 2` hover highlight. Those knobs are private, so they are set through
//  guarded, `responds(to:)`-checked selector calls; anything unavailable degrades gracefully.
//

#if TabsControl && os(macOS)

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

extension TabsControl {
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
                glass.autoresizingMask = [.width, .height]
                glass.cornerRadius = cornerRadius
                glass.setPrivateContentLensing(true)
                addSubview(glass)
                glassEffectView = glass
            } else if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
                let effect = NSVisualEffectView()
                effect.frame = bounds
                effect.autoresizingMask = [.width, .height]
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

    /// Owns and positions the per-tab Liquid-Glass backgrounds and the inter-tab separators that
    /// stand in for per-button bezel drawing when a ``TabsControl/Style`` opts into
    /// ``TabsControl/Style/controlDecoration``.
    ///
    /// All decoration views live inside the tabs container at `zPosition == -1`, keeping them behind
    /// every tab button (which draws its title on top).
    final class SystemTabDecorator {
        private unowned let container: NSView

        private var tabGlasses: [TabGlassView] = []
        private var separators: [TabSeparatorView] = []

        init(container: NSView) {
            self.container = container
        }

        /// Removes every decoration view from the container. Call when switching away from a
        /// decorating style.
        func remove() {
            tabGlasses.forEach { $0.removeFromSuperview() }
            tabGlasses.removeAll()
            separators.forEach { $0.removeFromSuperview() }
            separators.removeAll()
        }

        /// Repositions and reconfigures all decoration to match the current buttons, selection and
        /// hover state.
        func update(
            buttons: [TabButton],
            selectedIndex: Int?,
            hoveredIndex: Int?,
            decoration: TabsControl.ControlDecoration
        ) {
            updateTabGlasses(buttons: buttons, selectedIndex: selectedIndex, hoveredIndex: hoveredIndex, decoration: decoration)
            updateSeparators(buttons: buttons, selectedIndex: selectedIndex, hoveredIndex: hoveredIndex, decoration: decoration)
        }

        // MARK: - Per-tab glass

        private func updateTabGlasses(
            buttons: [TabButton],
            selectedIndex: Int?,
            hoveredIndex: Int?,
            decoration: TabsControl.ControlDecoration
        ) {
            while tabGlasses.count < buttons.count {
                let glass = TabGlassView(frame: .zero)
                container.addSubview(glass)
                tabGlasses.append(glass)
            }
            while tabGlasses.count > buttons.count {
                tabGlasses.removeLast().removeFromSuperview()
            }

            for (index, button) in buttons.enumerated() {
                let glass = tabGlasses[index]
                glass.cornerRadius = decoration.cornerRadius
                glass.frame = pillFrame(for: button.frame, insets: decoration.selectionInsets)

                // Keep each tab's glass immediately behind its own button. When tabs stack they
                // overlap, so a single shared depth would let a lower tab's title draw over a higher
                // tab's glass.
                glass.layer?.zPosition = (button.layer?.zPosition ?? 0.0) - 0.5

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
                if button.alphaValue <= 0.0 || glass.frame.width <= 0.0 {
                    glass.isHidden = true
                }
            }
        }

        // MARK: - Separators

        private func updateSeparators(
            buttons: [TabButton],
            selectedIndex: Int?,
            hoveredIndex: Int?,
            decoration: TabsControl.ControlDecoration
        ) {
            guard decoration.drawsSeparators, buttons.count > 1 else {
                separators.forEach { $0.isHidden = true }
                return
            }

            let neededCount = buttons.count - 1
            while separators.count < neededCount {
                let separator = TabSeparatorView(frame: .zero)
                container.addSubview(separator)
                separators.append(separator)
            }
            while separators.count > neededCount {
                separators.removeLast().removeFromSuperview()
            }

            for index in 0 ..< neededCount {
                let separator = separators[index]
                // A separator after tab `index` is hidden when it borders the selected tab or a
                // hovered tab (matching -[NSTabBar _updateSeparatorVisibility]).
                let leadingButton = buttons[index]
                let trailingButton = buttons[index + 1]
                // Also drop the separator once the tabs start piling up: a collapsed neighbour, or
                // two tabs overlapping, leaves no gap for a hairline to sit in.
                let isHidden =
                    selectedIndex == index || selectedIndex == index + 1 ||
                    hoveredIndex == index || hoveredIndex == index + 1 ||
                    leadingButton.alphaValue <= 0.0 || trailingButton.alphaValue <= 0.0 ||
                    leadingButton.frame.maxX > trailingButton.frame.minX
                separator.isHidden = isHidden
                guard !isHidden else { continue }

                let buttonFrame = leadingButton.frame
                separator.frame = NSRect(
                    x: buttonFrame.maxX - 0.5,
                    y: buttonFrame.minY + decoration.separatorVerticalInset,
                    width: 1.0,
                    height: max(0.0, buttonFrame.height - 2.0 * decoration.separatorVerticalInset)
                )
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
