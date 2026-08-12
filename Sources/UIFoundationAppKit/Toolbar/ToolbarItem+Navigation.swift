#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A Safari-style back / forward pair, as a single toolbar item.
    ///
    /// AppKit ships no navigation item of its own, so every app that wants one
    /// assembles a two-segment `NSSegmentedControl` by hand and rediscovers the
    /// same behaviours along the way. This type does the assembly and holds them
    /// in place:
    ///
    /// - A segment menu only becomes a *long-press* menu while the control has a
    ///   non-`nil` action. Attach a menu without one and AppKit pops it on an
    ///   ordinary click, so single-step navigation disappears.
    /// - An empty `NSMenu` still pops, as an empty box. "No history" has to be
    ///   expressed by detaching the menu, never by attaching one with no rows.
    ///
    /// Availability and history are **pulled** from a ``DataSource``, never
    /// pushed: `NSToolbarItem` already validates itself on the toolbar's
    /// validation cycle, so a host that changes its own history has nothing to
    /// remember to call. Clicks arrive through a ``Delegate``.
    ///
    /// ```swift
    /// let navigationItem = NSToolbar.Navigation()
    /// navigationItem.dataSource = self
    /// navigationItem.delegate = self
    /// ```
    ///
    /// A host that only wants the two chevrons implements two methods —
    /// ``DataSource/navigationToolbarItem(_:canNavigateIn:)`` and
    /// ``Delegate/navigationToolbarItem(_:didNavigateIn:)``. Everything else has
    /// a default that means "no history menu".
    ///
    /// The appearance is not a host's to change. The control is not exposed and
    /// nothing forwards to it: a navigation pair has one correct look, and the
    /// knob a host would reach through is the same one that holds the first
    /// behaviour above in place. The only host-facing text is
    /// ``backwardTitle`` / ``forwardTitle``, which exist for localization rather
    /// than for styling.
    open class Navigation: ToolbarItem, NSMenuDelegate {

        // MARK: - Direction

        /// Which half of the control a message is about.
        public enum Direction: Hashable, Sendable, CaseIterable {
            /// The leading segment: one step back through the history.
            case backward
            /// The trailing segment: one step forward again.
            case forward

            /// The segment this direction occupies.
            public var segmentIndex: Int {
                switch self {
                case .backward: 0
                case .forward: 1
                }
            }

            init?(segmentIndex: Int) {
                switch segmentIndex {
                case 0: self = .backward
                case 1: self = .forward
                default: return nil
                }
            }
        }

        // MARK: - History entry

        /// One row of a long-press history menu.
        ///
        /// Data, not a view: the item builds the `NSMenuItem` and owns what a
        /// click on it does, so the host never has to know about
        /// `representedObject` and the item never rewrites an object the host
        /// handed it.
        public struct HistoryEntry {
            /// The row's title.
            public var title: String
            /// An optional icon, drawn leading the title.
            public var image: NSImage?
            /// Whether the row can be chosen.
            public var isEnabled: Bool

            public init(title: String, image: NSImage? = nil, isEnabled: Bool = true) {
                self.title = title
                self.image = image
                self.isEnabled = isEnabled
            }
        }

        // MARK: - Item

        private lazy var _item = NavigationNSToolbarItem(for: self)
        open override var item: NSToolbarItem { _item }

        // MARK: - Control

        /// The hosted control. Internal — not part of the public API, and the
        /// tests' only way in.
        ///
        /// How the pair looks is settled here — two segments, momentary,
        /// separated bezel, direction-aware chevrons, no menu indicator — and
        /// nothing forwards to it. A navigation pair has one correct appearance,
        /// and the missing knob is the lesser cost: `target` and `action` hang
        /// off this control, and a `nil` action silently turns the long-press
        /// menus into click-to-open menus, so handing it out "for styling" would
        /// hand out that too.
        ///
        /// `private` would buy nothing over this: AppKit needs the view on the
        /// toolbar item, so `item.view` leads here for anyone outside who casts
        /// it either way. What is closed is the typed, inviting door — not
        /// reachability, which no design can close.
        let segmentedControl: NSSegmentedControl

        // MARK: - Data source and delegate

        /// Supplies availability and history. Pulled, never pushed — see
        /// ``validate()``.
        open weak var dataSource: (any DataSource)?

        /// Receives clicks on a segment and on a history row.
        open weak var delegate: (any Delegate)?

        // MARK: - Titles

        /// The name of the backward segment, used for its tooltip and for
        /// VoiceOver. Defaults to `"Back"`; localize per app.
        open var backwardTitle: String = "Back" {
            didSet { applySegmentPresentation() }
        }

        /// Sets the name of the backward segment.
        @discardableResult
        open func backwardTitle(_ title: String) -> Self {
            backwardTitle = title
            return self
        }

        /// The name of the forward segment, used for its tooltip and for
        /// VoiceOver. Defaults to `"Forward"`; localize per app.
        open var forwardTitle: String = "Forward" {
            didSet { applySegmentPresentation() }
        }

        /// Sets the name of the forward segment.
        @discardableResult
        open func forwardTitle(_ title: String) -> Self {
            forwardTitle = title
            return self
        }

        // MARK: - History menus

        /// Long-lived, one per direction. Attached and detached by ``validate()``,
        /// filled by ``menuNeedsUpdate(_:)``.
        private let backwardHistoryMenu = NSMenu()
        private let forwardHistoryMenu = NSMenu()

        private func historyMenu(for direction: Direction) -> NSMenu {
            switch direction {
            case .backward: backwardHistoryMenu
            case .forward: forwardHistoryMenu
            }
        }

        private func direction(ofHistoryMenu menu: NSMenu) -> Direction? {
            if menu === backwardHistoryMenu { return .backward }
            if menu === forwardHistoryMenu { return .forward }
            return nil
        }

        // MARK: - Init

        public override init(_ identifier: NSToolbarItem.Identifier? = nil) {
            segmentedControl = NSSegmentedControl()
            super.init(identifier)

            segmentedControl.segmentCount = Direction.allCases.count
            // Pressing a chevron is an action, not a choice: .selectOne would
            // leave the segment lit after the click.
            segmentedControl.trackingMode = .momentary
            segmentedControl.segmentStyle = .separated
            segmentedControl.segmentDistribution = .fillEqually
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            segmentedControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)

            for menu in [backwardHistoryMenu, forwardHistoryMenu] {
                menu.delegate = self
                // The rows come from the data source, including whether each one
                // can be chosen; automatic enabling would overrule that.
                menu.autoenablesItems = false
            }

            applySegmentPresentation()
            // Wired once and never again, because there is nowhere else it could
            // be changed from: an action-less control with segment menus opens
            // them on a plain click instead of on a long press, losing
            // single-step navigation without any error, and keeping
            // `segmentedControl` internal is what makes that unreachable rather
            // than merely warned against.
            segmentedControl.target = self
            segmentedControl.action = Self.segmentActionSelector

            _item.view = segmentedControl
            _item.paletteLabel = "Navigation"
            if #available(macOS 11.0, *) {
                _item.isNavigational = true
            }

            validate()
        }

        // MARK: - Validation

        /// Re-asks the data source whether each direction is available and how
        /// deep its history is, then updates the segments and attaches or
        /// detaches each history menu.
        ///
        /// AppKit calls this on the toolbar's validation cycle, so a host that
        /// only changes its own history has nothing to call. A host that needs
        /// the control refreshed at an exact moment — while the window is not
        /// key, say — can call it directly.
        open override func validate() {
            super.validate()

            for direction in Direction.allCases {
                let segmentIndex = direction.segmentIndex

                let canNavigate = dataSource?.navigationToolbarItem(self, canNavigateIn: direction) ?? false
                segmentedControl.setEnabled(canNavigate, forSegment: segmentIndex)

                let entryCount = dataSource?.navigationToolbarItem(self, numberOfHistoryEntriesIn: direction) ?? 0
                // Detached, not empty: a segment wired to a menu with no rows
                // still pops an empty box on a long press.
                segmentedControl.setMenu(entryCount > 0 ? historyMenu(for: direction) : nil, forSegment: segmentIndex)
            }
        }

        private static let segmentActionSelector = #selector(Navigation.segmentClicked(_:))

        // MARK: - Actions

        /// Does what a click on that segment does: tells the delegate to move one
        /// step, then re-reads the data source.
        ///
        /// A host binding ⌘[ / ⌘] to a main-menu item — `NSToolbarItem` has no key
        /// equivalents of its own — can route through here instead of duplicating
        /// the refresh.
        open func performNavigation(in direction: Direction) {
            delegate?.navigationToolbarItem(self, didNavigateIn: direction)
            validate()
        }

        @objc private func segmentClicked(_ sender: NSSegmentedControl) {
            // In momentary tracking `selectedSegment` is whichever segment is
            // being tracked right now, and -1 at every other moment — measured,
            // and the only moment this action is sent is during that tracking.
            // The consequence is that a click cannot be faked by assigning
            // `selectedSegment`, which is why the dispatch above is separable.
            guard let direction = Direction(segmentIndex: sender.selectedSegment) else { return }
            performNavigation(in: direction)
        }

        @objc private func historyRowChosen(_ sender: NSMenuItem) {
            guard let menu = sender.menu, let direction = direction(ofHistoryMenu: menu) else { return }
            delegate?.navigationToolbarItem(self, didSelectHistoryEntryAt: sender.tag, in: direction)
            validate()
        }

        // MARK: - NSMenuDelegate

        /// Fills the history menu that is about to open.
        ///
        /// Row content is pulled here rather than during validation because a
        /// row can be expensive to build — resolving an icon per row, typically
        /// — and validation runs on the event loop. Whether a menu exists at all
        /// still has to be settled earlier, in ``validate()``: attaching `nil`
        /// means there is nothing to open, and that decision cannot be made once
        /// the press has already started.
        open func menuNeedsUpdate(_ menu: NSMenu) {
            guard let direction = direction(ofHistoryMenu: menu) else { return }
            menu.removeAllItems()

            guard let dataSource else { return }
            let entryCount = dataSource.navigationToolbarItem(self, numberOfHistoryEntriesIn: direction)
            guard entryCount > 0 else { return }

            for index in 0 ..< entryCount {
                let entry = dataSource.navigationToolbarItem(self, historyEntryAt: index, in: direction)
                let menuItem = NSMenuItem(title: entry.title, action: #selector(historyRowChosen(_:)), keyEquivalent: "")
                menuItem.image = entry.image
                menuItem.isEnabled = entry.isEnabled
                menuItem.target = self
                menuItem.tag = index
                menu.addItem(menuItem)
            }
        }

        // MARK: - Presentation

        private func applySegmentPresentation() {
            for direction in Direction.allCases {
                let segmentIndex = direction.segmentIndex
                let title = title(for: direction)
                segmentedControl.setImage(Self.chevronImage(for: direction, accessibilityDescription: title), forSegment: segmentIndex)
                segmentedControl.setImageScaling(.scaleProportionallyDown, forSegment: segmentIndex)
                segmentedControl.setToolTip(title, forSegment: segmentIndex)
                // Stated rather than repaired: measured on macOS 26, the
                // indicator already defaults to off and attaching a menu does
                // not turn it on. This only holds the line against a host that
                // styled the control, and says out loud that the pair is meant
                // to read as two chevrons rather than two pop-up buttons.
                segmentedControl.setShowsMenuIndicator(false, forSegment: segmentIndex)
            }
        }

        private func title(for direction: Direction) -> String {
            switch direction {
            case .backward: backwardTitle
            case .forward: forwardTitle
            }
        }

        /// `chevron.backward` / `chevron.forward` rather than `.left` / `.right`:
        /// only the former mirror themselves in a right-to-left layout.
        private static func chevronImage(for direction: Direction, accessibilityDescription: String) -> NSImage? {
            if #available(macOS 11.0, *) {
                let symbolName = direction == .backward ? "chevron.backward" : "chevron.forward"
                return NSImage(systemSymbolName: symbolName, accessibilityDescription: accessibilityDescription)
            }
            // macOS 10.15 has no direction-aware chevron; the toolbar templates
            // are the closest thing that ships. They are shared instances, hence
            // the copy before stamping a description onto one.
            let templateName = direction == .backward ? NSImage.goBackTemplateName : NSImage.goForwardTemplateName
            guard let image = NSImage(named: templateName)?.copy() as? NSImage else { return nil }
            image.accessibilityDescription = accessibilityDescription
            return image
        }

        // MARK: - Nested toolbar item

        private final class NavigationNSToolbarItem: NSToolbarItem {
            weak var owner: NSToolbar.Navigation?

            init(for owner: NSToolbar.Navigation) {
                super.init(itemIdentifier: owner.identifier)
                self.owner = owner
            }

            override func validate() {
                super.validate()
                owner?.validate()
            }
        }
    }
}

// MARK: - Data source

extension NSToolbar.Navigation {

    /// Supplies what the navigation item draws: whether each direction is live,
    /// and what its long-press history holds.
    ///
    /// Everything here is pulled on the item's own schedule, so there is no
    /// "tell the item the history changed" step to forget.
    public protocol DataSource: AnyObject {

        /// Whether that half of the control is live.
        ///
        /// Pulled on every validation cycle — keep it cheap.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            canNavigateIn direction: NSToolbar.Navigation.Direction
        ) -> Bool

        /// How many history rows that direction has — **not** the rows
        /// themselves.
        ///
        /// Also pulled on every validation cycle, because it decides whether the
        /// segment gets a menu at all, and that has to be settled before the
        /// press rather than during it. Defaults to `0`, meaning no history menu.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            numberOfHistoryEntriesIn direction: NSToolbar.Navigation.Direction
        ) -> Int

        /// One row, asked for only while the menu is opening — the right place
        /// for per-row icon resolution.
        ///
        /// Index `0` is the **nearest** entry in that direction: the one a single
        /// click of that segment would land on, which is the order Safari uses.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            historyEntryAt index: Int,
            in direction: NSToolbar.Navigation.Direction
        ) -> NSToolbar.Navigation.HistoryEntry
    }
}

extension NSToolbar.Navigation.DataSource {

    public func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        numberOfHistoryEntriesIn direction: NSToolbar.Navigation.Direction
    ) -> Int {
        0
    }

    /// Unreachable while the count above stays at its default, which is what lets
    /// a host that wants no history menu leave both of these alone.
    public func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        historyEntryAt index: Int,
        in direction: NSToolbar.Navigation.Direction
    ) -> NSToolbar.Navigation.HistoryEntry {
        NSToolbar.Navigation.HistoryEntry(title: "")
    }
}

// MARK: - Delegate

extension NSToolbar.Navigation {

    /// Receives the two things a navigation item can be asked to do.
    public protocol Delegate: AnyObject {

        /// A segment was clicked: move one step in that direction.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            didNavigateIn direction: NSToolbar.Navigation.Direction
        )

        /// A history row was chosen. `index` uses the same nearest-first
        /// numbering the data source was asked with.
        func navigationToolbarItem(
            _ item: NSToolbar.Navigation,
            didSelectHistoryEntryAt index: Int,
            in direction: NSToolbar.Navigation.Direction
        )
    }
}

extension NSToolbar.Navigation.Delegate {

    public func navigationToolbarItem(
        _ item: NSToolbar.Navigation,
        didSelectHistoryEntryAt index: Int,
        in direction: NSToolbar.Navigation.Direction
    ) {}
}

#endif
