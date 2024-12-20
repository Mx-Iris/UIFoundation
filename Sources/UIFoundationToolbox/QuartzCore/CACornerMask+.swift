//
//  CACornerMask+.swift
//
//
//  Created by Florian Zand on 23.02.23.
//

#if canImport(QuartzCore)
import FrameworkToolbox
import QuartzCore.CoreAnimation

extension CACornerMask: @retroactive FrameworkToolboxCompatible {}

extension FrameworkToolbox<CACornerMask> {
    /// All corners.
    public static var all: CACornerMask = [.box.bottomLeft, .box.bottomRight, .box.topLeft, .box.topRight]
    /// No ocrners.
    public static var none: CACornerMask = []

    #if os(macOS)
    /// The bottom-left corner.
    public static var bottomLeft = CACornerMask.layerMinXMinYCorner
    /// The bottom-right corner.
    public static var bottomRight = CACornerMask.layerMaxXMinYCorner
    /// The top-left corner.
    public static var topLeft = CACornerMask.layerMinXMaxYCorner
    /// The top-right corner.
    public static var topRight = CACornerMask.layerMaxXMaxYCorner

    /// The Bottom-left and bottom-right corner.
    public static var bottomCorners: CACornerMask = [
        .layerMaxXMinYCorner,
        .layerMinXMinYCorner,
    ]

    /// The top-left and top-right corner.
    public static var topCorners: CACornerMask = [
        .layerMinXMaxYCorner,
        .layerMaxXMaxYCorner,
    ]
    #elseif canImport(UIKit)
    /// The bottom-left corner.
    public static var bottomLeft = CACornerMask.layerMinXMaxYCorner
    /// The bottom-right corner.
    public static var bottomRight = CACornerMask.layerMaxXMaxYCorner
    /// The top-left corner.
    public static var topLeft = CACornerMask.layerMinXMinYCorner
    /// The top-right corner.
    public static var topRight = CACornerMask.layerMaxXMinYCorner

    /// The Bottom-left and bottom-right corner.
    public static var bottomCorners: CACornerMask = [
        .layerMaxXMaxYCorner,
        .layerMinXMaxYCorner,
    ]

    /// The top-left and top-right corner.
    public static var topCorners: CACornerMask = [
        .layerMinXMinYCorner,
        .layerMaxXMinYCorner,
    ]
    #endif

    /// The Bottom-left and top-left corner.
    public static var leftCorners: CACornerMask = [
        .layerMinXMinYCorner,
        .layerMinXMaxYCorner,
    ]

    /// The Bottom-right and top-right corner.
    public static var rightCorners: CACornerMask = [
        .layerMaxXMinYCorner,
        .layerMaxXMaxYCorner,
    ]
}

extension CACornerMask: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
#endif
