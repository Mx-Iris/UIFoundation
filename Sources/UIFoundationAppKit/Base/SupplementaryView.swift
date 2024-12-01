#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

@IBDesignable
open class SupplementaryView: View, NSCollectionViewElement {}

#endif
