#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSMenuItem {
    /// Creates a menu item with the specified title.
    public convenience init(_ title: String) {
        self.init(title: title, action: nil, keyEquivalent: "")
    }

    /// Creates a menu item with the specified title and key equivalent.
    public convenience init(_ title: String, keyEquivalent: String, modifiers: NSEvent.ModifierFlags = .command) {
        self.init(title: title, action: nil, keyEquivalent: keyEquivalent)
        self.keyEquivalentModifierMask = modifiers
    }

    /// Creates a menu item with the specified title, action and key equivalent.
    public convenience init(_ title: String, action: Selector?, keyEquivalent: String = "", modifiers: NSEvent.ModifierFlags = .command) {
        self.init(title: title, action: action, keyEquivalent: keyEquivalent)
        self.keyEquivalentModifierMask = modifiers
    }

    /// Creates a menu item with the specified title and image.
    public convenience init(_ title: String, image: NSImage?) {
        self.init(title: title, action: nil, keyEquivalent: "")
        self.image = image
    }

    /// Creates a menu item with the specified title and SF Symbol name.
    @available(macOS 11.0, *)
    public convenience init(_ title: String, symbolName: String) {
        self.init(title: title, action: nil, keyEquivalent: "")
        self.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
    }

    /// Creates a menu item with the specified title and submenu.
    public convenience init(_ title: String, submenu: NSMenu) {
        self.init(title: title, action: nil, keyEquivalent: "")
        self.submenu = submenu
    }

    /// Creates a menu item with the specified title and submenu items.
    public convenience init(_ title: String, @MenuBuilder submenu items: () -> [NSMenuItem]) {
        self.init(title: title, action: nil, keyEquivalent: "")
        self.submenu = NSMenu(title: title, items: items())
    }

    /// Creates a menu item that hosts the specified view.
    public convenience init(view: NSView) {
        self.init(title: "", action: nil, keyEquivalent: "")
        self.view = view
    }
}

extension NSMenuItem {
    /// Sets the title of the menu item.
    @discardableResult
    public func title(_ title: String) -> Self {
        self.title = title
        return self
    }

    /// Sets the attributed title of the menu item.
    @discardableResult
    public func attributedTitle(_ attributedTitle: NSAttributedString?) -> Self {
        self.attributedTitle = attributedTitle
        return self
    }

    /// Sets the image of the menu item.
    @discardableResult
    public func image(_ image: NSImage?) -> Self {
        self.image = image
        return self
    }

    /// Sets the image of the menu item using the specified SF Symbol name.
    @available(macOS 11.0, *)
    @discardableResult
    public func symbolImage(_ symbolName: String) -> Self {
        self.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        return self
    }

    /// Sets the menu item's state.
    @discardableResult
    public func state(_ state: NSControl.StateValue) -> Self {
        self.state = state
        return self
    }

    /// Sets the menu item's state as a boolean (`on` if `true`, `off` if `false`).
    @discardableResult
    public func state(_ isOn: Bool) -> Self {
        self.state = isOn ? .on : .off
        return self
    }

    /// Sets the menu item's tag.
    @discardableResult
    public func tag(_ tag: Int) -> Self {
        self.tag = tag
        return self
    }

    /// Sets whether the menu item is enabled.
    @discardableResult
    public func isEnabled(_ isEnabled: Bool) -> Self {
        self.isEnabled = isEnabled
        return self
    }

    /// Sets whether the menu item is hidden.
    @discardableResult
    public func isHidden(_ isHidden: Bool) -> Self {
        self.isHidden = isHidden
        return self
    }

    /// Sets whether the menu item is an alternate.
    @discardableResult
    public func isAlternate(_ isAlternate: Bool) -> Self {
        self.isAlternate = isAlternate
        return self
    }

    /// Sets the indentation level of the menu item.
    @discardableResult
    public func indentationLevel(_ level: Int) -> Self {
        self.indentationLevel = level
        return self
    }

    /// Sets the tooltip of the menu item.
    @discardableResult
    public func toolTip(_ toolTip: String?) -> Self {
        self.toolTip = toolTip
        return self
    }

    /// Sets the represented object of the menu item.
    @discardableResult
    public func representedObject(_ representedObject: Any?) -> Self {
        self.representedObject = representedObject
        return self
    }

    /// Sets the key equivalent string of the menu item.
    @discardableResult
    public func keyEquivalent(_ keyEquivalent: String) -> Self {
        self.keyEquivalent = keyEquivalent
        return self
    }

    /// Sets the key equivalent modifier mask of the menu item.
    @discardableResult
    public func keyEquivalentModifierMask(_ mask: NSEvent.ModifierFlags) -> Self {
        self.keyEquivalentModifierMask = mask
        return self
    }

    /// Sets both the key equivalent string and modifier mask of the menu item.
    @discardableResult
    public func shortcut(_ keyEquivalent: String, holding modifiers: NSEvent.ModifierFlags = .command) -> Self {
        self.keyEquivalent = keyEquivalent
        self.keyEquivalentModifierMask = modifiers
        return self
    }

    /// Sets the view that draws the menu item's content.
    @discardableResult
    public func view(_ view: NSView?) -> Self {
        self.view = view
        return self
    }

    /// Sets the submenu of the menu item.
    @discardableResult
    public func submenu(_ submenu: NSMenu?) -> Self {
        self.submenu = submenu
        return self
    }

    /// Sets the submenu of the menu item using the menu builder.
    @discardableResult
    public func submenu(@MenuBuilder _ items: () -> [NSMenuItem]) -> Self {
        self.submenu = NSMenu(title: title, items: items())
        return self
    }

    /// Sets the action selector of the menu item.
    @discardableResult
    public func action(_ action: Selector?) -> Self {
        self.action = action
        return self
    }

    /// Sets the target of the menu item.
    @discardableResult
    public func target(_ target: AnyObject?) -> Self {
        self.target = target
        return self
    }
}

#endif
