//
//  TabBarCell.swift
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

final class TabBarCell: NSCell {
    var style: TabBar.Style! {
        didSet { controlView?.needsDisplay = true }
    }

    override init(textCell aString: String) {
        super.init(textCell: aString)

        self.isBordered = true
        self.backgroundStyle = .light
        self.focusRingType = .none
        self.isEnabled = false
        self.font = NSFont.systemFont(ofSize: 13)
    }

    required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override func cellSize(forBounds aRect: NSRect) -> NSSize {
        return NSSize(width: 36.0, height: 0.0)
    }

    override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        guard style != nil else { return }

        style.drawTabBarBezel(frame: cellFrame)
    }
}

#endif
