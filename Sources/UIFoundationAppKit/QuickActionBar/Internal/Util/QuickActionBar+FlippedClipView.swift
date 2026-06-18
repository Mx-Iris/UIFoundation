//
//  QuickActionBar+FlippedClipView.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import AppKit.NSClipView

extension QuickActionBar {
    /// A simple flipped clip view for `NSScrollView`.
    internal final class FlippedClipView: NSClipView {
        override var isFlipped: Bool { return true }
    }
}

#endif
