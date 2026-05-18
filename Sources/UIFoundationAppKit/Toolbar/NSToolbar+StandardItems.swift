#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

extension FrameworkToolbox where Base: NSToolbar {

    /// A toolbar item that displays an empty space with a flexible width.
    public static var flexibleSpace: ToolbarItem {
        ToolbarItem(.flexibleSpace)
    }

    /// A toolbar item that displays an empty space with a standard fixed size.
    public static var space: ToolbarItem {
        ToolbarItem(.space)
    }

    /// A toolbar item that toggles a sidebar (sends `toggleSidebar(_:)`).
    public static var toggleSidebar: ToolbarItem {
        ToolbarItem(.toggleSidebar)
    }

    /// A toolbar item that displays a tracking separator aligned with the sidebar divider.
    @available(macOS 11.0, *)
    public static var sidebarTrackingSeparator: ToolbarItem {
        ToolbarItem(.sidebarTrackingSeparator)
    }

    /// A toolbar item that toggles an inspector pane (sends `toggleInspector(_:)`).
    @available(macOS 14.0, *)
    public static var toggleInspector: ToolbarItem {
        ToolbarItem(.toggleInspector)
    }

    /// A toolbar item that displays a tracking separator aligned with the inspector divider.
    @available(macOS 14.0, *)
    public static var inspectorTrackingSeparator: ToolbarItem {
        ToolbarItem(.inspectorTrackingSeparator)
    }

    /// A toolbar item that prints the current document (sends `printDocument(_:)`).
    public static var print: ToolbarItem {
        ToolbarItem(.print)
    }

    /// A toolbar item that shows the standard color panel.
    public static var showColors: ToolbarItem {
        ToolbarItem(.showColors)
    }

    /// A toolbar item that shows the standard font panel.
    public static var showFonts: ToolbarItem {
        ToolbarItem(.showFonts)
    }

    /// A toolbar item that displays the iCloud sharing interface.
    public static var cloudSharing: ToolbarItem {
        ToolbarItem(.cloudSharing)
    }

    /// A toolbar item that shows writing tools (sends `showWritingTools(_:)`).
    @available(macOS 15.2, *)
    public static var writingTools: ToolbarItem {
        ToolbarItem(NSToolbarItem.Identifier("NSToolbarWritingToolsItem"))
    }
}

#endif
