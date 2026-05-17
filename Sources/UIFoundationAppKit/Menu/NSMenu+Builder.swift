#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSMenu {
    /// Creates a menu with the given title and items.
    public convenience init(_ title: String, @MenuBuilder _ items: () -> [NSMenuItem]) {
        self.init(title: title)
        append(items())
    }

    /// Creates a menu with the given title and items.
    public convenience init(title: String, @MenuBuilder _ items: () -> [NSMenuItem]) {
        self.init(title: title)
        append(items())
    }

    /// Creates a menu with the given items.
    public convenience init(@MenuBuilder _ items: () -> [NSMenuItem]) {
        self.init(title: "")
        append(items())
    }

    /// Creates a menu with the given title and items.
    public convenience init(title: String = "", items: [NSMenuItem]) {
        self.init(title: title)
        append(items)
    }

    /// Replaces the menu items with the given items.
    @discardableResult
    public func items(@MenuBuilder _ items: () -> [NSMenuItem]) -> Self {
        self.items = []
        append(items())
        return self
    }

    /// Appends the items produced by the builder.
    @discardableResult
    public func append(@MenuBuilder _ items: () -> [NSMenuItem]) -> Self {
        append(items())
        return self
    }

    private func append(_ newItems: [NSMenuItem]) {
        for item in newItems {
            addItem(item)
        }
    }
}

extension NSMenu {
    /// A container that increases the `indentationLevel` of its content by one.
    public struct IndentGroup {
        let children: () -> [NSMenuItem?]

        public init(@MenuBuilder children: @escaping () -> [NSMenuItem]) {
            self.children = { children() }
        }
    }
}

/// A result builder that produces an array of `NSMenuItem`.
@resultBuilder
public enum MenuBuilder {
    public static func buildBlock(_ blocks: [NSMenuItem]...) -> [NSMenuItem] {
        blocks.flatMap { $0 }
    }

    public static func buildOptional(_ items: [NSMenuItem]?) -> [NSMenuItem] {
        items ?? []
    }

    public static func buildEither(first: [NSMenuItem]) -> [NSMenuItem] {
        first
    }

    public static func buildEither(second: [NSMenuItem]) -> [NSMenuItem] {
        second
    }

    public static func buildArray(_ components: [[NSMenuItem]]) -> [NSMenuItem] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [NSMenuItem]) -> [NSMenuItem] {
        component
    }

    public static func buildExpression(_ expression: [NSMenuItem]?) -> [NSMenuItem] {
        expression ?? []
    }

    public static func buildExpression(_ expression: NSMenuItem?) -> [NSMenuItem] {
        expression.map { [$0] } ?? []
    }

    public static func buildExpression(_ title: String?) -> [NSMenuItem] {
        title.map { [NSMenuItem($0)] } ?? []
    }

    public static func buildExpression(_ titles: [String]?) -> [NSMenuItem] {
        (titles ?? []).map { NSMenuItem($0) }
    }

    public static func buildExpression(_ view: NSView?) -> [NSMenuItem] {
        view.map { [NSMenuItem(view: $0)] } ?? []
    }

    public static func buildExpression(_ views: [NSView]?) -> [NSMenuItem] {
        (views ?? []).map { NSMenuItem(view: $0) }
    }

    public static func buildExpression(_ group: NSMenu.IndentGroup?) -> [NSMenuItem] {
        guard let items = group?.children().compactMap({ $0 }) else { return [] }
        for item in items {
            item.indentationLevel += 1
        }
        return items
    }
}

#endif
