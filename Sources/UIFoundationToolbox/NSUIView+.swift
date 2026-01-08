#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#else
#error("Unsupported Platform")
#endif

import FrameworkToolbox
import UIFoundationTypealias

extension FrameworkToolbox where Base: NSUIView {
    public var optionalLayer: CALayer? {
        #if os(macOS)
        base.wantsLayer = true
        #endif
        return base.layer
    }

    /// The level of the view from the most outer `superview`. A value of `0` indicates that there isn't a superview.
    public var viewLevel: Int {
        var depth = 0
        var aSuperview = base.superview
        while aSuperview != nil {
            depth += 1
            aSuperview = aSuperview?.superview
        }
        return depth
    }

    /// Updates the anchor point of the view’s bounds rectangle while retaining the position.
    public func setAnchorPoint(_ anchorPoint: CGPoint) {
        guard let layer = optionalLayer else { return }
        guard layer.anchorPoint != anchorPoint else { return }
        var newPoint = CGPoint(x: base.bounds.size.width * anchorPoint.x, y: base.bounds.size.height * anchorPoint.y)
        var oldPoint = CGPoint(x: base.bounds.size.width * layer.anchorPoint.x, y: base.bounds.size.height * layer.anchorPoint.y)

        newPoint = newPoint.applying(layer.affineTransform())
        oldPoint = oldPoint.applying(layer.affineTransform())

        var position = layer.position

        position.x -= oldPoint.x
        position.x += newPoint.x

        position.y -= oldPoint.y
        position.y += newPoint.y

        layer.position = position
        layer.anchorPoint = anchorPoint
    }

    /// Removes all constrants from the view.
    public func removeAllConstraints() {
        var _superview = base.superview
        while let superview = _superview {
            for constraint in superview.constraints {
                if let first = constraint.firstItem as? NSUIView, first == base {
                    superview.removeConstraint(constraint)
                }

                if let second = constraint.secondItem as? NSUIView, second == base {
                    superview.removeConstraint(constraint)
                }
            }

            _superview = superview.superview
        }
        base.removeConstraints(base.constraints)
    }

    /// Sends the view to the front of it's superview.
    public func sendToFront() {
        guard let superview = base.superview else { return }
        #if os(macOS)
        superview.addSubview(base)
        #else
        superview.bringSubviewToFront(base)
        #endif
    }

    /// Sends the view to the back of it's superview.
    public func sendToBack() {
        guard let superview = base.superview else { return }
        #if os(macOS)
        superview.addSubview(base, positioned: .below, relativeTo: nil)
        #else
        superview.sendSubviewToBack(base)
        #endif
    }

    /// Returns the enclosing rect for the specified subviews.
    /// - Parameter subviews: The subviews for the rect.
    /// - Returns: The rect enclosing all the specified subviews.
    public func enclosingRect(for subviews: [NSUIView]) -> CGRect {
        var enlosingFrame = CGRect.zero
        for subview in subviews {
            let frame = base.convert(subview.bounds, from: subview)
            enlosingFrame = enlosingFrame.union(frame)
        }
        return enlosingFrame
    }

    #if os(macOS)
    /// Inserts a view above another view in the view hierarchy.
    ///
    /// - Parameters:
    ///   - view: The view to insert. It’s removed from its superview if it’s not a sibling of siblingSubview.
    ///   - siblingSubview: The sibling view that will be above the inserted view.
    public func insertSubview(_ view: NSView, belowSubview siblingSubview: NSView) {
        base.addSubview(view, positioned: .below, relativeTo: siblingSubview)
    }

    /// Inserts a view above another view in the view hierarchy.
    ///
    /// - Parameters:
    ///   - view: The view to insert. It’s removed from its superview if it’s not a sibling of siblingSubview.
    ///   - siblingSubview: The sibling view that will be behind the inserted view.
    public func insertSubview(_ view: NSView, aboveSubview siblingSubview: NSView) {
        base.addSubview(view, positioned: .above, relativeTo: siblingSubview)
    }
    #endif

    /// The first superview that matches the specificed view type.
    ///
    /// - Parameter viewType: The type of view to match.
    /// - Returns: The first parent view that matches the view type or `nil` if none match or there isn't a matching parent.
    public func firstSuperview<V: NSUIView>(for _: V.Type) -> V? {
        firstSuperview(where: { $0 is V }) as? V
    }

    /// The first superview that matches the specificed predicate.
    ///
    /// - Parameter predicate: The closure to match.
    /// - Returns: The first parent view that is matching the predicate or `nil` if none match or there isn't a matching parent.
    public func firstSuperview(where predicate: (NSUIView) -> (Bool)) -> NSUIView? {
        if let superview = base.superview {
            return predicate(superview) ? superview : superview.box.firstSuperview(where: predicate)
        }
        return nil
    }

    /// An array of all enclosing superviews.
    public func superviewChain() -> [NSUIView] {
        if let superview = base.superview {
            return [superview] + superview.box.superviewChain()
        }
        return []
    }

    /// An array of all subviews upto the maximum depth.
    ///
    /// A depth of `0` returns the subviews of the view, a value of `1` returns the subviews of the view and all their subviews, etc. To return all subviews use `max`.
    ///
    /// - Parameter depth: The maximum depth.
    public func subviews(depth: Int) -> [NSUIView] {
        if depth > 0 {
            return base.subviews + base.subviews.flatMap { $0.box.subviews(depth: depth - 1) }
        } else {
            return base.subviews
        }
    }

    /// An array of all subviews matching the specified view type.
    ///
    /// - Parameters:
    ///    - type: The type of subviews.
    ///    - depth: The maximum depth. As example a value of `0` returns the subviews of receiver and a value of `1` returns the subviews of the receiver and all their subviews. To return all subviews use `max`.
    ///
    public func subviews<V: NSUIView>(type _: V.Type, depth: Int = 0) -> [V] {
        subviews(depth: depth).compactMap { $0 as? V }
    }

    /// An array of all subviews matching the specified view type.
    ///
    /// - Parameters:
    ///    - type: The type of subviews.
    ///    - depth: The maximum depth. As example a value of `0` returns the subviews of receiver and a value of `1` returns the subviews of the receiver and all their subviews. To return all subviews use `max`.
    ///
    public func subviews(type: String, depth: Int = 0) -> [NSUIView] {
        subviews(where: { NSStringFromClass(Swift.type(of: $0)) == type }, depth: depth)
    }

    /// An array of all subviews matching the specified predicte.
    ///
    /// - Parameters:
    ///    - predicate: The predicate to match.
    ///    - depth: The maximum depth. As example a value of `0` returns the subviews of receiver and a value of `1` returns the subviews of the receiver and all their subviews. To return all subviews use `max`.
    ///
    public func subviews(where predicate: (NSUIView) -> (Bool), depth: Int = 0) -> [NSUIView] {
        subviews(depth: depth).filter { predicate($0) == true }
    }

    /// The first subview that matches the specificed view type.
    ///
    /// - Parameters:
    ///   - type: The type of view to match.
    ///   - depth: The maximum depth. As example a value of `0` returns the first subview matching of the receiver's subviews and a value of `1` returns the first subview matching of the receiver's subviews or any of their subviews. To return the first subview matching of all subviews use `max`.
    /// - Returns: The first subview that matches the view type or `nil` if no subview matches.
    public func firstSubview<V: NSUIView>(type _: V.Type, depth: Int = 0) -> V? {
        firstSubview(where: { $0 is V }, depth: depth) as? V
    }

    /// The first subview that matches the specificed view type.
    ///
    /// - Parameters:
    ///   - type: The type of view to match.
    ///   - depth: The maximum depth. As example a value of `0` returns the first subview matching of the receiver's subviews and a value of `1` returns the first subview matching of the receiver's subviews or any of their subviews. To return the first subview matching of all subviews use `max`.
    /// - Returns: The first subview that matches the view type or `nil` if no subview matches.
    public func firstSubview(type: String, depth: Int = 0) -> NSUIView? {
        firstSubview(where: { NSStringFromClass(Swift.type(of: $0)) == type }, depth: depth)
    }

    /// The first subview that matches the specificed predicate.
    ///
    /// - Parameters:
    ///   - predicate: TThe closure to match.
    ///   - depth: The maximum depth. As example a value of `0` returns the first subview matching of the receiver's subviews and a value of `1` returns the first subview matching of the receiver's subviews or any of their subviews. To return the first subview matching of all subviews use `max`.
    ///
    /// - Returns: The first subview that is matching the predicate or `nil` if no subview is matching.
    public func firstSubview(where predicate: (NSUIView) -> (Bool), depth: Int = 0) -> NSUIView? {
        if let subview = base.subviews.first(where: predicate) {
            return subview
        }
        if depth > 0 {
            for subview in base.subviews {
                if let subview = subview.box.firstSubview(where: predicate, depth: depth - 1) {
                    return subview
                }
            }
        }
        return nil
    }
}
