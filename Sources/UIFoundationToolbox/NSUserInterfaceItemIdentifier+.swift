#if canImport(AppKit)

import AppKit
import FrameworkToolbox

extension NSUserInterfaceItemIdentifier: ExpressibleByStringInterpolation {
    public init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

extension FrameworkToolbox {
    public static var typeIdentifier: NSUserInterfaceItemIdentifier {
        .init(String(describing: self))
    }
}

#endif
