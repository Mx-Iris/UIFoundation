//
//  CodeExample.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25).
//

import UIFoundationComponent

/// Renders a component and, underneath it, the source of the very expression
/// that produced it.
///
/// ```swift
/// #CodeExample(
///     HStack(spacing: 10) {
///         Text("A")
///         Text("B")
///     }
/// )
/// ```
@freestanding(expression)
public macro CodeExample(_ value: any Component) -> any Component =
    #externalMacro(module: "ComponentLayoutExampleMacros", type: "CodeExampleMacro")

/// Like ``CodeExample(_:)`` but without padding around the rendered sample --
/// for samples that draw their own edges.
@freestanding(expression)
public macro CodeExampleNoInsets(_ value: any Component) -> any Component =
    #externalMacro(module: "ComponentLayoutExampleMacros", type: "CodeExampleNoInsetsMacro")

/// Like ``CodeExample(_:)`` but without the rounded container around the
/// rendered sample.
@freestanding(expression)
public macro CodeExampleNoWrap(_ value: any Component) -> any Component =
    #externalMacro(module: "ComponentLayoutExampleMacros", type: "CodeExampleNoWrapMacro")

/// Attaches a `codeRepresentation` string holding the declaration's own source,
/// so a chapter can show how a custom component is written without a copy of it
/// going stale.
@attached(member, names: named(codeRepresentation))
public macro GenerateCode() =
    #externalMacro(module: "ComponentLayoutExampleMacros", type: "GenerateCodeMacro")
