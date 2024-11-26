#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class NoEmphasizedTableRowView: NSTableRowView {
    public override var isEmphasized: Bool {
        set {}
        get { false }
    }
}

open class TableRowView: NSTableRowView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        setup()
    }
    
    open func setup() {}
}

#endif
