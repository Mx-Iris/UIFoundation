//
//  TabsControl.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabsControl && os(macOS)

import AppKit

/// `TabsControl` is the main class of the component, and is designed to suffice for implementing tabs in your app.
/// The only necessary thing for it to work is an implementation of its `dataSource`.
open class TabsControl: NSControl, NSTextDelegate {
    private var delegateInterceptor = TabsControlDelegateInterceptor()

    private lazy var scrollView = TabsScrollView(frame: bounds)
    private lazy var tabsView = NSView(frame: scrollView.bounds)

    private var editingTab: (title: String, button: TabButton)?

    private lazy var tabsControlCell = TabsControlCell(textCell: "")

    /// The Liquid-Glass decoration manager, created only while the current ``style`` opts into
    /// ``TabsControl/Style/controlDecoration`` (e.g. ``TabsControl/SystemStyle``).
    private var decorator: SystemTabDecorator?

    /// The capsule-shaped Liquid-Glass bar background, created only while the current ``style``
    /// requests it via ``TabsControl/ControlDecoration/showsBarTrack``.
    private var barTrackView: SystemBarTrackView?

    /// The index of the tab currently under the mouse, used to drive the hover pill and to hide
    /// separators adjacent to the hovered tab.
    private var hoveredButtonIndex: Int?

    /// The stacked-layout geometry for the current scroll offset, or `nil` while the tabs still fit
    /// and are laid out evenly. Recomputed on every layout pass, so it always matches what is on screen.
    private var stackingGeometry: StackingGeometry?

    /// Whether the tabs are currently stacked into piles rather than evenly divided.
    public var isStacking: Bool { stackingGeometry != nil }

    /// Guards against re-entrancy: laying out resizes the document view, which can feed back through
    /// the clip view's bounds-changed notification.
    private var isLayingOutTabButtons = false

    /// Set when a layout is requested while one is already running, so the request is honoured by
    /// another pass rather than dropped.
    private var needsAnotherLayoutPass = false

    /// Set while the user is closing tabs by clicking, which pins the layout to the geometry the
    /// last full pass computed.
    ///
    /// AppKit calls this `_isInteractivelyClosingTabs` and honours it in
    /// `-[NSTabBar _reallyUpdateButtonsAndLayOutAnimated:isSelectingButton:]` by skipping
    /// `-_recalculateLayout` outright — the buttons are still laid out, just against the cached
    /// width and tab count. The survivors therefore keep their size and simply shift into the slot
    /// the closed tab left, which parks the next tab's close button under a stationary pointer and
    /// lets several tabs be closed in a row without moving the mouse. The bar only divides itself
    /// afresh once the pointer leaves.
    private var isInteractivelyClosingTabs = false

    /// The evenly divided tab width the last unpinned layout produced, reused while a close is pinned.
    private var heldButtonWidth: CGFloat?

    /// Set while a compound change is being applied, so the layout passes it triggers collapse into
    /// one.
    ///
    /// AppKit coalesces the same way: every relayout goes through a single `CATransaction` commit
    /// handler (`-[NSTabBar _scheduleButtonLayOutAnimated:]` guarded by `_didScheduleAnimatedLayout`),
    /// so a close and the selection change it causes produce one pass rather than two that fight
    /// over the same buttons.
    private var isCoalescingLayout = false
    private var needsCoalescedLayout = false
    private var coalescedLayoutIsAnimated = false

    /// The bar-level tracking area. Individual tabs report their own hover; this one exists to notice
    /// the pointer leaving the control as a whole, which is when a pinned close is allowed to settle.
    private var barTrackingArea: NSTrackingArea?

    /// The layout produced by the most recent pass, reused when only the hover state changes.
    private var lastTabLayouts: [TabLayoutInfo] = []

    // MARK: - Data Source & Delegate

    /// The data source of the tabs control, providing all the necessary information for the class to build the tabs.
    @IBOutlet open weak var dataSource: DataSource?

    /// The delegate of the tabs control, providing additional possibilities for customization and precise behavior.
    @IBOutlet open weak var delegate: Delegate? {
        get { delegateInterceptor.receiver as? Delegate }
        set { delegateInterceptor.receiver = newValue as? NSObject }
    }

    // MARK: - Styling

    open var style: Style = DefaultStyle() {
        didSet {
            tabsControlCell.style = style
            tabButtons.forEach { $0.style = self.style }
            configureDecorator()
            updateTabs()
        }
    }

    /// Creates or tears down the ``decorator`` and the bar track to match whether the current
    /// ``style`` opts into control-level Liquid-Glass decoration.
    private func configureDecorator() {
        guard let decoration = style.controlDecoration else {
            decorator?.remove()
            decorator = nil
            barTrackView?.removeFromSuperview()
            barTrackView = nil
            return
        }

        if decorator == nil {
            decorator = SystemTabDecorator(container: tabsView)
        }

        if decoration.showsBarTrack {
            if barTrackView == nil {
                let track = SystemBarTrackView(frame: bounds)
                track.autoresizingMask = [.width, .height]
                addSubview(track, positioned: .below, relativeTo: scrollView)
                barTrackView = track
            }
        } else {
            barTrackView?.removeFromSuperview()
            barTrackView = nil
        }
    }

    // MARK: - Initializers & Setup

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    private func setup() {
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        cell = tabsControlCell
        configureSubviews()
    }

    private func configureSubviews() {
        scrollView.drawsBackground = false
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.usesPredominantAxisScrolling = true
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.verticalScrollElasticity = .none
        scrollView.autoresizingMask = [.width, .height]
        scrollView.translatesAutoresizingMaskIntoConstraints = true

        tabsView.autoresizingMask = [.width, .height]
        scrollView.documentView = tabsView

        addSubview(scrollView)

        startObservingScrollView()
    }

    deinit {
        self.stopObservingScrollView()
    }

    // MARK: - Public Overrides

    open override func menu(for event: NSEvent) -> NSMenu? {
        return nil
    }

    // MARK: - Data Source

    /// Reloads all tabs of the tabs control. Used when the `dataSource` has changed for instance.
    open func reloadTabs() {
        reloadTabs(animated: false)
    }

    /// Reloads all tabs, optionally animating the change.
    ///
    /// When animated, existing tabs slide to their new slots and freshly inserted tabs fade in — a
    /// newly created button has no previous frame to travel from, so animating its frame would make
    /// it fly in from the origin.
    open func reloadTabs(animated: Bool) {
        guard let dataSource = dataSource else { return }

        let oldItemsCount = self.tabButtons.count
        let newItemsCount = dataSource.tabsControlNumberOfTabs(self)

        if newItemsCount < oldItemsCount {
            self.tabButtons.filter { $0.index >= newItemsCount }.forEach { $0.removeFromSuperview() }
        }

        let tabButtons = self.tabButtons
        var insertedButtons: [TabButton] = []
        for i in 0 ..< newItemsCount {
            let item = dataSource.tabsControl(self, itemAtIndex: i)

            var button: TabButton
            if i >= oldItemsCount {
                button = TabButton(
                    index: i,
                    item: item,
                    target: self,
                    action: #selector(TabsControl.selectTab(_:)),
                    style: style
                )
                button.isNewlyInserted = true
                insertedButtons.append(button)

                button.wantsLayer = true
                button.state = .off
                tabsView.addSubview(button)
            } else {
                button = tabButtons[i]
            }

            button.index = i
            button.item = item
            button.tabsControl = self

            button.editable = delegate?.tabsControl?(self, canEditTitleOfItem: item) == true
            button.buttonPosition = TabPosition.fromIndex(i, totalCount: newItemsCount)
            button.style = style

            button.title = dataSource.tabsControl(self, titleForItem: item)
            button.icon = dataSource.tabsControl?(self, iconForItem: item)
            button.menu = dataSource.tabsControl?(self, menuForItem: item)
            if let canClose = delegate?.tabsControl?(self, canCloseItem: item), canClose {
                button.closeIcon = dataSource.tabsControl?(self, closeIconForItem: item)
                button.closePosition = dataSource.tabsControl?(self, closePositionForItem: item)
                button.closeTarget = self
                button.closeAction = #selector(TabsControl.closeTab(_:))
            } else {
                button.closeIcon = nil
                button.closePosition = nil
                button.closeTarget = nil
                button.closeAction = nil
            }
            button.alternativeTitleIcon = dataSource.tabsControl?(self, titleAlternativeIconForItem: item)
        }

        layoutTabButtons(nil, animated: animated)
        insertedButtons.forEach { $0.isNewlyInserted = false }
        invalidateRestorableState()
    }

    /// Places a tab button at `frame`.
    ///
    /// A freshly inserted tab is opened *out of nothing* — zero width at its leading edge, springing
    /// out to full size while its neighbours make room — rather than faded in on top of the layout.
    /// That is what the system does: a new window tab grows from a sliver to full width with no
    /// opacity change at all.
    private func place(_ button: TabButton, at frame: NSRect, animated: Bool) {
        guard animated, !button.isHidden else {
            Self.setFrame(frame, of: button, animated: false)
            return
        }

        if button.isNewlyInserted {
            let closed = NSRect(x: frame.minX, y: frame.minY, width: 0.0, height: frame.height)
            Self.setFrame(closed, of: button, animated: false)
        }
        Self.setFrame(frame, of: button, animated: true)
    }

    // MARK: - Frame Animation

    /// The spring the system window-tab bar moves tabs with.
    ///
    /// Taken from AppKit 26.5's `tabBarAnimation()`, which builds a `CASpringAnimation` with exactly
    /// these constants and pins its duration to `settlingDuration` (0.5 s on macOS 26.5). AppKit
    /// registers it through `setAnimations:` for `bounds`, `frameOrigin`, `position` and `constant`
    /// on every tab button, separator, border and glass view it owns.
    ///
    /// The damping ratio is `600 / (2 * sqrt(400 * 1))` == 15 — heavily overdamped, so the motion
    /// leaves briskly, never overshoots, and settles on a long soft tail. That tail is what makes the
    /// system bar feel unhurried; a fixed short duration with an ease curve reads as noticeably snappier.
    private enum LayoutSpring {
        static let mass: CGFloat = 1.0
        static let stiffness: CGFloat = 400.0
        static let damping: CGFloat = 600.0
    }

    /// The duration of the `NSAnimationContext` AppKit wraps a tab-bar relayout in
    /// (`-[NSTabBar _beginAnimationGrouping]`), which pairs it with a **linear** curve.
    ///
    /// It is not the duration tabs move over — the spring above owns that. It gates whether anything
    /// animates at all and supplies the timing for the properties no spring is registered for, which
    /// for this control means the insertion and removal fades.
    static let layoutAnimationDuration: TimeInterval = 0.15

    /// Builds the system's tab-movement spring for one layer property.
    private static func makeLayoutSpring(keyPath: String, from originValue: Any) -> CASpringAnimation {
        let animation = CASpringAnimation(keyPath: keyPath)
        animation.mass = LayoutSpring.mass
        animation.stiffness = LayoutSpring.stiffness
        animation.damping = LayoutSpring.damping
        animation.fromValue = originValue
        // Read only after the constants are in place — `settlingDuration` is derived from them.
        animation.duration = animation.settlingDuration
        return animation
    }

    /// Moves `view` to `newFrame`, animating the motion when asked.
    ///
    /// The frame is always published with implicit animation switched **off**, and the motion is then
    /// added as an explicit layer animation. AppKit's own machinery is unusable here: a control whose
    /// cell overrides `draw(withFrame:in:)` — which every ``TabButton`` does — silently *drops* frame
    /// changes made inside an animation context, whether through `animator()` or through an enclosing
    /// group with `allowsImplicitAnimation`. No animation is installed and the model value never
    /// changes, so the button simply never moves and is left stranded behind its own decoration.
    /// Everything the control positions goes through here, so buttons and decoration travel together.
    static func setFrame(_ newFrame: NSRect, of view: NSView, animated: Bool) {
        guard view.frame != newFrame else { return }

        // Re-target from where the view currently *appears* to be, so a layout pass that interrupts
        // an in-flight animation carries on smoothly instead of snapping back to the model value.
        let layer = view.layer
        let originPosition = layer.map { $0.presentation()?.position ?? $0.position }
        let originBounds = layer.map { $0.presentation()?.bounds ?? $0.bounds }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.0
            context.allowsImplicitAnimation = false
            view.frame = newFrame
        }

        guard animated, let layer, let originPosition, let originBounds else { return }

        layer.add(makeLayoutSpring(keyPath: "position", from: NSValue(point: originPosition)), forKey: "position")
        layer.add(makeLayoutSpring(keyPath: "bounds", from: NSValue(rect: originBounds)), forKey: "bounds")
    }

    // MARK: - Layout

    private func updateTabs(animated: Bool = false) {
        layoutTabButtons(nil, animated: animated)
        invalidateRestorableState()
    }

    /// Runs `body` with layout requests collected rather than performed, then performs at most one.
    private func coalescingLayout(_ body: () -> Void) {
        guard !isCoalescingLayout else {
            body()
            return
        }

        isCoalescingLayout = true
        needsCoalescedLayout = false
        coalescedLayoutIsAnimated = false
        body()
        isCoalescingLayout = false

        guard needsCoalescedLayout else { return }
        layoutTabButtons(nil, animated: coalescedLayoutIsAnimated)
    }

    private func layoutTabButtons(_ buttons: [TabButton]?, animated: Bool) {
        // An explicit button order belongs to the reorder drag, which never runs inside a coalesced
        // change; only whole-control layouts are collected.
        if isCoalescingLayout, buttons == nil {
            needsCoalescedLayout = true
            coalescedLayoutIsAnimated = coalescedLayoutIsAnimated || animated
            return
        }

        guard !isLayingOutTabButtons else {
            // The scroll offset moved underneath the pass that is already running. Dropping the
            // request would strand the buttons at positions computed for an offset that no longer
            // exists, while their visibility is judged against the new one — which is exactly how a
            // blank stretch opens up at the head of a stacked bar.
            needsAnotherLayoutPass = true
            return
        }
        isLayingOutTabButtons = true
        defer {
            isLayingOutTabButtons = false
            // The tabs have just moved under a pointer that did not, so hover has to be re-decided
            // from where the pointer actually is.
            updateHoverForCurrentMouseLocation()
        }

        // Laying out resizes the document view, which can make the clip view re-constrain its bounds
        // and feed straight back in here. Re-run instead of dropping; it converges as soon as the
        // offset stops moving, and the bound keeps a pathological case from spinning.
        var remainingPasses = 4
        repeat {
            needsAnotherLayoutPass = false
            layoutTabButtonsOnce(buttons, animated: animated)
            remainingPasses -= 1
        } while needsAnotherLayoutPass && remainingPasses > 0
    }

    private func layoutTabButtonsOnce(_ buttons: [TabButton]?, animated: Bool) {
        let tabButtons = buttons ?? tabButtons

        // While a close is pinned the geometry is reused rather than recomputed, which is how the
        // survivors keep their width — see ``isInteractivelyClosingTabs``. Reusing a `nil` geometry
        // keeps an unstacked bar unstacked, where ``heldButtonWidth`` pins the width instead. The
        // anchor is re-read either way: closing a tab before the selected one renumbers it, and a
        // geometry still folded against its old index would bury it in the pile.
        let geometry = isInteractivelyClosingTabs
            ? stackingGeometry?.anchored(onFrontmostIndex: selectedButtonIndex)
            : makeStackingGeometry(for: tabButtons)

        if let geometry {
            stackingGeometry = geometry
            layoutStackedTabButtons(tabButtons, geometry: geometry, animated: animated)
        } else {
            stackingGeometry = nil
            layoutUnstackedTabButtons(tabButtons, animated: animated)
        }
    }

    /// Builds the stacking geometry when the current style allows stacking and the tabs no longer fit
    /// at their minimum width. Returns `nil` while the tabs still fit, in which case the classic
    /// evenly-divided layout is used.
    private func makeStackingGeometry(for tabButtons: [TabButton]) -> StackingGeometry? {
        guard let decoration = style.controlDecoration, decoration.allowsStacking else { return nil }
        guard tabButtons.count > 1 else { return nil }

        let minimumWidth = decoration.minimumTabWidth
        let visibleWidth = max(0.0, scrollView.frame.width - 2.0 * decoration.barContentInset)
        guard visibleWidth > 0.0, visibleWidth < minimumWidth * CGFloat(tabButtons.count) else { return nil }

        // Closing a tab shortens the strip, which can leave the clip view scrolled past the new end.
        // Pull it back before the layout reads it, so the frames and the visibility test are decided
        // by the same offset and the bar cannot end up scrolled into empty space.
        let maximumScrollOffset = max(0.0, minimumWidth * CGFloat(tabButtons.count) - visibleWidth)
        let clipView = scrollView.contentView
        var scrollOffset = clipView.bounds.origin.x
        if scrollOffset < 0.0 || scrollOffset > maximumScrollOffset {
            scrollOffset = min(max(0.0, scrollOffset), maximumScrollOffset)
            clipView.setBoundsOrigin(NSPoint(x: scrollOffset, y: clipView.bounds.origin.y))
            scrollView.reflectScrolledClipView(clipView)
        }

        return StackingGeometry(
            tabCount: tabButtons.count,
            tabWidth: minimumWidth,
            visibleWidth: visibleWidth,
            scrollOffset: scrollOffset,
            barHeight: tabsView.frame.height,
            frontmostIndex: selectedButtonIndex
        )
    }

    /// Places the tabs using the stacked geometry. Offsets from ``StackingGeometry`` are viewport
    /// relative, so the scroll offset is added back to express them in the scrolling document's
    /// coordinate space — the tabs then appear pinned to the viewport as it scrolls.
    private func layoutStackedTabButtons(_ tabButtons: [TabButton], geometry: StackingGeometry, animated: Bool) {
        let contentInset = style.controlDecoration?.barContentInset ?? 0.0
        let documentOrigin = contentInset + geometry.scrollOffset
        var layouts: [TabLayoutInfo] = []
        layouts.reserveCapacity(tabButtons.count)

        for (index, button) in tabButtons.enumerated() {
            let layout = geometry.layout(at: index)
            var buttonFrame = layout.frame
            buttonFrame.origin.x += documentOrigin

            let zPosition = geometry.zPosition(at: index)
            button.layer?.zPosition = zPosition
            layouts.append(TabLayoutInfo(frame: buttonFrame, isCollapsed: layout.isCollapsed, zPosition: zPosition, button: button))

            // Opacity is reserved for tabs that have folded out of sight; everything visible keeps a
            // width, however narrow, exactly as the system does.
            let alpha: CGFloat = layout.isCollapsed ? 0.0 : 1.0
            if animated && !button.isHidden {
                button.animator().alphaValue = alpha
            } else {
                button.alphaValue = alpha
            }

            place(button, at: buttonFrame, animated: animated)

            if let selectable = delegate?.tabsControl?(self, canSelectItem: button.representedObject!) {
                button.isEnabled = selectable
            }
        }

        // The document is always the full un-stacked width so the scroll range stays correct.
        let viewFrame = CGRect(
            x: 0.0,
            y: 0.0,
            width: 2.0 * contentInset + geometry.contentWidth,
            height: geometry.barHeight
        )
        if tabsView.frame != viewFrame {
            tabsView.frame = viewFrame
        }

        applyDecoration(layouts: layouts, animated: animated)
    }

    /// Hands the freshly computed layout to the decoration and remembers it, so a later hover change
    /// can restyle without recomputing (and without sampling mid-animation button state).
    private func applyDecoration(layouts: [TabLayoutInfo], animated: Bool) {
        lastTabLayouts = layouts
        guard let decoration = style.controlDecoration else { return }
        decorator?.update(
            layouts: layouts,
            selectedIndex: selectedButtonIndex,
            hoveredIndex: hoveredButtonIndex,
            decoration: decoration,
            animated: animated
        )
    }

    private func layoutUnstackedTabButtons(_ tabButtons: [TabButton], animated: Bool) {
        var tabsViewWidth = CGFloat(0.0)
        var layouts: [TabLayoutInfo] = []
        layouts.reserveCapacity(tabButtons.count)

        // Decorating styles inset the tabs so their pills clear the rounded ends of the bar track.
        let contentInset = style.controlDecoration?.barContentInset ?? 0.0
        let availableWidth = max(0.0, scrollView.frame.width - 2.0 * contentInset)
        let fullWidth = tabButtons.isEmpty ? 0.0 : availableWidth / CGFloat(tabButtons.count)
        let buttonHeight = tabsView.frame.height

        var buttonWidth = CGFloat(0)
        if isInteractivelyClosingTabs, let heldButtonWidth {
            buttonWidth = heldButtonWidth
        } else {
            switch style.tabButtonWidth {
            case .full:
                buttonWidth = fullWidth
            case let .flexible(minWidth, maxWidth):
                buttonWidth = max(minWidth, min(maxWidth, fullWidth))
            case let .fixed(width):
                buttonWidth = width
            }
            heldButtonWidth = buttonWidth
        }

        var buttonX = contentInset
        for (index, button) in tabButtons.enumerated() {
            let offset = style.tabButtonOffset(position: button.buttonPosition)
            let buttonFrame = CGRect(x: buttonX + offset.x, y: offset.y, width: buttonWidth, height: buttonHeight)
            buttonX += buttonWidth + offset.x

            // A modest finite depth, not `greatestFiniteMagnitude`: decoration sits just behind its
            // button at `zPosition - 0.5`, and at 1e38 that offset is lost to float precision, which
            // would let the glass composite *over* the title and blur it.
            let zPosition: CGFloat = button.state == NSControl.StateValue.on ? 1000.0 : CGFloat(index)
            button.layer?.zPosition = zPosition
            layouts.append(TabLayoutInfo(frame: buttonFrame, isCollapsed: false, zPosition: zPosition, button: button))

            // Tabs may have been faded out by a previous stacked layout.
            button.alphaValue = 1.0

            place(button, at: buttonFrame, animated: animated)

            if let selectable = delegate?.tabsControl?(self, canSelectItem: button.representedObject!) {
                button.isEnabled = selectable
            }

            tabsViewWidth += buttonWidth
        }

        // Left alone while a close is pinned, so the strip keeps the extent it had before the tab
        // went. AppKit skips the same work: `-_recalculateLayoutAndUpdateContainerViewFrames` is one
        // of the things `_isInteractivelyClosingTabs` suppresses. The trailing gap this opens up is
        // the point — it closes when the pointer leaves.
        if !isInteractivelyClosingTabs {
            let contentWidth = contentInset > 0.0 ? (buttonX + contentInset) : tabsViewWidth
            let viewFrame = CGRect(x: 0.0, y: 0.0, width: contentWidth, height: buttonHeight)
            Self.setFrame(viewFrame, of: tabsView, animated: animated)
        }

        applyDecoration(layouts: layouts, animated: animated)
    }

    // MARK: - Mouse Tracking

    open override func updateTrackingAreas() {
        if let barTrackingArea {
            removeTrackingArea(barTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        barTrackingArea = trackingArea

        super.updateTrackingAreas()
    }

    open override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)

        // Only the bar's own area counts. Crossing between two tabs exits a `TabButton`'s area
        // without ever leaving the control, and must not end the run of closes.
        guard event.trackingArea === barTrackingArea else { return }
        releasePinnedCloseLayout()
    }

    /// Lets the tabs divide the bar afresh once the pointer has left, ending the run of closes the
    /// pinned width was protecting. Mirrors `-[NSTabBar mouseExited:]`.
    private func releasePinnedCloseLayout() {
        guard isInteractivelyClosingTabs else { return }
        isInteractivelyClosingTabs = false
        layoutTabButtons(nil, animated: true)
    }

    /// Re-decides which tab the pointer is over, from where the pointer actually is.
    ///
    /// Tabs move under a stationary pointer every time the bar lays out, so hover cannot be left to
    /// enter and exit events alone — the system re-establishes it at the end of every layout pass
    /// (`-[NSTabBar _updateIndexOfTabUnderCurrentMouseLocation:]`). Closing several tabs in a row
    /// depends on it: the tab that slides into the vacated slot has to reveal its own close button
    /// without the mouse having moved.
    private func updateHoverForCurrentMouseLocation() {
        guard let window, NSApp.isActive else { return }

        let localPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
        var hoveredButton: TabButton?
        if bounds.contains(localPoint) {
            // A pointer resting on a pile targets the pile, not whichever tab lies beneath it.
            let isOverPile = stackingGeometry.map { !stackingRegion(at: localPoint, geometry: $0).isEmpty } ?? false
            if !isOverPile {
                // Stacked tabs overlap, so resolve to the visually topmost, as `hitTest(_:)` does.
                let pointInTabs = tabsView.convert(localPoint, from: self)
                let candidates = tabButtons.filter { $0.alphaValue > 0.0 && $0.frame.contains(pointInTabs) }
                hoveredButton = candidates.max(by: { ($0.layer?.zPosition ?? 0.0) < ($1.layer?.zPosition ?? 0.0) })
            }
        }

        for button in tabButtons {
            button.setShowsCloseButton(button === hoveredButton)
        }

        guard hoveredButton?.index != hoveredButtonIndex else { return }
        hoveredButtonIndex = hoveredButton?.index

        // Restyle from the last computed layout rather than re-running one: hover only changes which
        // tab is highlighted, never where anything sits.
        applyDecoration(layouts: lastTabLayouts, animated: false)
    }

    /// Called by a ``TabButton`` when the mouse enters or leaves it, so the decoration can move its
    /// hover pill and refresh separator visibility. No-op unless the current ``style`` decorates.
    func tabButton(_ button: TabButton, didChangeHover isHovered: Bool) {
        // A pointer resting on a pile targets the pile, not whichever tab happens to lie beneath it:
        // no hover highlight and no close button. Matches the system, which clears the hovered index
        // whenever the point falls in a stacking region. A tab collapsed into a pile never hovers.
        var effectiveHover = isHovered
        if isHovered {
            if button.alphaValue <= 0.0 {
                effectiveHover = false
            } else if let geometry = stackingGeometry, let window {
                let localPoint = convert(window.mouseLocationOutsideOfEventStream, from: nil)
                if !stackingRegion(at: localPoint, geometry: geometry).isEmpty {
                    effectiveHover = false
                }
            }
        }

        button.setShowsCloseButton(effectiveHover)

        let newHoveredIndex: Int?
        if effectiveHover {
            newHoveredIndex = button.index
        } else {
            newHoveredIndex = (hoveredButtonIndex == button.index) ? nil : hoveredButtonIndex
        }

        guard newHoveredIndex != hoveredButtonIndex else { return }
        hoveredButtonIndex = newHoveredIndex

        // Restyle from the last computed layout rather than re-running one: hover only changes
        // which tab is highlighted, never where anything sits.
        applyDecoration(layouts: lastTabLayouts, animated: false)
    }

    // MARK: - Stacking Interaction

    /// The pile, if any, that a point in the control's own coordinate space lands on.
    private func stackingRegion(at localPoint: NSPoint, geometry: StackingGeometry) -> StackingRegion {
        let regions = geometry.stackingRegions(selectedIndex: selectedButtonIndex)
        guard !regions.isEmpty else { return [] }

        let contentInset = style.controlDecoration?.barContentInset ?? 0.0
        let viewportX = localPoint.x - contentInset

        var selectedFrame: NSRect?
        if let selected = selectedButtonIndex, selected >= 0, selected < tabButtons.count {
            selectedFrame = geometry.layout(at: selected).frame
        }

        return geometry.region(atViewportX: viewportX, existingRegions: regions, selectedFrame: selectedFrame)
    }

    open override func hitTest(_ point: NSPoint) -> NSView? {
        guard let geometry = stackingGeometry else { return super.hitTest(point) }

        let localPoint = convert(point, from: superview)
        guard bounds.contains(localPoint) else { return super.hitTest(point) }

        // A click on a pile scrolls the bar open instead of selecting whichever tab happens to be
        // under the pointer, matching -[NSTabBar hitTest:].
        if !stackingRegion(at: localPoint, geometry: geometry).isEmpty { return self }

        // Stacked tabs overlap, and NSView hit-tests in subview order rather than by `zPosition`,
        // so the visually topmost tab has to be resolved explicitly.
        let pointInTabs = tabsView.convert(localPoint, from: self)
        let candidates = tabButtons.filter { $0.alphaValue > 0.0 && $0.frame.contains(pointInTabs) }
        if let topmost = candidates.max(by: { ($0.layer?.zPosition ?? 0.0) < ($1.layer?.zPosition ?? 0.0) }) {
            return topmost.hitTest(pointInTabs) ?? topmost
        }

        return super.hitTest(point)
    }

    open override func mouseDown(with event: NSEvent) {
        guard let geometry = stackingGeometry else {
            super.mouseDown(with: event)
            return
        }

        let localPoint = convert(event.locationInWindow, from: nil)
        let region = stackingRegion(at: localPoint, geometry: geometry)
        guard !region.isEmpty else {
            super.mouseDown(with: event)
            return
        }

        scrollStack(to: geometry.scrollTarget(for: region))
    }

    /// Animates the bar to a new scroll offset, expanding the pile that was clicked.
    private func scrollStack(to offset: CGFloat) {
        let clipView = scrollView.contentView
        let target = NSPoint(x: offset, y: clipView.bounds.origin.y)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.allowsImplicitAnimation = true
            clipView.animator().setBoundsOrigin(target)
        }
        scrollView.reflectScrolledClipView(clipView)
    }

    // MARK: - ScrollView Observation

    private func startObservingScrollView() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TabsControl.scrollViewDidScroll(_:)),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        // Stacked layout is a function of the scroll offset, so every scroll has to re-run it.
        // This mirrors -[NSTabBar _clipViewBoundsChanged:].
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(TabsControl.clipViewBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    private func stopObservingScrollView() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
    }

    @objc private func scrollViewDidScroll(_ notification: Notification) {
        layoutTabButtons(nil, animated: false)
        invalidateRestorableState()
    }

    @objc private func clipViewBoundsDidChange(_ notification: Notification) {
        // Scrolling ends a run of closes. The tabs have moved out from under the pointer anyway, so
        // the pinned width is protecting nothing — and leaving it pinned would freeze the stacked
        // geometry against a scroll offset that has since moved, making the bar stop responding.
        // `-[NSTabBar _clipViewBoundsChanged:]` clears the same flag and lays out unanimated. A
        // window resize arrives here too, by way of the clip view re-bounding.
        let wasPinned = isInteractivelyClosingTabs
        isInteractivelyClosingTabs = false

        guard isStacking || wasPinned else { return }
        layoutTabButtons(nil, animated: false)
    }

    // MARK: - Reordering

    private func reorderTab(_ tab: TabButton, withEvent event: NSEvent) {
        var orderedTabs = tabButtons
        let tabX = tab.frame.minX
        let dragPoint = tabsView.convert(event.locationInWindow, from: nil)

        var prevPoint = dragPoint
        var reordered = false

        let draggingTab = tab.copy() as! TabButton
        addSubview(draggingTab)
        tab.isHidden = true

        var temporarySelectedButtonIndex = selectedButtonIndex!
        while true {
            guard let event = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) else { break }

            if event.type == .leftMouseUp {
                NSAnimationContext.current.completionHandler = { [self] in
                    draggingTab.removeFromSuperview()
                    tab.isHidden = false

                    if reordered == true {
                        let items = orderedTabs.compactMap { $0.representedObject }
                        delegate?.tabsControl?(self, didReorderItems: items)
                    }

                    reloadTabs()
                    invalidateRestorableState()
                    selectedButtonIndex = temporarySelectedButtonIndex
                }
                draggingTab.animator().frame = tab.frame
                break
            }

            let nextPoint = tabsView.convert(event.locationInWindow, from: nil)
            let nextX = tabX + (nextPoint.x - dragPoint.x)

            var r = draggingTab.frame
            r.origin.x = nextX
            draggingTab.frame = r

            let movingLeft = (nextPoint.x < prevPoint.x)
            prevPoint = nextPoint

            let primaryIndex = orderedTabs.firstIndex(of: tab)!
            var secondaryIndex: Int?

            if movingLeft == true && draggingTab.frame.midX < tab.frame.minX && tab !== orderedTabs.first! {
                // shift left
                secondaryIndex = primaryIndex - 1
            } else if movingLeft == false && draggingTab.frame.midX > tab.frame.maxX && tab != orderedTabs.last! {
                secondaryIndex = primaryIndex + 1
            }

            if let secondIndex = secondaryIndex {
                orderedTabs.swapAt(primaryIndex, secondIndex)

                // Shouldn't indexes be swapped too? But if we do so, it doesn't work!
                orderedTabs[primaryIndex].buttonPosition = TabPosition.fromIndex(primaryIndex, totalCount: orderedTabs.count)
                orderedTabs[secondIndex].buttonPosition = TabPosition.fromIndex(secondIndex, totalCount: orderedTabs.count)

                temporarySelectedButtonIndex += secondIndex - primaryIndex
                layoutTabButtons(orderedTabs, animated: true)
                invalidateRestorableState()
                reordered = true
            }
        }
    }

    // MARK: - Close

    @objc private func closeTab(_ sender: Any?) {
        guard let button = sender as? TabButton,
              let item = button.representedObject,
              delegate?.tabsControl?(self, canCloseItem: item) == true else
        { return }
        let buttonIndex = button.index
        let closedTheTrailingTab = button === tabButtons.last

        // Pin the tab width, so the tab to the right slides into this slot at the size it already
        // has and its close button lands under the pointer — that is what lets a run of tabs be
        // closed without moving the mouse. `-[NSTabBar closeTabButton:]` arms this only for a real
        // click, which it detects as `window.currentEvent != nil`, and never for the trailing tab,
        // where nothing would slide under the pointer to be clicked next.
        isInteractivelyClosingTabs = !closedTheTrailingTab && window?.currentEvent != nil

        coalescingLayout {
            // Gone at once, the way the system closes a window tab: the animation people read as "the
            // tab closed" is the survivors reflowing into the space, not the tab itself leaving. Fading
            // it out where it stands leaves a motionless ghost for its neighbours to slide through.
            button.removeFromSuperview()

            // Renumber the survivors *before* laying out: the decoration maps a tab to its position in
            // this array, so stale indices would light up the wrong tab — permanently, when closing a
            // tab after the selected one leaves `selectedButtonIndex` untouched.
            let tabButtons = tabButtons
            for (index, tabButton) in tabButtons.enumerated() {
                tabButton.index = index
            }

            // A lone survivor has nothing left to slide under the pointer, so there is nothing to
            // protect: divide the bar straight away. AppKit clears the same flag on the same test.
            if tabButtons.count < 2 {
                isInteractivelyClosingTabs = false
            }

            delegate?.tabsControl?(self, didCloseItem: item)

            guard let currentSelectedButtonIndex = selectedButtonIndex else {
                layoutTabButtons(nil, animated: true)
                return
            }

            if buttonIndex == currentSelectedButtonIndex {
                // The selected tab itself was closed: select an adjacent enabled tab.
                var nextButtonIndex: Int?
                if tabButtons.isEmpty {
                    nextButtonIndex = nil
                } else if buttonIndex == 0 {
                    nextButtonIndex = 0
                } else {
                    nextButtonIndex = buttonIndex - 1
                }
                if let nextButtonIndex, let nextButton = tabButtons[safe: nextButtonIndex], nextButton.isEnabled {
                    selectedButtonIndex = nextButtonIndex
                } else {
                    selectedButtonIndex = nil
                }
                if let action, let target {
                    NSApp.sendAction(action, to: target, from: self)
                }
                delegate?.tabsControlDidChangeSelection?(self, item: selectedButton?.representedObject)
            } else if buttonIndex < currentSelectedButtonIndex {
                // A tab before the selection was closed: shift the selection so the same tab stays
                // selected. Assigning requests a layout through `didSet`.
                selectedButtonIndex = currentSelectedButtonIndex - 1
            } else {
                // A tab *after* the selection was closed, so the selection is untouched and nothing
                // else will lay out — the survivors would keep the gap open forever.
                layoutTabButtons(nil, animated: true)
            }
        }
    }

    // MARK: - Selection

    /// The tab button cell's action — a genuine click on a tab.
    @objc private func selectTab(_ sender: Any?) {
        guard let button = sender as? TabButton,
              button.isEnabled
        else { return }

        selectButton(button)

        // Everything below belongs to the click. `TabButtonCell` sends its action on mouse-down, so a
        // real tab click always presents one; any other caller must be kept out of the drag-tracking
        // wait, which parks the main thread in `.eventTracking` until the user next presses the mouse.
        // Reaching it from a programmatic selection froze the whole app — tab hover included — until
        // the next click somewhere else released it.
        guard let currentEvent = NSApp.currentEvent, currentEvent.type == .leftMouseDown else { return }

        if currentEvent.clickCount > 1 {
            editTabButton(button)
        } else if let item = button.representedObject,
            delegate?.tabsControl?(self, canReorderItem: item) == true {

            guard let event = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged], until: Date.distantFuture, inMode: .eventTracking, dequeue: false),
                  event.type == NSEvent.EventType.leftMouseDragged
            else { return }

            reorderTab(button, withEvent: currentEvent)
        }
    }

    /// Moves the selection to `button`, without any of the click-driven follow-up.
    private func selectButton(_ button: TabButton) {
        guard button.isEnabled else { return }

        selectedButtonIndex = button.index
        invalidateRestorableState()

        if let action, let target {
            NSApp.sendAction(action, to: target, from: self)
        }

        // `selectedButtonIndex`'s `didSet` already posts `selectionDidChangeNotification`.
        delegate?.tabsControlDidChangeSelection?(self, item: button.representedObject)
    }

    private func scrollToSelectedButton() {
        guard let selectedButton = selectedButton else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.allowsImplicitAnimation = true
            selectedButton.scrollToVisible(selectedButton.bounds)
        }, completionHandler: nil)
    }

    private var selectedButton: TabButton? {
        guard let index = selectedButtonIndex else { return nil }
        return tabButtons.first(where: { $0.index == index })
    }

    public private(set) var selectedButtonIndex: Int? {
        didSet {
            // Not while a close is being folded into a single pass. The system only ever scrolls the
            // bar to reveal a freshly *inserted* tab (`_firstInsertedTabButtonIndex`); scrolling
            // because a close moved the selection would drag the whole strip out from under the
            // pointer just as the user lines up the next close.
            if !isCoalescingLayout {
                scrollToSelectedButton()
            }

            updateButtonStatesForSelection()
            // Animated: selecting is usually the tail of a user-facing change (insert, close), and a
            // non-animated pass here would cancel the animation that change just started. When tabs
            // are stacked the selection also re-anchors the fold, which the system animates too.
            layoutTabButtons(nil, animated: true)
            invalidateRestorableState()

            NotificationCenter.default.post(name: TabsControl.selectionDidChangeNotification, object: self)
        }
    }

    /// Selects an item at a given index. Selecting an invalid index unselects all tabs.
    ///
    /// - parameter index: An integer indicating the index of the item to be selected.
    open func selectItemAtIndex(_ index: Int) {
        guard let button = tabButtons[safe: index] else { return }
        selectButton(button)
    }

    private func updateButtonStatesForSelection() {
        for button in tabButtons {
            guard let selectedIndex = selectedButtonIndex else {
                button.state = NSControl.StateValue.off
                continue
            }

            button.state = button.index == selectedIndex ? NSControl.StateValue.on : NSControl.StateValue.off
        }
    }

    // MARK: - Editing

    /// Starts editing the tab as if the user double-clicked on it. If `index` is out of bounds, it does nothing.
    open func editTabAtIndex(_ index: Int) {
        guard let tabButton = tabButtons[safe: index] else { return }

        editTabButton(tabButton)
    }

    func editTabButton(_ tab: TabButton) {
        guard let representedObject = tab.representedObject,
              delegate?.tabsControl?(self, canEditTitleOfItem: representedObject) == true
        else { return }

        guard let fieldEditor = window?.fieldEditor(true, for: tab)
        else { return }

        window?.makeFirstResponder(self)

        editingTab = (tab.title, tab)
        tab.edit(fieldEditor: fieldEditor, delegate: self)
    }

    // MARK: - NSTextDelegate

    open func textDidEndEditing(_ notification: Notification) {
        guard let fieldEditor = notification.object as? NSText else {
            assertionFailure("Expected field editor.")
            return
        }

        let newValue = fieldEditor.string
        editingTab?.button.finishEditing(fieldEditor: fieldEditor, newValue: newValue)
        window?.makeFirstResponder(self)

        defer {
            self.editingTab = nil
        }

        guard let item = editingTab?.button.representedObject,
              newValue != editingTab?.title
        else { return }

        delegate?.tabsControl?(self, setTitle: newValue, forItem: item)
        editingTab?.button.representedObject = dataSource?.tabsControl(self, itemAtIndex: selectedButtonIndex!)
    }

    // MARK: - Drawing

    open override var isOpaque: Bool {
        return false
    }

    open override var isFlipped: Bool {
        return true
    }

    // MARK: - Tab Widths

    open func currentTabWidth() -> CGFloat {
        let tabs = tabButtons
        guard let firstTab = tabs.first else { return 0.0 }
        return firstTab.frame.width
    }

    // MARK: - State Restoration

    private enum RestorationKeys {
        static let scrollXOffset = "scrollOrigin"
        static let selectedButtonIndex = "selectedButtonIndex"
    }

    open override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)

        let scrollXOffset: CGFloat = scrollView.contentView.bounds.origin.x
        let selectedButtonIndex: Int = self.selectedButtonIndex ?? NSNotFound

        coder.encode(Double(scrollXOffset), forKey: RestorationKeys.scrollXOffset)
        coder.encode(selectedButtonIndex, forKey: RestorationKeys.selectedButtonIndex)
    }

    open override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)

        let scrollXOffset = coder.decodeDouble(forKey: RestorationKeys.scrollXOffset)
        let selectedButtonIndex = coder.decodeInteger(forKey: RestorationKeys.selectedButtonIndex)

        var bounds = scrollView.contentView.bounds
        bounds.origin.x = CGFloat(scrollXOffset)
        scrollView.contentView.bounds = bounds

        guard selectedButtonIndex != NSNotFound,
              let selectedButton = tabButtons.first(where: { $0.index == selectedButtonIndex })
        else { return }

        selectButton(selectedButton)
    }

    // MARK: - Helpers

    private var tabButtons: [TabButton] {
        return tabsView.subviews
            .compactMap { $0 as? TabButton }
            .sorted(by: { $0.index < $1.index })
    }
}

#endif
