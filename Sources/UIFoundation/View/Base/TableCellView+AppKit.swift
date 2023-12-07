#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TableCellView: NSTableCellView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = .init(String(describing: Self.self))
        makeUI()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        makeUI()
    }

    open func makeUI() {}

    open func firstLayout() {}

    private lazy var _firstLayout: Void = {
        firstLayout()
    }()

    open override func layout() {
        super.layout()
        _ = _firstLayout
    }
}

#endif
