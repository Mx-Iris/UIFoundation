#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

extension FrameworkToolbox where Base: NSToolbar {
    /// A vertical line separator that can be inserted between toolbar items.
    public static func separator() -> ToolbarItem {
        let margin: CGFloat = 4
        let lineWidth: CGFloat = 1
        let height: CGFloat = 16
        let containerWidth = margin * 2 + lineWidth

        let container = NSView(frame: NSRect(x: 0, y: 0, width: containerWidth, height: height))
        let line = NSBox(frame: NSRect(x: margin, y: 0, width: lineWidth, height: height))
        line.boxType = .separator
        line.fillColor = .separatorColor
        container.addSubview(line)

        return NSToolbar.View(NSToolbarItem.Identifier("UIFoundation.Toolbar.separator"), view: container)
    }
}

#endif
