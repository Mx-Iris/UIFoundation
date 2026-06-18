//
//  TabsControl+Theme.swift
//  UIFoundation
//
//  Ported into UIFoundation from KPCTabsControl
//  (https://github.com/onekiloparsec/KPCTabsControl) by Cédric Foellmi
//  and Christian Tietze.
//
//  MIT License — Copyright (c) 2014-2016 Cédric Foellmi
//

#if TabsControl && os(macOS)

import AppKit

extension TabsControl {
    /// The theme of a single tab button.
    public protocol ButtonTheme {
        var backgroundColor: NSColor { get }
        var borderColor: NSColor { get }
        var titleColor: NSColor { get }
        var titleFont: NSFont { get }
    }

    /// The theme of the whole tabs-control bar.
    public protocol ControlTheme {
        var backgroundColor: NSColor { get }
        var borderColor: NSColor { get }
    }

    /// The theme of a complete ``TabsControl``.
    public protocol Theme {
        var tabButtonTheme: ButtonTheme { get }
        var selectedTabButtonTheme: ButtonTheme { get }
        var unselectableTabButtonTheme: ButtonTheme { get }
        var tabsControlTheme: ControlTheme { get }
    }
}

extension TabsControl.Theme {
    /// Convenience accessor that selects the per-button theme matching the given selection state.
    public func tabButtonTheme(fromSelectionState selectionState: TabsControl.SelectionState) -> TabsControl.ButtonTheme {
        switch selectionState {
        case .normal: return tabButtonTheme
        case .selected: return selectedTabButtonTheme
        case .unselectable: return unselectableTabButtonTheme
        }
    }
}

#endif
