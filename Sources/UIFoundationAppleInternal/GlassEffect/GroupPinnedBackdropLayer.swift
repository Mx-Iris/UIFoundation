//
//  Measured on macOS 27.0 AppKit (2775.10.103.1).
//  Reverse-engineering notes: Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md
//  Decision record: Documentations/Evolutions/0022-glass-effect-replica-view.md
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AssociatedObject
import ObjectiveC
import QuartzCore
import UIFoundationAppleInternalObjC

/// A `CABackdropLayer` whose group name cannot be taken away.
///
/// SwiftUI re-applies its own `SwiftUI:<identity>` name to a glass view's backdrop layer on some
/// of its updates — measured when the window becomes key — which would silently undo the sharing
/// ``GlassEffectReplicaView`` depends on. The replica therefore changes the class of the layer
/// SwiftUI built to this one, the way KVO changes an observed object's class, and every later
/// `groupName` write is answered with the pinned name instead.
///
/// The instance was allocated by SwiftUI as a plain `CABackdropLayer`, so this class must never
/// add stored properties; the pinned name lives in an associated object. `pinnedGroupName` only
/// looks stored — `@AssociatedObject` rewrites it into accessors, so the attribute must stay.
@available(macOS 26.0, *)
final class GroupPinnedBackdropLayer: CABackdropLayer {
    /// The name every write to `groupName` is replaced with. `nil` lets writes through again.
    @AssociatedObject(.copy(.nonatomic))
    var pinnedGroupName: String?

    override var groupName: String? {
        get { super.groupName }
        set { super.groupName = pinnedGroupName ?? newValue }
    }

    /// Makes `layer` keep `groupName` from now on, changing its class on the first call. Returns
    /// `false` only when the runtime refused the class change.
    @discardableResult
    static func pin(_ layer: CABackdropLayer, to groupName: String) -> Bool {
        if !(layer is GroupPinnedBackdropLayer) {
            guard object_setClass(layer, GroupPinnedBackdropLayer.self) != nil else { return false }
        }
        let pinnedLayer = unsafeDowncast(layer, to: GroupPinnedBackdropLayer.self)
        pinnedLayer.pinnedGroupName = groupName
        pinnedLayer.groupName = groupName
        return true
    }
}

#endif
