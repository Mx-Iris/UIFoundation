#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: StringProtocol {
    public var nsImage: NSImage? {
        .init(named: String(base))
    }
}


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
    
    public func image(withTintColor tintColor: NSColor) -> NSImage {
        guard base.isTemplate else {
            return base
        }

        guard let copiedImage = base.copy() as? NSImage else {
            return base
        }

        copiedImage.lockFocus()
        tintColor.set()
        let imageBounds = CGRect(x: 0, y: 0, width: copiedImage.size.width, height: copiedImage.size.height)
        imageBounds.fill(using: .sourceAtop)
        copiedImage.unlockFocus()

        copiedImage.isTemplate = false
        return copiedImage
    }
    
    public func toSize(_ targetSize: NSSize) -> NSImage {
        // 假设你已经有了一个 NSImage 实例叫做 originalImage
        let originalImage = base

        // 创建一个新的 NSImage 实例
        let scaledImage = NSImage(size: targetSize)

        scaledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        // 计算宽度和高度的缩放比例
//        let aspectRatio = originalImage.size.width / originalImage.size.height
        let widthRatio = targetSize.width / originalImage.size.width
        let heightRatio = targetSize.height / originalImage.size.height

        // 保持宽高比
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledWidth = originalImage.size.width * scaleFactor
        let scaledHeight = originalImage.size.height * scaleFactor

        // 计算绘制起点，使图像居中
        let x = (targetSize.width - scaledWidth) / 2.0
        let y = (targetSize.height - scaledHeight) / 2.0

        // 绘制图像
        let rect = NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
        originalImage.draw(in: rect, from: NSRect(origin: .zero, size: originalImage.size), operation: .copy, fraction: 1.0)

        scaledImage.unlockFocus()

        // 现在 scaledImage 包含了保持宽高比缩放后的图像
        return scaledImage
    }
}

#endif
