#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundationToolbox

/// Covers `NSSplitView.box.restoreDividerPositions(autosaveName:initialPositions:)` and the
/// stored-layout check behind it.
///
/// The check is the reason the API exists, so most of this suite is aimed at it. AppKit restores a
/// stored divider layout only when its entry count still matches `arrangedSubviews.count`, and it
/// gives no indication when it declines -- so "the key exists" and "the layout will be restored"
/// are different questions, and answering the first one instead is what makes a split view fall
/// back to an even split after a version adds a pane.
/// The dividing-axis length every fixture split view is built at. A top-level constant rather than
/// a static member so it can be a default argument without crossing out of the suite's isolation.
private let splitViewLength: CGFloat = 1000

@Suite("SplitView autosave")
@MainActor
struct SplitViewAutosaveTests {
    // MARK: - Fixtures

    /// The key AppKit stores under, spelled out independently of the implementation.
    private func storageKey(forAutosaveName autosaveName: String) -> String {
        "NSSplitView Subview Frames \(autosaveName)"
    }

    /// A unique autosave name per test, cleared before use so a crashed run cannot leak into the
    /// next one.
    private func makeAutosaveName(_ testName: String) -> String {
        let autosaveName = "UIFoundationTests.SplitViewAutosave.\(testName)"
        UserDefaults.standard.removeObject(forKey: storageKey(forAutosaveName: autosaveName))
        return autosaveName
    }

    private func removeStoredLayout(forAutosaveName autosaveName: String) {
        UserDefaults.standard.removeObject(forKey: storageKey(forAutosaveName: autosaveName))
    }

    private func makeSplitView(
        paneCount: Int,
        isVertical: Bool = true,
        length: CGFloat = splitViewLength
    ) -> NSSplitView {
        let splitView = NSSplitView()
        splitView.isVertical = isVertical
        splitView.dividerStyle = .thin
        splitView.frame = isVertical
            ? NSRect(x: 0, y: 0, width: length, height: 400)
            : NSRect(x: 0, y: 0, width: 400, height: length)
        for _ in 0 ..< paneCount {
            splitView.addArrangedSubview(NSView())
        }
        splitView.layoutSubtreeIfNeeded()
        return splitView
    }

    /// A stored entry in AppKit's own shape: five comma-space-separated fields.
    private func makeStoredEntry(_ index: Int) -> String {
        "0, 0, 100, 100, NO"
    }

    private func storeLayout(entryCount: Int, forAutosaveName autosaveName: String) {
        let storedLayout = (0 ..< entryCount).map(makeStoredEntry)
        UserDefaults.standard.set(storedLayout, forKey: storageKey(forAutosaveName: autosaveName))
    }

    /// Where a divider actually ended up: the trailing edge of the pane in front of it.
    private func dividerPosition(in splitView: NSSplitView, at dividerIndex: Int) -> CGFloat {
        let precedingPane = splitView.arrangedSubviews[dividerIndex]
        return splitView.isVertical ? precedingPane.frame.maxX : precedingPane.frame.maxY
    }

    /// Lets one hop through the main queue run, for the deferred-application path.
    ///
    /// Suspending is the only thing that works, and spinning a run loop instead is the trap.
    /// A test body already runs *inside* a block on the main queue, and the main queue is
    /// serial: nothing enqueued behind that block can run until it returns or suspends, no
    /// matter what happens within it. Measured -- with a timer attached so the run loop really
    /// did spin for the full 50 ms, the enqueued block still had not run when it returned.
    /// (Without an input source there is not even a spin: `run(until:)` finds nothing to do and
    /// returns in microseconds. That is a second, independent trap.)
    private func drainMainQueue() async {
        try? await Task.sleep(for: .milliseconds(50))
    }

    /// Records what was asked of `setPosition(_:ofDividerAt:)`, which is the whole of what this
    /// API promises about timing: which positions, computed against which length, and when.
    ///
    /// The deferred path cannot be asserted through the resulting layout. A split view grown from
    /// a zero-width frame lands in the state AppKit itself complains about
    /// (`-resizeSubviewsWithOldSize: ... left the arranged view frames in an inconsistent state`)
    /// and stops responding to `setPosition` at all -- measured, and `adjustSubviews()` does not
    /// rescue it. Laying the panes out is AppKit's job in any case; placing the call correctly is
    /// this module's.
    private final class PositionRecordingSplitView: NSSplitView {
        private(set) var requestedPositions: [(position: CGFloat, dividerIndex: Int)] = []

        override func setPosition(_ position: CGFloat, ofDividerAt dividerIndex: Int) {
            requestedPositions.append((position, dividerIndex))
            super.setPosition(position, ofDividerAt: dividerIndex)
        }
    }

    private func makeRecordingSplitView(paneCount: Int, length: CGFloat) -> PositionRecordingSplitView {
        let splitView = PositionRecordingSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.frame = NSRect(x: 0, y: 0, width: length, height: 400)
        for _ in 0 ..< paneCount {
            splitView.addArrangedSubview(NSView())
        }
        splitView.layoutSubtreeIfNeeded()
        return splitView
    }

    // MARK: - The stored-layout check

    @Test("A stored layout whose entry count no longer matches the panes is not restorable")
    func storedLayoutWithMismatchedEntryCountIsNotRestorable() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        // What shipping a version that adds a pane leaves behind: a perfectly well-formed layout
        // for a split view that no longer exists.
        let splitView = makeSplitView(paneCount: 3)
        storeLayout(entryCount: 2, forAutosaveName: autosaveName)

        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName) == false)
        // The check every host writes instead, shown getting it wrong on the same input.
        #expect(UserDefaults.standard.array(forKey: storageKey(forAutosaveName: autosaveName)) != nil)
    }

    @Test("A well-formed stored layout for the right number of panes is restorable")
    func wellFormedStoredLayoutIsRestorable() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 3)
        storeLayout(entryCount: 3, forAutosaveName: autosaveName)

        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName))
    }

    @Test("Nothing stored is not restorable")
    func absentStoredLayoutIsNotRestorable() {
        let autosaveName = makeAutosaveName(#function)
        let splitView = makeSplitView(paneCount: 2)

        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName) == false)
    }

    @Test("A stored value that is not an array of layout descriptions is not restorable")
    func malformedStoredLayoutIsNotRestorable() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }
        let storageKey = storageKey(forAutosaveName: autosaveName)

        let splitView = makeSplitView(paneCount: 2)

        // Not an array at all.
        UserDefaults.standard.set("not an array", forKey: storageKey)
        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName) == false)

        // An empty array -- the count check rejects this one on its own.
        UserDefaults.standard.set([String](), forKey: storageKey)
        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName) == false)

        // Right count, but no entry carries enough fields to describe a frame.
        UserDefaults.standard.set(["0, 0", "0, 0"], forKey: storageKey)
        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName) == false)

        // Right count, entries of the right shape, but not strings.
        UserDefaults.standard.set([1, 2], forKey: storageKey)
        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName) == false)
    }

    /// Keeps a canary on the storage key itself by letting AppKit write one, rather than trusting
    /// the format string recovered from `+[NSSplitView _autosaveDefaultsKeyForName:]`.
    @Test("AppKit stores divider layouts under the key this module reconstructs")
    func appKitStoresUnderTheReconstructedKey() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 2)
        splitView.autosaveName = autosaveName
        // No wait needed: measured, AppKit has written the layout by the time this returns.
        splitView.setPosition(300, ofDividerAt: 0)

        let storedLayout = UserDefaults.standard.array(forKey: storageKey(forAutosaveName: autosaveName))
        #expect(storedLayout != nil, "AppKit wrote the autosaved layout somewhere else")
        // And it is a shape `hasRestorableDividerPositions` accepts, which is the other half of
        // the contract: what AppKit writes has to pass the check that decides whether to read it.
        #expect(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName))
    }

    // MARK: - Applying initial positions

    @Test("Initial positions are applied when there is no stored layout")
    func initialPositionsApplyWithoutStoredLayout() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 3)
        let didRestore = splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240), .distanceFromEnd(260)]
        )
        splitView.layoutSubtreeIfNeeded()

        #expect(didRestore == false)
        #expect(dividerPosition(in: splitView, at: 0) == CGFloat(240))
        #expect(dividerPosition(in: splitView, at: 1) == splitViewLength - 260)
    }

    @Test("Initial positions are skipped when a stored layout will be restored")
    func initialPositionsAreSkippedWithStoredLayout() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        // Park the divider somewhere the initial positions would move it away from, then let
        // AppKit autosave that.
        let splitView = makeSplitView(paneCount: 2)
        splitView.autosaveName = autosaveName
        splitView.setPosition(700, ofDividerAt: 0)
        try? #require(splitView.box.hasRestorableDividerPositions(autosaveName: autosaveName))

        let reopenedSplitView = makeSplitView(paneCount: 2)
        let didRestore = reopenedSplitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240)]
        )
        reopenedSplitView.layoutSubtreeIfNeeded()

        #expect(didRestore)
        #expect(dividerPosition(in: reopenedSplitView, at: 0) == CGFloat(700))
    }

    @Test("A mismatched stored layout falls back to the initial positions")
    func mismatchedStoredLayoutFallsBackToInitialPositions() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        // The regression this API is for: the key is present, so a `!= nil` check would skip the
        // initial positions, and AppKit would decline to restore -- leaving an even split.
        let splitView = makeSplitView(paneCount: 3)
        storeLayout(entryCount: 2, forAutosaveName: autosaveName)

        let didRestore = splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240)]
        )
        splitView.layoutSubtreeIfNeeded()

        #expect(didRestore == false)
        #expect(dividerPosition(in: splitView, at: 0) == CGFloat(240))
    }

    @Test("distanceFromEnd and fractionOfLength measure along the dividing axis", arguments: [true, false])
    func lengthRelativePositionsFollowTheDividingAxis(isVertical: Bool) {
        let autosaveName = makeAutosaveName("\(#function).\(isVertical)")
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 3, isVertical: isVertical)
        splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.fractionOfLength(0.25), .distanceFromEnd(300)]
        )
        splitView.layoutSubtreeIfNeeded()

        #expect(dividerPosition(in: splitView, at: 0) == splitViewLength * 0.25)
        #expect(dividerPosition(in: splitView, at: 1) == splitViewLength - 300)
    }

    @Test("unchanged leaves its divider alone and keeps the following ones aligned")
    func unchangedSkipsItsDivider() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 3)
        splitView.setPosition(500, ofDividerAt: 0)
        splitView.layoutSubtreeIfNeeded()

        splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.unchanged, .distanceFromEnd(200)]
        )
        splitView.layoutSubtreeIfNeeded()

        #expect(dividerPosition(in: splitView, at: 0) == CGFloat(500))
        #expect(dividerPosition(in: splitView, at: 1) == splitViewLength - 200)
    }

    @Test("More positions than dividers is not an error")
    func surplusPositionsAreIgnored() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 2)
        splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240), .distanceFromStart(600), .distanceFromStart(800)]
        )
        splitView.layoutSubtreeIfNeeded()

        #expect(dividerPosition(in: splitView, at: 0) == CGFloat(240))
    }

    @Test("A split view with a single pane has no divider to position")
    func singlePaneSplitViewIsLeftAlone() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 1)
        splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240)]
        )

        #expect(splitView.arrangedSubviews.count == 1)
    }



    // MARK: - Timing

    @Test("Length-relative positions wait for a split view that has not been laid out yet")
    func lengthRelativePositionsWaitForALaidOutSplitView() async {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        // What calling this from `viewDidLoad` looks like: no size yet, and the size arrives
        // before the main queue gets its next turn.
        let splitView = makeRecordingSplitView(paneCount: 3, length: 0)

        splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240), .distanceFromEnd(260)]
        )

        // Nothing may be placed yet: `.distanceFromEnd(260)` against a zero length would put the
        // divider at -260.
        #expect(splitView.requestedPositions.isEmpty)

        splitView.frame = NSRect(x: 0, y: 0, width: splitViewLength, height: 400)
        await drainMainQueue()

        #expect(splitView.requestedPositions.map(\.dividerIndex) == [0, 1])
        #expect(splitView.requestedPositions.map(\.position) == [240, splitViewLength - 260])
    }

    @Test("A split view that never gets a size still takes the positions that do not need one")
    func positionsNeedingNoLengthSurviveASplitViewWithNoSize() async {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeRecordingSplitView(paneCount: 3, length: 0)

        splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240), .distanceFromEnd(260)]
        )
        await drainMainQueue()

        // The length-relative one is dropped rather than resolved against a zero length.
        #expect(splitView.requestedPositions.map(\.dividerIndex) == [0])
        #expect(splitView.requestedPositions.map(\.position) == [240])
    }

    @Test("Positions that need no length are applied synchronously")
    func absolutePositionsApplySynchronously() {
        let autosaveName = makeAutosaveName(#function)
        defer { removeStoredLayout(forAutosaveName: autosaveName) }

        let splitView = makeSplitView(paneCount: 2)
        splitView.box.restoreDividerPositions(
            autosaveName: autosaveName,
            initialPositions: [.distanceFromStart(240)]
        )
        splitView.layoutSubtreeIfNeeded()

        // No main-queue hop in between.
        #expect(dividerPosition(in: splitView, at: 0) == CGFloat(240))
    }
}

#endif
