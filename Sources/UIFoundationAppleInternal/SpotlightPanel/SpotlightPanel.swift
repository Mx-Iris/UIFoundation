//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Reverse-engineering notes: Researchs/Spotlight-Panel-Internals.md
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit
import OSToolbox

/// A replica of macOS 26's Spotlight panel: the floating translucent platter with a query field
/// that grows downwards into a result list.
///
/// Everything visible is reproduced from measurements of Spotlight's own binary — placement,
/// the present and dismiss springs, the non-uniform scale, the content blur, the sizing rules.
/// **The results are not**: this type never searches anything. A host supplies items through
/// ``SpotlightPanelDataSource`` and reacts through ``SpotlightPanelDelegate``.
///
/// ```swift
/// let spotlightPanel = SpotlightPanel()
/// spotlightPanel.dataSource = self
/// spotlightPanel.delegate = self
/// spotlightPanel.present()
/// ```
///
/// Requires the `SpotlightPanel` trait, which also turns on `AppleInternal` (the content blur is
/// private API) and `Navigation`.
@MainActor
@Loggable
public final class SpotlightPanel {
    /// Behaviour and text. Changing it while presented takes effect on the next presentation.
    public var configuration: Configuration

    public weak var dataSource: (any SpotlightPanelDataSource)?
    public weak var delegate: (any SpotlightPanelDelegate)?

    private var panel: Panel?
    private var contentViewController: ContentViewController?
    private var backgroundView: BackgroundView?

    private let animationCoordinator = AnimationCoordinator()
    private let windowFrameAnimator = WindowFrameAnimator()
    private var sizingDebouncer: Debouncer

    private var currentSearchTask: SearchTask?
    private var currentItems: [AnyHashable] = []

    /// The height the panel settled on last time it was expanded, fed back into
    /// ``PlatterBehavior/heightCanPersist``.
    private var storedExpandedHeight: CGFloat?

    private var didActivateItem = false

    /// Where the panel is in the collapse / expand cycle.
    public private(set) var expansionState: ExpansionState = .uninitialized

    public init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.sizingDebouncer = Debouncer(delay: configuration.sizingDebounceDelay)
    }

    // MARK: - Presenting

    /// Whether a panel is on screen.
    public var isPresented: Bool { panel != nil }

    /// The current query text.
    public var searchTerm: String {
        get { contentViewController?.searchTerm ?? "" }
        set { contentViewController?.searchTerm = newValue }
    }

    /// Raise the panel.
    ///
    /// Calling this while a dismissal is animating reverses it in place rather than building a
    /// second panel, which is what makes a double-tap of a host's hotkey feel continuous.
    ///
    /// - Parameters:
    ///   - screen: which screen to place the panel on. Defaults to the one with the mouse, or
    ///     the main screen.
    ///   - initialSearchTerm: text to start with, already searched on.
    public func present(on screen: NSScreen? = nil, initialSearchTerm: String = "") {
        if let panel, animationCoordinator.phase == .dismissing {
            #log(.debug, "Reversing an in-flight dismissal")
            panel.isDismissing = false
            activateApplicationIfNeeded()
            panel.makeKeyAndOrderFront(nil)
            runPresentAnimation(on: panel)
            return
        }

        guard panel == nil else { return }

        let targetScreen = screen ?? screenUnderMouse ?? NSScreen.main
        guard let targetScreen else {
            #log(.error, "No screen to present on")
            return
        }

        didActivateItem = false
        storedExpandedHeight = nil
        expansionState = .collapsed
        sizingDebouncer = Debouncer(delay: configuration.sizingDebounceDelay)

        let metrics = configuration.metrics
        let windowSize = metrics.windowSize(forContentHeight: metrics.collapsedHeight)
        let windowOrigin = metrics.defaultOrigin(forWindowSize: windowSize, on: targetScreen)
        let contentRect = CGRect(origin: windowOrigin, size: windowSize)

        let panel = Panel(contentRect: contentRect)
        panel.dismissesWhenResigningKey = configuration.dismissesWhenResigningKey
        buildContent(in: panel)
        wireUpEvents(for: panel)
        self.panel = panel

        contentViewController?.placeholderText = configuration.placeholderText
        if !initialSearchTerm.isEmpty {
            contentViewController?.searchTerm = initialSearchTerm
        }

        activateApplicationIfNeeded()
        panel.makeKeyAndOrderFront(nil)
        contentViewController?.focusSearchField()

        // The first search waits for the entrance animation to finish. Running both at once puts
        // a window resize on top of the layer's scale animation, and the scale's centring
        // translation is computed from the layer's bounds *at the time the animation is built* —
        // so a window that grows mid-flight leaves the panel visibly off-centre as it settles.
        runPresentAnimation(on: panel) { [weak self] in
            self?.issueSearch(for: initialSearchTerm)
        }
    }

    /// Take the panel down, animating out.
    public func dismiss() {
        guard let panel, let backgroundLayer = backgroundView?.layer else { return }
        guard animationCoordinator.phase != .dismissing else { return }

        panel.isDismissing = true
        currentSearchTask?.cancel()
        currentSearchTask = nil
        sizingDebouncer.cancel()
        windowFrameAnimator.cancel()

        #log(.debug, "Dismissal requested")
        animationCoordinator.dismiss(window: panel, layer: backgroundLayer) { [weak self] in
            self?.finishDismissal()
        }
    }

    private func runPresentAnimation(
        on panel: Panel,
        completion: @escaping @MainActor () -> Void = {}
    ) {
        guard let backgroundLayer = backgroundView?.layer else {
            completion()
            return
        }
        animationCoordinator.present(window: panel, layer: backgroundLayer, completion: completion)
    }

    private func finishDismissal() {
        guard let panel else { return }
        panel.orderOut(nil)
        panel.close()

        self.panel = nil
        contentViewController = nil
        backgroundView = nil
        currentItems = []
        expansionState = .uninitialized

        if !didActivateItem {
            delegate?.spotlightPanelDidCancel(self)
        }
        delegate?.spotlightPanelDidDismiss(self)
    }

    private func activateApplicationIfNeeded() {
        guard configuration.activatesApplicationOnPresent else { return }
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private var screenUnderMouse: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) }
    }

    // MARK: - Content

    private func buildContent(in panel: Panel) {
        let metrics = configuration.metrics

        let windowContentView = NSView()
        windowContentView.wantsLayer = true
        panel.contentView = windowContentView

        let backgroundView = BackgroundView(cornerRadius: metrics.cornerRadius)
        windowContentView.addSubview(backgroundView)

        let padding = metrics.animationPadding
        NSLayoutConstraint.activate([
            backgroundView.topAnchor.constraint(equalTo: windowContentView.topAnchor, constant: padding),
            backgroundView.leadingAnchor.constraint(equalTo: windowContentView.leadingAnchor, constant: padding),
            backgroundView.trailingAnchor.constraint(equalTo: windowContentView.trailingAnchor, constant: -padding),
            backgroundView.bottomAnchor.constraint(equalTo: windowContentView.bottomAnchor, constant: -padding),
        ])

        let contentViewController = ContentViewController(
            metrics: metrics,
            searchFieldFontSize: configuration.searchFieldFontSize,
            searchFieldLeadingSymbolName: configuration.searchFieldLeadingSymbolName,
            searchDebounceDelay: configuration.searchDebounceDelay
        )
        contentViewController.resultsView.selectionCornerRadius = metrics.resultSelectionCornerRadius
        contentViewController.resultsView.selectionHorizontalInset = metrics.resultSelectionHorizontalInset
        let contentView = contentViewController.view
        backgroundView.contentView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: backgroundView.contentView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: backgroundView.contentView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: backgroundView.contentView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: backgroundView.contentView.bottomAnchor),
        ])

        self.backgroundView = backgroundView
        self.contentViewController = contentViewController

        windowContentView.layoutSubtreeIfNeeded()
    }

    private func wireUpEvents(for panel: Panel) {
        guard let contentViewController else { return }

        contentViewController.canSelectItem = { [weak self] item in
            guard let self else { return true }
            return self.delegate?.spotlightPanel(self, canSelectItem: item) ?? true
        }
        contentViewController.viewForItem = { [weak self] item in
            guard let self else { return nil }
            return self.dataSource?.spotlightPanel(self, viewForItem: item, searchTerm: self.searchTerm)
        }
        contentViewController.selectionDidChange = { [weak self] item in
            guard let self, let item else { return }
            self.delegate?.spotlightPanel(self, didSelectItem: item)
        }
        contentViewController.itemDidActivate = { [weak self] item in
            self?.activate(item)
        }
        contentViewController.searchTermDidChange = { [weak self] searchTerm in
            guard let self else { return }
            self.delegate?.spotlightPanel(self, searchTermDidChange: searchTerm)
            self.issueSearch(for: searchTerm)
        }
        contentViewController.cancelRequested = { [weak self] in
            self?.dismiss()
        }
        contentViewController.tabPressed = { [weak self] isForward in
            guard let self else { return false }
            return self.delegate?.spotlightPanel(self, didPressTabForward: isForward) ?? false
        }
        contentViewController.drillDownRequested = { [weak self] item in
            guard let self else { return false }
            return self.delegate?.spotlightPanel(self, didRequestDrillDownForItem: item) ?? false
        }

        panel.resignedKey = { [weak self] in
            self?.dismiss()
        }
        panel.copyRequested = { [weak self] in
            guard let self,
                  self.contentViewController?.searchFieldHasSelectedText == false,
                  let selectedItem = self.contentViewController?.resultsView.selectedItem
            else { return false }
            self.delegate?.spotlightPanel(self, didRequestCopyForItem: selectedItem)
            return true
        }
        panel.quickLookRequested = { [weak self] in
            guard let self, let selectedItem = self.contentViewController?.resultsView.selectedItem else {
                return false
            }
            self.delegate?.spotlightPanel(self, didRequestQuickLookForItem: selectedItem)
            return true
        }
    }

    private func activate(_ item: AnyHashable) {
        let shouldDismiss = delegate?.spotlightPanel(self, didActivateItem: item) ?? true
        guard shouldDismiss else { return }
        didActivateItem = true
        dismiss()
    }

    // MARK: - Searching

    /// Re-ask the data source for the current query.
    public func reloadResults() {
        issueSearch(for: searchTerm)
    }

    private func issueSearch(for searchTerm: String) {
        currentSearchTask?.cancel()

        guard let dataSource else {
            apply(items: [], searchTerm: searchTerm)
            return
        }

        let searchTask = SearchTask(searchTerm: searchTerm) { [weak self] results in
            guard let self, self.currentSearchTask?.searchTerm == searchTerm else { return }
            self.currentSearchTask = nil
            self.apply(items: results, searchTerm: searchTerm)
        }
        currentSearchTask = searchTask
        dataSource.spotlightPanel(self, itemsForSearchTask: searchTask)
    }

    /// Push a set of results in without going through the data source.
    public func setResults(_ items: [AnyHashable]) {
        apply(items: items, searchTerm: searchTerm)
    }

    private func apply(items: [AnyHashable], searchTerm: String) {
        guard let contentViewController else { return }

        currentItems = items
        contentViewController.showsResults = !items.isEmpty
        contentViewController.resultsView.setItems(items)

        let platterBehavior = dataSource?.spotlightPanel(
            self,
            platterBehaviorForItems: items,
            searchTerm: searchTerm
        ) ?? defaultPlatterBehavior(forItemCount: items.count)

        scheduleResize(for: platterBehavior, hasResults: !items.isEmpty)
    }

    // MARK: - Sizing

    /// The behavior a plain result list gets when the data source does not override it.
    public func defaultPlatterBehavior(forItemCount itemCount: Int) -> PlatterBehavior {
        guard itemCount > 0 else { return .collapsed }

        let metrics = configuration.metrics
        let expandedFloor = metrics.minimumExpandedHeight - metrics.collapsedHeight - metrics.separatorHeight
        return .list(
            minimumHeight: max(expandedFloor, 0),
            maximumHeight: max(maximumResultsHeight, 0)
        )
    }

    /// The ceiling a result list is clamped to, derived from the screen the panel is on.
    private var maximumResultsHeight: CGFloat {
        let metrics = configuration.metrics
        let screen = panel?.screen ?? NSScreen.main
        let visibleHeight = screen?.visibleFrame.height ?? metrics.minimumExpandedHeight
        let totalCeiling = visibleHeight * configuration.maximumHeightFractionOfScreen
        return totalCeiling - metrics.collapsedHeight - metrics.separatorHeight
    }

    private func scheduleResize(for platterBehavior: PlatterBehavior, hasResults: Bool) {
        let resize: () -> Void = { [weak self] in
            guard let self else { return }
            self.performResize(for: platterBehavior, hasResults: hasResults)
        }

        if platterBehavior.isAnimated {
            sizingDebouncer.schedule(resize)
        } else {
            sizingDebouncer.fireImmediately(resize)
        }
    }

    private func performResize(for platterBehavior: PlatterBehavior, hasResults: Bool) {
        guard let panel, let contentViewController else { return }

        let metrics = configuration.metrics
        let measuredResultsHeight = contentViewController.resultsView.measuredContentHeight
        let contentHeight = platterBehavior.resolvedContentHeight(
            collapsedHeight: metrics.collapsedHeight,
            measuredResultsHeight: measuredResultsHeight,
            separatorHeight: metrics.separatorHeight,
            storedExpandedHeight: storedExpandedHeight,
            hasResults: hasResults
        )

        let isExpanding = contentHeight > metrics.collapsedHeight
        storedExpandedHeight = isExpanding
            ? contentHeight - metrics.collapsedHeight - metrics.separatorHeight
            : storedExpandedHeight

        let targetFrame = metrics.frame(panel.frame, resizedToContentHeight: contentHeight)
        guard targetFrame != panel.frame else {
            expansionState = isExpanding ? .expanded : .collapsed
            return
        }

        expansionState = isExpanding ? .expanding : .collapsed

        guard platterBehavior.isAnimated, !AnimationRecipe.prefersReducedMotion else {
            windowFrameAnimator.cancel()
            panel.setFrame(targetFrame, display: true)
            expansionState = isExpanding ? .expanded : .collapsed
            return
        }

        windowFrameAnimator.animate(
            panel,
            to: targetFrame,
            duration: configuration.resizeAnimationDuration
        ) { [weak self] in
            self?.expansionState = isExpanding ? .expanded : .collapsed
        }
    }
}

#endif
