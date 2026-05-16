//
//  FlippedContainerView.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

import AppKit

extension QuickActionBar {
    /// A flipped `NSView` (origin at top-left) used as the window's content view.
    ///
    /// Keeps subviews pinned to the top at a constant y-coordinate when the window
    /// frame changes, preventing layout jumps during the expand/collapse animation.
    internal final class FlippedContainerView: NSView {
        override var isFlipped: Bool { return true }
    }
}

#endif
