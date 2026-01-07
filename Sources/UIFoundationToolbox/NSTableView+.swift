#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSTableView {
    public func makeView<View: NSView>(ofClass cls: View.Type, owner: Any? = nil, viewBuilder: (() -> View) = { .init() }) -> View {
        if let reuseView = base.makeView(withIdentifier: .init(cls), owner: owner) as? View {
            return reuseView
        } else {
            let view = viewBuilder()
            view.identifier = .init(cls)
            return view
        }
    }

    public func makeViewFromNib<View: NSView>(ofClass cls: View.Type, owner: Any? = nil) -> View? {
        return base.makeView(withIdentifier: .init(cls), owner: owner) as? View
    }

    public var hasValidClickedRow: Bool {
        isValidRow(base.clickedRow)
    }

    public var hasValidClickedColumn: Bool {
        isValidColumn(base.clickedColumn)
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
