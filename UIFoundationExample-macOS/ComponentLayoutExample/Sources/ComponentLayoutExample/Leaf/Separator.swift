//
//  Separator.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's `Separator`.
//

import AppKit
import UIFoundationComponent

/// A hairline divider that picks its own orientation from the constraint it is
/// given: horizontal inside a `VStack`, vertical inside an `HStack`.
public struct Separator: ComponentBuilder {
    /// The colour used when none is given.
    public static var defaultSeparatorColor: NSColor = .separatorColor

    public let color: NSColor

    public init(color: NSColor = Separator.defaultSeparatorColor) {
        self.color = color
    }

    public func build() -> some Component {
        ViewComponent<NSView>()
            .update { [color] view in
                // Written straight onto the layer. `NSView` has no
                // `backgroundColor` of its own, and AppKitPlus 0.4.4 does not
                // add one either -- its `NSView (Appearance)` category, which
                // did, is absent from the shipped framework (it collides with
                // `LayerBackgroundProviding`; see AGENTS.md). `wantsLayer` is
                // set here rather than assumed, so a separator works outside a
                // layer-backed ancestor too.
                view.wantsLayer = true
                view.layer?.backgroundColor = color.cgColor
            }
            .constraint { constraint in
                if constraint.minSize.height <= 0, constraint.maxSize.width != .infinity {
                    let size = CGSize(width: constraint.maxSize.width, height: 1 / screenScale)
                    return Constraint(minSize: size, maxSize: size)
                } else if constraint.minSize.width <= 0, constraint.maxSize.height != .infinity {
                    let size = CGSize(width: 1 / screenScale, height: constraint.maxSize.height)
                    return Constraint(minSize: size, maxSize: size)
                }
                return constraint
            }
    }

    private var screenScale: CGFloat {
        NSScreen.main?.backingScaleFactor ?? 2
    }
}
