#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSTableView {
    @available(*, deprecated, renamed: "makeView(ofClass:owner:)")
    public func makeView<CellView: NSTableCellView>(withType type: CellView.Type, owner: Any?) -> CellView {
        makeView(ofClass: type, owner: owner)
    }

    @available(*, deprecated, renamed: "makeViewFromNib(ofClass:owner:)")
    public func makeViewFromNib<CellView: NSTableCellView>(withType type: CellView.Type, owner: Any?) -> CellView? {
        makeViewFromNib(ofClass: type, owner: owner)
    }

    public func makeView<CellView: NSTableCellView>(ofClass cls: CellView.Type, owner: Any?) -> CellView {
        if let reuseView = base.makeView(withIdentifier: .init(cls), owner: owner) as? CellView {
            return reuseView
        } else {
            let cellView = CellView()
            cellView.identifier = .init(cls)
            return CellView()
        }
    }

    public func makeViewFromNib<CellView: NSTableCellView>(ofClass cls: CellView.Type, owner: Any?) -> CellView? {
        return base.makeView(withIdentifier: .init(cls), owner: owner) as? CellView
    }

    public var hasValidClickedRow: Bool {
        isValidRow(base.clickedRow)
    }

    public var hasValidClickedColumn: Bool {
        isValidRow(base.clickedColumn)
    }

    public var hasValidSelectedRow: Bool {
        isValidRow(base.selectedRow)
    }

    public var hasValidSelectedColumn: Bool {
        isValidColumn(base.selectedColumn)
    }

    public func isValidRow(_ row: Int) -> Bool {
        row >= 0 && row < base.numberOfRows
    }

    public func isValidColumn(_ column: Int) -> Bool {
        column >= 0 && column < base.numberOfColumns
    }
}

#endif
