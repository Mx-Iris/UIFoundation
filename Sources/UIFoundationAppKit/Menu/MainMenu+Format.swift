#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension MainMenu {
    /// The Format menu with the template's standard content.
    public static func format(title: String = "Format") -> NSMenuItem {
        format(title: title) {
            Format.font()
            Format.text()
        }
    }

    /// The Format menu with custom content.
    public static func format(title: String = "Format", @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem {
        NSMenuItem(title, submenu: items)
    }

    /// Standard items of the Format menu.
    @MainActor
    public enum Format {
        /// The Font submenu. The template targets Show Fonts / Bold / Italic /
        /// Bigger / Smaller directly at `NSFontManager` (everything else goes
        /// to the first responder); the numeric tags are the `NSFontTraitMask`
        /// and `NSFontAction` values the template hardcodes. The assembly step
        /// installs the submenu as the font manager's font menu.
        public static func font() -> NSMenuItem {
            let fontManager = NSFontManager.shared
            return NSMenuItem("Font") {
                NSMenuItem("Show Fonts", action: Selector(("orderFrontFontPanel:")), keyEquivalent: "t").target(fontManager)
                NSMenuItem("Bold", action: Selector(("addFontTrait:")), keyEquivalent: "b").target(fontManager).tag(2)
                NSMenuItem("Italic", action: Selector(("addFontTrait:")), keyEquivalent: "i").target(fontManager).tag(1)
                NSMenuItem("Underline", action: Selector(("underline:")), keyEquivalent: "u")
                NSMenuItem.separator()
                NSMenuItem("Bigger", action: Selector(("modifyFont:")), keyEquivalent: "+").target(fontManager).tag(3)
                NSMenuItem("Smaller", action: Selector(("modifyFont:")), keyEquivalent: "-").target(fontManager).tag(4)
                NSMenuItem.separator()
                NSMenuItem("Kern") {
                    NSMenuItem("Use Default", action: Selector(("useStandardKerning:")))
                    NSMenuItem("Use None", action: Selector(("turnOffKerning:")))
                    NSMenuItem("Tighten", action: Selector(("tightenKerning:")))
                    NSMenuItem("Loosen", action: Selector(("loosenKerning:")))
                }
                NSMenuItem("Ligatures") {
                    NSMenuItem("Use Default", action: Selector(("useStandardLigatures:")))
                    NSMenuItem("Use None", action: Selector(("turnOffLigatures:")))
                    NSMenuItem("Use All", action: Selector(("useAllLigatures:")))
                }
                NSMenuItem("Baseline") {
                    NSMenuItem("Use Default", action: Selector(("unscript:")))
                    NSMenuItem("Superscript", action: Selector(("superscript:")))
                    NSMenuItem("Subscript", action: Selector(("subscript:")))
                    NSMenuItem("Raise", action: Selector(("raiseBaseline:")))
                    NSMenuItem("Lower", action: Selector(("lowerBaseline:")))
                }
                NSMenuItem.separator()
                NSMenuItem("Show Colors", action: Selector(("orderFrontColorPanel:")), keyEquivalent: "C")
                NSMenuItem.separator()
                NSMenuItem("Copy Style", action: Selector(("copyFont:")), keyEquivalent: "c", modifiers: [.option, .command])
                NSMenuItem("Paste Style", action: Selector(("pasteFont:")), keyEquivalent: "v", modifiers: [.option, .command])
            }
            .identifier(ItemIdentifier.font)
        }

        /// The Text submenu. The Writing Direction section headers are the
        /// template's disabled plain items, and the direction items keep the
        /// template's tab-prefixed titles — both are how the xib renders the
        /// indented Paragraph / Selection groups.
        public static func text() -> NSMenuItem {
            NSMenuItem("Text") {
                NSMenuItem("Align Left", action: Selector(("alignLeft:")), keyEquivalent: "{")
                NSMenuItem("Center", action: Selector(("alignCenter:")), keyEquivalent: "|")
                NSMenuItem("Justify", action: Selector(("alignJustified:")))
                NSMenuItem("Align Right", action: Selector(("alignRight:")), keyEquivalent: "}")
                NSMenuItem.separator()
                NSMenuItem("Writing Direction") {
                    NSMenuItem("Paragraph").isEnabled(false)
                    NSMenuItem("\tDefault", action: Selector(("makeBaseWritingDirectionNatural:")))
                    NSMenuItem("\tLeft to Right", action: Selector(("makeBaseWritingDirectionLeftToRight:")))
                    NSMenuItem("\tRight to Left", action: Selector(("makeBaseWritingDirectionRightToLeft:")))
                    NSMenuItem.separator()
                    NSMenuItem("Selection").isEnabled(false)
                    NSMenuItem("\tDefault", action: Selector(("makeTextWritingDirectionNatural:")))
                    NSMenuItem("\tLeft to Right", action: Selector(("makeTextWritingDirectionLeftToRight:")))
                    NSMenuItem("\tRight to Left", action: Selector(("makeTextWritingDirectionRightToLeft:")))
                }
                NSMenuItem.separator()
                NSMenuItem("Show Ruler", action: Selector(("toggleRuler:")))
                NSMenuItem("Copy Ruler", action: Selector(("copyRuler:")), keyEquivalent: "c", modifiers: [.control, .command])
                NSMenuItem("Paste Ruler", action: Selector(("pasteRuler:")), keyEquivalent: "v", modifiers: [.control, .command])
            }
        }
    }
}

#endif
