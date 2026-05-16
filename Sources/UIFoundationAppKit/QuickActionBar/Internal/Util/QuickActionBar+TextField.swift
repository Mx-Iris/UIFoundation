//
//  TextField.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

import AppKit
import Foundation

// To call the global objc undo/redo selectors via #selector() instead of Selector().
@objc private protocol UndoRedoActionRespondable {
    func undo(_ sender: AnyObject)
    func redo(_ sender: AnyObject)
}

extension QuickActionBar {
    /// A text field that handles cut/copy/paste/undo/redo without a menu wired up.
    ///
    /// Originally contributed by [cyrilzakka](https://github.com/dagronf/DSFQuickActionBar/pull/4/files).
    internal final class TextField: NSTextField {
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            if
                event.type == .keyDown,
                event.modifierFlags.contains(.command),
                let chars = event.charactersIgnoringModifiers?.lowercased()
            {
                switch chars {
                case "x":
                    if NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self) {
                        return true
                    }
                case "c":
                    if NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self) {
                        return true
                    }
                case "v":
                    if NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self) {
                        return true
                    }
                case "a":
                    if NSApp.sendAction(#selector(NSResponder.selectAll(_:)), to: nil, from: self) {
                        return true
                    }
                case "z":
                    if event.modifierFlags.contains(.shift) {
                        if NSApp.sendAction(#selector(UndoRedoActionRespondable.redo(_:)), to: nil, from: self) {
                            return true
                        }
                    } else {
                        if NSApp.sendAction(#selector(UndoRedoActionRespondable.undo(_:)), to: nil, from: self) {
                            return true
                        }
                    }
                default:
                    break
                }
            }
            return super.performKeyEquivalent(with: event)
        }

        override var allowsVibrancy: Bool {
            return true
        }
    }
}

#endif
