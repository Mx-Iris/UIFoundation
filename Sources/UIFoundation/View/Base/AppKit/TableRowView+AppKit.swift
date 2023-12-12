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
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

#endif
