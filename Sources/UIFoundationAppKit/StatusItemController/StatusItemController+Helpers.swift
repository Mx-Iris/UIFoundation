//
//  Ported from hexedbits/StatusItemController (MIT)
//  https://github.com/hexedbits/StatusItemController
//
//  Original Author: Jesse Squires
//  Copyright © 2020-present Jesse Squires, Hexed Bits
//
//  The two right-click helpers below are internalized (suffixed with
//  `ForStatusItem`) to keep the upstream's public `isRightClickUp` /
//  `isCurrentEventRightClickUp` properties from leaking into UIFoundation's
//  top-level AppKit namespace. They exist solely to support
//  `StatusItemController`'s left/right click dispatch.
//

#if StatusItemController && os(macOS)

import AppKit

extension NSEvent {
    /// Returns `true` if the event is `.rightMouseUp` or a control-click equivalent.
    internal var isRightClickUpForStatusItem: Bool {
        let isRightClick = (self.type == .rightMouseUp)
        let isControlClick = self.modifierFlags.contains(.control)
        return isRightClick || isControlClick
    }
}

extension NSApplication {
    /// Returns `true` if the application's current event is a right-click-up or control-click equivalent.
    internal var isCurrentEventRightClickUpForStatusItem: Bool {
        self.currentEvent?.isRightClickUpForStatusItem ?? false
    }
}

#endif
