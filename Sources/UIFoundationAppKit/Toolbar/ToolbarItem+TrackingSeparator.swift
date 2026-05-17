#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

extension NSToolbar {
    /// A toolbar separator that aligns with the vertical split-view divider in the same window.
    @available(macOS 11.0, *)
    open class TrackingSeparator: ToolbarItem {

        private let _item: TrackingNSToolbarItem
        public override var item: NSToolbarItem { _item }

        /// The vertical split view that the separator aligns with.
        open var splitView: NSSplitView {
            get { _item.splitView }
            set { _item.splitView = newValue }
        }

        /// Sets the vertical split view that the separator aligns with.
        @discardableResult
        open func splitView(_ splitView: NSSplitView) -> Self {
            _item.splitView = splitView
            return self
        }

        /// The index of the split view divider to align with the tracking separator.
        open var dividerIndex: Int {
            get { _item.dividerIndex }
            set { _item.dividerIndex = newValue }
        }

        /// Sets the index of the split view divider to align with the tracking separator.
        @discardableResult
        open func dividerIndex(_ index: Int) -> Self {
            _item.dividerIndex = index
            return self
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, splitView: NSSplitView, dividerIndex: Int) {
            let resolvedIdentifier = identifier ?? NSToolbar.box.automaticIdentifier(for: "TrackingSeparator")
            self._item = TrackingNSToolbarItem(identifier: resolvedIdentifier, splitView: splitView, dividerIndex: dividerIndex)
            super.init(resolvedIdentifier)
            _item.owner = self
        }

        private final class TrackingNSToolbarItem: NSTrackingSeparatorToolbarItem {
            weak var owner: NSToolbar.TrackingSeparator?
            override func validate() {
                super.validate()
                owner?.validate()
            }
        }
    }
}

#endif
