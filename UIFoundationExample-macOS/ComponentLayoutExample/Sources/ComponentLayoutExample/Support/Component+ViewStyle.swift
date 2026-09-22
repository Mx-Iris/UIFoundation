//
//  Component+ViewStyle.swift
//  ComponentLayoutExample
//
//  The view-styling modifiers the chapters use, spelled for AppKit.
//
//  On UIKit every one of these is free: `UIView` has `backgroundColor`, `alpha`
//  and `tintColor`, so `@dynamicMemberLookup` resolves `.backgroundColor(.red)`
//  straight onto the view with nothing written by hand. `NSView` has none of
//  them -- the equivalents live on the layer, or under another name, or not at
//  all -- so each one needs a real method here.
//
//  They are declared on `Component` and go through `update(_:)`, which means
//  they write to whatever view the component already produces rather than
//  wrapping it in a new one. That matches upstream: `Text(…).backgroundColor(…)`
//  colours the label itself. A component that produces no view of its own
//  (a bare `VStack`, say) needs `.view()` first, exactly as upstream.
//
//  Two of the nine the chapters use are NOT here, on purpose:
//
//    * `contentMode` -- AppKitPlus's `NSView (Geometry)` category provides it.
//    * `clipsToBounds` -- a real `NSView` property since macOS 14.
//
//  Both resolve through `@dynamicMemberLookup` already. Declaring them again
//  here would shadow the real ones.
//

import AppKit
import UIFoundationComponent

extension Component {
    /// Fills the view's layer.
    ///
    /// `NSView` has no `backgroundColor`, and a layer-less view silently drops
    /// the colour, so this turns layer backing on rather than assuming it.
    public func backgroundColor(_ color: NSColor?) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.backgroundColor = color?.cgColor
        }
    }

    /// Rounds the view's corners.
    public func cornerRadius(_ radius: CGFloat) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.cornerRadius = radius
        }
    }

    /// Picks the corner curve -- `.continuous` for the squircle shape.
    public func cornerCurve(_ curve: CALayerCornerCurve) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.cornerCurve = curve
        }
    }

    public func borderWidth(_ width: CGFloat) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.borderWidth = width
        }
    }

    public func borderColor(_ color: NSColor?) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.borderColor = color?.cgColor
        }
    }

    public func shadowColor(_ color: NSColor?) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.shadowColor = color?.cgColor
        }
    }

    public func shadowOpacity(_ opacity: Float) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.shadowOpacity = opacity
        }
    }

    /// - Note: AppKit's `CALayer.shadowOffset` measures **upwards** on an
    ///   unflipped layer, so a positive `height` here pushes the shadow the
    ///   opposite way from UIKit. The chapters keep the upstream values, which
    ///   is why their shadows sit above rather than below.
    public func shadowOffset(_ offset: CGSize) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.shadowOffset = offset
        }
    }

    public func shadowRadius(_ radius: CGFloat) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.shadowRadius = radius
        }
    }

    /// Clips subviews to the rounded corners.
    ///
    /// `NSView.clipsToBounds` exists only from macOS 14, and this package has to
    /// compile at the example app's own floor, so this writes the layer property
    /// it wraps.
    public func masksToBounds(_ masksToBounds: Bool) -> UpdateComponent<Self> {
        update { view in
            view.wantsLayer = true
            view.layer?.masksToBounds = masksToBounds
        }
    }

    /// AppKit spells this `alphaValue`.
    public func alpha(_ alpha: CGFloat) -> UpdateComponent<Self> {
        update { view in
            view.alphaValue = alpha
        }
    }

    /// Tints template image content.
    ///
    /// `UIView.tintColor` is inherited down the view tree and applies to many
    /// kinds of control. AppKit has no such thing -- AppKitPlus shipped a
    /// `tintColor` category once and removed it, because a tint propagated down
    /// a tree wrote straight into `NSGlassEffectView`'s own glass tint. The
    /// honest counterpart is per-view content tint, which is what the chapters
    /// actually use it for (colouring SF Symbols).
    public func tintColor(_ color: NSColor?) -> UpdateComponent<Self> {
        update { view in
            switch view {
            case let imageView as NSImageView:
                imageView.contentTintColor = color
            case let button as NSButton:
                button.contentTintColor = color
            default:
                // Only the two classes that actually declare a content tint.
                // Adding a `contentTintColor` of our own to `NSControl` to
                // cover the rest would be the same illegal-override trap
                // AGENTS.md records for AppKitPlus.
                break
            }
        }
    }
}
