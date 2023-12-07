#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension NSEdgeInsets: Hashable {
    public static let zero = NSEdgeInsetsZero

    public func hash(into hasher: inout Hasher) {
        hasher.combine(left)
        hasher.combine(top)
        hasher.combine(bottom)
        hasher.combine(right)
    }

    public static func == (lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
        lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
    }
}

#endif
