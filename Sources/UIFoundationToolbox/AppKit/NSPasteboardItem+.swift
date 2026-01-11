#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSPasteboardItem {
    /// The color of the pasteboard item.
    public var color: NSColor? {
        get {
            if let data = base.data(forType: .color), let color: NSColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) {
                return color
            }
            return nil
        }
        set {
            if let newValue = newValue, let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: false) {
                base.setData(data, forType: .color)
            }
        }
    }
    
    /// The string of the pasteboard item.
    public var string: String? {
        get { base.string(forType: .string) }
        set {
            if let newValue = newValue {
                base.setString(newValue, forType: .string)
            }
        }
    }
    
    /// The png image of the pasteboard item.
//    public var pngImage: NSImage? {
//        get {
//            if let data = base.data(forType: .png), let image = NSImage(data: data) {
//                return image
//            }
//            return nil
//        }
//        set {
//            if let data = newValue?.pngData() {
//                base.setData(data, forType: .png)
//            }
//        }
//    }
    
    /// The tiff image of the pasteboard item.
    public var tiffImage: NSImage? {
        get {
            if let data = base.data(forType: .tiff), let image = NSImage(data: data) {
                return image
            }
            return nil
        }
        set {
            if let data = newValue?.tiffRepresentation {
                base.setData(data, forType: .tiff)
            }
        }
    }
    
    /// The url of the pasteboard item.
    public var url: URL? {
        get {
            if let data = base.data(forType: .URL), let url = URL(dataRepresentation: data, relativeTo: nil) {
                return url
            }
            return nil
        }
        set {
            if let data = newValue?.dataRepresentation {
                base.setData(data, forType: .URL)
            }
        }
    }
    
    /// The file url of the pasteboard item.
    public var fileURL: URL? {
        get {
            if let data = base.data(forType: .fileURL), let url = URL(dataRepresentation: data, relativeTo: nil) {
                return url
            }
            return nil
        }
        set {
            if let data = newValue?.dataRepresentation {
                base.setData(data, forType: .fileURL)
            }
        }
    }
}

#endif
