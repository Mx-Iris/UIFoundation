#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@IBDesignable
open class SupplementaryView: LayerBackedView, NSCollectionViewElement {}

#endif
