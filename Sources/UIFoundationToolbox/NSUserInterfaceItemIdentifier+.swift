#if canImport(AppKit)

import AppKit

extension NSUserInterfaceItemIdentifier: ExpressibleByStringInterpolation {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

#endif
