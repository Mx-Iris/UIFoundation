#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif
import FrameworkToolbox
import UIFoundationTypealias

extension FrameworkToolbox where Base == CGRect {
    public func inset(by insets: NSUIEdgeInsets) -> CGRect {
        return CGRect(
            x: base.origin.x + insets.left,
            y: base.origin.y + insets.top,
            width: base.width - (insets.left + insets.right),
            height: base.height - (insets.top + insets.bottom)
        )
    }

    public enum Inset {
        case left(CGFloat)
        case right(CGFloat)
        case top(CGFloat)
        case bottom(CGFloat)
    }

    public func inset(_ insets: Inset...) -> CGRect {
        var result = base
        for inset in insets {
            switch inset {
            case let .left(value):
                result = self.inset(by: NSUIEdgeInsets(top: 0, left: value, bottom: 0, right: 0))
            case let .right(value):
                result = self.inset(by: NSUIEdgeInsets(top: 0, left: 0, bottom: 0, right: value))
            case let .top(value):
                result = self.inset(by: NSUIEdgeInsets(top: value, left: 0, bottom: 0, right: 0))
            case let .bottom(value):
                result = self.inset(by: NSUIEdgeInsets(top: 0, left: 0, bottom: value, right: 0))
            }
        }
        return result
    }

    public func inset(dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
        base.insetBy(dx: dx, dy: dy)
    }

    public func scale(_ scale: CGSize) -> CGRect {
        base.applying(.init(scaleX: scale.width, y: scale.height))
    }

    public func margin(_ margin: CGSize) -> CGRect {
        base.insetBy(dx: -margin.width / 2, dy: -margin.height / 2)
    }

    public func moved(dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
        base.applying(.init(translationX: dx, y: dy))
    }

    public func moved(by point: CGPoint) -> CGRect {
        base.applying(.init(translationX: point.x, y: point.y))
    }

    public func margin(top: CGFloat = 0, left: CGFloat = 0, bottom: CGFloat = 0, right: CGFloat = 0) -> CGRect {
        inset(by: .init(top: -top, left: -left, bottom: -bottom, right: -right))
    }

    public var pixelAligned: CGRect {
        // https://developer.apple.com/library/archive/documentation/GraphicsAnimation/Conceptual/HighResolutionOSX/APIs/APIs.html#//apple_ref/doc/uid/TP40012302-CH5-SW9
        // NSIntegralRectWithOptions(self, [.alignMinXOutward, .alignMinYOutward, .alignWidthOutward, .alignMaxYOutward])
        #if os(macOS)
        NSIntegralRectWithOptions(base, .alignAllEdgesNearest)
        #else
        // NSIntegralRectWithOptions is not available in ObjC Foundation on iOS
        // "self.integral" is not the same, but for now it has to be enough
        // https://twitter.com/krzyzanowskim/status/1512451888515629063
        base.integral
        #endif
    }
}

extension CGRect: @retroactive FrameworkToolboxCompatible, @retroactive FrameworkToolboxDynamicMemberLookup {}
