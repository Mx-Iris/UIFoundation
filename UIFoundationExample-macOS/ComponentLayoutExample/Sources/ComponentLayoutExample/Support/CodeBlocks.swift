//
//  CodeBlocks.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25) -- its `Code.swift`, `InlineCode.swift` and `Block.swift`.
//

import AppKit
import UIFoundationComponent

/// A standalone code block, for snippets that are illustrative rather than live
/// (`#CodeExample` covers the live ones).
public struct Code: ComponentBuilder {
    let code: String

    public init(_ code: String) {
        self.code = code
    }

    public init(_ codeBlock: () -> String) {
        self.code = codeBlock()
    }

    public func build() -> some Component {
        CodeComponent(code).inset(h: 16, v: 10).view().codeBlockStyle()
    }
}

/// A code fragment sized to sit inside a line of prose.
public struct InlineCode: ComponentBuilder {
    let code: String

    public init(_ code: String) {
        self.code = code
    }

    public init(_ codeBlock: () -> String) {
        self.code = codeBlock()
    }

    public func build() -> some Component {
        CodeComponent(code)
            .inset(h: 6, v: 4)
            .view()
            .codeBlockStyle()
            // Pulls the taller box back onto the text's own line.
            .inset(v: -6)
    }
}

/// A labelled, tinted rectangle -- the placeholder the layout chapters arrange
/// to show what a stack or a flow is doing.
public struct Block: ComponentBuilder {
    let text: String

    public init(_ text: String) {
        self.text = text
    }

    public func build() -> some Component {
        Text(text, font: .subtitle).textColor(.white).blockBackground(color: .systemBlue)
    }
}

extension Component {
    /// The rounded tinted panel a ``Block`` sits on.
    public func blockBackground(color: NSColor) -> some Component {
        background {
            Space()
                .fill()
                .backgroundColor(color.withAlphaComponent(0.2))
                .cornerRadius(16)
                .cornerCurve(.continuous)
                .borderWidth(2)
                .borderColor(color)
        }
    }
}
