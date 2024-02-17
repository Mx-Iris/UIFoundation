#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public protocol ViewReloading: NSView {
    func reloadData()
}

extension NSTableView: ViewReloading {}

extension NSCollectionView: ViewReloading {}

extension NSViewInvalidating where Self == NSView.Invalidations.ReloadData {
    public static var reloadData: Self { Self() }
}

extension NSView.Invalidations {
    public struct ReloadData: NSViewInvalidating {
        public func invalidate(view: NSView) {
            guard let view = view as? ViewReloading else { return }
            view.reloadData()
        }
    }
}

#endif
