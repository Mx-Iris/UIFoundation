#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class ScrollViewController<View: NSView>: NSViewController {
    public lazy var documentView: View = documentViewGenerator()

    public let scrollView = NSScrollView()
    
    private let documentViewGenerator: () -> View
    
    public init(viewGenerator: @autoclosure @escaping () -> View = View()) {
        self.documentViewGenerator = viewGenerator
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func commonInit() {}

    
    open override func loadView() {
        view = scrollView
        scrollView.documentView = documentView
    }
}

#endif
