#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class CollectionView: NSCollectionView {
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

public protocol CollectionViewProtocol: NSCollectionView {}

extension NSCollectionView: CollectionViewProtocol {}

extension CollectionViewProtocol {
    public static func scrollableCollectionView() -> (scrollView: NSScrollView, collectionView: Self) {
        let scrollView = ScrollView()
        let collectionView = Self()
        scrollView.do {
            $0.documentView = collectionView
            $0.hasVerticalScroller = true
        }
        return (scrollView, collectionView)
    }
}

extension NSCollectionView {
    public class func scrollableCollectionView<ScrollViewType: NSScrollView, CollectionViewType: NSCollectionView>() -> (scrollView: ScrollViewType, collectionView: CollectionViewType) {
        let scrollView = ScrollViewType()
        let collectionView = CollectionViewType()
        scrollView.do {
            $0.documentView = collectionView
            $0.hasVerticalScroller = true
        }
        return (scrollView, collectionView)
    }
}

#endif
