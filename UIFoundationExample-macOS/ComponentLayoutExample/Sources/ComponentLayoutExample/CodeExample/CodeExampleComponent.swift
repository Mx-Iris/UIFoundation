//
//  CodeExampleComponent.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25).
//

import AppKit
import UIFoundationComponent

/// A snippet shown as "what it renders" stacked over "what it says".
///
/// Built by the `#CodeExample` family; there is no reason to construct one by
/// hand, though the macro's expansion names it, so it has to be public.
public struct CodeExampleComponent: Component {
    public enum Style {
        /// Padding around the sample, both halves in their own rounded box.
        case `default`
        /// No padding -- for samples that fill their own edges.
        case noInset
        /// No rounded box around the sample.
        case noWrap
    }

    let content: any Component
    let code: String
    let style: Style

    public init(content: any Component, code: String, style: Style = .default) {
        self.content = content
        self.code = code
        self.style = style
    }

    public func layout(_ constraint: Constraint) -> some RenderNode {
        let codeBlock = CodeComponent(code).inset(h: 16, v: 10).view().codeBlockStyle()
        return switch style {
        case .default:
            VStack(spacing: 4) {
                content.inset(16).view().codeBlockStyle()
                codeBlock
            }.layout(constraint)
        case .noInset:
            VStack(spacing: 4) {
                content.view().codeBlockStyle()
                codeBlock
            }.layout(constraint)
        case .noWrap:
            VStack(spacing: 4) {
                content.codeBlockStyle()
                codeBlock
            }.layout(constraint)
        }
    }
}

extension Component {
    /// The rounded, hairline-bordered box both halves of a code example sit in.
    public func codeBlockStyle(
        backgroundColor: NSColor = NSColor.systemGray.withAlphaComponent(0.1)
    ) -> some Component {
        self.backgroundColor(backgroundColor)
            .cornerRadius(10)
            .cornerCurve(.continuous)
            .borderWidth(0.5)
            .borderColor(.separatorColor)
            .masksToBounds(true)
    }
}
