//
//  MenuCompatibility.swift
//  ComponentLayoutExample
//
//  Context menus, spelled for AppKit.
//
//  UIKit builds one from values (`UIMenu(children: [UIAction(…)])`); AppKit
//  builds one from objects wired by target/action. These two initialisers put
//  the AppKit objects behind the same shape, so a chapter's menu reads as one
//  expression rather than five statements.
//

import AppKit
import UIFoundationComponent

extension NSMenu {
    /// Builds a menu from its items, the way `UIMenu(children:)` does.
    public convenience init(children: [NSMenuItem]) {
        self.init(title: "")
        for child in children {
            addItem(child)
        }
    }
}

extension NSMenuItem {
    /// A menu item with a closure instead of a target/action pair.
    ///
    /// - Note: UIKit's `UIAction` takes `attributes: [.destructive]`, which
    ///   renders the row in red. AppKit has no counterpart -- destructive menu
    ///   items on macOS look like every other row -- so there is no parameter
    ///   for it here rather than one that quietly does nothing.
    public convenience init(
        title: String,
        systemImage: String? = nil,
        handler: @escaping () -> Void
    ) {
        self.init(title: title, action: nil, keyEquivalent: "")
        if let systemImage {
            image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
        }
        box.actionBlock = { _ in handler() }
    }
}
