@resultBuilder
public enum StackViewBuilder {
    public static func buildExpression(_ expression: StackViewComponent) -> [StackViewComponent] {
        return [expression]
    }

    public static func buildBlock(_ components: [StackViewComponent]...) -> [StackViewComponent] {
        return components.flatMap { $0 }
    }

    public static func buildBlock(_ components: StackViewComponent...) -> [StackViewComponent] {
        return components.map { $0 }
    }

    public static func buildOptional(_ component: [StackViewComponent]?) -> [StackViewComponent] {
        return component ?? []
    }

    public static func buildEither(first component: [StackViewComponent]) -> [StackViewComponent] {
        return component
    }

    public static func buildEither(second component: [StackViewComponent]) -> [StackViewComponent] {
        return component
    }

    public static func buildArray(_ components: [[StackViewComponent]]) -> [StackViewComponent] {
        Array(components.joined())
    }
}
