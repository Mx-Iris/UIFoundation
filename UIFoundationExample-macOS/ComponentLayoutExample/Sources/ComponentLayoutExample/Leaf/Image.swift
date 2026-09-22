//
//  Image.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's `Image`.
//

import AppKit
import UIFoundationComponent

/// An image, sized to fit the constraint while keeping its aspect ratio.
public struct Image: Component {
    public let image: NSImage

    /// Loads a named image from the main bundle.
    public init(_ imageName: String) {
        #if DEBUG
        if let image = NSImage(named: imageName) {
            self.init(image)
        } else {
            assertionFailure("Image named \(imageName) not found.")
            self.init(NSImage())
        }
        #else
        self.init(NSImage(named: imageName) ?? NSImage())
        #endif
    }

    /// Loads an SF Symbol.
    public init(systemName: String, accessibilityDescription: String? = nil) {
        #if DEBUG
        if let image = NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityDescription) {
            self.init(image)
        } else {
            assertionFailure("System image named \(systemName) not found.")
            self.init(NSImage())
        }
        #else
        self.init(NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityDescription) ?? NSImage())
        #endif
    }

    /// Loads an SF Symbol at a given size and weight.
    ///
    /// AppKit applies a `SymbolConfiguration` by deriving a new image from the
    /// original (`withSymbolConfiguration(_:)`), where UIKit takes it at load
    /// time -- hence the second step here.
    public init(
        systemName: String,
        withConfiguration configuration: NSImage.SymbolConfiguration?,
        accessibilityDescription: String? = nil
    ) {
        let symbol = NSImage(systemSymbolName: systemName, accessibilityDescription: accessibilityDescription)
        let configured = configuration.flatMap { symbol?.withSymbolConfiguration($0) } ?? symbol
        #if DEBUG
        if configured == nil {
            assertionFailure("System image named \(systemName) not found.")
        }
        #endif
        self.init(configured ?? NSImage())
    }

    public init(_ image: NSImage) {
        self.image = image
    }

    public func layout(_ constraint: Constraint) -> ImageRenderNode {
        ImageRenderNode(image: image, size: image.size.boundWithAspectRatio(to: constraint))
    }
}

/// The render node backing an ``Image``.
public struct ImageRenderNode: RenderNode {
    public let image: NSImage
    public let size: CGSize

    public func makeView() -> NSImageView {
        let view = NSImageView()
        // `UIImageView` defaults to filling its frame; `NSImageView` defaults to
        // `.scaleProportionallyDown`, which refuses to scale an image *up*. The
        // layout system has already picked the frame, so the view should honour
        // it in both directions.
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }

    public func updateView(_ view: NSImageView) {
        view.image = image
    }
}
