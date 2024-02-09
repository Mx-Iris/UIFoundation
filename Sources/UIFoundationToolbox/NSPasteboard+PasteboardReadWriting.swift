//
//  NSPasteboard+PasteboardReadWriting.swift
//
//
//  Created by Florian Zand on 31.12.23.
//

#if os(macOS)
import AppKit
import FrameworkToolbox
import FrameworkToolboxMacro
/// A type that can be read from and written to a pasteboard (`String`, `URL`, `NSColor`, `NSImage` or `NSSound`).
public protocol PasteboardReadWriting {}

//@FrameworkToolboxExtension
extension PasteboardReadWriting {}

extension String: PasteboardReadWriting {}
extension URL: PasteboardReadWriting {}
extension NSColor: PasteboardReadWriting {}
extension NSImage: PasteboardReadWriting {}
extension NSSound: PasteboardReadWriting {}

extension FrameworkToolbox where Base: PasteboardReadWriting {
    /// Writes the object to the the general pasteboard.
    public func writeToPasteboard() {
        NSPasteboard.general.box.write([base])
    }
}

extension FrameworkToolbox where Base: Collection<any PasteboardReadWriting> {
    /// Writes the objects to the the general pasteboard.
    public func writeToPasteboard() {
        NSPasteboard.general.box.write(base)
    }
}

extension FrameworkToolbox where Base: Collection, Base.Element: PasteboardReadWriting {
    /// Writes the objects to the the general pasteboard.
    public func writeToPasteboard() {
        NSPasteboard.general.box.write(Array(base))
    }
}

extension PasteboardReadWriting {
    var nsPasteboardWriting: NSPasteboardWriting? {
        (self as? NSPasteboardWriting) ?? (self as? NSURL)
    }
}

extension FrameworkToolbox where Base: NSPasteboard {
    /// Writes the specified `PasteboardReadWriting` objects to the pasteboard.
    ///
    /// - Parameter objects: An array of `PasteboardReadWriting` objects.
    public func write(_ objects: some Collection<PasteboardReadWriting>) {
        guard objects.isEmpty != false else { return }
        base.clearContents()
        let writings = objects.compactMap(\.nsPasteboardWriting)
        base.writeObjects(writings)
    }

    /// The current `PasteboardReadWriting` objects of the pasteboard.
    public func pasteboardReadWritings() -> [PasteboardReadWriting] {
        var items: [PasteboardReadWriting] = []

        if let fileURLs {
            items.append(contentsOf: fileURLs)
        }

        if let colors {
            items.append(contentsOf: colors)
        }

        if let strings {
            items.append(contentsOf: strings)
        }

        if let sounds {
            items.append(contentsOf: sounds)
        }

        if let images {
            items.append(contentsOf: images)
        }

        return items
    }
}

extension FrameworkToolbox where Base: NSDraggingInfo {
    /// The current `PasteboardReadWriting` objects of the dragging info.
    public func pasteboardReadWritings() -> [PasteboardReadWriting] {
        base.draggingPasteboard.box.pasteboardReadWritings()
    }
}

#endif
