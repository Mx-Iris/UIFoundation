//
//  LeafEnvironmentKeys.swift
//  ComponentLayoutExample
//
//  Font and text colour, inherited down the component tree.
//
//  These live here rather than in UIFoundationComponent on purpose: the library
//  ships the layout system, not the things you put in it (Evolution 0024). The
//  environment machinery they build on -- `EnvironmentKey`, `EnvironmentValues`,
//  `EnvironmentComponent` -- is all public, which is exactly what makes writing
//  your own leaf components outside the library possible.
//

import AppKit
import UIFoundationComponent

/// The font a ``Text`` falls back to when it was given a plain string and no
/// font of its own.
public struct FontEnvironmentKey: EnvironmentKey {
    public static var defaultValue: NSFont? { nil }
}

/// The colour a ``Text`` draws plain strings in.
public struct TextColorEnvironmentKey: EnvironmentKey {
    public static var defaultValue: NSColor? { nil }
}

extension EnvironmentValues {
    /// The font in force for this part of the tree.
    public var font: NSFont? {
        get { self[FontEnvironmentKey.self] }
        set { self[FontEnvironmentKey.self] = newValue }
    }

    /// The text colour in force for this part of the tree.
    public var textColor: NSColor? {
        get { self[TextColorEnvironmentKey.self] }
        set { self[TextColorEnvironmentKey.self] = newValue }
    }
}

extension Component {
    /// Sets the font for this component and everything below it.
    ///
    /// - Note: This is a real method, so it wins over the `@dynamicMemberLookup`
    ///   subscript that would otherwise resolve `.font(_:)` onto the underlying
    ///   view. That is deliberate -- the environment value is inherited, a view
    ///   property is not.
    public func font(_ font: NSFont?) -> EnvironmentComponent<NSFont?, Self> {
        environment(\.font, value: font)
    }

    /// Sets the text colour for this component and everything below it.
    public func textColor(_ color: NSColor?) -> EnvironmentComponent<NSColor?, Self> {
        environment(\.textColor, value: color)
    }
}
