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

#endif
