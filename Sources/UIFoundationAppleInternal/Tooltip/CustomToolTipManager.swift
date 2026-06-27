#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationAppKit
import UIFoundationAppleInternalObjC

/// Entry point for the customizable system tooltip pipeline.
///
/// Install the hook once at application launch — typically from
/// `applicationDidFinishLaunching:` — and then write to ``globalStyle`` or
/// ``setStyle(_:for:)`` (per `NSView`) to change tooltip appearance:
///
/// ```swift
/// CustomToolTipManager.install()
/// CustomToolTipManager.shared.globalStyle = .default
///
/// // Per-view override
/// myView.box.customTooltipStyle = .default.with { $0.cornerRadius = 10 }
/// ```
///
/// The hook is an isa-swizzling subclass installed via
/// `ObjCRuntimeToolbox`'s `@DynamicSubclassHook`, applied to the singleton
/// `NSToolTipManager.shared`. ``install()`` / ``uninstall()`` are ref-counted —
/// N installs require N uninstalls.
///
/// ## Layer-backing trade-off
///
/// When ``globalStyle`` enables any of the layer-backed fields
/// (``ToolTipStyle/cornerRadius``, border, shadow, ``ToolTipStyle/backgroundColor``),
/// the panel's content view is replaced with a layer-backed view at the time
/// the panel is first created, **giving up the system `NSVisualEffectMaterial.toolTip`
/// blur**. Per-view overrides for those fields only take effect when the global
/// style also enables layer backing — the panel is a singleton cached by
/// `NSToolTipManager`, and we do not hot-swap its content view across tooltip
/// invocations to keep behaviour predictable.
///
/// Per-view overrides for font, text color, content margin, and cursor offset
/// work regardless of the layer-backing decision.
@MainActor
public final class CustomToolTipManager {

    public static let shared: CustomToolTipManager = CustomToolTipManager()

    private init() {}

    /// Style applied to every tooltip in the process, unless an
    /// `NSView`-specific override has been set via ``setStyle(_:for:)``.
    public var globalStyle: ToolTipStyle = .system {
        didSet { propagateInitialDelay() }
    }

    // MARK: - Install / uninstall

    /// Install the isa-swizzled subclass on the `NSToolTipManager` singleton.
    ///
    /// Ref-counted: calling `install()` N times requires N calls to ``uninstall()``
    /// to fully restore the original isa. Safe to call from any thread; the
    /// caller is responsible for ensuring it runs before any tooltip is shown.
    public static func install() {
        let manager = NSToolTipManager.shared
        CustomToolTipManagerHook.install(on: manager)
        shared.propagateInitialDelay()
    }

    /// Decrement the install ref-count and restore the original isa when it
    /// drops to zero.
    public static func uninstall() {
        CustomToolTipManagerHook.uninstall(from: NSToolTipManager.shared)
    }

    private func propagateInitialDelay() {
        guard let initialDelay = globalStyle.initialDelay else { return }
        NSToolTipManager.shared.initialToolTipDelay = initialDelay
    }

    // MARK: - Per-view style

    /// Attach (or clear with `nil`) a style override that applies only while the
    /// tooltip for `view` is being shown.
    public func setStyle(_ style: ToolTipStyle?, for view: NSView) {
        view.box.customTooltipStyle = style
    }

    // MARK: - Hook bridge

    nonisolated(unsafe) private static var currentDisplayingView: NSView?

    /// Called by the hook before `super.displayToolTip(_:)` runs. Must always
    /// be paired with ``endDisplay()`` in the same call stack.
    func beginDisplay(toolTip: NSToolTip) {
        Self.currentDisplayingView = toolTip.view
    }

    /// Called by the hook after `super.displayToolTip(_:)` returns.
    func endDisplay() {
        Self.currentDisplayingView = nil
    }

    /// The style the hook should use to override fields on the current call.
    ///
    /// Returns the per-view style attached to the currently displaying view
    /// (if any), otherwise falls back to ``globalStyle``. Individual hook
    /// methods inspect each field and fall back to `callSuper()` when the
    /// field is `nil`.
    var currentResolvedStyle: ToolTipStyle {
        if let view = Self.currentDisplayingView,
           let perView = view.box.customTooltipStyle {
            return perView
        }
        return globalStyle
    }

    /// Push the layer-backed fields of the current style onto a panel that has
    /// already been swapped to use `LayerBackedView` as its content view.
    ///
    /// No-op when the content view is not layer-backed (i.e. the panel still
    /// uses `NSVisualEffectView`).
    func applyLayerBackingStyleIfNeeded(toWindow window: NSWindow) {
        guard let layerBackedView = window.contentView as? LayerBackedView else { return }
        let style = currentResolvedStyle
        if let backgroundColor = style.backgroundColor {
            layerBackedView.backgroundColor = backgroundColor
        }
        if let cornerRadius = style.cornerRadius {
            layerBackedView.cornerRadius = cornerRadius
        }
        if let borderColor = style.borderColor {
            layerBackedView.borderColor = borderColor
            layerBackedView.borderPositions = .all
        }
        if let borderWidth = style.borderWidth {
            layerBackedView.borderWidth = borderWidth
        }
        if let shadowColor = style.shadowColor {
            layerBackedView.shadowColor = shadowColor
            layerBackedView.shadowOpacity = 1
        }
        if let shadowOffset = style.shadowOffset {
            layerBackedView.shadowOffset = shadowOffset
        }
        if let shadowRadius = style.shadowRadius {
            layerBackedView.shadowRadius = shadowRadius
        }
    }
}

#endif
