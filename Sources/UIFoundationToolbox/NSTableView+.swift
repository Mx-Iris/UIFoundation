#if canImport(AppKit)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSTableView {
    public func makeView<CellView: NSTableCellView>(withType: CellView.Type, onwer: Any?) -> CellView {
        if let reuseView = base.makeView(withIdentifier: CellView.box.typeNameIdentifier, owner: onwer) as? CellView {
            return reuseView
        } else {
            let cellView = CellView()
            cellView.identifier = CellView.box.typeNameIdentifier
            return CellView()
        }
    }
    
    public func makeViewFromNib<CellView: NSTableCellView>(withType: CellView.Type, owner: Any?) -> CellView? {
        return base.makeView(withIdentifier: CellView.box.typeNameIdentifier, owner: owner) as? CellView
    }
}

#endif
