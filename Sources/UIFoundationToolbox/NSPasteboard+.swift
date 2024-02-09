//
//  NSPasteboard+.swift
//
//
//  Created by Florian Zand on 08.06.23.
//

#if os(macOS)
import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSPasteboard {
    /// The string of the pasteboard or `nil` if no string is available.
    public var string: String? {
        get { base.pasteboardItems?.compactMap { $0.string(forType: .string) }.first }
        set {
            if let newValue {
                base.clearContents()
                base.setString(newValue, forType: .string)
            }
        }
    }

    /// The strings of the pasteboard or `nil` if no strings are available.
    ///
    /// Setting this property replaces all current items in the pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var strings: [String]? {
        get { base.pasteboardItems?.compactMap { $0.string(forType: .string) } }
        set { write(newValue ?? []) }
    }

    /// The images of the pasteboard or `nil` if no images are available.
    ///
    /// Setting this property replaces all current items in the pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var images: [NSImage]? {
        get { read(for: NSImage.self) }
        set { write(newValue ?? []) }
    }

    /// The file urls of the pasteboard or `nil` if no file urls are available.
    ///
    /// Setting this property replaces all current items in the pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var fileURLs: [URL]? {
        get { read(for: NSURL.self)?.compactMap { $0 as URL }.filter { $0.absoluteString.contains("file://") } }
        set { write(newValue ?? []) }
    }

    /// The urls of the pasteboard or `nil` if no urls are available.
    ///
    /// Setting this property replaces all current items in the pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var urls: [URL]? {
        get { read(for: NSURL.self)?.compactMap { $0 as URL }.filter { $0.absoluteString.contains("file://") == false } }
        set { write(newValue ?? []) }
    }

    /// The colors of the pasteboard or `nil` if no colors are available.
    ///
    /// Setting this property replaces all current items in the pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var colors: [NSColor]? {
        get { read(for: NSColor.self) }
        set { write(newValue ?? []) }
    }

    /// The sounds of the pasteboard or `nil` if no sounds are available.
    ///
    /// Setting this property replaces all current items in the pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var sounds: [NSSound]? {
        get { read(for: NSSound.self) }
        set { write(newValue ?? []) }
    }

    func write(_ values: [some NSPasteboardWriting]) {
        guard values.isEmpty == false else { return }
        base.clearContents()
        base.writeObjects(values)
    }

    /// Reads from the receiver objects that match the specified type.
    func read<V: NSPasteboardReading>(for _: V.Type, options: [NSPasteboard.ReadingOptionKey: Any]? = nil) -> [V]? {
        if let objects = base.readObjects(forClasses: [V.self], options: options) as? [V], objects.isEmpty == false {
            return objects
        }
        return nil
    }
}




extension FrameworkToolbox where Base: NSDraggingInfo {
    /// The string of the dragging info or `nil` if no string is available.
    public var string: String? {
        get { base.draggingPasteboard.box.string }
        set { base.draggingPasteboard.box.string = newValue }
    }

    /// The strings of the dragging info or `nil` if no strings are available.
    ///
    /// Setting this property replaces all current items in the dragging pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var strings: [String]? {
        get { base.draggingPasteboard.strings }
        set { base.draggingPasteboard.strings = newValue }
    }

    /// The file urls of the dragging info or `nil` if no file urls are available.
    ///
    /// Setting this property replaces all current items in the dragging pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var fileURLs: [URL]? {
        get { base.draggingPasteboard.fileURLs }
        set { base.draggingPasteboard.fileURLs = newValue }
    }

    /// The urls of the dragging info or `nil` if no urls are available.
    ///
    /// Setting this property replaces all current items in the dragging pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var urls: [URL]? {
        get { base.draggingPasteboard.urls }
        set { base.draggingPasteboard.urls = newValue }
    }

    /// The images of the dragging info or `nil` if no images are available.
    ///
    /// Setting this property replaces all current items in the dragging pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var images: [NSImage]? {
        get { base.draggingPasteboard.images }
        set { base.draggingPasteboard.images = newValue }
    }

    /// The colors of the dragging info or `nil` if no colors are available.
    ///
    /// Setting this property replaces all current items in the dragging pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var colors: [NSColor]? {
        get { base.draggingPasteboard.colors }
        set { base.draggingPasteboard.colors = newValue }
    }

    /// The sounds of the dragging info or `nil` if no sounds are available.
    ///
    /// Setting this property replaces all current items in the dragging pasteboard with the new items. The returned array may have fewer objects than the number of pasteboard items; this happens if a pasteboard item does not have a value of the indicated type.
    public var sounds: [NSSound]? {
        get { base.draggingPasteboard.sounds }
        set { base.draggingPasteboard.sounds = newValue }
    }
}

#endif
