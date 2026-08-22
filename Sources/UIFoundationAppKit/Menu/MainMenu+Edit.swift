#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    public static let editUndo = standard("editUndo")
    public static let editRedo = standard("editRedo")
    public static let editCut = standard("editCut")
    public static let editCopy = standard("editCopy")
    public static let editPaste = standard("editPaste")
    public static let editPasteAndMatchStyle = standard("editPasteAndMatchStyle")
    public static let editDelete = standard("editDelete")
    public static let editSelectAll = standard("editSelectAll")

    public static let editFind = standard("editFind")
    public static let editFindFind = standard("editFindFind")
    public static let editFindFindAndReplace = standard("editFindFindAndReplace")
    public static let editFindNext = standard("editFindNext")
    public static let editFindPrevious = standard("editFindPrevious")
    public static let editFindUseSelection = standard("editFindUseSelection")
    public static let editFindJumpToSelection = standard("editFindJumpToSelection")

    public static let editSpellingAndGrammar = standard("editSpellingAndGrammar")
    public static let editSpellingShowSpellingAndGrammar = standard("editSpellingShowSpellingAndGrammar")
    public static let editSpellingCheckDocumentNow = standard("editSpellingCheckDocumentNow")
    public static let editSpellingCheckSpellingWhileTyping = standard("editSpellingCheckSpellingWhileTyping")
    public static let editSpellingCheckGrammarWithSpelling = standard("editSpellingCheckGrammarWithSpelling")
    public static let editSpellingCorrectSpellingAutomatically = standard("editSpellingCorrectSpellingAutomatically")

    public static let editSubstitutions = standard("editSubstitutions")
    public static let editSubstitutionsShowSubstitutions = standard("editSubstitutionsShowSubstitutions")
    public static let editSubstitutionsSmartCopyPaste = standard("editSubstitutionsSmartCopyPaste")
    public static let editSubstitutionsSmartQuotes = standard("editSubstitutionsSmartQuotes")
    public static let editSubstitutionsSmartDashes = standard("editSubstitutionsSmartDashes")
    public static let editSubstitutionsSmartLinks = standard("editSubstitutionsSmartLinks")
    public static let editSubstitutionsDataDetectors = standard("editSubstitutionsDataDetectors")
    public static let editSubstitutionsTextReplacement = standard("editSubstitutionsTextReplacement")

    public static let editTransformations = standard("editTransformations")
    public static let editTransformationsMakeUpperCase = standard("editTransformationsMakeUpperCase")
    public static let editTransformationsMakeLowerCase = standard("editTransformationsMakeLowerCase")
    public static let editTransformationsCapitalize = standard("editTransformationsCapitalize")

    public static let editSpeech = standard("editSpeech")
    public static let editSpeechStartSpeaking = standard("editSpeechStartSpeaking")
    public static let editSpeechStopSpeaking = standard("editSpeechStopSpeaking")
}

extension MainMenu {
    /// The Edit menu with the template's standard content.
    ///
    /// AppKit appends "Start Dictation…" and "Emoji & Symbols" to the Edit
    /// menu on its own (suppressible via the `NSDisabledDictationMenuItem` /
    /// `NSDisabledCharacterPaletteMenuItem` defaults), so they are deliberately
    /// not part of the standard content.
    public static func edit(title: String = "Edit") -> NSMenuItem {
        edit(title: title) {
            Edit.undo()
            Edit.redo()
            NSMenuItem.separator()
            Edit.cut()
            Edit.copy()
            Edit.paste()
            Edit.pasteAndMatchStyle()
            Edit.delete()
            Edit.selectAll()
            NSMenuItem.separator()
            Edit.find()
            Edit.spellingAndGrammar()
            Edit.substitutions()
            Edit.transformations()
            Edit.speech()
        }
    }

    /// The Edit menu with custom content.
    public static func edit(title: String = "Edit", @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem {
        NSMenuItem(title, submenu: items)
            .identifier(ItemIdentifier.edit)
    }

    /// Standard items of the Edit menu.
    @MainActor
    public enum Edit {
        public static func undo() -> NSMenuItem {
            NSMenuItem("Undo", action: #Selector("undo:"), keyEquivalent: "z")
                .identifier(ItemIdentifier.editUndo)
        }

        public static func redo() -> NSMenuItem {
            NSMenuItem("Redo", action: #Selector("redo:"), keyEquivalent: "Z")
                .identifier(ItemIdentifier.editRedo)
        }

        public static func cut() -> NSMenuItem {
            NSMenuItem("Cut", action: #Selector("cut:"), keyEquivalent: "x")
                .identifier(ItemIdentifier.editCut)
        }

        public static func copy() -> NSMenuItem {
            NSMenuItem("Copy", action: #Selector("copy:"), keyEquivalent: "c")
                .identifier(ItemIdentifier.editCopy)
        }

        public static func paste() -> NSMenuItem {
            NSMenuItem("Paste", action: #Selector("paste:"), keyEquivalent: "v")
                .identifier(ItemIdentifier.editPaste)
        }

        public static func pasteAndMatchStyle() -> NSMenuItem {
            NSMenuItem("Paste and Match Style", action: #Selector("pasteAsPlainText:"), keyEquivalent: "V", modifiers: [.option, .command])
                .identifier(ItemIdentifier.editPasteAndMatchStyle)
        }

        public static func delete() -> NSMenuItem {
            NSMenuItem("Delete", action: #Selector("delete:"))
                .identifier(ItemIdentifier.editDelete)
        }

        public static func selectAll() -> NSMenuItem {
            NSMenuItem("Select All", action: #Selector("selectAll:"), keyEquivalent: "a")
                .identifier(ItemIdentifier.editSelectAll)
        }

        /// The Find submenu. The numeric tags are the `NSFindPanelAction`
        /// values the template hardcodes.
        public static func find() -> NSMenuItem {
            NSMenuItem("Find") {
                NSMenuItem("Find…", action: #Selector("performFindPanelAction:"), keyEquivalent: "f")
                    .tag(1)
                    .identifier(ItemIdentifier.editFindFind)
                NSMenuItem("Find and Replace…", action: #Selector("performFindPanelAction:"), keyEquivalent: "f", modifiers: [.option, .command])
                    .tag(12)
                    .identifier(ItemIdentifier.editFindFindAndReplace)
                NSMenuItem("Find Next", action: #Selector("performFindPanelAction:"), keyEquivalent: "g")
                    .tag(2)
                    .identifier(ItemIdentifier.editFindNext)
                NSMenuItem("Find Previous", action: #Selector("performFindPanelAction:"), keyEquivalent: "G")
                    .tag(3)
                    .identifier(ItemIdentifier.editFindPrevious)
                NSMenuItem("Use Selection for Find", action: #Selector("performFindPanelAction:"), keyEquivalent: "e")
                    .tag(7)
                    .identifier(ItemIdentifier.editFindUseSelection)
                NSMenuItem("Jump to Selection", action: #Selector("centerSelectionInVisibleArea:"), keyEquivalent: "j")
                    .identifier(ItemIdentifier.editFindJumpToSelection)
            }
            .identifier(ItemIdentifier.editFind)
        }

        public static func spellingAndGrammar() -> NSMenuItem {
            NSMenuItem("Spelling and Grammar", submenu: NSMenu(title: "Spelling") {
                NSMenuItem("Show Spelling and Grammar", action: #Selector("showGuessPanel:"), keyEquivalent: ":")
                    .identifier(ItemIdentifier.editSpellingShowSpellingAndGrammar)
                NSMenuItem("Check Document Now", action: #Selector("checkSpelling:"), keyEquivalent: ";")
                    .identifier(ItemIdentifier.editSpellingCheckDocumentNow)
                NSMenuItem.separator()
                NSMenuItem("Check Spelling While Typing", action: #Selector("toggleContinuousSpellChecking:"))
                    .identifier(ItemIdentifier.editSpellingCheckSpellingWhileTyping)
                NSMenuItem("Check Grammar With Spelling", action: #Selector("toggleGrammarChecking:"))
                    .identifier(ItemIdentifier.editSpellingCheckGrammarWithSpelling)
                NSMenuItem("Correct Spelling Automatically", action: #Selector("toggleAutomaticSpellingCorrection:"))
                    .identifier(ItemIdentifier.editSpellingCorrectSpellingAutomatically)
            })
            .identifier(ItemIdentifier.editSpellingAndGrammar)
        }

        public static func substitutions() -> NSMenuItem {
            NSMenuItem("Substitutions") {
                NSMenuItem("Show Substitutions", action: #Selector("orderFrontSubstitutionsPanel:"))
                    .identifier(ItemIdentifier.editSubstitutionsShowSubstitutions)
                NSMenuItem.separator()
                NSMenuItem("Smart Copy/Paste", action: #Selector("toggleSmartInsertDelete:"))
                    .identifier(ItemIdentifier.editSubstitutionsSmartCopyPaste)
                NSMenuItem("Smart Quotes", action: #Selector("toggleAutomaticQuoteSubstitution:"))
                    .identifier(ItemIdentifier.editSubstitutionsSmartQuotes)
                NSMenuItem("Smart Dashes", action: #Selector("toggleAutomaticDashSubstitution:"))
                    .identifier(ItemIdentifier.editSubstitutionsSmartDashes)
                NSMenuItem("Smart Links", action: #Selector("toggleAutomaticLinkDetection:"))
                    .identifier(ItemIdentifier.editSubstitutionsSmartLinks)
                NSMenuItem("Data Detectors", action: #Selector("toggleAutomaticDataDetection:"))
                    .identifier(ItemIdentifier.editSubstitutionsDataDetectors)
                NSMenuItem("Text Replacement", action: #Selector("toggleAutomaticTextReplacement:"))
                    .identifier(ItemIdentifier.editSubstitutionsTextReplacement)
            }
            .identifier(ItemIdentifier.editSubstitutions)
        }

        public static func transformations() -> NSMenuItem {
            NSMenuItem("Transformations") {
                NSMenuItem("Make Upper Case", action: #Selector("uppercaseWord:"))
                    .identifier(ItemIdentifier.editTransformationsMakeUpperCase)
                NSMenuItem("Make Lower Case", action: #Selector("lowercaseWord:"))
                    .identifier(ItemIdentifier.editTransformationsMakeLowerCase)
                NSMenuItem("Capitalize", action: #Selector("capitalizeWord:"))
                    .identifier(ItemIdentifier.editTransformationsCapitalize)
            }
            .identifier(ItemIdentifier.editTransformations)
        }

        public static func speech() -> NSMenuItem {
            NSMenuItem("Speech") {
                NSMenuItem("Start Speaking", action: #Selector("startSpeaking:"))
                    .identifier(ItemIdentifier.editSpeechStartSpeaking)
                NSMenuItem("Stop Speaking", action: #Selector("stopSpeaking:"))
                    .identifier(ItemIdentifier.editSpeechStopSpeaking)
            }
            .identifier(ItemIdentifier.editSpeech)
        }
    }
}

#endif
