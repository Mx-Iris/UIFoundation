//
//  Read off macOS 26.6's AppKit and measured on macOS 27.2.
//  Reverse-engineering notes: Researchs/AppKit-NSToolbar-CenteredItemWidthRatio-Internals.md
//  Decision record: Documentations/Evolutions/draft-toolbar-centered-item-width-ratio.md
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
import UIFoundationAppleInternalObjC

extension FrameworkToolbox where Base: NSToolbar {
    /// The width the toolbar gives its centered item — the one `centeredItemIdentifiers` names — as a fraction of
    /// the toolbar's own width, or `nil` where AppKit lacks the private property. Assigning there does nothing.
    ///
    /// The toolbar lays the item out `ceil(ratio × toolbar width)` points wide, never wider than its maximum width
    /// or than the room its leading and trailing items leave, and keeps it centred on the toolbar's visual centre.
    /// A ratio of 0 or less means no preference — a toolbar starts at −1 — and the item then takes its maximum
    /// width. So does a ratio whose width would fall below the item's minimum width: the toolbar drops it rather
    /// than raising it to the minimum (measured on macOS 27.2). Xcode 26 gives its Activity View 0.4.
    ///
    /// The item's minimum and maximum width come from its view's constraints, measured the way the toolbar
    /// measures every item, so pin both: a view with no maximum stretches over all the room there is.
    ///
    /// Assigning it does not lay the toolbar out again; the next layout of the toolbar — the window resizing, an
    /// item changing — applies it. Set it before the toolbar goes into a window to have it from the first layout.
    public var preferredCenteredItemWidthRatio: CGFloat? {
        get {
            guard Base.carriesPreferredPrincipalItemWidthRatio else { return nil }
            return base.preferredPrincipalItemWidthRatio
        }
        nonmutating set {
            guard Base.carriesPreferredPrincipalItemWidthRatio, let newValue else { return }
            base.preferredPrincipalItemWidthRatio = newValue
        }
    }
}

extension NSToolbar {
    // Checked rather than assumed, so that an AppKit that drops the private property costs the preference, not a
    // crash.
    fileprivate static var carriesPreferredPrincipalItemWidthRatio: Bool {
        instancesRespond(to: #selector(getter: NSToolbar.preferredPrincipalItemWidthRatio))
            && instancesRespond(to: #selector(setter: NSToolbar.preferredPrincipalItemWidthRatio))
    }
}

#endif
