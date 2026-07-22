//
//  TabBar+Theme.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabBar && os(macOS)

import AppKit

extension TabBar {
    /// The theme of a single tab button.
    public protocol ButtonTheme {
        var backgroundColor: NSColor { get }
        var borderColor: NSColor { get }
        var titleColor: NSColor { get }
        var titleFont: NSFont { get }
    }

    /// The theme of the whole tab-bar bar.
    public protocol ControlTheme {
        var backgroundColor: NSColor { get }
        var borderColor: NSColor { get }
    }

    /// The theme of a complete ``TabBar``.
    public protocol Theme {
        var tabButtonTheme: ButtonTheme { get }
        var selectedTabButtonTheme: ButtonTheme { get }
        var unselectableTabButtonTheme: ButtonTheme { get }
        var tabBarTheme: ControlTheme { get }
    }
}

extension TabBar.Theme {
    /// Convenience accessor that selects the per-button theme matching the given selection state.
    public func tabButtonTheme(fromSelectionState selectionState: TabBar.SelectionState) -> TabBar.ButtonTheme {
        switch selectionState {
        case .normal: return tabButtonTheme
        case .selected: return selectedTabButtonTheme
        case .unselectable: return unselectableTabButtonTheme
        }
    }
}

#endif
