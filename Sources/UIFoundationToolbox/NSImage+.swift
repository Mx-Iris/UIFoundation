#if canImport(AppKit)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSImage {
    public var cgImage: CGImage? {
        guard let imageData = base.tiffRepresentation else { return nil }
        guard let sourceData = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(sourceData, 0, nil)
    }

    public var ciImage: CIImage? {
        guard let imageData = base.tiffRepresentation else { return nil }
        return CIImage(data: imageData)
    }

    public func fill(color: NSColor) -> NSImage {
        let imageSize = base.size
        let imageRect = CGRect(origin: .zero, size: imageSize)

        let tinted = NSImage(size: imageSize)
        tinted.lockFocus()

        base.draw(in: imageRect)

        color.set()
        imageRect.fill(using: .sourceAtop)

        tinted.unlockFocus()

        return tinted
    }

    public static func createMaskedImageWithWhiteBackground(text: String, font: NSFont, size: CGSize) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()

        // Fill with white background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Set up context for clipping (making text transparent)
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        context?.setBlendMode(.destinationOut)

        // Draw the text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]

        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: NSPoint(x: (size.width - string.size().width) * 0.5, y: (size.height - string.size().height) * 0.5))

        context?.restoreGState()

        image.unlockFocus()
        return image
    }
}

#endif
