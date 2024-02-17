#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class CollectionViewItem: NSCollectionViewItem {
    open var imageForHighlightState: [HighlightState: NSImage] = [:]

    public override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        identifier = .init(String(describing: Self.self))
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    open override func loadView() {
        view = View()
    }

    private func commonInit() {}

    open func setHighlightImage(_ image: NSImage?, forState highlightState: HighlightState) {
        if let image {
            imageForHighlightState[highlightState] = image
        } else {
            imageForHighlightState.removeValue(forKey: highlightState)
        }
    }

    open override var highlightState: NSCollectionViewItem.HighlightState {
        didSet {
            if let image = imageForHighlightState[highlightState] {
                imageView?.image = image
            }
        }
    }
}

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
