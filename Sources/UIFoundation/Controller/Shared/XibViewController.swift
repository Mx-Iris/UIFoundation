#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

open class XibViewController: NSUIViewController {

    open class var nibBundle: Bundle { .main }

    open class var nibName: String { String(describing: Self.self) }
    
    public init() {
        super.init(nibName: String(describing: Self.nibName), bundle: Self.nibBundle)
        commonInit()
    }

    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        commonInit()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func commonInit() {}
}
