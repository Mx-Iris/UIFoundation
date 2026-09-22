//
//  AppKitCompatibility.swift
//  ComponentLayoutExample
//
//  The UIKit spellings the ported chapters use, mapped onto AppKit.
//
//  Names are chosen so none of them could collide with something AppKit adds
//  later: AppKit's own colours all end in `Color` (`labelColor`,
//  `separatorColor`), so `label` and `secondaryLabel` are free, and `NSFont`
//  has no semantic-style statics at all.
//

import AppKit

extension NSFont {
    /// Chapter heading.
    public static let title = NSFont.boldSystemFont(ofSize: 32)
    /// Section heading within a chapter.
    public static let subtitle = NSFont.boldSystemFont(ofSize: 20)
    /// Emphasised body copy.
    public static let bodyBold = NSFont.boldSystemFont(ofSize: 16)
    /// Body copy.
    public static let body = NSFont.systemFont(ofSize: 16)
    /// Labels under a sample.
    public static let caption = NSFont.systemFont(ofSize: 14)

    /// UIKit ships `UIFont.italicSystemFont(ofSize:)`; AppKit has no such
    /// factory and expects the trait to be applied to a descriptor instead.
    public static func italicSystemFont(ofSize fontSize: CGFloat) -> NSFont {
        let systemFont = NSFont.systemFont(ofSize: fontSize)
        let descriptor = systemFont.fontDescriptor.withSymbolicTraits(.italic)
        return NSFont(descriptor: descriptor, size: fontSize) ?? systemFont
    }
}

extension NSColor {
    /// UIKit's `.label`.
    public static let label = NSColor.labelColor
    /// UIKit's `.secondaryLabel`.
    public static let secondaryLabel = NSColor.secondaryLabelColor
    /// UIKit's `.tertiaryLabel`.
    public static let tertiaryLabel = NSColor.tertiaryLabelColor
    /// UIKit's `.separator`.
    public static let separator = NSColor.separatorColor
    /// UIKit's `.systemBackground`.
    public static let systemBackground = NSColor.windowBackgroundColor
    /// UIKit's `.secondarySystemBackground`.
    public static let secondarySystemBackground = NSColor.underPageBackgroundColor
    /// UIKit's `.tertiarySystemBackground`.
    public static let tertiarySystemBackground = NSColor.controlBackgroundColor
    /// UIKit's `.secondarySystemFill`.
    public static let secondarySystemFill = NSColor.quaternarySystemFill
    /// UIKit's `.tertiarySystemFill`.
    public static let tertiarySystemFill = NSColor.quaternaryLabelColor
    /// UIKit's `.quaternarySystemFill`. AppKit's nearest is the unemphasised
    /// selection fill.
    public static let quaternarySystemFill = NSColor.unemphasizedSelectedContentBackgroundColor

    // UIKit's numbered grey ramp, which AppKit has no counterpart to at all --
    // it ships one `systemGray` and leaves the rest to semantic colours. These
    // are **approximations** built from that single grey, chosen so the ramp
    // keeps its ordering (2 darkest, 6 lightest) and so every one of them
    // adapts to light and dark on its own. The chapters use them as neutral
    // sample backgrounds, where being a shade off does not matter.

    /// Approximates UIKit's `.systemGray2`.
    public static let systemGray2 = NSColor.systemGray.withAlphaComponent(0.7)
    /// Approximates UIKit's `.systemGray3`.
    public static let systemGray3 = NSColor.systemGray.withAlphaComponent(0.5)
    /// Approximates UIKit's `.systemGray4`.
    public static let systemGray4 = NSColor.systemGray.withAlphaComponent(0.35)
    /// Approximates UIKit's `.systemGray5`.
    public static let systemGray5 = NSColor.systemGray.withAlphaComponent(0.2)
    /// Approximates UIKit's `.systemGray6`.
    public static let systemGray6 = NSColor.systemGray.withAlphaComponent(0.12)
}

extension NSSwitch {
    /// UIKit's `UISwitch.isOn`, over AppKit's tri-state `NSControl.StateValue`.
    ///
    /// Safe as an extension property: AppKit spells this `state` and has never
    /// had an `isOn`, so there is nothing here to collide with.
    public var isOn: Bool {
        get { state == .on }
        set { state = newValue ? .on : .off }
    }
}
