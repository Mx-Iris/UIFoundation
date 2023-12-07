#if canImport(CoreGraphics)

import CoreGraphics
import FrameworkToolbox

#if canImport(AppKit)
import AppKit

extension FrameworkToolbox where Base: CGImage {
    public var nsImage: NSImage? {
        let size = CGSize(width: base.width, height: base.height)
        return NSImage(cgImage: base, size: size)
    }
}
#endif

#if canImport(UIKit)

import UIKit

extension FrameworkToolbox where Base: CGImage {
    public var uiImage: UIImage? {
        return .init(cgImage: base)
    }
}
#endif

#if canImport(CoreImage)

import CoreImage

extension FrameworkToolbox where Base: CGImage {
    public var ciImage: CIImage {
        return CIImage(cgImage: base)
    }
}

#endif

#endif
