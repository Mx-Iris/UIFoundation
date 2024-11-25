#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSOutlineView {
    public var itemAtClickedRow: Any? {
        guard hasValidClickedRow else { return nil }
        return base.item(atRow: base.clickedRow)
    }

    public var itemAtSelectedRow: Any? {
        guard hasValidSelectedRow else { return nil }
        return base.item(atRow: base.selectedRow)
    }

    public var itemsAtSelectedRows: [Any] {
        base.selectedRowIndexes.compactMap {
            guard isValidRow($0) else { return nil }
            return base.item(atRow: $0)
        }
    }

    public func clickedRowItemConform<T>(of type: T.Type) -> Bool {
        guard let clickedRowItem = itemAtClickedRow else { return false }
        return Swift.type(of: clickedRowItem) == type
    }

    public func selectedRowItemConform<T>(of type: T.Type) -> Bool {
        guard let item = itemAtSelectedRow else { return false }
        return Swift.type(of: item) == type
    }
}

#endif
