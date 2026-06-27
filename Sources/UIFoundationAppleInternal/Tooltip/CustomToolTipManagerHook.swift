#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import ObjCRuntimeToolbox
import UIFoundationAppKit
import UIFoundationAppleInternalObjC

/// Isa-swizzling subclass installed on the `NSToolTipManager` singleton.
///
/// Each `@DynamicSubclassOverride`-tagged method becomes an Objective-C
/// override on a runtime-synthesized subclass of `NSToolTipManager`. The
/// macro injects a typed `callSuper(...)` helper into each method body that
/// forwards to the original implementation; per-field nil-fallback through
/// `callSuper()` is what lets a partially-populated `ToolTipStyle` behave like
/// "tweak these fields, leave the rest at the system default".
///
/// The macro forbids `@MainActor` on hook methods, so the bodies here are
/// `nonisolated`. The Objective-C dispatcher only ever invokes them on the
/// main thread (verified by the reverse-engineering report in
/// `Researchs/AppKit-NSToolTipManager-Internals.md`), so every interaction
/// with the main-actor-isolated ``CustomToolTipManager`` is wrapped in
/// `MainActor.assumeIsolated` to honour the runtime invariant.
@DynamicSubclassHook(of: NSToolTipManager.self, suffix: "Customizable")
struct CustomToolTipManagerHook {

    // MARK: - displayToolTip: — sets up the per-call TLS so the fields below
    // can resolve a per-view style.

    @DynamicSubclassOverride
    func displayToolTip(_ toolTip: NSToolTip) {
        MainActor.assumeIsolated {
            CustomToolTipManager.shared.beginDisplay(toolTip: toolTip)
        }
        defer {
            MainActor.assumeIsolated {
                CustomToolTipManager.shared.endDisplay()
            }
        }
        callSuper(toolTip)
    }

    // MARK: - Text appearance

    @DynamicSubclassOverride
    func toolTipAttributes() -> [NSAttributedString.Key: Any] {
        let style = MainActor.assumeIsolated {
            CustomToolTipManager.shared.currentResolvedStyle
        }
        var attributes = callSuper()
        if let font = style.font {
            attributes[.font] = font
        }
        if let textColor = style.textColor {
            attributes[.foregroundColor] = textColor
        }
        return attributes
    }

    @DynamicSubclassOverride
    func toolTipTextColor() -> NSColor {
        let textColor = MainActor.assumeIsolated {
            CustomToolTipManager.shared.currentResolvedStyle.textColor
        }
        return textColor ?? callSuper()
    }

    @DynamicSubclassOverride
    func toolTipBackgroundColor() -> NSColor {
        let backgroundColor = MainActor.assumeIsolated {
            CustomToolTipManager.shared.currentResolvedStyle.backgroundColor
        }
        return backgroundColor ?? callSuper()
    }

    // MARK: - Geometry

    @DynamicSubclassOverride
    func toolTipContentMargin() -> CGSize {
        let contentMargin = MainActor.assumeIsolated {
            CustomToolTipManager.shared.currentResolvedStyle.contentMargin
        }
        return contentMargin ?? callSuper()
    }

    @DynamicSubclassOverride
    func toolTipYOffset() -> CGFloat {
        let yOffsetFromCursor = MainActor.assumeIsolated {
            CustomToolTipManager.shared.currentResolvedStyle.yOffsetFromCursor
        }
        return yOffsetFromCursor ?? callSuper()
    }

    // MARK: - Layer-backing reconciliation
    //
    // We let the system create the panel + NSVisualEffectView in
    // _newToolTipWindow (untouched here). On every display, installContentView:
    // is invoked before addDrawingSubviewForToolTip:, so it is the right spot
    // to reconcile the panel's contentView with the current resolved style —
    // per-view overrides work just as well as the global style, and switching
    // back to a style without layer-backed fields restores the system blur for
    // that view's tooltips.

    @DynamicSubclassOverride
    func installContentView(
        _ contentView: NSView?,
        forToolTip toolTip: NSToolTip,
        toolTipWindow window: NSWindow,
        isNew: Bool
    ) {
        callSuper(contentView, toolTip, window, isNew)
        MainActor.assumeIsolated {
            CustomToolTipManager.shared.reconcileContentView(
                forWindow: window,
                toolTip: toolTip,
                manager: self.base
            )
        }
    }
}

#endif
