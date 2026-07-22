//
//  Helpers.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabBar && os(macOS)

import AppKit

extension TabBar {
    /// `Offset` is a simple `NSPoint` typealias used to increase readability in layout maths.
    public typealias Offset = NSPoint
}

extension TabBar.Offset {
    init(x: CGFloat) {
        self.init()
        self.x = x
        self.y = 0
    }

    init(y: CGFloat) {
        self.init()
        self.x = 0
        self.y = y
    }
}

/// Addition operator for an `NSPoint` and a ``TabBar/Offset``.
func + (lhs: NSPoint, rhs: TabBar.Offset) -> NSPoint {
    return NSPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
}

extension NSRect {
    /// Returns a copy whose width and height are reduced by `dx` and `dy`.
    func shrinkBy(dx: CGFloat, dy: CGFloat) -> NSRect {
        var result = self
        result.size = CGSize(width: result.size.width - dx, height: result.size.height - dy)
        return result
    }
}

#endif
