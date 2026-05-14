#if IDEIcons

// Ported from https://github.com/freysie/ide-icons (MIT License, Copyright © 2022-2023 Freya Alminde)
// AppKit/UIKit port with all SwiftUI dependencies removed.

import Foundation
import CoreGraphics
import UIFoundationTypealias

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
private let deviceScale: CGFloat = 1.0
#elseif os(visionOS)
private let deviceScale: CGFloat = 2.0
#elseif canImport(UIKit)
@MainActor private var deviceScale: CGFloat { UIScreen.main.scale }
#endif

@available(macOS 11.0, iOS 13.0, tvOS 13.0, *)
extension NSUIImage {
    /// Returns an image object depicting an IDE icon.
    public convenience init(_ icon: IDEIcon) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.init(size: icon.unscaledBounds.size, flipped: false) { bounds in
            var icon = icon
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let isDark = NSAppearance.currentDrawing().bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            icon.colorScheme = isDark ? .dark : .light
            icon.drawBackground(context: context, bounds: bounds)
            icon.drawInterior(context: context, bounds: bounds)
            return true
        }
        #else
        guard let cgImage = icon.cgImage else { self.init(); return }
        self.init(cgImage: cgImage, scale: deviceScale, orientation: .up)
        #endif
    }
}

#if canImport(UIKit)
@available(iOS 13.0, tvOS 13.0, *)
private var imageCache = [IDEIcon: NSUIImage]()
#endif

@available(macOS 11.0, iOS 13.0, tvOS 13.0, *)
extension IDEIcon {
    var _image: NSUIImage {
        #if canImport(UIKit)
        if let cachedImage = imageCache[self] { return cachedImage }
        #endif
        let image = NSUIImage(self)
        #if canImport(UIKit)
        imageCache[self] = image
        #endif
        return image
    }
}

/// Predefined IDE icon sizes.
public enum IDEIconSize {
    /// 16 pt.
    public static let regular: CGFloat = 16.0
    /// 32 pt.
    public static let large: CGFloat = 32.0
}

@available(macOS 11.0, iOS 13.0, tvOS 13.0, *)
extension IDEIcon {
    // The resulting icon image.
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var image: NSImage { _image }
    public var templateImage: NSImage {
        let image = _image
        image.isTemplate = true
        return image
    }
    #else
    public var image: UIImage { _image }
    #endif

    public var fontSize: CGFloat { (size / 1.5).rounded() * deviceScale }
    public var outerRadius: CGFloat { min(5, (size / 4.5).rounded(.down)) }
    public var outlineWidth: CGFloat { 1 * deviceScale }
    public var borderWidth: CGFloat { 1 * deviceScale }
    public var unscaledBounds: CGRect { CGRect(x: 0, y: 0, width: size, height: size) }

    /// The resulting CoreGraphics image object.
    public var cgImage: CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(size * deviceScale),
            height: Int(size * deviceScale),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.genericRGBLinear)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        let bounds = CGRect(x: 0, y: 0, width: size * deviceScale, height: size * deviceScale)

        drawBackground(context: context, bounds: bounds)

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        defer { NSGraphicsContext.restoreGraphicsState() }
        #else
        UIGraphicsPushContext(context)
        defer { UIGraphicsPopContext() }

        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1, y: -1)
        #endif

        drawInterior(context: context, bounds: bounds)

        return context.makeImage()
    }

    public func drawBackground(context: CGContext, bounds: CGRect) {
        let deviceBounds = context.convertToDeviceSpace(bounds)
        let scale = deviceBounds.size.height / bounds.size.height

        let outlineRadius = outerRadius - (borderWidth + outlineWidth)
        let borderRadius = outerRadius - borderWidth

        switch style {
        case .default:
            context.beginPath()
            context.addPath(roundedRect: bounds, cornerRadius: outerRadius)
            context.closePath()
            context.setFillColor(color.outlineColor[colorScheme].cgColor)
            context.fillPath()

            context.beginPath()
            context.addPath(roundedRect: bounds.insetBy(borderWidth), cornerRadius: borderRadius)
            context.closePath()
            context.setFillColor(color.borderColor[colorScheme].cgColor)
            context.fillPath()

            context.beginPath()
            context.addPath(roundedRect: bounds.insetBy(borderWidth + outlineWidth), cornerRadius: outlineRadius)
            context.closePath()
            context.setFillColor(color.backgroundColor[colorScheme].cgColor)
            context.fillPath()

        case .outline:
            let lineWidth = scale >= 2 ? 1 / scale : 1
            context.setLineWidth(lineWidth)
            context.beginPath()
            context.addPath(roundedRect: bounds.insetBy(borderWidth + lineWidth / 2), cornerRadius: borderRadius)
            context.closePath()
            context.setStrokeColor(color.borderColor[colorScheme].cgColor)
            context.strokePath()

        case .simple:
            context.beginPath()
            context.addPath(roundedRect: bounds.insetBy(borderWidth), cornerRadius: borderRadius * 1.5)
            context.closePath()
            context.setFillColor(color.simpleColor.cgColor)
            context.fillPath()

        case .simpleHighlighted:
            context.beginPath()
            context.addPath(roundedRect: bounds.insetBy(borderWidth), cornerRadius: borderRadius * 1.5)
            context.closePath()
            context.setFillColor(NSUIColor.white.cgColor)
            context.fillPath()
        }
    }

    public func drawInterior(context: CGContext, bounds: CGRect) {
        if style == .default, color != .monochrome {
            context.setShadow(offset: .zero, blur: 2, color: CGColor(gray: 0, alpha: colorScheme == .dark ? 1 : 0.5))
        }

        let condensed: Bool
        let font: NSUIFont
        if ![.simple, .simpleHighlighted].contains(style),
           case .text(let s) = content,
           ["Ex", "Pr"].contains(s),
           let sfProFont = NSUIFont(name: "SFPro-CondensedMedium", size: fontSize + fontSizeAdjustment) {
            font = sfProFont
            condensed = true
        } else {
            font = NSUIFont.systemFont(ofSize: fontSize + fontSizeAdjustment, weight: fontWeight)
            condensed = false
        }

        var textColor = NSUIColor.white.cgColor
        if style == .outline || color == .monochrome {
            textColor = color.borderColor[colorScheme].cgColor
        }

        if style == .simpleHighlighted {
            context.setBlendMode(.clear)
            textColor = NSUIColor.black.cgColor
        }

        #if canImport(UIKit)
        var yOffsetAdjustment = yOffsetAdjustment * -1
        #else
        var yOffsetAdjustment = yOffsetAdjustment
        #endif

        let symbolFrame = bounds.insetBy(borderWidth + outlineWidth)

        switch content {
        case .text(let string):
            if size >= IDEIconSize.large { yOffsetAdjustment -= 1 }

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center

            let resolvedTextColor: NSUIColor = {
                #if canImport(AppKit) && !targetEnvironment(macCatalyst)
                return NSColor(cgColor: textColor) ?? .clear
                #else
                return UIColor(cgColor: textColor)
                #endif
            }()

            let attributedString = NSAttributedString(string: string, attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle,
                .foregroundColor: resolvedTextColor,
            ])

            var textFrame = attributedString.size().centered(in: symbolFrame).integral.offsetBy(dx: 0, dy: yOffsetAdjustment)

            if condensed, size < IDEIconSize.large {
                textFrame = textFrame.offsetBy(dx: 0, dy: -1)
            }

            attributedString.draw(in: textFrame)

        case .systemImage(let systemName):
            let pointSize = fontSize + fontSizeAdjustment

            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            let resolvedColor = NSColor(cgColor: textColor) ?? .clear
            var configuration = NSImage.SymbolConfiguration(pointSize: pointSize, weight: style.symbolFontWeight, scale: .small)
            if #available(macOS 12.0, *) {
                configuration = configuration.applying(NSImage.SymbolConfiguration(paletteColors: [resolvedColor]))
            }
            guard let symbolImage = NSImage(systemSymbolName: systemName, accessibilityDescription: nil)?
                .withSymbolConfiguration(configuration) else { return }

            symbolImage.draw(
                in: symbolImage.size.centered(in: symbolFrame.insetBy(1)).offsetBy(dx: 0, dy: yOffsetAdjustment).integral,
                from: .zero,
                operation: style == .simpleHighlighted ? .destinationOut : .sourceOver,
                fraction: 1
            )
            #else
            let resolvedColor = UIColor(cgColor: textColor)
            var configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: style.symbolWeight, scale: .small)
            if #available(iOS 15.0, tvOS 15.0, *) {
                configuration = configuration.applying(UIImage.SymbolConfiguration(paletteColors: [resolvedColor]))
            }
            guard let symbolImage = UIImage(systemName: systemName)?
                .applyingSymbolConfiguration(configuration) else { return }

            symbolImage.draw(
                in: symbolImage.size.centered(in: symbolFrame.insetBy(1)).offsetBy(dx: 0, dy: yOffsetAdjustment).integral,
                blendMode: style == .simpleHighlighted ? .destinationOut : .normal,
                alpha: 1
            )
            #endif

        case .image:
            break
        }
    }
}

extension CGSize {
    fileprivate func centered(in rect: CGRect) -> CGRect {
        let centeredPoint = CGPoint(x: rect.minX + (rect.width - width) / 2, y: rect.minY + (rect.height - height) / 2)
        return CGRect(origin: centeredPoint, size: self)
    }
}

extension CGRect {
    fileprivate func insetBy(_ factor: Double) -> CGRect {
        insetBy(dx: factor, dy: factor)
    }
}

extension CGContext {
    fileprivate func addPath(roundedRect rect: CGRect, cornerRadius: CGFloat) {
        addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
    }
}

#endif
