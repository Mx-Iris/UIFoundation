//
//  Helpers.swift
//  UIFoundation
//
//  Internal static helpers used by `QuickActionBar`. Replaces
//  `DSFAppearanceManager.UsingEffectiveAppearance(ofWindow:)` and the
//  `NSImage` extensions from upstream DSFQuickActionBar.
//

#if QuickActionBar

import AppKit
import Foundation

extension QuickActionBar {
    /// Run `body` with the effective appearance of `window` as the current
    /// drawing appearance. Falls back to running `body` unchanged if no
    /// window is provided.
    internal static func usingEffectiveAppearance(of window: NSWindow?, _ body: () -> Void) {
        guard let window = window else {
            body()
            return
        }
        if #available(macOS 11.0, *) {
            window.effectiveAppearance.performAsCurrentDrawingAppearance(body)
        } else {
            let previous = NSAppearance.current
            NSAppearance.current = window.effectiveAppearance
            body()
            NSAppearance.current = previous
        }
    }

    /// Create an image by drawing into a fresh ARGB32 bitmap representation.
    internal static func createARGB32Image(width: Int, height: Int, drawBlock: () throws -> Void) rethrows -> NSImage {
        let offscreenRep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: NSColorSpaceName.calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!

        let graphicsContext = NSGraphicsContext(bitmapImageRep: offscreenRep)

        do {
            NSGraphicsContext.saveGraphicsState()
            defer { NSGraphicsContext.restoreGraphicsState() }
            NSGraphicsContext.current = graphicsContext
            try drawBlock()
        }

        let image = NSImage(size: NSSize(width: width, height: height))
        image.addRepresentation(offscreenRep)
        return image
    }

    /// Scale `image` proportionally to fit inside a square of side `dimension`,
    /// centering it within the target.
    internal static func scaleImageProportionally(_ image: NSImage, to dimension: Double) -> NSImage? {
        scaleImageProportionally(image, to: NSSize(width: dimension, height: dimension))
    }

    /// Scale `image` proportionally to fit inside `targetSize`, centering it within the target.
    internal static func scaleImageProportionally(_ image: NSImage, to targetSize: NSSize) -> NSImage? {
        guard let tiff = image.tiffRepresentation, let representationFromOriginal = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        let originalSize = NSSize(width: representationFromOriginal.pixelsWide, height: representationFromOriginal.pixelsHigh)

        let widthScale: CGFloat = targetSize.width / originalSize.width
        let heightScale: CGFloat = targetSize.height / originalSize.height
        let scale = min(widthScale, heightScale)

        let scaledImageSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        guard let representation = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .calibratedRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return nil
        }

        representation.size = targetSize

        let xOffset = (targetSize.width - scaledImageSize.width) / 2.0
        let yOffset = (targetSize.height - scaledImageSize.height) / 2.0

        do {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
            image.draw(
                in: NSRect(
                    x: xOffset,
                    y: yOffset,
                    width: scaledImageSize.width,
                    height: scaledImageSize.height
                ),
                from: .zero,
                operation: .copy,
                fraction: 1.0
            )
            NSGraphicsContext.restoreGraphicsState()
        }

        let newImage = NSImage(size: targetSize)
        newImage.addRepresentation(representation)
        return newImage
    }
}

#endif
