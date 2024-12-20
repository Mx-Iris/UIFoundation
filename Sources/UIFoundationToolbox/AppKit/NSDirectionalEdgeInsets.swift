//
//  File.swift
//  UIFoundation
//
//  Created by JH on 2024/12/20.
//

import FrameworkToolbox

#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

extension NSDirectionalEdgeInsets: @retroactive FrameworkToolboxCompatible {}

extension FrameworkToolbox<NSDirectionalEdgeInsets> {
    #if os(macOS)
    /// A directional edge insets structure whose top, leading, bottom, and trailing fields all have a value of ´0´.
    public static let zero = NSDirectionalEdgeInsets(0)
    #endif

   

    /// The width (leading + trailing) of the insets.
    public var width: CGFloat {
        get {
            base.leading + base.trailing
        }
        set {
            let value = newValue / 2.0
            base.leading = value
            base.trailing = value
        }
    }

    /// The height (top + bottom) of the insets.
    public var height: CGFloat {
        get {
            base.top + base.bottom
        }
        set {
            let value = newValue / 2.0
            base.top = value
            base.bottom = value
        }
    }

    /// The bottom and top value.
    public var bottomTop: CGFloat {
        get {
            Swift.max(base.bottom, base.top)
        }
        set {
            base.bottom = newValue
            base.top = newValue
        }
    }

    /// The leading and trailing value.
    public var leadingTrailing: CGFloat {
        get {
            Swift.max(base.leading, base.trailing)
        }
        set {
            base.leading = newValue
            base.trailing = newValue
        }
    }

    #if os(macOS)
    /// The insets as `NSEdgeInsets`.
    public var nsEdgeInsets: NSEdgeInsets {
        .init(top: base.top, left: base.leading, bottom: base.bottom, right: base.trailing)
    }

    #elseif canImport(UIKit)
    /// The insets as `UIEdgeInsets`.
    public var uiEdgeInsets: UIEdgeInsets {
        .init(top: base.top, left: base.leading, bottom: base.bottom, right: base.trailing)
    }
    #endif
}

extension NSDirectionalEdgeInsets: @retroactive ExpressibleByFloatLiteral, @retroactive ExpressibleByIntegerLiteral {
    
    public init(floatLiteral value: FloatLiteralType) {
        self.init(value)
    }
    
    public init(integerLiteral value: IntegerLiteralType) {
        self.init(CGFloat(value))
    }
    
    /// Creates an edge insets structure with the specified value for top, bottom, leading and trailing.
    public init(_ value: CGFloat) {
        self.init(top: value, leading: value, bottom: value, trailing: value)
    }

    /// Creates an edge insets structure with the specified width (leading + trailing) and height (top + bottom) values.
    public init(width: CGFloat = 0.0, height: CGFloat = 0.0) {
        self.init()
        self.box.width = width
        self.box.height = height
    }

    /// Creates an edge insets structure with the specified shared bottom/top and leading/trailing values.
    public init(bottomTop: CGFloat, leadingTrailing: CGFloat) {
        self.init(top: bottomTop, leading: leadingTrailing, bottom: bottomTop, trailing: leadingTrailing)
    }

    /// Creates an edge insets structure with the specified shared bottom and top values.
    public init(bottomTop: CGFloat) {
        self.init(bottomTop: bottomTop, leadingTrailing: 0.0)
    }

    /// Creates an edge insets structure with the specified shared leading and trailing values.
    public init(leadingTrailing: CGFloat) {
        self.init(bottomTop: 0.0, leadingTrailing: leadingTrailing)
    }
}

extension NSDirectionalEdgeInsets: @retroactive Equatable {}
extension NSDirectionalEdgeInsets: @retroactive Hashable {
    public static func == (lhs: NSDirectionalEdgeInsets, rhs: NSDirectionalEdgeInsets) -> Bool {
        lhs.hashValue == rhs.hashValue
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(top)
        hasher.combine(bottom)
        hasher.combine(trailing)
        hasher.combine(leading)
    }
}
