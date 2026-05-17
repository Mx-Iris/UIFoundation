#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A toolbar item that hosts an `NSPopUpButton`.
    open class PopUpButton: ToolbarItem {

        private lazy var _item = PopUpNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        /// The popup button hosted by the toolbar item.
        public let button: NSPopUpButton

        private var actionTrampoline: ToolbarActionTrampoline?

        // MARK: - Menu

        /// The menu displayed by the popup button.
        open var menu: NSMenu? {
            get { button.menu }
            set { button.menu = newValue }
        }

        /// Sets the menu displayed by the popup button.
        @discardableResult
        open func menu(_ menu: NSMenu) -> Self {
            button.menu = menu
            return self
        }

        /// Sets the menu items of the popup button.
        @discardableResult
        open func items(@MenuBuilder _ items: () -> [NSMenuItem]) -> Self {
            button.menu = NSMenu(title: "", items: items())
            return self
        }

        /// Sets the title shown on the popup button.
        @discardableResult
        open func title(_ title: String) -> Self {
            button.setTitle(title)
            return self
        }

        /// A Boolean value indicating whether the button displays a pull-down or pop-up menu.
        open var pullsDown: Bool {
            get { button.pullsDown }
            set { button.pullsDown = newValue }
        }

        /// Sets whether the button displays a pull-down or pop-up menu.
        @discardableResult
        open func pullsDown(_ pullsDown: Bool) -> Self {
            button.pullsDown = pullsDown
            return self
        }

        /// The selected menu item, or `nil` if none is selected.
        open var selectedItem: NSMenuItem? {
            get { button.selectedItem }
            set { button.select(newValue) }
        }

        /// Selects the item at the specified index.
        @discardableResult
        open func selectItem(at index: Int) -> Self {
            button.selectItem(at: index)
            return self
        }

        /// Selects the item with the specified title.
        @discardableResult
        open func selectItem(withTitle title: String) -> Self {
            button.selectItem(withTitle: title)
            return self
        }

        /// Selects the item with the specified tag.
        @discardableResult
        open func selectItem(withTag tag: Int) -> Self {
            button.selectItem(withTag: tag)
            return self
        }

        // MARK: - Action

        /// The handler called when the user picks an item from the popup button.
        public var actionBlock: ((NSToolbar.PopUpButton) -> Void)? {
            didSet { installAction() }
        }

        /// Sets the handler called when the user picks an item from the popup button.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.PopUpButton) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        /// The action selector called when the user picks an item.
        public var action: Selector? {
            get { actionTrampoline == nil ? button.action : nil }
            set {
                actionBlock = nil
                button.action = newValue
            }
        }

        /// The target that receives the action message.
        public var target: AnyObject? {
            get { actionTrampoline == nil ? button.target : nil }
            set {
                actionBlock = nil
                button.target = newValue
            }
        }

        private func installAction() {
            if let actionBlock = actionBlock {
                let trampoline = ToolbarActionTrampoline { [weak self] in
                    guard let self = self else { return }
                    actionBlock(self)
                }
                actionTrampoline = trampoline
                button.target = trampoline
                button.action = ToolbarActionTrampoline.invokeSelector
            } else {
                if button.action == ToolbarActionTrampoline.invokeSelector {
                    button.action = nil
                }
                if button.target === actionTrampoline {
                    button.target = nil
                }
                actionTrampoline = nil
            }
        }

        // MARK: - Init

        /// Creates a popup-button toolbar item with the specified menu items.
        public init(_ identifier: NSToolbarItem.Identifier? = nil, @MenuBuilder _ items: () -> [NSMenuItem]) {
            self.button = Self.makePopUpButton(menu: NSMenu(title: "", items: items()))
            super.init(identifier)
            _item.view = button
        }

        /// Creates a popup-button toolbar item with the specified menu.
        public init(_ identifier: NSToolbarItem.Identifier? = nil, menu: NSMenu) {
            self.button = Self.makePopUpButton(menu: menu)
            super.init(identifier)
            _item.view = button
        }

        /// Creates a popup-button toolbar item that hosts the specified popup button.
        public init(_ identifier: NSToolbarItem.Identifier? = nil, popUpButton: NSPopUpButton) {
            popUpButton.translatesAutoresizingMaskIntoConstraints = true
            self.button = popUpButton
            super.init(identifier)
            _item.view = button
        }

        private static func makePopUpButton(menu: NSMenu) -> NSPopUpButton {
            let button = NSPopUpButton(frame: .zero, pullsDown: true)
            button.bezelStyle = .texturedRounded
            button.imageScaling = .scaleProportionallyDown
            button.menu = menu
            return button
        }

        private final class PopUpNSToolbarItem: NSToolbarItem {
            weak var owner: NSToolbar.PopUpButton?
            init(for owner: NSToolbar.PopUpButton) {
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
