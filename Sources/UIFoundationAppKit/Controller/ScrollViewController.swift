#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationShared

open class ScrollViewController<View: NSView>: XiblessViewController<NSScrollView> {
    public lazy var documentView: View = documentViewGenerator() {
        didSet {
            guard isViewLoaded else { return }
            documentViewDidChange(oldValue)
        }
    }

    public var scrollView: NSScrollView { contentView }

    private let documentViewGenerator: () -> View

    public init(viewGenerator: @autoclosure @escaping () -> View = View()) {
        self.documentViewGenerator = viewGenerator
        super.init(viewGenerator: NSScrollView())
    }

    open override func loadView() {
        super.loadView()
        scrollView.documentView = documentView
    }

    /// Called from `documentView`'s `didSet` only after the view is loaded.
    /// Subclasses override this to react to a replaced document view (e.g. resync
    /// data sources). The default reassigns `scrollView.documentView`.
    open func documentViewDidChange(_ oldDocumentView: View) {
        scrollView.documentView = documentView
    }
}

#endif
