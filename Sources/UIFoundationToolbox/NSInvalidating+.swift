#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationUtilities

public protocol ViewReloading: NSView {
    func reloadData()
}

extension NSTableView: ViewReloading {}

extension NSCollectionView: ViewReloading {}

extension Invalidations {
    public struct ReloadData: InvalidatingViewProtocol {
        public static let reloadData: Self = .init()

        public func invalidate(view: NSView) {
            guard let view = view as? ViewReloading else { return }
            view.reloadData()
        }
    }
}

extension InvalidatingViewProtocol where Self == Invalidations.ReloadData {
    public static var reloadData: Self { .reloadData }
}

@available(macOS 12, *)
extension NSView.Invalidations {
    public struct ReloadData: NSViewInvalidating {
        public static let reloadData: Self = .init()

        public func invalidate(view: NSView) {
            guard let view = view as? ViewReloading else { return }
            view.reloadData()
        }
    }
}

@available(macOS 12, *)
extension NSViewInvalidating where Self == NSView.Invalidations.ReloadData {
    public static var reloadData: Self { .reloadData }
}

#endif
