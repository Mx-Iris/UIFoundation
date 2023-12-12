@resultBuilder
struct ArrayBuilder<Element> {
    static func buildPartialBlock(first: Element) -> [Element] { [first] }
    static func buildPartialBlock(first: [Element]) -> [Element] { first }
    static func buildPartialBlock(accumulated: [Element], next: Element) -> [Element] { accumulated + [next] }
    static func buildPartialBlock(accumulated: [Element], next: [Element]) -> [Element] { accumulated + next }
    
    // Empty block
    static func buildBlock() -> [Element] { [] }
    
    // Empty partial block. Useful for switch cases to represent no elements.
    static func buildPartialBlock(first: Void) -> [Element] { [] }
    
    // Impossible partial block. Useful for fatalError().
    static func buildPartialBlock(first: Never) -> [Element] {}
    
    // Block for an 'if' condition.
    static func buildIf(_ element: [Element]?) -> [Element] { element ?? [] }
    
    // Block for an 'if' condition which also have an 'else' branch.
    static func buildEither(first: [Element]) -> [Element] { first }
    
    // Block for the 'else' branch of an 'if' condition.
    static func buildEither(second: [Element]) -> [Element] { second }
    
    // Block for an array of elements. Useful for 'for' loops.
    static func buildArray(_ components: [[Element]]) -> [Element] { components.flatMap { $0 } }
}

extension Array {
    init(@ArrayBuilder<Element> _ builder: () -> [Element]) {
        self.init(builder())
    }
}
