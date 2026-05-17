#if FilterUI && os(macOS)

import AppKit

@objcMembers open class FilterTokenValue: NSObject, NSCopying, NSPasteboardReading, NSPasteboardWriting {
    public let objectValue: Any?
    public var comparisonType: FilterTokenComparisonType?

    public init(objectValue: Any?, comparisonType: FilterTokenComparisonType?) {
        self.objectValue = objectValue
        self.comparisonType = comparisonType
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        self
    }

    public static func readableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.filterTokenValue]
    }

    public static func readingOptions(forType type: NSPasteboard.PasteboardType, pasteboard: NSPasteboard) -> NSPasteboard.ReadingOptions {
        .asPropertyList
    }

    public required convenience init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        guard let propertyList = propertyList as? [String: Any] else { return nil }
        let comparisonType = FilterTokenComparisonType(rawValue: propertyList["comparisonType"] as? Int ?? -1)
        self.init(objectValue: propertyList["stringValue"], comparisonType: comparisonType)
    }

    public func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
        ["stringValue": objectValue, "comparisonType": comparisonType?.rawValue]
    }

    public func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
        [.filterTokenValue]
    }
}

@objc public enum FilterTokenComparisonType: Int, CaseIterable {
    case contains
    case doesNotContain
    case beginsWith
    case endsWith

    public var displayName: String {
        switch self {
        case .contains: return NSLocalizedString("Contains", bundle: .module, comment: "")
        case .doesNotContain: return NSLocalizedString("Does Not Contain", bundle: .module, comment: "")
        case .beginsWith: return NSLocalizedString("Begins With", bundle: .module, comment: "")
        case .endsWith: return NSLocalizedString("Ends With", bundle: .module, comment: "")
        }
    }
}

extension NSPasteboard.PasteboardType {
    public static let filterTokenValue = Self("local.filter-ui.FilterTokenValue")
}

#endif
