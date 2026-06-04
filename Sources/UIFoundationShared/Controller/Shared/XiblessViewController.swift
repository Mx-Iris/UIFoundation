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
            // Skip while the view is unloaded — `loadView()` will pick up the new value
            // through the lazy var when it eventually runs. Doing work here would
            // prematurely access `self.view`, force-trigger `loadView()`, and (in
            // subclasses that wire subviews against `self.view`) install duplicate
            // constraints when the outer caller's work resumes.
            guard isViewLoaded else { return }
            contentViewDidChange(oldValue)
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

    /// Called from `contentView`'s `didSet` only after the view is loaded. Subclasses
    /// override this to rewire their hierarchy (e.g. replace the visual-effect content
    /// view or update a scroll view's document view) and do not need to guard against
    /// the unloaded state themselves.
    open func contentViewDidChange(_ oldContentView: View) {
        view = contentView
    }
}
