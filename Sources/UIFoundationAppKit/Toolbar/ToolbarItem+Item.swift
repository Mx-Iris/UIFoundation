#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A standard toolbar item with a title, image, and optional click action.
    open class Item: ActionableToolbarItem {

        private lazy var _item = ItemNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        // MARK: - Title / image

        /// The title of the item.
        open var title: String {
            get { _item.title }
            set { _item.title = newValue }
        }

        /// Sets the title of the item.
        @discardableResult
        open func title(_ title: String) -> Self {
            _item.title = title
            return self
        }

        /// The image of the item.
        open var image: NSImage? {
            get { _item.image }
            set { _item.image = newValue }
        }

        /// Sets the image of the item.
        @discardableResult
        open func image(_ image: NSImage?) -> Self {
            _item.image = image
            return self
        }

        /// Sets the image to the SF Symbol with the specified name.
        @available(macOS 11.0, *)
        @discardableResult
        open func symbolImage(_ symbolName: String) -> Self {
            _item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            return self
        }

        /// Sets the Boolean value indicating whether the item has a bordered style.
        @available(*, deprecated, renamed: "isBordered(_:)")
        @discardableResult
        open func bordered(_ isBordered: Bool) -> Self {
            self.isBordered = isBordered
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks the item.
        public var actionBlock: ((NSToolbar.Item) -> Void)? {
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

        private var storedActionBlock: ((NSToolbar.Item) -> Void)?

        /// Sets the handler called when the user clicks the item.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.Item) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        open override func clearActionBlockStorage() {
            storedActionBlock = nil
        }

        // MARK: - Init

        public override init(_ identifier: NSToolbarItem.Identifier? = nil) {
            super.init(identifier)
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, title: String, action: ((NSToolbar.Item) -> Void)? = nil) {
            super.init(identifier)
            self.title = title
            self.actionBlock = action
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, title: String? = nil, image: NSImage, action: ((NSToolbar.Item) -> Void)? = nil) {
            super.init(identifier)
            self.title = title ?? ""
            self.image = image
            self.actionBlock = action
        }

        @available(macOS 11.0, *)
        public init?(_ identifier: NSToolbarItem.Identifier? = nil, title: String? = nil, symbolName: String, action: ((NSToolbar.Item) -> Void)? = nil) {
            guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
            super.init(identifier)
            self.title = title ?? ""
            self.image = image
            self.actionBlock = action
        }

        private final class ItemNSToolbarItem: NSToolbarItem {
            weak var owner: NSToolbar.Item?
            init(for owner: NSToolbar.Item) {
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
