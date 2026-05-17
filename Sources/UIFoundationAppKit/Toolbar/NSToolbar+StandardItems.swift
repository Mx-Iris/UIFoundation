#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

extension FrameworkToolbox where Base: NSToolbar {

    /// A toolbar item that displays an empty space with a flexible width.
    public static func flexibleSpace() -> ToolbarItem {
        ToolbarItem(.flexibleSpace)
    }

    /// A toolbar item that displays an empty space with a standard fixed size.
    public static func space() -> ToolbarItem {
        ToolbarItem(.space)
    }

    /// A toolbar item that toggles a sidebar (sends `toggleSidebar(_:)`).
    public static func toggleSidebar() -> ToolbarItem {
        ToolbarItem(.toggleSidebar)
    }

    /// A toolbar item that displays a tracking separator aligned with the sidebar divider.
    @available(macOS 11.0, *)
    public static func sidebarTrackingSeparator() -> ToolbarItem {
        ToolbarItem(.sidebarTrackingSeparator)
    }

    /// A toolbar item that toggles an inspector pane (sends `toggleInspector(_:)`).
    @available(macOS 14.0, *)
    public static func toggleInspector() -> ToolbarItem {
        ToolbarItem(.toggleInspector)
    }

    /// A toolbar item that displays a tracking separator aligned with the inspector divider.
    @available(macOS 14.0, *)
    public static func inspectorTrackingSeparator() -> ToolbarItem {
        ToolbarItem(.inspectorTrackingSeparator)
    }

    /// A toolbar item that prints the current document (sends `printDocument(_:)`).
    public static func print() -> ToolbarItem {
        ToolbarItem(.print)
    }

    /// A toolbar item that shows the standard color panel.
    public static func showColors() -> ToolbarItem {
        ToolbarItem(.showColors)
    }

    /// A toolbar item that shows the standard font panel.
    public static func showFonts() -> ToolbarItem {
        ToolbarItem(.showFonts)
    }

    /// A toolbar item that displays the iCloud sharing interface.
    public static func cloudSharing() -> ToolbarItem {
        ToolbarItem(.cloudSharing)
    }

    /// A toolbar item that shows writing tools (sends `showWritingTools(_:)`).
    @available(macOS 15.2, *)
    public static func writingTools() -> ToolbarItem {
        ToolbarItem(NSToolbarItem.Identifier("NSToolbarWritingToolsItem"))
    }
}

#endif
