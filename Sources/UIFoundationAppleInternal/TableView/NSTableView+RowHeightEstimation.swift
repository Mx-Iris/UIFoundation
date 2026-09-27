//
//  Measured on macOS 15.5 (24F74), 26.6.2 (25G83) and 27.0 (26A428) AppKit.
//  Reverse-engineering notes: Researchs/AppKit-NSTableView-RowHeightEstimation-Internals.md
//  Decision record: Documentations/Evolutions/0026-table-view-row-height-estimation.md
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
import UIFoundationAppleInternalObjC

extension FrameworkToolbox where Base: NSTableView {
    /// Whether the table places the rows it has not measured yet at an estimated height, or `nil`
    /// where this build of AppKit lacks the private switch. Assigning there does nothing.
    ///
    /// AppKit estimates only when rows can differ in height, and in the source list style group
    /// rows alone make them differ: every group row after the first gets spacing above it. The
    /// estimate is corrected as rows get measured, but a row view already placed at the old
    /// estimate is not always moved. After a reload, or a disclosure, far down such a table, part
    /// of the visible rows can stay where the estimate put them, and the rows the next scroll
    /// brings in are drawn over them. With estimation off, AppKit computes the position of every
    /// row exactly.
    ///
    /// ```swift
    /// outlineView.delegate = self
    /// outlineView.box.estimatesRowHeights = false   // after the delegate — see below
    /// ```
    ///
    /// **Setting the delegate turns it back on.** `-[NSTableView setDelegate:]` and
    /// `-[NSOutlineView setDelegate:]` both ask for estimation, so turn it off after the
    /// delegate is set, and again after every change of delegate — including the ones a delegate
    /// proxy makes on its own.
    ///
    /// **Switching it does not move the rows on screen.** AppKit discards its row geometry, but it
    /// neither reloads the table nor re-places the row views it has, so rows placed from an
    /// estimate stay where the estimate put them. Switch before the table shows rows — in the same
    /// call that sets the delegate — or call `reloadData()` after switching.
    public var estimatesRowHeights: Bool? {
        get {
            guard Base.carriesRowHeightEstimationSwitch else { return nil }
            return base._estimatesRowHeights
        }
        nonmutating set {
            guard Base.carriesRowHeightEstimationSwitch, let newValue else { return }
            base._estimatesRowHeights = newValue
        }
    }
}

extension NSTableView {
    /// Whether this build of AppKit carries `-_estimatesRowHeights` and `-_setEstimatesRowHeights:`.
    ///
    /// Checked rather than assumed so that a future AppKit that drops the pair costs the switch,
    /// not a crash.
    fileprivate static var carriesRowHeightEstimationSwitch: Bool {
        instancesRespond(to: #selector(getter: NSTableView._estimatesRowHeights))
            && instancesRespond(to: #selector(setter: NSTableView._estimatesRowHeights))
    }
}

#endif
