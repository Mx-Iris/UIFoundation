#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class ScrollViewController<View: NSView>: NSViewController {
    public let contentView: View

    public let scrollView = NSScrollView()
    
    public init(viewGenerator: @autoclosure () -> View) {
        self.contentView = viewGenerator()
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    public convenience init() {
        self.init(viewGenerator: View())
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func commonInit() {}

    
    open override func loadView() {
        view = scrollView
        scrollView.documentView = contentView
    }
}

#endif
