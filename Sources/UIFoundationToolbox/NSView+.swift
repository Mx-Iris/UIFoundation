#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
import UIFoundationTypealias
import AssociatedObject

extension FrameworkToolbox where Base: NSView {
    public func scrollPageDown() {
        base.scroll(base.visibleRect.box.moved(dy: base.visibleRect.height).origin)
    }

    public func scrollPageUp() {
        base.scroll(base.visibleRect.box.moved(dy: -base.visibleRect.height).origin)
    }

    public func scrollToBeginningOfDocument() {
        base.scroll(CGPoint(x: base.visibleRect.origin.x, y: base.frame.minY))
    }

    public func scrollToEndOfDocument() {
        base.scroll(CGPoint(x: base.visibleRect.origin.x, y: base.frame.maxY))
    }

    private class GestureRecognizerHandler<GestureRecognizer: NSGestureRecognizer>: NSObject {
        var action: (GestureRecognizer) -> Void

        init(action: @escaping (GestureRecognizer) -> Void) {
            self.action = action
        }

        @objc func handleGestureRecognizerAction(_ sender: NSGestureRecognizer) {
            action(sender as! GestureRecognizer)
        }
    }

    @AssociatedObject(.retain(.nonatomic))
    private var actionHandlers: [NSObject] = []

    public mutating func addGestureRecognizer<Configuration: GestureRecognizerConfiguration>(for configuration: Configuration, action: @escaping (Configuration.GestureRecognizer) -> Void) {
        let gestureRecognizer = configuration.makeGestureRecognizer()
        let actionHandler = GestureRecognizerHandler<Configuration.GestureRecognizer>(action: action)
        gestureRecognizer.target = actionHandler
        gestureRecognizer.action = #selector(GestureRecognizerHandler.handleGestureRecognizerAction(_:))
        base.addGestureRecognizer(gestureRecognizer)
        actionHandlers.append(actionHandler)
    }
    
    public func addSubview(_ subview: NSUIView, fill: Bool) {
        base.addSubview(subview)
        if fill {
            subview.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                subview.topAnchor.constraint(equalTo: base.topAnchor),
                subview.leadingAnchor.constraint(equalTo: base.leadingAnchor),
                subview.trailingAnchor.constraint(equalTo: base.trailingAnchor),
                subview.bottomAnchor.constraint(equalTo: base.bottomAnchor),
            ])
        }
    }
}

// enum GestureRecognizerConfiguration {
//
//    case click(mask: ButtonMask, numberOfClicks: Int, numberOfTouches: Int?)
//    case press(mask: ButtonMask, minimumPressDuration: TimeInterval, allowableMovement: CGFloat, numberOfTouchesRequired: Int?)
//    case pan(mask: ButtonMask, numberOfTouchesRequired: Int?)
//
//
// }

public protocol GestureRecognizerConfiguration {
    associatedtype GestureRecognizer: NSGestureRecognizer
    func makeGestureRecognizer() -> GestureRecognizer
}

public struct GestureRecognizerButtonMask: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    public static let primary = Self(rawValue: 1 << 0)
    public static let secondary = Self(rawValue: 1 << 1)
}

public struct ClickGestureRecognizerConfiguration: GestureRecognizerConfiguration {
    public var buttonMask: GestureRecognizerButtonMask
    public var numberOfClicks: Int
    public var numberOfTouchesRequired: Int

    public init(buttonMask: GestureRecognizerButtonMask = .primary, numberOfClicks: Int = 1, numberOfTouchesRequired: Int = 1) {
        self.buttonMask = buttonMask
        self.numberOfClicks = numberOfClicks
        self.numberOfTouchesRequired = numberOfTouchesRequired
    }
    
    public func makeGestureRecognizer() -> NSClickGestureRecognizer {
        let gesture = NSClickGestureRecognizer()
        gesture.buttonMask = buttonMask.rawValue
        gesture.numberOfClicksRequired = numberOfClicks
        gesture.numberOfTouchesRequired = numberOfTouchesRequired
        return gesture
    }
}

//public struct Press {}
//
//public struct Pan {}

#endif
