//
//  Measured on macOS 27.0 AppKit (2775.10.103.1).
//  Reverse-engineering notes: Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md
//  Decision record: Documentations/Evolutions/0022-glass-effect-replica-view.md
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import QuartzCore
import UIFoundationAppleInternalObjC

@available(macOS 26.0, *)
extension NSGlassEffectView {
    /// Whether this build of AppKit still carries the private setters
    /// ``matchGlassConfiguration(of:)`` copies through.
    ///
    /// Checked rather than assumed so that a future AppKit that drops them costs a mismatched
    /// backdrop, not a crash.
    public static var isPrivateConfigurationSupported: Bool {
        instancesRespond(to: #selector(setter: NSGlassEffectView._variant))
            && instancesRespond(to: #selector(setter: NSGlassEffectView._subvariant))
            && instancesRespond(to: #selector(setter: NSGlassEffectView._adaptiveAppearance))
    }

    /// The `CABackdropLayer` SwiftUI builds to render this view's glass, or `nil` until it has.
    ///
    /// It is not built synchronously. Adding the view to a window, `layoutSubtreeIfNeeded()`,
    /// `displayIfNeeded()` and `CATransaction.flush()` all leave this `nil`; it exists once the
    /// run loop has turned. The search skips the content holder, so a glass view nested in this
    /// one's `contentView` is never mistaken for this one's own layer.
    public var glassBackdropLayer: CABackdropLayer? {
        let contentHolderView = contentView?.superview
        for subview in subviews where subview !== contentHolderView {
            if let backdropLayer = Self.firstBackdropLayer(under: subview.layer, depth: 0) {
                return backdropLayer
            }
        }
        return nil
    }

    /// The Core Animation backdrop group the glass samples its backdrop in.
    ///
    /// Layers in one group share a single capture of what lies behind the group, so two glass views
    /// in the same group produce the same pixels even when one sits inside the other — that is the
    /// whole trick behind ``GlassEffectReplicaView``. `nil` until ``glassBackdropLayer`` exists;
    /// setting it before then does nothing.
    public var glassBackdropGroupName: String? {
        get { glassBackdropLayer?.groupName }
        set { glassBackdropLayer?.groupName = newValue }
    }

    /// Copies everything that decides how the glass renders — the public settings and the private
    /// variant / subvariant / adaptive appearance — so that, given the same backdrop, this view
    /// renders like `other`.
    ///
    /// The private part is skipped when ``isPrivateConfigurationSupported`` is false.
    public func matchGlassConfiguration(of other: NSGlassEffectView) {
        cornerRadius = other.cornerRadius
        style = other.style
        tintColor = other.tintColor
        if #available(macOS 27.0, *) {
            effectIsInteractive = other.effectIsInteractive
        }
        guard Self.isPrivateConfigurationSupported else { return }
        _variant = other._variant
        _subvariant = other._subvariant
        _adaptiveAppearance = other._adaptiveAppearance
    }

    /// The nearest `NSGlassEffectView` above `view` in the view hierarchy — the glass whose
    /// content `view` is part of — or `nil` when there is none.
    ///
    /// The walk starts at `view.superview`, so passing a glass view returns the glass *around*
    /// it, never itself.
    public static func enclosingGlassEffectView(of view: NSView) -> NSGlassEffectView? {
        var candidate = view.superview
        while let current = candidate {
            if let glassEffectView = current as? NSGlassEffectView {
                return glassEffectView
            }
            candidate = current.superview
        }
        return nil
    }

    private static func firstBackdropLayer(under layer: CALayer?, depth: Int) -> CABackdropLayer? {
        guard let layer, depth < 32 else { return nil }
        if let backdropLayer = layer as? CABackdropLayer {
            return backdropLayer
        }
        for sublayer in layer.sublayers ?? [] {
            if let backdropLayer = firstBackdropLayer(under: sublayer, depth: depth + 1) {
                return backdropLayer
            }
        }
        return nil
    }
}

#endif
