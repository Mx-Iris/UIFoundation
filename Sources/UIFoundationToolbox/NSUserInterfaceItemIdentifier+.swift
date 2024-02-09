#if canImport(AppKit)

import AppKit
import FrameworkToolbox

extension NSUserInterfaceItemIdentifier: ExpressibleByStringLiteral, ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    public init(stringLiteral value: String) {
        self.init(rawValue: value)
    }

    public init(integerLiteral value: Int) {
        self.init(rawValue: String(value))
    }

    public init(floatLiteral value: Float) {
        self.init(rawValue: String(value))
    }

    public init(_ anyClass: AnyClass) {
        self.init(String(describing: anyClass))
    }
}

extension FrameworkToolbox {
    public static var typeIdentifier: NSUserInterfaceItemIdentifier {
        .init(String(describing: self))
    }
}

#endif
