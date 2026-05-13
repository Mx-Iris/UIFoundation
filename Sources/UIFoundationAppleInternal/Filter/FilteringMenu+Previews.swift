#if FilterUI

import SwiftUI
import UIFoundationAppKit

@available(macOS 12.0, *)
struct FilteringMenu_Previews: PreviewProvider {
    static var previews: some View {
        NSViewPreview {
            let menu = FilteringMenu()
            menu.autoenablesItems = false
            menu.addItem(tableItem("actors"))
            menu.addItem(tableItem("categories"))
            menu.addItem(tableItem("film"))
            menu.addItem(tableItem("staff"))
            menu.addItem(procedureItem("film_inserted"))
            menu.addItem(procedureItem("film_deleted"))

            let view = NSView()
            view.menu = menu
            return view
        }
    }

    static func tableItem(_ name: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: nil)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [tableColor]))
        // .tinted(with: tableColor)
        item.title = name
        let submenu = FilteringMenu()
        submenu.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        submenu.autoenablesItems = false
        submenu.addItem(columnItem("id", type: "uuid"))
        submenu.addItem(columnItem("name", type: "varchar"))
        submenu.addItem(columnItem("score", type: "numeric(2)"))
        submenu.addItem(columnItem("is_enabled", type: "bool"))
        item.submenu = submenu
        return item
    }

    static func procedureItem(_ name: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.image = NSImage(systemSymbolName: "scroll", accessibilityDescription: nil)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.systemGray]))
        // .tinted(with: .systemGray)
        item.title = name
        return item
    }

    static func columnItem(_ name: String, type: String) -> NSMenuItem {
        let item = NSMenuItem()
        item.image = NSImage(systemSymbolName: "app", accessibilityDescription: nil)!
            .withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [.systemPurple]))
        // .tinted(with: .systemPurple)
        item.title = name
        let string = NSMutableAttributedString(string: name)
        string.append(NSAttributedString(string: " " + type, attributes: [
            .foregroundColor: NSColor.secondaryLabelColor,
        ]))
        item.attributedTitle = string
        return item
    }

    static let tableColor = NSColor(calibratedRed: 87 / 255, green: 113 / 255, blue: 146 / 255, alpha: 1)
}

#endif
