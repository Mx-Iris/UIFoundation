#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A toolbar item that presents a menu (`NSMenuToolbarItem`).
    open class Menu: ToolbarItem {

        private lazy var _item = MenuNSToolbarItem(for: self)
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

        /// Sets the image of the item to an SF Symbol.
        @available(macOS 11.0, *)
        @discardableResult
        open func symbolImage(_ symbolName: String) -> Self {
            _item.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
            return self
        }

        /// A Boolean value that determines whether the item displays an indicator
        /// of additional functionality.
        open var showsIndicator: Bool {
            get { _item.showsIndicator }
            set { _item.showsIndicator = newValue }
        }

        /// Sets whether the item displays an indicator of additional functionality.
        @discardableResult
        open func showsIndicator(_ shows: Bool) -> Self {
            _item.showsIndicator = shows
            return self
        }

        /// The menu presented from the toolbar item.
        open var menu: NSMenu {
            get { _item.menu }
            set { _item.menu = newValue }
        }

        /// Sets the menu presented from the toolbar item.
        @discardableResult
        open func menu(_ menu: NSMenu) -> Self {
            _item.menu = menu
            return self
        }

        /// Sets the menu presented from the toolbar item using the menu builder.
        @discardableResult
        open func menu(@MenuBuilder _ items: () -> [NSMenuItem]) -> Self {
            _item.menu = NSMenu(title: title, items: items())
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks the item.
        public var actionBlock: ((NSToolbar.Menu) -> Void)? {
            didSet { installAction() }
        }

        /// Sets the handler called when the user clicks the item.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.Menu) -> Void)?) -> Self {
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

        /// The target that receives the action message.
        public var target: AnyObject? {
            get { actionTrampoline == nil ? _item.target : nil }
            set {
                actionBlock = nil
                _item.target = newValue
            }
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

        public init(_ identifier: NSToolbarItem.Identifier? = nil, menu: NSMenu) {
            super.init(identifier)
            _item.menu = menu
            title = menu.title
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, title: String, menu: NSMenu) {
            super.init(identifier)
            _item.menu = menu
            self.title = title
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, image: NSImage, menu: NSMenu) {
            super.init(identifier)
            _item.menu = menu
            self.image = image
        }

        @available(macOS 11.0, *)
        public init?(_ identifier: NSToolbarItem.Identifier? = nil, symbolName: String, menu: NSMenu) {
            guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
            super.init(identifier)
            _item.menu = menu
            self.image = image
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, title: String, @MenuBuilder _ items: () -> [NSMenuItem]) {
            super.init(identifier)
            _item.menu = NSMenu(title: title, items: items())
            self.title = title
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, image: NSImage, @MenuBuilder _ items: () -> [NSMenuItem]) {
            super.init(identifier)
            _item.menu = NSMenu(title: "", items: items())
            self.image = image
        }

        @available(macOS 11.0, *)
        public init?(_ identifier: NSToolbarItem.Identifier? = nil, symbolName: String, @MenuBuilder _ items: () -> [NSMenuItem]) {
            guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
            super.init(identifier)
            _item.menu = NSMenu(title: "", items: items())
            self.image = image
        }

        private final class MenuNSToolbarItem: NSMenuToolbarItem {
            weak var owner: NSToolbar.Menu?
            init(for owner: NSToolbar.Menu) {
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
