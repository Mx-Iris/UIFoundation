#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSCollectionView {
    public enum SupplementaryElementKind: CaseIterable {
        case sectionHeader
        case sectionFooter
        case interItemGapIndicator

        public var stringValue: String {
            switch self {
            case .sectionHeader:
                NSCollectionView.elementKindSectionHeader
            case .sectionFooter:
                NSCollectionView.elementKindSectionFooter
            case .interItemGapIndicator:
                NSCollectionView.elementKindInterItemGapIndicator
            }
        }
    }

    public func registerItem(_ itemClass: (some NSCollectionViewItem).Type) {
        base.register(itemClass, forItemWithIdentifier: .init(itemClass))
    }

    public func registerView(_ viewClass: (some NSView & NSCollectionViewElement).Type, forSupplementaryViewOfKind kind: SupplementaryElementKind) {
        base.register(viewClass, forSupplementaryViewOfKind: kind.stringValue, withIdentifier: .init(viewClass))
    }
    
    public func registerViewFromNib(_ viewClass: (some NSView & NSCollectionViewElement).Type, forSupplementaryViewOfKind kind: SupplementaryElementKind) {
        base.register(NSNib(nibClass: viewClass), forSupplementaryViewOfKind: kind.stringValue, withIdentifier: .init(viewClass))
    }

    public func makeItem<CollectionViewItem: NSCollectionViewItem>(ofClass itemClass: CollectionViewItem.Type, for indexPath: IndexPath) -> CollectionViewItem {
        base.makeItem(withIdentifier: .init(itemClass), for: indexPath) as! CollectionViewItem
    }

    public func makeSupplementaryView<SupplementaryView: NSView & NSCollectionViewElement>(ofClass viewClass: SupplementaryView.Type, ofKind kind: SupplementaryElementKind, for indexPath: IndexPath) -> SupplementaryView {
        base.makeSupplementaryView(ofKind: kind.stringValue, withIdentifier: .init(viewClass), for: indexPath) as! SupplementaryView
    }
}

#endif
