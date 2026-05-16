//
//  QuickActionBar+Window.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

import AppKit

extension QuickActionBar {
    @objc(QuickActionBarWindow) final class Window: EphemeralWindow {
        var quickActionBar: QuickActionBar!

        // Debounce edits to minimise the number of search calls.
        let debouncer = QuickActionBar.Debounce(seconds: 0.2)

        override var canBecomeKey: Bool { return true }
        override var canBecomeMain: Bool { return currentCanBecomeMainWindow }

        override func resignFirstResponder() -> Bool {
            return true
        }

        var currentCanBecomeMainWindow: Bool = true

        var showKeyboardShortcuts: Bool = false

        var placeholderText: String = "" {
            didSet {
                editLabel.placeholderString = placeholderText
            }
        }

        private var _currentSearchText: String = ""
        private(set) var currentSearchText: String {
            get { _currentSearchText }
            set {
                _currentSearchText = newValue
                editLabel.stringValue = newValue
            }
        }

        private lazy var primaryStack: NSStackView = {
            let stack = NSStackView()
            stack.identifier = NSUserInterfaceItemIdentifier("primary")
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.orientation = .vertical
            stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)

            stack.setContentHuggingPriority(.required, for: .horizontal)
            stack.setContentHuggingPriority(.required, for: .vertical)
            stack.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

            stack.setHuggingPriority(.required, for: .vertical)

            stack.needsLayout = true

            return stack
        }()

        internal lazy var editLabel: NSTextField = {
            let textField = QuickActionBar.TextField()
            textField.translatesAutoresizingMaskIntoConstraints = false
            textField.wantsLayer = true
            textField.drawsBackground = false
            textField.isBordered = false
            textField.isBezeled = false
            textField.font = NSFont.systemFont(ofSize: 24, weight: .regular)
            textField.textColor = NSColor.textColor
            textField.alignment = .left
            textField.isEnabled = true
            textField.isEditable = true
            textField.isSelectable = true
            textField.cell?.wraps = false
            textField.cell?.isScrollable = true
            textField.maximumNumberOfLines = 1
            textField.placeholderString = QuickActionBar.DefaultPlaceholderString

            textField.focusRingType = .none

            textField.setContentHuggingPriority(.defaultLow, for: .horizontal)
            textField.setContentHuggingPriority(.defaultHigh, for: .vertical)
            textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            textField.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

            return textField
        }()

        private lazy var searchImage: NSImageView = {
            let imageView = NSImageView()
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
            imageView.addConstraint(NSLayoutConstraint(item: imageView, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .width, multiplier: 1, constant: 24))
            imageView.addConstraint(NSLayoutConstraint(item: imageView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 40))
            imageView.imageScaling = .scaleProportionallyUpOrDown

            let image = self.quickActionBar.searchImage!
            imageView.image = image
            return imageView
        }()

        private let asyncActivityIndicator = QuickActionBar.DelayedIndeterminiteRadialProgressIndicator()

        private lazy var searchStack: NSStackView = {
            let stack = NSStackView()
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.detachesHiddenViews = true
            stack.orientation = .horizontal

            if let _ = self.quickActionBar.searchImage {
                stack.addArrangedSubview(searchImage)
            }

            let textContainer = NSView()
            textContainer.translatesAutoresizingMaskIntoConstraints = false
            textContainer.addSubview(editLabel)

            NSLayoutConstraint.activate([
                editLabel.leadingAnchor.constraint(equalTo: textContainer.leadingAnchor),
                editLabel.trailingAnchor.constraint(equalTo: textContainer.trailingAnchor),
                editLabel.centerYAnchor.constraint(equalTo: textContainer.centerYAnchor),
                textContainer.heightAnchor.constraint(greaterThanOrEqualTo: editLabel.heightAnchor),
            ])

            stack.addArrangedSubview(textContainer)

            textContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)

            stack.addArrangedSubview(asyncActivityIndicator)

            stack.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            stack.setContentHuggingPriority(.defaultHigh, for: .vertical)

            stack.setHuggingPriority(.required, for: .vertical)

            return stack
        }()

        lazy var results: QuickActionBar.ResultsView = {
            let resultsView = QuickActionBar.ResultsView()
            resultsView.translatesAutoresizingMaskIntoConstraints = false
            resultsView.setContentHuggingPriority(.defaultLow, for: .horizontal)
            resultsView.quickActionBar = self.quickActionBar
            resultsView.showKeyboardShortcuts = self.showKeyboardShortcuts
            resultsView.configure()

            return resultsView
        }()

        internal var userDidActivateItem: Bool = false

        private var isResultsExpanded = false

        private var currentSearchRequestTask: QuickActionBar.SearchTask?

        private var springAnimationTimer: Timer?
        private var springState = SpringState()
        private var animationStartFrame: NSRect = .zero
        private var animationTargetFrame: NSRect = .zero
        private var animationIsShowing: Bool = true
        private var lastSpringTickTime: CFTimeInterval = 0
    }
}

extension QuickActionBar.Window {
    @inlinable func reloadData() {
        results.reloadData()
    }

    /// Calculate the collapsed content height (search bar only, no results).
    func collapsedContentHeight() -> CGFloat {
        primaryStack.layoutSubtreeIfNeeded()
        return primaryStack.fittingSize.height
    }
}

extension QuickActionBar.Window {
    internal func setup(parentWindow: NSWindow? = nil, initialSearchText: String?) {
        autorecalculatesKeyViewLoop = true

        // Adopt the effective appearance of the parent window during setup.
        QuickActionBar.usingEffectiveAppearance(of: parentWindow) {
            // Transparent container — a flipped container keeps the search bar
            // y-coordinate constant as the window grows downward during animation.
            let container = QuickActionBar.FlippedContainerView()
            container.wantsLayer = true
            self.contentView = container

            let content = QuickActionBar.PrimaryRoundedView()
            content.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(content)

            let pad = QuickActionBar.animationPadding
            NSLayoutConstraint.activate([
                content.topAnchor.constraint(equalTo: container.topAnchor, constant: pad),
                content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: pad),
                content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -pad),
                content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -pad),
            ])

            content.wantsLayer = true
            self.animationLayer = content.layer

            primaryStack.wantsLayer = true
            primaryStack.translatesAutoresizingMaskIntoConstraints = false
            primaryStack.setContentHuggingPriority(.required, for: .horizontal)
            primaryStack.setContentHuggingPriority(.required, for: .vertical)

            content.contentView.addSubview(primaryStack)

            // Pin stack to top/leading/trailing only — no bottom constraint, so
            // the stack can extend beyond the glass view while the window is
            // mid-expand. The glass layer mask clips the overflow.
            NSLayoutConstraint.activate([
                content.contentView.topAnchor.constraint(equalTo: primaryStack.topAnchor),
                content.contentView.leadingAnchor.constraint(equalTo: primaryStack.leadingAnchor),
                content.contentView.trailingAnchor.constraint(equalTo: primaryStack.trailingAnchor),
            ])

            self.backgroundColor = NSColor.clear
            self.isOpaque = false

            // 'titled' + 'borderless' together produce a heavier drop shadow than
            // 'borderless' alone.
            self.styleMask = [.titled, .fullSizeContentView, .borderless]

            self.isMovable = false
            self.isMovableByWindowBackground = false

            primaryStack.addArrangedSubview(searchStack)

            results.isHidden = true
            primaryStack.addArrangedSubview(results)

            primaryStack.needsLayout = true

            editLabel.delegate = self

            self.makeFirstResponder(editLabel)
            self.invalidateShadow()
            self.level = .init(23)

            if let parent = parentWindow {
                self.order(.above, relativeTo: parent.windowNumber)
            }

            self.primaryStack.layoutSubtreeIfNeeded()

            if let initialSearchText = initialSearchText {
                self.currentSearchText = initialSearchText
            }

            // Defer the initial search until after the present animation completes.
            self.didFinishPresentAnimation = { [weak self] in
                self?.searchTermDidChange()
            }
        }
    }
}

extension QuickActionBar.Window {
    override func cancelOperation(_: Any?) {
        // Make the window lose its initial responder status, which will close it.
        resignMain()
    }

    func pressedLeftArrowInResultsView() {
        makeFirstResponder(editLabel)
    }
}

extension QuickActionBar.Window {
    func provideResultIdentifiers(_ identifiers: [AnyHashable]) {
        results.identifiers = identifiers
    }
}

// MARK: - Results Expand/Collapse Animation

extension QuickActionBar.Window {
    /// Called by `ResultsView` when the results count changes.
    func handleResultsCountChanged(hasResults: Bool) {
        if hasResults == isResultsExpanded {
            results.isHidden = !hasResults
            return
        }
        isResultsExpanded = hasResults
        animateResultsTransition(showing: hasResults)
    }

    private func animateResultsTransition(showing: Bool) {
        springAnimationTimer?.invalidate()
        springAnimationTimer = nil

        let startFrame = self.frame
        let targetFrame = calculateWindowFrame(showingResults: showing)

        if showing {
            // Show results immediately so the stack is at full height. The
            // glass layer mask clips overflow until the window expands.
            results.isHidden = false
        }

        springState = SpringState()
        animationStartFrame = startFrame
        animationTargetFrame = targetFrame
        animationIsShowing = showing
        lastSpringTickTime = CACurrentMediaTime()

        // Manual timer keeps the model frame and visual frame in sync;
        // animator().setFrame would let Auto Layout resolve against the
        // final frame mid-animation.
        let timer = Timer(timeInterval: 1.0 / 120.0, repeats: true) { [weak self] _ in
            self?.springAnimationTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        springAnimationTimer = timer
    }

    private func springAnimationTick() {
        let now = CACurrentMediaTime()
        let deltaTime = CGFloat(now - lastSpringTickTime)
        lastSpringTickTime = now

        let clampedDeltaTime = min(deltaTime, 1.0 / 30.0)
        let settled = springState.step(deltaTime: clampedDeltaTime)

        let progress = springState.position
        let currentFrame = interpolateRect(
            from: animationStartFrame,
            to: animationTargetFrame,
            progress: progress
        )
        self.setFrame(currentFrame, display: true)

        if settled {
            self.setFrame(animationTargetFrame, display: true)

            springAnimationTimer?.invalidate()
            springAnimationTimer = nil

            if !animationIsShowing {
                results.isHidden = true
            }
            invalidateShadow()
        }
    }

    /// Calculate the target window frame, keeping the visual top edge fixed.
    private func calculateWindowFrame(showingResults: Bool) -> NSRect {
        let pad = QuickActionBar.animationPadding
        let edgeInsets = primaryStack.edgeInsets
        let searchBarHeight = searchStack.fittingSize.height
        let stackSpacing = primaryStack.spacing

        var contentHeight = edgeInsets.top + searchBarHeight + edgeInsets.bottom
        if showingResults {
            contentHeight += stackSpacing + quickActionBar.height
        }

        let windowHeight = contentHeight + 2 * pad

        let currentFrame = self.frame
        let topY = currentFrame.origin.y + currentFrame.height
        return NSRect(
            x: currentFrame.origin.x,
            y: topY - windowHeight,
            width: currentFrame.width,
            height: windowHeight
        )
    }

    private func interpolateRect(from: NSRect, to: NSRect, progress: CGFloat) -> NSRect {
        return NSRect(
            x: from.origin.x + (to.origin.x - from.origin.x) * progress,
            y: from.origin.y + (to.origin.y - from.origin.y) * progress,
            width: from.width + (to.width - from.width) * progress,
            height: from.height + (to.height - from.height) * progress
        )
    }
}

// MARK: - Spring Physics Solver

/// Damped harmonic oscillator for smooth window frame animation.
/// Parameters approximate `Spring(duration: 0.3, bounce: 0.2)`.
private struct SpringState {
    var position: CGFloat = 0   // 0 = start, 1 = target
    var velocity: CGFloat = 0

    static let stiffness: CGFloat = 300
    static let damping: CGFloat = 28
    static let mass: CGFloat = 1

    private static let positionThreshold: CGFloat = 0.0005
    private static let velocityThreshold: CGFloat = 0.01

    /// Advance the spring simulation. Returns `true` when settled at the target.
    mutating func step(deltaTime: CGFloat) -> Bool {
        let displacement = position - 1.0
        let springForce = -Self.stiffness * displacement
        let dampingForce = -Self.damping * velocity
        let acceleration = (springForce + dampingForce) / Self.mass

        velocity += acceleration * deltaTime
        position += velocity * deltaTime

        return abs(position - 1.0) < Self.positionThreshold
            && abs(velocity) < Self.velocityThreshold
    }
}

// MARK: - Search

extension QuickActionBar.Window {
    private func searchTermDidChange() {
        precondition(Thread.isMainThread)

        cancelCurrentSearchTask()

        guard let contentSource = quickActionBar.contentSource else { return }

        let currentSearch = editLabel.stringValue
        _currentSearchText = currentSearch

        asyncActivityIndicator.startAnimation(self)

        let itemsTask = QuickActionBar.SearchTask(searchTerm: currentSearch) { [weak self] results in
            DispatchQueue.main.async { [weak self] in
                guard let `self` = self else { return }
                self.cancelCurrentSearchTask()
                self.updateResults(currentSearch: currentSearch, results: results ?? [])
            }
        }

        currentSearchRequestTask = itemsTask

        contentSource.quickActionBar(quickActionBar, itemsForSearchTermTask: itemsTask)
    }

    private func updateResults(currentSearch: String, results: [AnyHashable]) {
        precondition(Thread.isMainThread)

        asyncActivityIndicator.stopAnimation(self)
        self.results.currentSearchTerm = currentSearch
        self.results.identifiers = results
    }

    private func cancelCurrentSearchTask() {
        precondition(Thread.isMainThread)

        currentSearchRequestTask?.completion = nil
        currentSearchRequestTask = nil
    }
}

// MARK: - Text control handling

extension QuickActionBar.Window: NSTextFieldDelegate {
    func controlTextDidChange(_: Notification) {
        debouncer.debounce { [weak self] in
            self?.searchTermDidChange()
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(moveDown(_:)) {
            return results.selectNextSelectableRow()
        } else if commandSelector == #selector(moveUp(_:)) {
            return results.selectPreviousSelectableRow()
        } else if commandSelector == #selector(insertNewline(_:)) {
            let currentRowSelection = results.selectedRow
            guard currentRowSelection >= 0 else { return false }
            results.rowAction()
            return true
        } else if
            showKeyboardShortcuts,
            let event = currentEvent,
            event.modifierFlags.contains(.command),
            let characters = event.characters,
            let index = Int(characters) {
            return results.performShortcutAction(for: index)
        }

        return false
    }
}

#endif
