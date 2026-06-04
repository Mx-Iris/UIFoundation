#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XiblessCollectionViewItem<View: NSView>: CollectionViewItem {
    /// Builds the view that backs `contentView`. NSCollectionView instantiates items
    /// through `init(nibName:bundle:)`, so an `@autoclosure` generator can't be
    /// threaded in from the call site — subclasses override this method instead.
    open class func makeView() -> View { .init() }

    public lazy var contentView: View = Self.makeView() {
        didSet {
            // Mirror `XiblessViewController`: only react after the view is loaded.
            // While unloaded, `loadView()` will pick up the new value through the
            // lazy var when it eventually runs.
            guard isViewLoaded else { return }
            contentViewDidChange(oldValue)
        }
    }

    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func loadView() {
        view = contentView
    }

    /// Called from `contentView`'s `didSet` only after the view is loaded.
    /// Subclasses override this to rewire bindings to the new view; the default
    /// swaps the item's `view` reference.
    open func contentViewDidChange(_ oldContentView: View) {
        view = contentView
    }
}

#endif
