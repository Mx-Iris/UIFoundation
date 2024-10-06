#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XiblessCollectionViewItem<View: NSView>: CollectionViewItem {
    open class func makeView() -> View { .init() }

    open var contentView: View {
        didSet {
            view = contentView
        }
    }

    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        self.contentView = Self.makeView()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func loadView() {
        view = contentView
    }
}

#endif
