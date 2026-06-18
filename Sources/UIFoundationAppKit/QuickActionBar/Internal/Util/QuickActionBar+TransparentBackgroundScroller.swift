//
//  QuickActionBar+TransparentBackgroundScroller.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import AppKit
import Foundation

extension QuickActionBar {
    /// A scroller with a transparent background.
    internal final class TransparentBackgroundScroller: NSScroller {
        override func draw(_ dirtyRect: NSRect) {
            NSColor.clear.set()
            dirtyRect.fill()
            self.drawKnob()
        }
    }
}

#endif
