#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSOutlineView {
    public var itemAtClickedRow: Any? {
        base.item(atRow: base.clickedRow)
    }

    public var itemAtSelectedRow: Any? {
        base.item(atRow: base.selectedRow)
    }

    public func clickedRowItemConform<T>(of type: T.Type) -> Bool {
        guard let clickedRowItem = itemAtClickedRow else { return false }
        return Swift.type(of: clickedRowItem) == type
    }
}

#endif
