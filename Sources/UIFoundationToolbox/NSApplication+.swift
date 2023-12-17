//
//  NSApplication.swift
//  SegmentedControl
//
//  Created by John on 30/03/2021.
//

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSApplication {

    /**
     * Perform block with the application's effectiveAppearance.
     * For example this allows fetching the correct named color from a NSColor e.g.
     *
     * NSApp.withEffectiveAppearance {
     *     appearanceAwareColor = NSColor.textColor.cgColor
     * }
     */
    public func withEffectiveAppearance(_ block: () -> Void) {
        if #available(*, macOS 11) {
            base.effectiveAppearance.performAsCurrentDrawingAppearance(block)
        } else {
            let previousAppearance = NSAppearance.current
            NSAppearance.current = base.effectiveAppearance
            block()
            NSAppearance.current = previousAppearance
        }
    }

}
