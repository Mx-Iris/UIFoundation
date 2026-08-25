#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension MainMenu.ItemIdentifier {
    /// Standard items of the Edit menu, addressed as `.Edit.undo` etc.; the
    /// groups' own items nest one level further (`.Edit.Find.next`).
    public enum Edit {
        public static let undo = standard("Edit.undo")
        public static let redo = standard("Edit.redo")
        public static let cut = standard("Edit.cut")
        public static let copy = standard("Edit.copy")
        public static let paste = standard("Edit.paste")
        public static let pasteAndMatchStyle = standard("Edit.pasteAndMatchStyle")
        public static let delete = standard("Edit.delete")
        public static let selectAll = standard("Edit.selectAll")
        public static let find = standard("Edit.find")
        public static let spellingAndGrammar = standard("Edit.spellingAndGrammar")
        public static let substitutions = standard("Edit.substitutions")
        public static let transformations = standard("Edit.transformations")
        public static let speech = standard("Edit.speech")

        public enum Find {
            public static let find = standard("Edit.Find.find")
            public static let findAndReplace = standard("Edit.Find.findAndReplace")
            public static let next = standard("Edit.Find.next")
            public static let previous = standard("Edit.Find.previous")
            public static let useSelection = standard("Edit.Find.useSelection")
            public static let jumpToSelection = standard("Edit.Find.jumpToSelection")
        }

        public enum Spelling {
            public static let showSpellingAndGrammar = standard("Edit.Spelling.showSpellingAndGrammar")
            public static let checkDocumentNow = standard("Edit.Spelling.checkDocumentNow")
            public static let checkSpellingWhileTyping = standard("Edit.Spelling.checkSpellingWhileTyping")
            public static let checkGrammarWithSpelling = standard("Edit.Spelling.checkGrammarWithSpelling")
            public static let correctSpellingAutomatically = standard("Edit.Spelling.correctSpellingAutomatically")
        }

        public enum Substitutions {
            public static let showSubstitutions = standard("Edit.Substitutions.showSubstitutions")
            public static let smartCopyPaste = standard("Edit.Substitutions.smartCopyPaste")
            public static let smartQuotes = standard("Edit.Substitutions.smartQuotes")
            public static let smartDashes = standard("Edit.Substitutions.smartDashes")
            public static let smartLinks = standard("Edit.Substitutions.smartLinks")
            public static let dataDetectors = standard("Edit.Substitutions.dataDetectors")
            public static let textReplacement = standard("Edit.Substitutions.textReplacement")
        }

        public enum Transformations {
            public static let makeUpperCase = standard("Edit.Transformations.makeUpperCase")
            public static let makeLowerCase = standard("Edit.Transformations.makeLowerCase")
            public static let capitalize = standard("Edit.Transformations.capitalize")
        }

        public enum Speech {
            public static let startSpeaking = standard("Edit.Speech.startSpeaking")
            public static let stopSpeaking = standard("Edit.Speech.stopSpeaking")
        }
    }
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

    /// The Edit menu with the template's standard content, amended by
    /// `customize`. The transformation reaches the menu's own item (`.edit`)
    /// as well as everything under it, the groups' leaves included
    /// (`.Edit.Find.next` and friends).
    public static func edit(title: String = "Edit", customizing customize: (Builder) -> Void) -> NSMenuItem {
        customized(edit(title: title), by: customize)
    }

    /// Standard items of the Edit menu.
    @MainActor
    public enum Edit {
        public static func undo() -> NSMenuItem {
            NSMenuItem("Undo", action: #Selector("undo:"), keyEquivalent: "z")
                .identifier(ItemIdentifier.Edit.undo)
        }

        public static func redo() -> NSMenuItem {
            NSMenuItem("Redo", action: #Selector("redo:"), keyEquivalent: "Z")
                .identifier(ItemIdentifier.Edit.redo)
        }

        public static func cut() -> NSMenuItem {
            NSMenuItem("Cut", action: #Selector("cut:"), keyEquivalent: "x")
                .identifier(ItemIdentifier.Edit.cut)
        }

        public static func copy() -> NSMenuItem {
            NSMenuItem("Copy", action: #Selector("copy:"), keyEquivalent: "c")
                .identifier(ItemIdentifier.Edit.copy)
        }

        public static func paste() -> NSMenuItem {
            NSMenuItem("Paste", action: #Selector("paste:"), keyEquivalent: "v")
                .identifier(ItemIdentifier.Edit.paste)
        }

        public static func pasteAndMatchStyle() -> NSMenuItem {
            NSMenuItem("Paste and Match Style", action: #Selector("pasteAsPlainText:"), keyEquivalent: "V", modifiers: [.option, .command])
                .identifier(ItemIdentifier.Edit.pasteAndMatchStyle)
        }

        public static func delete() -> NSMenuItem {
            NSMenuItem("Delete", action: #Selector("delete:"))
                .identifier(ItemIdentifier.Edit.delete)
        }

        public static func selectAll() -> NSMenuItem {
            NSMenuItem("Select All", action: #Selector("selectAll:"), keyEquivalent: "a")
                .identifier(ItemIdentifier.Edit.selectAll)
        }

        /// The Find submenu. The numeric tags are the `NSFindPanelAction`
        /// values the template hardcodes.
        public static func find() -> NSMenuItem {
            NSMenuItem("Find") {
                NSMenuItem("Find…", action: #Selector("performFindPanelAction:"), keyEquivalent: "f")
                    .tag(1)
                    .identifier(ItemIdentifier.Edit.Find.find)
                NSMenuItem("Find and Replace…", action: #Selector("performFindPanelAction:"), keyEquivalent: "f", modifiers: [.option, .command])
                    .tag(12)
                    .identifier(ItemIdentifier.Edit.Find.findAndReplace)
                NSMenuItem("Find Next", action: #Selector("performFindPanelAction:"), keyEquivalent: "g")
                    .tag(2)
                    .identifier(ItemIdentifier.Edit.Find.next)
                NSMenuItem("Find Previous", action: #Selector("performFindPanelAction:"), keyEquivalent: "G")
                    .tag(3)
                    .identifier(ItemIdentifier.Edit.Find.previous)
                NSMenuItem("Use Selection for Find", action: #Selector("performFindPanelAction:"), keyEquivalent: "e")
                    .tag(7)
                    .identifier(ItemIdentifier.Edit.Find.useSelection)
                NSMenuItem("Jump to Selection", action: #Selector("centerSelectionInVisibleArea:"), keyEquivalent: "j")
                    .identifier(ItemIdentifier.Edit.Find.jumpToSelection)
            }
            .identifier(ItemIdentifier.Edit.find)
        }

        /// The Find submenu amended by `customize`, which reaches the group's
        /// own item (`.Edit.find`) — the only way to retitle it — as well as
        /// its rows.
        public static func find(customizing customize: (Builder) -> Void) -> NSMenuItem {
            customized(find(), by: customize)
        }

        public static func spellingAndGrammar() -> NSMenuItem {
            NSMenuItem("Spelling and Grammar", submenu: NSMenu(title: "Spelling") {
                NSMenuItem("Show Spelling and Grammar", action: #Selector("showGuessPanel:"), keyEquivalent: ":")
                    .identifier(ItemIdentifier.Edit.Spelling.showSpellingAndGrammar)
                NSMenuItem("Check Document Now", action: #Selector("checkSpelling:"), keyEquivalent: ";")
                    .identifier(ItemIdentifier.Edit.Spelling.checkDocumentNow)
                NSMenuItem.separator()
                NSMenuItem("Check Spelling While Typing", action: #Selector("toggleContinuousSpellChecking:"))
                    .identifier(ItemIdentifier.Edit.Spelling.checkSpellingWhileTyping)
                NSMenuItem("Check Grammar With Spelling", action: #Selector("toggleGrammarChecking:"))
                    .identifier(ItemIdentifier.Edit.Spelling.checkGrammarWithSpelling)
                NSMenuItem("Correct Spelling Automatically", action: #Selector("toggleAutomaticSpellingCorrection:"))
                    .identifier(ItemIdentifier.Edit.Spelling.correctSpellingAutomatically)
            })
            .identifier(ItemIdentifier.Edit.spellingAndGrammar)
        }

        /// The Spelling and Grammar submenu amended by `customize`, which
        /// reaches the group's own item (`.Edit.spellingAndGrammar`) as well as
        /// its rows.
        public static func spellingAndGrammar(customizing customize: (Builder) -> Void) -> NSMenuItem {
            customized(spellingAndGrammar(), by: customize)
        }

        public static func substitutions() -> NSMenuItem {
            NSMenuItem("Substitutions") {
                NSMenuItem("Show Substitutions", action: #Selector("orderFrontSubstitutionsPanel:"))
                    .identifier(ItemIdentifier.Edit.Substitutions.showSubstitutions)
                NSMenuItem.separator()
                NSMenuItem("Smart Copy/Paste", action: #Selector("toggleSmartInsertDelete:"))
                    .identifier(ItemIdentifier.Edit.Substitutions.smartCopyPaste)
                NSMenuItem("Smart Quotes", action: #Selector("toggleAutomaticQuoteSubstitution:"))
                    .identifier(ItemIdentifier.Edit.Substitutions.smartQuotes)
                NSMenuItem("Smart Dashes", action: #Selector("toggleAutomaticDashSubstitution:"))
                    .identifier(ItemIdentifier.Edit.Substitutions.smartDashes)
                NSMenuItem("Smart Links", action: #Selector("toggleAutomaticLinkDetection:"))
                    .identifier(ItemIdentifier.Edit.Substitutions.smartLinks)
                NSMenuItem("Data Detectors", action: #Selector("toggleAutomaticDataDetection:"))
                    .identifier(ItemIdentifier.Edit.Substitutions.dataDetectors)
                NSMenuItem("Text Replacement", action: #Selector("toggleAutomaticTextReplacement:"))
                    .identifier(ItemIdentifier.Edit.Substitutions.textReplacement)
            }
            .identifier(ItemIdentifier.Edit.substitutions)
        }

        /// The Substitutions submenu amended by `customize`, which reaches the
        /// group's own item (`.Edit.substitutions`) as well as its rows.
        public static func substitutions(customizing customize: (Builder) -> Void) -> NSMenuItem {
            customized(substitutions(), by: customize)
        }

        public static func transformations() -> NSMenuItem {
            NSMenuItem("Transformations") {
                NSMenuItem("Make Upper Case", action: #Selector("uppercaseWord:"))
                    .identifier(ItemIdentifier.Edit.Transformations.makeUpperCase)
                NSMenuItem("Make Lower Case", action: #Selector("lowercaseWord:"))
                    .identifier(ItemIdentifier.Edit.Transformations.makeLowerCase)
                NSMenuItem("Capitalize", action: #Selector("capitalizeWord:"))
                    .identifier(ItemIdentifier.Edit.Transformations.capitalize)
            }
            .identifier(ItemIdentifier.Edit.transformations)
        }

        /// The Transformations submenu amended by `customize`, which reaches
        /// the group's own item (`.Edit.transformations`) as well as its rows.
        public static func transformations(customizing customize: (Builder) -> Void) -> NSMenuItem {
            customized(transformations(), by: customize)
        }

        public static func speech() -> NSMenuItem {
            NSMenuItem("Speech") {
                NSMenuItem("Start Speaking", action: #Selector("startSpeaking:"))
                    .identifier(ItemIdentifier.Edit.Speech.startSpeaking)
                NSMenuItem("Stop Speaking", action: #Selector("stopSpeaking:"))
                    .identifier(ItemIdentifier.Edit.Speech.stopSpeaking)
            }
            .identifier(ItemIdentifier.Edit.speech)
        }

        /// The Speech submenu amended by `customize`, which reaches the group's
        /// own item (`.Edit.speech`) as well as its rows.
        public static func speech(customizing customize: (Builder) -> Void) -> NSMenuItem {
            customized(speech(), by: customize)
        }
    }
}

#endif
