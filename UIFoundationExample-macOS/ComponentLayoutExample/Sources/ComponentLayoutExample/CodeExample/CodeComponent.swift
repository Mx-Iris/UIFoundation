//
//  CodeComponent.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25).
//

import AppKit
import UIFoundationComponent

/// One shared, never-displayed text view used only to measure.
///
/// Upstream does the same thing. Measuring through the view that will actually
/// draw the snippet is the point: a second, differently configured text view
/// would answer a slightly different height, and the code block would clip.
private let sizingTextView = CodeTextView()

/// A syntax-highlighted Swift snippet.
public struct CodeComponent: Component {
    let code: String

    public init(_ code: String) {
        self.code = code
    }

    public init(_ codeBlock: () -> String) {
        self.code = codeBlock()
    }

    public func layout(_ constraint: Constraint) -> some RenderNode {
        sizingTextView.code = code
        let size = sizingTextView.sizeThatFits(constraint.maxSize)
        return ViewComponent<CodeTextView>()
            .code(code)
            .size(size)
            .layout(constraint)
    }
}
