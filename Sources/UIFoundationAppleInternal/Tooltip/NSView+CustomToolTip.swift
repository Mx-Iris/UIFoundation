#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import AssociatedObject
import FrameworkToolbox
import UIFoundationToolbox

/// Per-view override slot for ``ToolTipStyle``.
///
/// The value is stored as an Objective-C associated object so it survives the
/// view's lifetime without any extra plumbing. The hook resolves it during a
/// tooltip's `displayToolTip:` call via the TLS set by
/// ``CustomToolTipManager/beginDisplay(toolTip:)``.
extension NSView {
    @AssociatedObject(.copy(.nonatomic))
    var _customTooltipStyle: ToolTipStyle?
}

extension FrameworkToolbox where Base: NSView {

    /// Style override that applies only while the system tooltip for this view
    /// is displayed. Setting `nil` clears the override and the view falls back
    /// to ``CustomToolTipManager/globalStyle``.
    ///
    /// ```swift
    /// myView.box.customTooltipStyle = .default.with { $0.cornerRadius = 10 }
    /// ```
    public var customTooltipStyle: ToolTipStyle? {
        get { base._customTooltipStyle }
        nonmutating set { base._customTooltipStyle = newValue }
    }
}

#endif
