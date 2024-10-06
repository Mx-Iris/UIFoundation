#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

open class XiblessViewController<View: NSUIView>: NSUIViewController {
    public lazy var contentView: View = contentViewGenerator() {
        didSet {
            view = contentView
        }
    }

    private let contentViewGenerator: () -> View
    
    public init(viewGenerator: @autoclosure @escaping () -> View = View()) {
        self.contentViewGenerator = viewGenerator
        super.init(nibName: nil, bundle: nil)
        commonInit()
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
