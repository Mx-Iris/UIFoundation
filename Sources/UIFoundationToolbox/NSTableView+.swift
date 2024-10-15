#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSTableView {

    public func makeView<View: NSView>(ofClass cls: View.Type, owner: Any?) -> View {
        if let reuseView = base.makeView(withIdentifier: .init(cls), owner: owner) as? View {
            return reuseView
        } else {
            let cellView = View()
            cellView.identifier = .init(cls)
            return cellView
        }
    }

    public func makeViewFromNib<View: NSView>(ofClass cls: View.Type, owner: Any?) -> View? {
        return base.makeView(withIdentifier: .init(cls), owner: owner) as? View
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
