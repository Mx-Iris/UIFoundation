#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A toolbar item that hosts an `NSButton`.
    open class Button: ToolbarItem {

        private lazy var _item = ButtonNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        /// The button hosted by the toolbar item.
        public let button: NSButton

        private var actionTrampoline: ToolbarActionTrampoline?

        // MARK: - Button chainables

        /// Sets the title of the button.
        @discardableResult
        public func title(_ title: String) -> Self {
            button.title = title
            return self
        }

        /// Sets the alternate title of the button.
        @discardableResult
        public func alternateTitle(_ title: String) -> Self {
            button.alternateTitle = title
            return self
        }

        /// Sets the attributed title of the button.
        @discardableResult
        public func attributedTitle(_ title: NSAttributedString) -> Self {
            button.attributedTitle = title
            return self
        }

        /// Sets the button type.
        @discardableResult
        public func type(_ type: NSButton.ButtonType) -> Self {
            button.setButtonType(type)
            return self
        }

        /// Sets the button state.
        @discardableResult
        public func state(_ state: NSControl.StateValue) -> Self {
            button.state = state
            return self
        }

        /// Sets the button state from a boolean.
        @discardableResult
        public func state(_ isOn: Bool) -> Self {
            button.state = isOn ? .on : .off
            return self
        }

        /// Sets whether the button has a border.
        @discardableResult
        public func bordered(_ isBordered: Bool) -> Self {
            button.isBordered = isBordered
            return self
        }

        /// Sets the image of the button.
        @discardableResult
        public func image(_ image: NSImage?) -> Self {
            button.image = image
            return self
        }

        /// Sets the image of the button to an SF Symbol.
        @available(macOS 11.0, *)
        @discardableResult
        public func symbolImage(_ symbolName: String) -> Self {
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
                button.image = image
            }
            return self
        }

        /// Sets the alternate image of the button.
        @discardableResult
        public func alternateImage(_ image: NSImage?) -> Self {
            button.alternateImage = image
            return self
        }

        /// Sets the position of the button's image relative to its title.
        @discardableResult
        public func imagePosition(_ position: NSControl.ImagePosition) -> Self {
            button.imagePosition = position
            return self
        }

        /// Sets the image scaling of the button.
        @discardableResult
        public func imageScaling(_ scaling: NSImageScaling) -> Self {
            button.imageScaling = scaling
            return self
        }

        /// Sets the bezel style of the button.
        @discardableResult
        public func bezelStyle(_ style: NSButton.BezelStyle) -> Self {
            button.bezelStyle = style
            return self
        }

        /// Sets the bezel color of the button (where supported).
        @discardableResult
        public func bezelColor(_ color: NSColor?) -> Self {
            button.bezelColor = color
            return self
        }

        /// Sets the content tint color of the button.
        @discardableResult
        public func contentTintColor(_ color: NSColor?) -> Self {
            button.contentTintColor = color
            return self
        }

        /// Sets the key equivalent of the button.
        @discardableResult
        public func shortcut(_ shortcut: String, holding modifiers: NSEvent.ModifierFlags = .command) -> Self {
            button.keyEquivalent = shortcut
            button.keyEquivalentModifierMask = modifiers
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks the button.
        public var actionBlock: ((NSToolbar.Button) -> Void)? {
            didSet { installAction() }
        }

        /// Sets the handler called when the user clicks the button.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.Button) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        /// The action selector called when the user clicks the button.
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

        /// Creates a button toolbar item that displays the specified title.
        public init(_ identifier: NSToolbarItem.Identifier? = nil, title: String, action: ((NSToolbar.Button) -> Void)? = nil) {
            self.button = Self.makeBezeledButton(title: title, image: nil)
            super.init(identifier)
            commonInit()
            self.actionBlock = action
        }

        /// Creates a button toolbar item that displays the specified title and image.
        public init(_ identifier: NSToolbarItem.Identifier? = nil, title: String? = nil, image: NSImage, action: ((NSToolbar.Button) -> Void)? = nil) {
            self.button = Self.makeBezeledButton(title: title ?? "", image: image)
            super.init(identifier)
            commonInit()
            self.actionBlock = action
        }

        /// Creates a button toolbar item that displays the specified SF Symbol image.
        @available(macOS 11.0, *)
        public init?(_ identifier: NSToolbarItem.Identifier? = nil, title: String? = nil, symbolName: String, action: ((NSToolbar.Button) -> Void)? = nil) {
            guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else { return nil }
            self.button = Self.makeBezeledButton(title: title ?? "", image: image)
            super.init(identifier)
            commonInit()
            self.actionBlock = action
        }

        /// Creates a button toolbar item that hosts the specified button.
        public init(_ identifier: NSToolbarItem.Identifier? = nil, button: NSButton, action: ((NSToolbar.Button) -> Void)? = nil) {
            self.button = button
            super.init(identifier)
            commonInit()
            self.actionBlock = action
        }

        private func commonInit() {
            button.translatesAutoresizingMaskIntoConstraints = false
            _item.view = button
        }

        private static func makeBezeledButton(title: String, image: NSImage?) -> NSButton {
            let button = NSButton(title: title, target: nil, action: nil)
            button.bezelStyle = .texturedRounded
            if let image = image {
                button.image = image
                button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
                button.imageScaling = .scaleProportionallyDown
            }
            return button
        }

        private final class ButtonNSToolbarItem: NSToolbarItem {
            weak var owner: NSToolbar.Button?
            init(for owner: NSToolbar.Button) {
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
