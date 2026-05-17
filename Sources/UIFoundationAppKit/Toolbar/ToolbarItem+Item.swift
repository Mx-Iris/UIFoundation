#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A standard toolbar item with a title, image, and optional click action.
    open class Item: ToolbarItem {

        private lazy var _item = ItemNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        private var actionTrampoline: ToolbarActionTrampoline?

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

        /// A Boolean value indicating whether the item has a bordered style.
        open var isBordered: Bool {
            get { _item.isBordered }
            set { _item.isBordered = newValue }
        }

        /// Sets the Boolean value indicating whether the item has a bordered style.
        @discardableResult
        open func bordered(_ isBordered: Bool) -> Self {
            _item.isBordered = isBordered
            return self
        }

        /// A Boolean value indicating whether the item behaves as a navigation item.
        @available(macOS 12.0, *)
        open var isNavigational: Bool {
            get { _item.isNavigational }
            set { _item.isNavigational = newValue }
        }

        /// Sets the Boolean value indicating whether the item behaves as a navigation item.
        @available(macOS 12.0, *)
        @discardableResult
        open func isNavigational(_ isNavigational: Bool) -> Self {
            _item.isNavigational = isNavigational
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks the item.
        public var actionBlock: ((NSToolbar.Item) -> Void)? {
            didSet { installAction() }
        }

        /// Sets the handler called when the user clicks the item.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.Item) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        /// The action selector called when the user clicks the item.
        public var action: Selector? {
            get { actionTrampoline == nil ? _item.action : nil }
            set {
                actionBlock = nil
                _item.action = newValue
            }
        }

        /// Sets the action selector called when the user clicks the item.
        @discardableResult
        public func action(_ action: Selector?) -> Self {
            self.action = action
            return self
        }

        /// The target that receives the action message.
        public var target: AnyObject? {
            get { actionTrampoline == nil ? _item.target : nil }
            set {
                actionBlock = nil
                _item.target = newValue
            }
        }

        /// Sets the target that receives the action message.
        @discardableResult
        public func target(_ target: AnyObject?) -> Self {
            self.target = target
            return self
        }

        private func installAction() {
            if let actionBlock = actionBlock {
                let trampoline = ToolbarActionTrampoline { [weak self] in
                    guard let self = self else { return }
                    actionBlock(self)
                }
                actionTrampoline = trampoline
                _item.target = trampoline
                _item.action = ToolbarActionTrampoline.invokeSelector
            } else {
                if _item.action == ToolbarActionTrampoline.invokeSelector {
                    _item.action = nil
                }
                if _item.target === actionTrampoline {
                    _item.target = nil
                }
                actionTrampoline = nil
            }
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
