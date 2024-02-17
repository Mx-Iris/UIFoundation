#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class CollectionView: NSCollectionView {
    open class func scrollableCollectionView() -> (scrollView: ScrollView, collectionView: CollectionView) {
        let scrollView = ScrollView()
        let collectionView = Self()
        scrollView.do {
            $0.documentView = collectionView
            $0.hasVerticalScroller = true
        }
        return (scrollView, collectionView)
    }

    open class func scrollableCollectionView<CollectionViewType: CollectionView>() -> (scrollView: ScrollView, collectionView: CollectionViewType) {
        let scrollView = ScrollView()
        let collectionView = CollectionViewType()
        scrollView.do {
            $0.documentView = collectionView
            $0.hasVerticalScroller = true
        }
        return (scrollView, collectionView)
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        setup()
    }

    open func setup() {}
}

#endif
