#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class CollectionView: NSCollectionView {
    open class func scrollableCollectionView() -> (scrollView: ScrollView, collectionView: CollectionView) {
        let scrollView = ScrollView()
        let collectionView = CollectionView()
        scrollView.do {
            $0.documentView = collectionView
            $0.hasVerticalScroller = true
        }
        return (scrollView, collectionView)
    }
}

#endif
