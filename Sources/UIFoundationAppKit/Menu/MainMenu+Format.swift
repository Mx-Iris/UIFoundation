#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    /// Standard items of the Format menu, addressed as `.Format.font`,
    /// `.Format.Font.bold`, `.Format.Font.Kern.tighten` etc.
    public enum Format {
        /// Wiring marker: the assembly step installs this submenu via
        /// `NSFontManager.setFontMenu(_:)`.
        public static let font = standard("Format.font")
        public static let text = standard("Format.text")

        public enum Font {
            public static let showFonts = standard("Format.Font.showFonts")
            public static let bold = standard("Format.Font.bold")
            public static let italic = standard("Format.Font.italic")
            public static let underline = standard("Format.Font.underline")
            public static let bigger = standard("Format.Font.bigger")
            public static let smaller = standard("Format.Font.smaller")
            public static let kern = standard("Format.Font.kern")
            public static let ligatures = standard("Format.Font.ligatures")
            public static let baseline = standard("Format.Font.baseline")
            public static let showColors = standard("Format.Font.showColors")
            public static let copyStyle = standard("Format.Font.copyStyle")
            public static let pasteStyle = standard("Format.Font.pasteStyle")

            public enum Kern {
                public static let useDefault = standard("Format.Font.Kern.useDefault")
                public static let useNone = standard("Format.Font.Kern.useNone")
                public static let tighten = standard("Format.Font.Kern.tighten")
                public static let loosen = standard("Format.Font.Kern.loosen")
            }

            public enum Ligatures {
                public static let useDefault = standard("Format.Font.Ligatures.useDefault")
                public static let useNone = standard("Format.Font.Ligatures.useNone")
                public static let useAll = standard("Format.Font.Ligatures.useAll")
            }

            public enum Baseline {
                public static let useDefault = standard("Format.Font.Baseline.useDefault")
                public static let superscript = standard("Format.Font.Baseline.superscript")
                public static let `subscript` = standard("Format.Font.Baseline.subscript")
                public static let raise = standard("Format.Font.Baseline.raise")
                public static let lower = standard("Format.Font.Baseline.lower")
            }
        }

        public enum Text {
            public static let alignLeft = standard("Format.Text.alignLeft")
            public static let center = standard("Format.Text.center")
            public static let justify = standard("Format.Text.justify")
            public static let alignRight = standard("Format.Text.alignRight")
            public static let writingDirection = standard("Format.Text.writingDirection")
            public static let showRuler = standard("Format.Text.showRuler")
            public static let copyRuler = standard("Format.Text.copyRuler")
            public static let pasteRuler = standard("Format.Text.pasteRuler")

            public enum WritingDirection {
                public static let paragraphHeader = standard("Format.Text.WritingDirection.paragraphHeader")
                public static let paragraphDefault = standard("Format.Text.WritingDirection.paragraphDefault")
                public static let paragraphLeftToRight = standard("Format.Text.WritingDirection.paragraphLeftToRight")
                public static let paragraphRightToLeft = standard("Format.Text.WritingDirection.paragraphRightToLeft")
                public static let selectionHeader = standard("Format.Text.WritingDirection.selectionHeader")
                public static let selectionDefault = standard("Format.Text.WritingDirection.selectionDefault")
                public static let selectionLeftToRight = standard("Format.Text.WritingDirection.selectionLeftToRight")
                public static let selectionRightToLeft = standard("Format.Text.WritingDirection.selectionRightToLeft")
            }
        }
    }
}

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
            .identifier(ItemIdentifier.format)
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
                NSMenuItem("Show Fonts", action: #Selector("orderFrontFontPanel:"), keyEquivalent: "t")
                    .target(fontManager)
                    .identifier(ItemIdentifier.Format.Font.showFonts)
                NSMenuItem("Bold", action: #Selector("addFontTrait:"), keyEquivalent: "b")
                    .target(fontManager)
                    .tag(2)
                    .identifier(ItemIdentifier.Format.Font.bold)
                NSMenuItem("Italic", action: #Selector("addFontTrait:"), keyEquivalent: "i")
                    .target(fontManager)
                    .tag(1)
                    .identifier(ItemIdentifier.Format.Font.italic)
                NSMenuItem("Underline", action: #Selector("underline:"), keyEquivalent: "u")
                    .identifier(ItemIdentifier.Format.Font.underline)
                NSMenuItem.separator()
                NSMenuItem("Bigger", action: #Selector("modifyFont:"), keyEquivalent: "+")
                    .target(fontManager)
                    .tag(3)
                    .identifier(ItemIdentifier.Format.Font.bigger)
                NSMenuItem("Smaller", action: #Selector("modifyFont:"), keyEquivalent: "-")
                    .target(fontManager)
                    .tag(4)
                    .identifier(ItemIdentifier.Format.Font.smaller)
                NSMenuItem.separator()
                NSMenuItem("Kern") {
                    NSMenuItem("Use Default", action: #Selector("useStandardKerning:"))
                        .identifier(ItemIdentifier.Format.Font.Kern.useDefault)
                    NSMenuItem("Use None", action: #Selector("turnOffKerning:"))
                        .identifier(ItemIdentifier.Format.Font.Kern.useNone)
                    NSMenuItem("Tighten", action: #Selector("tightenKerning:"))
                        .identifier(ItemIdentifier.Format.Font.Kern.tighten)
                    NSMenuItem("Loosen", action: #Selector("loosenKerning:"))
                        .identifier(ItemIdentifier.Format.Font.Kern.loosen)
                }
                .identifier(ItemIdentifier.Format.Font.kern)
                NSMenuItem("Ligatures") {
                    NSMenuItem("Use Default", action: #Selector("useStandardLigatures:"))
                        .identifier(ItemIdentifier.Format.Font.Ligatures.useDefault)
                    NSMenuItem("Use None", action: #Selector("turnOffLigatures:"))
                        .identifier(ItemIdentifier.Format.Font.Ligatures.useNone)
                    NSMenuItem("Use All", action: #Selector("useAllLigatures:"))
                        .identifier(ItemIdentifier.Format.Font.Ligatures.useAll)
                }
                .identifier(ItemIdentifier.Format.Font.ligatures)
                NSMenuItem("Baseline") {
                    NSMenuItem("Use Default", action: #Selector("unscript:"))
                        .identifier(ItemIdentifier.Format.Font.Baseline.useDefault)
                    NSMenuItem("Superscript", action: #Selector("superscript:"))
                        .identifier(ItemIdentifier.Format.Font.Baseline.superscript)
                    NSMenuItem("Subscript", action: #Selector("subscript:"))
                        .identifier(ItemIdentifier.Format.Font.Baseline.`subscript`)
                    NSMenuItem("Raise", action: #Selector("raiseBaseline:"))
                        .identifier(ItemIdentifier.Format.Font.Baseline.raise)
                    NSMenuItem("Lower", action: #Selector("lowerBaseline:"))
                        .identifier(ItemIdentifier.Format.Font.Baseline.lower)
                }
                .identifier(ItemIdentifier.Format.Font.baseline)
                NSMenuItem.separator()
                NSMenuItem("Show Colors", action: #Selector("orderFrontColorPanel:"), keyEquivalent: "C")
                    .identifier(ItemIdentifier.Format.Font.showColors)
                NSMenuItem.separator()
                NSMenuItem("Copy Style", action: #Selector("copyFont:"), keyEquivalent: "c", modifiers: [.option, .command])
                    .identifier(ItemIdentifier.Format.Font.copyStyle)
                NSMenuItem("Paste Style", action: #Selector("pasteFont:"), keyEquivalent: "v", modifiers: [.option, .command])
                    .identifier(ItemIdentifier.Format.Font.pasteStyle)
            }
            .identifier(ItemIdentifier.Format.font)
        }

        /// The Text submenu. The Writing Direction section headers are the
        /// template's disabled plain items, and the direction items keep the
        /// template's tab-prefixed titles — both are how the xib renders the
        /// indented Paragraph / Selection groups.
        public static func text() -> NSMenuItem {
            NSMenuItem("Text") {
                NSMenuItem("Align Left", action: #Selector("alignLeft:"), keyEquivalent: "{")
                    .identifier(ItemIdentifier.Format.Text.alignLeft)
                NSMenuItem("Center", action: #Selector("alignCenter:"), keyEquivalent: "|")
                    .identifier(ItemIdentifier.Format.Text.center)
                NSMenuItem("Justify", action: #Selector("alignJustified:"))
                    .identifier(ItemIdentifier.Format.Text.justify)
                NSMenuItem("Align Right", action: #Selector("alignRight:"), keyEquivalent: "}")
                    .identifier(ItemIdentifier.Format.Text.alignRight)
                NSMenuItem.separator()
                NSMenuItem("Writing Direction") {
                    NSMenuItem("Paragraph")
                        .isEnabled(false)
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.paragraphHeader)
                    NSMenuItem("\tDefault", action: #Selector("makeBaseWritingDirectionNatural:"))
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.paragraphDefault)
                    NSMenuItem("\tLeft to Right", action: #Selector("makeBaseWritingDirectionLeftToRight:"))
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.paragraphLeftToRight)
                    NSMenuItem("\tRight to Left", action: #Selector("makeBaseWritingDirectionRightToLeft:"))
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.paragraphRightToLeft)
                    NSMenuItem.separator()
                    NSMenuItem("Selection")
                        .isEnabled(false)
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.selectionHeader)
                    NSMenuItem("\tDefault", action: #Selector("makeTextWritingDirectionNatural:"))
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.selectionDefault)
                    NSMenuItem("\tLeft to Right", action: #Selector("makeTextWritingDirectionLeftToRight:"))
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.selectionLeftToRight)
                    NSMenuItem("\tRight to Left", action: #Selector("makeTextWritingDirectionRightToLeft:"))
                        .identifier(ItemIdentifier.Format.Text.WritingDirection.selectionRightToLeft)
                }
                .identifier(ItemIdentifier.Format.Text.writingDirection)
                NSMenuItem.separator()
                NSMenuItem("Show Ruler", action: #Selector("toggleRuler:"))
                    .identifier(ItemIdentifier.Format.Text.showRuler)
                NSMenuItem("Copy Ruler", action: #Selector("copyRuler:"), keyEquivalent: "c", modifiers: [.control, .command])
                    .identifier(ItemIdentifier.Format.Text.copyRuler)
                NSMenuItem("Paste Ruler", action: #Selector("pasteRuler:"), keyEquivalent: "v", modifiers: [.control, .command])
                    .identifier(ItemIdentifier.Format.Text.pasteRuler)
            }
            .identifier(ItemIdentifier.Format.text)
        }
    }
}

#endif
