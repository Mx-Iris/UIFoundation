#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension NSUserInterfaceItemIdentifier: @retroactive ExpressibleByExtendedGraphemeClusterLiteral {}
extension NSUserInterfaceItemIdentifier: @retroactive ExpressibleByUnicodeScalarLiteral {}
extension NSUserInterfaceItemIdentifier: @retroactive ExpressibleByStringLiteral, @retroactive ExpressibleByIntegerLiteral, @retroactive ExpressibleByFloatLiteral, @retroactive ExpressibleByStringInterpolation {
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

#endif
