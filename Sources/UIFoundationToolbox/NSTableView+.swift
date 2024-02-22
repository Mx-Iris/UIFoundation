#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSTableView {
    @available(*, deprecated, renamed: "makeView(ofClass:owner:)")
    public func makeView<CellView: NSTableCellView>(withType type: CellView.Type, owner: Any?) -> CellView {
        self.makeView(ofClass: type, owner: owner)
    }
    
    @available(*, deprecated, renamed: "makeViewFromNib(ofClass:owner:)")
    public func makeViewFromNib<CellView: NSTableCellView>(withType type: CellView.Type, owner: Any?) -> CellView? {
        self.makeViewFromNib(ofClass: type, owner: owner)
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
}

#endif
