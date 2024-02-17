#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

open class XiblessViewController<View: NSUIView>: NSUIViewController {
    public let contentView: View

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
        view = contentView
    }
}
