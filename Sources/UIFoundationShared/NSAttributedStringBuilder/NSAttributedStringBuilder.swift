#if NSAttributedStringBuilder

// Ported from https://github.com/ethanhuang13/NSAttributedStringBuilder (MIT License, Copyright © 2019 Ethan Huang)
// Rewired to use NSUI* typealiases from UIFoundationTypealias.

import Foundation

public typealias Attributes = [NSAttributedString.Key: Any]

@resultBuilder
public enum NSAttributedStringBuilder {
    public static func buildBlock() -> [Component] {
        []
    }

    public static func buildBlock(_ components: [Component]...) -> [Component] {
        components.flatMap { $0 }
    }

    public static func buildEither(first component: [Component]?) -> [Component] {
        component ?? []
    }

    public static func buildEither(second component: [Component]?) -> [Component] {
        component ?? []
    }

    public static func buildOptional(_ component: [Component]?) -> [Component] {
        component ?? []
    }

    public static func buildExpression(_ expression: [Component]?) -> [Component] {
        expression ?? []
    }

    public static func buildExpression(_ expression: Component?) -> [Component] {
        expression.map { [$0] } ?? []
    }

    public static func buildArray(_ components: [[Component]]) -> [Component] {
        components.flatMap { $0 }
    }

    public static func buildFinalResult(_ components: [any Component]) -> NSAttributedString {
        let mutableAttributedString = NSMutableAttributedString(string: "")
        for component in components {
            mutableAttributedString.append(component.attributedString)
        }
        return mutableAttributedString
    }
}

extension NSAttributedString {
    public convenience init(@NSAttributedStringBuilder _ builder: () -> NSAttributedString) {
        self.init(attributedString: builder())
    }
}

#endif
