#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Foundation
import FrameworkToolbox

extension FrameworkToolbox<NSRectEdge> {
    /// The bottom edge of the rectangle.
    public static var bottom: NSRectEdge { .minY }

    /// The right edge of the rectangle.
    public static var right: NSRectEdge { .maxX }

    /// The top edge of the rectangle.
    public static var top: NSRectEdge { .maxY }

    /// The left edge of the rectangle.
    public static var left: NSRectEdge { .minX }
}

#endif
