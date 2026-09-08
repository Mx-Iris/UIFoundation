#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A toolbar item that hosts an arbitrary `NSView`.
    open class View: ActionableToolbarItem {

        private lazy var _item = ViewNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        /// The view hosted by the toolbar item.
        open var view: NSView? {
            get { _item.view }
            set { _item.view = newValue }
        }

        /// Sets the view hosted by the toolbar item.
        @discardableResult
        open func view(_ view: NSView?) -> Self {
            _item.view = view
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks the item.
        public var actionBlock: ((NSToolbar.View) -> Void)? {
            get { storedActionBlock }
            set {
                storedActionBlock = newValue
                installActionHandler(newValue.map { handler in
                    { [weak self] in
                        guard let self else { return }
                        handler(self)
                    }
                })
            }
        }

        private var storedActionBlock: ((NSToolbar.View) -> Void)?

        /// Sets the handler called when the user clicks the item.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.View) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        open override func clearActionBlockStorage() {
            storedActionBlock = nil
        }

        // MARK: - Init

        public init(_ identifier: NSToolbarItem.Identifier? = nil, view: NSView) {
            super.init(identifier)
            _item.view = view
        }

        private final class ViewNSToolbarItem: NSToolbarItem {
            weak var owner: NSToolbar.View?
            init(for owner: NSToolbar.View) {
                super.init(itemIdentifier: owner.identifier)
                self.owner = owner
            }
            override func validate() {
                super.validate()
                owner?.validate()
            }
        }
    }
}

#endif
