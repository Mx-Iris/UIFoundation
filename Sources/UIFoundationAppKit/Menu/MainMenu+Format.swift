#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    /// Wiring marker: the assembly step installs this submenu via
    /// `NSFontManager.setFontMenu(_:)`.
    public static let font = standard("font")
    public static let formatFontShowFonts = standard("formatFontShowFonts")
    public static let formatFontBold = standard("formatFontBold")
    public static let formatFontItalic = standard("formatFontItalic")
    public static let formatFontUnderline = standard("formatFontUnderline")
    public static let formatFontBigger = standard("formatFontBigger")
    public static let formatFontSmaller = standard("formatFontSmaller")
    public static let formatFontKern = standard("formatFontKern")
    public static let formatFontKernUseDefault = standard("formatFontKernUseDefault")
    public static let formatFontKernUseNone = standard("formatFontKernUseNone")
    public static let formatFontKernTighten = standard("formatFontKernTighten")
    public static let formatFontKernLoosen = standard("formatFontKernLoosen")
    public static let formatFontLigatures = standard("formatFontLigatures")
    public static let formatFontLigaturesUseDefault = standard("formatFontLigaturesUseDefault")
    public static let formatFontLigaturesUseNone = standard("formatFontLigaturesUseNone")
    public static let formatFontLigaturesUseAll = standard("formatFontLigaturesUseAll")
    public static let formatFontBaseline = standard("formatFontBaseline")
    public static let formatFontBaselineUseDefault = standard("formatFontBaselineUseDefault")
    public static let formatFontBaselineSuperscript = standard("formatFontBaselineSuperscript")
    public static let formatFontBaselineSubscript = standard("formatFontBaselineSubscript")
    public static let formatFontBaselineRaise = standard("formatFontBaselineRaise")
    public static let formatFontBaselineLower = standard("formatFontBaselineLower")
    public static let formatFontShowColors = standard("formatFontShowColors")
    public static let formatFontCopyStyle = standard("formatFontCopyStyle")
    public static let formatFontPasteStyle = standard("formatFontPasteStyle")

    public static let formatText = standard("formatText")
    public static let formatTextAlignLeft = standard("formatTextAlignLeft")
    public static let formatTextCenter = standard("formatTextCenter")
    public static let formatTextJustify = standard("formatTextJustify")
    public static let formatTextAlignRight = standard("formatTextAlignRight")
    public static let formatTextWritingDirection = standard("formatTextWritingDirection")
    public static let formatTextWritingDirectionParagraphHeader = standard("formatTextWritingDirectionParagraphHeader")
    public static let formatTextWritingDirectionParagraphDefault = standard("formatTextWritingDirectionParagraphDefault")
    public static let formatTextWritingDirectionParagraphLeftToRight = standard("formatTextWritingDirectionParagraphLeftToRight")
    public static let formatTextWritingDirectionParagraphRightToLeft = standard("formatTextWritingDirectionParagraphRightToLeft")
    public static let formatTextWritingDirectionSelectionHeader = standard("formatTextWritingDirectionSelectionHeader")
    public static let formatTextWritingDirectionSelectionDefault = standard("formatTextWritingDirectionSelectionDefault")
    public static let formatTextWritingDirectionSelectionLeftToRight = standard("formatTextWritingDirectionSelectionLeftToRight")
    public static let formatTextWritingDirectionSelectionRightToLeft = standard("formatTextWritingDirectionSelectionRightToLeft")
    public static let formatTextShowRuler = standard("formatTextShowRuler")
    public static let formatTextCopyRuler = standard("formatTextCopyRuler")
    public static let formatTextPasteRuler = standard("formatTextPasteRuler")
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
                    .identifier(ItemIdentifier.formatFontShowFonts)
                NSMenuItem("Bold", action: #Selector("addFontTrait:"), keyEquivalent: "b")
                    .target(fontManager)
                    .tag(2)
                    .identifier(ItemIdentifier.formatFontBold)
                NSMenuItem("Italic", action: #Selector("addFontTrait:"), keyEquivalent: "i")
                    .target(fontManager)
                    .tag(1)
                    .identifier(ItemIdentifier.formatFontItalic)
                NSMenuItem("Underline", action: #Selector("underline:"), keyEquivalent: "u")
                    .identifier(ItemIdentifier.formatFontUnderline)
                NSMenuItem.separator()
                NSMenuItem("Bigger", action: #Selector("modifyFont:"), keyEquivalent: "+")
                    .target(fontManager)
                    .tag(3)
                    .identifier(ItemIdentifier.formatFontBigger)
                NSMenuItem("Smaller", action: #Selector("modifyFont:"), keyEquivalent: "-")
                    .target(fontManager)
                    .tag(4)
                    .identifier(ItemIdentifier.formatFontSmaller)
                NSMenuItem.separator()
                NSMenuItem("Kern") {
                    NSMenuItem("Use Default", action: #Selector("useStandardKerning:"))
                        .identifier(ItemIdentifier.formatFontKernUseDefault)
                    NSMenuItem("Use None", action: #Selector("turnOffKerning:"))
                        .identifier(ItemIdentifier.formatFontKernUseNone)
                    NSMenuItem("Tighten", action: #Selector("tightenKerning:"))
                        .identifier(ItemIdentifier.formatFontKernTighten)
                    NSMenuItem("Loosen", action: #Selector("loosenKerning:"))
                        .identifier(ItemIdentifier.formatFontKernLoosen)
                }
                .identifier(ItemIdentifier.formatFontKern)
                NSMenuItem("Ligatures") {
                    NSMenuItem("Use Default", action: #Selector("useStandardLigatures:"))
                        .identifier(ItemIdentifier.formatFontLigaturesUseDefault)
                    NSMenuItem("Use None", action: #Selector("turnOffLigatures:"))
                        .identifier(ItemIdentifier.formatFontLigaturesUseNone)
                    NSMenuItem("Use All", action: #Selector("useAllLigatures:"))
                        .identifier(ItemIdentifier.formatFontLigaturesUseAll)
                }
                .identifier(ItemIdentifier.formatFontLigatures)
                NSMenuItem("Baseline") {
                    NSMenuItem("Use Default", action: #Selector("unscript:"))
                        .identifier(ItemIdentifier.formatFontBaselineUseDefault)
                    NSMenuItem("Superscript", action: #Selector("superscript:"))
                        .identifier(ItemIdentifier.formatFontBaselineSuperscript)
                    NSMenuItem("Subscript", action: #Selector("subscript:"))
                        .identifier(ItemIdentifier.formatFontBaselineSubscript)
                    NSMenuItem("Raise", action: #Selector("raiseBaseline:"))
                        .identifier(ItemIdentifier.formatFontBaselineRaise)
                    NSMenuItem("Lower", action: #Selector("lowerBaseline:"))
                        .identifier(ItemIdentifier.formatFontBaselineLower)
                }
                .identifier(ItemIdentifier.formatFontBaseline)
                NSMenuItem.separator()
                NSMenuItem("Show Colors", action: #Selector("orderFrontColorPanel:"), keyEquivalent: "C")
                    .identifier(ItemIdentifier.formatFontShowColors)
                NSMenuItem.separator()
                NSMenuItem("Copy Style", action: #Selector("copyFont:"), keyEquivalent: "c", modifiers: [.option, .command])
                    .identifier(ItemIdentifier.formatFontCopyStyle)
                NSMenuItem("Paste Style", action: #Selector("pasteFont:"), keyEquivalent: "v", modifiers: [.option, .command])
                    .identifier(ItemIdentifier.formatFontPasteStyle)
            }
            .identifier(ItemIdentifier.font)
        }

        /// The Text submenu. The Writing Direction section headers are the
        /// template's disabled plain items, and the direction items keep the
        /// template's tab-prefixed titles — both are how the xib renders the
        /// indented Paragraph / Selection groups.
        public static func text() -> NSMenuItem {
            NSMenuItem("Text") {
                NSMenuItem("Align Left", action: #Selector("alignLeft:"), keyEquivalent: "{")
                    .identifier(ItemIdentifier.formatTextAlignLeft)
                NSMenuItem("Center", action: #Selector("alignCenter:"), keyEquivalent: "|")
                    .identifier(ItemIdentifier.formatTextCenter)
                NSMenuItem("Justify", action: #Selector("alignJustified:"))
                    .identifier(ItemIdentifier.formatTextJustify)
                NSMenuItem("Align Right", action: #Selector("alignRight:"), keyEquivalent: "}")
                    .identifier(ItemIdentifier.formatTextAlignRight)
                NSMenuItem.separator()
                NSMenuItem("Writing Direction") {
                    NSMenuItem("Paragraph")
                        .isEnabled(false)
                        .identifier(ItemIdentifier.formatTextWritingDirectionParagraphHeader)
                    NSMenuItem("\tDefault", action: #Selector("makeBaseWritingDirectionNatural:"))
                        .identifier(ItemIdentifier.formatTextWritingDirectionParagraphDefault)
                    NSMenuItem("\tLeft to Right", action: #Selector("makeBaseWritingDirectionLeftToRight:"))
                        .identifier(ItemIdentifier.formatTextWritingDirectionParagraphLeftToRight)
                    NSMenuItem("\tRight to Left", action: #Selector("makeBaseWritingDirectionRightToLeft:"))
                        .identifier(ItemIdentifier.formatTextWritingDirectionParagraphRightToLeft)
                    NSMenuItem.separator()
                    NSMenuItem("Selection")
                        .isEnabled(false)
                        .identifier(ItemIdentifier.formatTextWritingDirectionSelectionHeader)
                    NSMenuItem("\tDefault", action: #Selector("makeTextWritingDirectionNatural:"))
                        .identifier(ItemIdentifier.formatTextWritingDirectionSelectionDefault)
                    NSMenuItem("\tLeft to Right", action: #Selector("makeTextWritingDirectionLeftToRight:"))
                        .identifier(ItemIdentifier.formatTextWritingDirectionSelectionLeftToRight)
                    NSMenuItem("\tRight to Left", action: #Selector("makeTextWritingDirectionRightToLeft:"))
                        .identifier(ItemIdentifier.formatTextWritingDirectionSelectionRightToLeft)
                }
                .identifier(ItemIdentifier.formatTextWritingDirection)
                NSMenuItem.separator()
                NSMenuItem("Show Ruler", action: #Selector("toggleRuler:"))
                    .identifier(ItemIdentifier.formatTextShowRuler)
                NSMenuItem("Copy Ruler", action: #Selector("copyRuler:"), keyEquivalent: "c", modifiers: [.control, .command])
                    .identifier(ItemIdentifier.formatTextCopyRuler)
                NSMenuItem("Paste Ruler", action: #Selector("pasteRuler:"), keyEquivalent: "v", modifiers: [.control, .command])
                    .identifier(ItemIdentifier.formatTextPasteRuler)
            }
            .identifier(ItemIdentifier.formatText)
        }
    }
}

#endif
