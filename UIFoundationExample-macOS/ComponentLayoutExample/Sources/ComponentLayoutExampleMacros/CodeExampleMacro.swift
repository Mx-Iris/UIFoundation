//
//  CodeExampleMacro.swift
//  ComponentLayoutExampleMacros
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25), unchanged in substance -- the expansion is platform-agnostic.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Expands `#CodeExample(expr)` into a pair: the evaluated expression, and its
/// own source text.
///
/// This is what keeps a chapter honest. Writing the sample once and the caption
/// once means the two drift the first time someone edits only one of them.
private func makeCodeExampleExpansion(
    of node: some FreestandingMacroExpansionSyntax,
    style: String
) -> ExprSyntax {
    guard let argument = node.arguments.first?.expression else {
        fatalError("compiler bug: the macro does not have any arguments")
    }

    return """
        {
            let (component, code) = (
                \(argument),
                \(literal: argument.description.trimLeadingWhitespacesBasedOnFirstLine())
            )
            return CodeExampleComponent(content: component, code: code, style: \(raw: style))
        }()
        """
}

public struct CodeExampleMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        makeCodeExampleExpansion(of: node, style: ".default")
    }
}

public struct CodeExampleNoInsetsMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        makeCodeExampleExpansion(of: node, style: ".noInset")
    }
}

public struct CodeExampleNoWrapMacro: ExpressionMacro {
    public static func expansion(
        of node: some FreestandingMacroExpansionSyntax,
        in context: some MacroExpansionContext
    ) -> ExprSyntax {
        makeCodeExampleExpansion(of: node, style: ".noWrap")
    }
}

/// Gives a type a `codeRepresentation` string holding its own declaration, so a
/// chapter can show how a custom component is written without copying it.
public struct GenerateCodeMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        [
            """
            static var codeRepresentation: String {
                \(literal: declaration.with(\.attributes, []).description.trimLeadingWhitespacesBasedOnFirstLine())
            }
            """
        ]
    }
}

@main
struct ComponentLayoutExamplePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodeExampleMacro.self,
        CodeExampleNoInsetsMacro.self,
        CodeExampleNoWrapMacro.self,
        GenerateCodeMacro.self,
    ]
}
