#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension NSSplitView {
    /// Where a divider starts out, before the user has dragged one anywhere worth restoring.
    ///
    /// Positions are handed to `setPosition(_:ofDividerAt:)` untouched, so they inherit its
    /// semantics: AppKit clamps each one to that divider's legal drag range (the panes' own
    /// size constraints, plus whatever the delegate returns from
    /// `splitView(_:constrainSplitPosition:ofSubviewAt:)`), collapses a pane when the position
    /// lands inside its collapse threshold, and maps the divider index in a right-to-left
    /// layout. Nothing here compensates for any of that -- the result matches what the host
    /// would get calling `setPosition(_:ofDividerAt:)` itself.
    public enum InitialDividerPosition: Hashable, Sendable {
        /// A distance from the leading edge along the dividing axis -- the value
        /// `setPosition(_:ofDividerAt:)` itself takes.
        case distanceFromStart(CGFloat)

        /// A distance from the far edge: the thickness the pane past this divider starts with.
        case distanceFromEnd(CGFloat)

        /// A fraction of the split view's length along the dividing axis.
        case fractionOfLength(Double)

        /// Leave this divider wherever AppKit put it. Fills a slot so the ones after it still
        /// line up with their divider.
        case unchanged

        /// Whether resolving this case needs a laid-out split view.
        fileprivate var requiresDividingAxisLength: Bool {
            switch self {
            case .distanceFromStart, .unchanged: false
            case .distanceFromEnd, .fractionOfLength: true
            }
        }

        fileprivate func resolve(inDividingAxisLength dividingAxisLength: CGFloat) -> CGFloat? {
            switch self {
            case .distanceFromStart(let distance): distance
            case .distanceFromEnd(let distance): dividingAxisLength - distance
            case .fractionOfLength(let fraction): dividingAxisLength * CGFloat(fraction)
            case .unchanged: nil
            }
        }
    }
}

extension FrameworkToolbox where Base: NSSplitView {
    /// Reports whether `autosaveName` holds a layout AppKit would actually restore.
    ///
    /// The stored value alone does not answer this, which is why the check is spelled out
    /// rather than written as `array(forKey:) != nil`. Measured on macOS 26.5.2:
    /// `-[NSSplitView _restoreFromAutosaveName]` hands the array to
    /// `-_walkLayoutDescriptionArray:withFrameHandler:`, which walks away without restoring
    /// anything -- and without logging -- unless the entry count equals `arrangedSubviews.count`
    /// and at least one entry parses as a comma-separated string of five or more fields.
    ///
    /// The count is the one that bites in practice. Ship a version that adds a pane and every
    /// existing user's stored layout stops being applicable, while the key stays right where it
    /// was: a `!= nil` check reads that as "not the first launch", so neither the stored layout
    /// nor the host's initial positions land and the split view falls back to AppKit's even
    /// split. It looks like autosaving broke, and only after an upgrade.
    public func hasRestorableDividerPositions(autosaveName: NSSplitView.AutosaveName) -> Bool {
        // `+[NSSplitView _autosaveDefaultsKeyForName:]` is one line:
        // `[NSString stringWithFormat:@"NSSplitView Subview Frames %@", name]`.
        let storageKey = "NSSplitView Subview Frames \(autosaveName)"
        // `array(forKey:)` covers the "stored value is not an array" rejection on its own.
        guard let storedLayout = UserDefaults.standard.array(forKey: storageKey) else { return false }
        guard storedLayout.count == base.arrangedSubviews.count else { return false }
        return storedLayout.contains { storedEntry in
            guard let layoutDescription = storedEntry as? String else { return false }
            return layoutDescription.components(separatedBy: ", ").count >= 5
        }
    }

    /// Registers `autosaveName`, and applies `initialPositions` only when there is no stored
    /// layout to restore -- the "lay the dividers out the first time, then never again" shape
    /// that `autosaveName` on its own has no opening for.
    ///
    /// Each element positions the divider at the matching index; use
    /// ``NSSplitView/InitialDividerPosition/unchanged`` to skip one and extras are ignored.
    /// They are applied in order, which matters, because AppKit clamps every position against
    /// the dividers already placed.
    ///
    /// Positions needing a length (``NSSplitView/InitialDividerPosition/distanceFromEnd(_:)``
    /// and ``NSSplitView/InitialDividerPosition/fractionOfLength(_:)``) are applied
    /// synchronously when the split view has been laid out, and otherwise after one hop through
    /// the main queue -- calling this from `viewDidLoad`, where the split view still has no
    /// size, is expected. If it still has no size by then, only the cases that do not need one
    /// are applied.
    ///
    /// ```swift
    /// splitView.box.restoreDividerPositions(
    ///     autosaveName: "MainWindow",
    ///     initialPositions: [.distanceFromStart(sidebarWidth), .distanceFromEnd(inspectorWidth)]
    /// )
    /// ```
    ///
    /// There is deliberately no `@resultBuilder` spelling of this. Measured on Swift 6.2: a bare
    /// implicit member chain inside a result-builder closure cannot resolve its contextual type
    /// -- `cannot infer contextual base in reference to member` -- for a generic builder, a
    /// non-generic one, `buildPartialBlock` and a variadic `buildBlock` alike. A builder would
    /// therefore force every case to be written out in full, which an array literal does not.
    ///
    /// - Returns: `true` when the dividers came from the stored layout, `false` when
    ///   `initialPositions` was applied.
    @discardableResult
    public func restoreDividerPositions(
        autosaveName: NSSplitView.AutosaveName,
        initialPositions: [NSSplitView.InitialDividerPosition]
    ) -> Bool {
        // Ask before registering the name: doing so is itself what consumes the stored layout.
        let canRestoreStoredLayout = hasRestorableDividerPositions(autosaveName: autosaveName)

        // Restoring hangs off the "the value actually changed" branch of
        // `-[NSSplitView setAutosaveName:]`, so assigning a name that is already in place does
        // nothing at all. Clearing it first is what makes the assignment below restore.
        // `-_restoreFromAutosaveName` opens with a `length != 0` guard, so the intermediate
        // `nil` cannot itself disturb the current layout.
        base.autosaveName = nil
        base.autosaveName = autosaveName

        if !canRestoreStoredLayout {
            applyInitialDividerPositions(initialPositions)
        }
        return canRestoreStoredLayout
    }

    /// The split view's extent along the axis its dividers cut across.
    private var dividingAxisLength: CGFloat {
        base.isVertical ? base.bounds.width : base.bounds.height
    }

    private func applyInitialDividerPositions(_ initialPositions: [NSSplitView.InitialDividerPosition]) {
        guard !initialPositions.isEmpty else { return }

        if dividingAxisLength > 0 || !initialPositions.contains(where: \.requiresDividingAxisLength) {
            setInitialDividerPositions(initialPositions)
        } else {
            let splitView = base
            DispatchQueue.main.async {
                splitView.box.setInitialDividerPositions(initialPositions)
            }
        }
    }

    private func setInitialDividerPositions(_ initialPositions: [NSSplitView.InitialDividerPosition]) {
        let dividingAxisLength = dividingAxisLength
        // One divider between every adjacent pair of arranged subviews. AppKit asserts on an
        // out-of-range index, so anything past the last one is dropped rather than passed on.
        let lastDividerIndex = base.arrangedSubviews.count - 2
        guard lastDividerIndex >= 0 else { return }

        for (dividerIndex, initialPosition) in initialPositions.enumerated() where dividerIndex <= lastDividerIndex {
            // Nothing to fall back to when the split view never got a size.
            if dividingAxisLength <= 0, initialPosition.requiresDividingAxisLength { continue }
            guard let position = initialPosition.resolve(inDividingAxisLength: dividingAxisLength) else { continue }
            base.setPosition(position, ofDividerAt: dividerIndex)
        }
    }
}

#endif
