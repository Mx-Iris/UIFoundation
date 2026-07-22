//
//  TabBar+Constants.swift
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
    /// The name of the notification posted upon the selection of a new tab.
    public static let selectionDidChangeNotification = Notification.Name("UIFoundation.TabBar.selectionDidChange")

    /// The position of a tab button inside the control. Used by ``TabBar/Style``.
    ///
    /// - first:  The left-most tab button.
    /// - middle: Any middle tab button between first and last.
    /// - last:   The right-most tab button.
    public enum TabPosition {
        case first
        case middle
        case last

        /// Convenience function to derive a `TabPosition` from an index and a total count.
        static func fromIndex(_ index: Int, totalCount: Int) -> TabPosition {
            switch index {
            case 0: return .first
            case totalCount - 1: return .last
            default: return .middle
            }
        }
    }

    /// The side of a tab on which the close button is drawn.
    @objc public enum ClosePosition: Int {
        case left
        case right
    }

    /// The tab width modes.
    ///
    /// - full:     The tab widths are equally distributed across the control width.
    /// - flexible: The tab widths are adjusted between min and max, depending on the control width.
    /// - fixed:    Every tab uses the same fixed width.
    public enum TabWidth {
        case full
        case flexible(min: CGFloat, max: CGFloat)
        case fixed(width: CGFloat)
    }

    /// The selection state of a tab.
    ///
    /// - normal:       The tab is not selected.
    /// - selected:     The tab is selected.
    /// - unselectable: The tab cannot be selected.
    public enum SelectionState {
        case normal
        case selected
        case unselectable
    }

    /// Border mask option set, used by tab buttons and the control itself.
    public struct BorderMask: OptionSet {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public static func all() -> BorderMask {
            return BorderMask.top.union(BorderMask.left).union(BorderMask.right).union(BorderMask.bottom)
        }

        public static let top = BorderMask(rawValue: 1 << 0)
        public static let left = BorderMask(rawValue: 1 << 1)
        public static let right = BorderMask(rawValue: 1 << 2)
        public static let bottom = BorderMask(rawValue: 1 << 3)
    }
}

#endif
