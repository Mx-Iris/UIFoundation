#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

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
    }

    /// Standard items of the Edit menu.
    @MainActor
    public enum Edit {
        public static func undo() -> NSMenuItem {
            NSMenuItem("Undo", action: Selector(("undo:")), keyEquivalent: "z")
        }

        public static func redo() -> NSMenuItem {
            NSMenuItem("Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        }

        public static func cut() -> NSMenuItem {
            NSMenuItem("Cut", action: Selector(("cut:")), keyEquivalent: "x")
        }

        public static func copy() -> NSMenuItem {
            NSMenuItem("Copy", action: Selector(("copy:")), keyEquivalent: "c")
        }

        public static func paste() -> NSMenuItem {
            NSMenuItem("Paste", action: Selector(("paste:")), keyEquivalent: "v")
        }

        public static func pasteAndMatchStyle() -> NSMenuItem {
            NSMenuItem("Paste and Match Style", action: Selector(("pasteAsPlainText:")), keyEquivalent: "V", modifiers: [.option, .command])
        }

        public static func delete() -> NSMenuItem {
            NSMenuItem("Delete", action: Selector(("delete:")))
        }

        public static func selectAll() -> NSMenuItem {
            NSMenuItem("Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
        }

        /// The Find submenu. The numeric tags are the `NSFindPanelAction`
        /// values the template hardcodes.
        public static func find() -> NSMenuItem {
            NSMenuItem("Find") {
                NSMenuItem("Find…", action: Selector(("performFindPanelAction:")), keyEquivalent: "f").tag(1)
                NSMenuItem("Find and Replace…", action: Selector(("performFindPanelAction:")), keyEquivalent: "f", modifiers: [.option, .command]).tag(12)
                NSMenuItem("Find Next", action: Selector(("performFindPanelAction:")), keyEquivalent: "g").tag(2)
                NSMenuItem("Find Previous", action: Selector(("performFindPanelAction:")), keyEquivalent: "G").tag(3)
                NSMenuItem("Use Selection for Find", action: Selector(("performFindPanelAction:")), keyEquivalent: "e").tag(7)
                NSMenuItem("Jump to Selection", action: Selector(("centerSelectionInVisibleArea:")), keyEquivalent: "j")
            }
        }

        public static func spellingAndGrammar() -> NSMenuItem {
            NSMenuItem("Spelling and Grammar", submenu: NSMenu(title: "Spelling") {
                NSMenuItem("Show Spelling and Grammar", action: Selector(("showGuessPanel:")), keyEquivalent: ":")
                NSMenuItem("Check Document Now", action: Selector(("checkSpelling:")), keyEquivalent: ";")
                NSMenuItem.separator()
                NSMenuItem("Check Spelling While Typing", action: Selector(("toggleContinuousSpellChecking:")))
                NSMenuItem("Check Grammar With Spelling", action: Selector(("toggleGrammarChecking:")))
                NSMenuItem("Correct Spelling Automatically", action: Selector(("toggleAutomaticSpellingCorrection:")))
            })
        }

        public static func substitutions() -> NSMenuItem {
            NSMenuItem("Substitutions") {
                NSMenuItem("Show Substitutions", action: Selector(("orderFrontSubstitutionsPanel:")))
                NSMenuItem.separator()
                NSMenuItem("Smart Copy/Paste", action: Selector(("toggleSmartInsertDelete:")))
                NSMenuItem("Smart Quotes", action: Selector(("toggleAutomaticQuoteSubstitution:")))
                NSMenuItem("Smart Dashes", action: Selector(("toggleAutomaticDashSubstitution:")))
                NSMenuItem("Smart Links", action: Selector(("toggleAutomaticLinkDetection:")))
                NSMenuItem("Data Detectors", action: Selector(("toggleAutomaticDataDetection:")))
                NSMenuItem("Text Replacement", action: Selector(("toggleAutomaticTextReplacement:")))
            }
        }

        public static func transformations() -> NSMenuItem {
            NSMenuItem("Transformations") {
                NSMenuItem("Make Upper Case", action: Selector(("uppercaseWord:")))
                NSMenuItem("Make Lower Case", action: Selector(("lowercaseWord:")))
                NSMenuItem("Capitalize", action: Selector(("capitalizeWord:")))
            }
        }

        public static func speech() -> NSMenuItem {
            NSMenuItem("Speech") {
                NSMenuItem("Start Speaking", action: Selector(("startSpeaking:")))
                NSMenuItem("Stop Speaking", action: Selector(("stopSpeaking:")))
            }
        }
    }
}

#endif
