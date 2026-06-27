#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import ObjectiveC
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
/// N installs require N uninstalls, and the last `uninstall()` walks the cached
/// `_normalToolTipPanel` / `_expansionToolTipPanel` to restore the original
/// `NSVisualEffectView` content view, window chrome, and `initialToolTipDelay`
/// before the isa is reverted.
///
/// ## Layer-backing reconciliation
///
/// On every tooltip display the hook calls ``reconcileContentView(forWindow:toolTip:manager:)``,
/// which inspects the resolved style and swaps `panel.contentView` between
/// the system `NSVisualEffectView` (`material = .toolTip`) and a
/// `LayerBackedView` so the requested corner / border / shadow / solid
/// background can be drawn. Only the cached draw-view ivar matching the
/// currently displayed panel (normal vs expansion) is reset to `nil` via KVC,
/// so the system rebuilds it inside the new content view on the next
/// `addDrawingSubviewForToolTip:` call; the other panel's cached draw view is
/// left intact. The panel's pre-customization `backgroundColor` / `isOpaque` /
/// `hasShadow` are saved in an associated object and restored when the
/// resolved style stops needing layer backing.
///
/// Per-view overrides work in isolation — a single styled view can co-exist
/// with other views that still get the unmodified system tooltip.
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
    /// to fully restore the original isa. The first call snapshots the system
    /// `initialToolTipDelay`; the last `uninstall()` restores it, sweeps the
    /// cached panels back to `NSVisualEffectView`, and nils the cached draw-view
    /// ivars.
    public static func install() {
        let manager = NSToolTipManager.shared
        if shared.installCount == 0 {
            shared.originalInitialDelay = manager.initialToolTipDelay
        }
        shared.installCount += 1
        CustomToolTipManagerHook.install(on: manager)
        shared.propagateInitialDelay()
    }

    /// Decrement the install ref-count. When it reaches zero, restore the
    /// cached panels to their pre-customization state and revert the isa.
    public static func uninstall() {
        guard shared.installCount > 0 else { return }
        shared.installCount -= 1
        let manager = NSToolTipManager.shared
        if shared.installCount == 0 {
            shared.restorePanelsToSystemDefaults(manager: manager)
            if let originalInitialDelay = shared.originalInitialDelay {
                manager.initialToolTipDelay = originalInitialDelay
            }
            shared.originalInitialDelay = nil
        }
        CustomToolTipManagerHook.uninstall(from: manager)
    }

    private var installCount: Int = 0
    private var originalInitialDelay: TimeInterval?

    private func propagateInitialDelay() {
        guard installCount > 0 else { return }
        let manager = NSToolTipManager.shared
        if let initialDelay = globalStyle.initialDelay {
            manager.initialToolTipDelay = initialDelay
        } else if let originalInitialDelay {
            manager.initialToolTipDelay = originalInitialDelay
        }
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

    // MARK: - Content view reconciliation

    /// Bring the panel's content view in sync with the currently resolved
    /// style: layer-backed if any of background / corner / border / shadow is
    /// requested, otherwise the system `NSVisualEffectMaterial.toolTip` blur.
    ///
    /// Must be called from the `installContentView:forToolTip:toolTipWindow:isNew:`
    /// hook so the swap completes before `addDrawingSubviewForToolTip:` runs.
    /// On a swap, only the cached draw-view ivar matching the displayed panel
    /// (`_normalToolTipDrawView` vs `_expansionToolTipDrawView`) is reset to
    /// `nil` via KVC — the other panel's cached draw view stays parented to
    /// its untouched content view.
    func reconcileContentView(forWindow window: NSWindow, toolTip: NSToolTip, manager: NSToolTipManager) {
        let style = currentResolvedStyle
        let wantsLayerBacking = style.isLayerBackingEnabled
        let currentIsLayerBacked = window.contentView is LayerBackedView

        if wantsLayerBacking != currentIsLayerBacked {
            if wantsLayerBacking {
                saveOriginalChromeIfNeeded(for: window)
                window.contentView = LayerBackedView()
                window.backgroundColor = .clear
                window.isOpaque = false
                window.hasShadow = false
            } else {
                window.contentView = makeSystemVisualEffectContentView()
                restoreOriginalChrome(for: window)
            }
            // The displayed panel's draw view was a subview of the old
            // contentView; nil only the matching cache so the system rebuilds
            // it inside the new contentView on the next addDrawingSubviewForToolTip:
            // call. The other panel's draw view is left intact.
            let drawViewIvar = toolTip.isExpansionToolTip
                ? "_expansionToolTipDrawView"
                : "_normalToolTipDrawView"
            manager.setValue(nil, forKey: drawViewIvar)
        }

        applyLayerBackingStyle(toWindow: window)
    }

    /// Push the layer-backed style fields onto a panel that is currently using
    /// a `LayerBackedView` content view. No-op when the content view is still
    /// the system `NSVisualEffectView`.
    private func applyLayerBackingStyle(toWindow window: NSWindow) {
        guard let layerBackedView = window.contentView as? LayerBackedView else { return }
        let style = currentResolvedStyle
        layerBackedView.backgroundColor = style.backgroundColor
        layerBackedView.cornerRadius = style.cornerRadius ?? 0
        layerBackedView.borderColor = style.borderColor
        layerBackedView.borderWidth = style.borderWidth ?? 0
        if style.borderColor != nil || (style.borderWidth ?? 0) > 0 {
            layerBackedView.borderPositions = .all
        }
        layerBackedView.shadowColor = style.shadowColor
        layerBackedView.shadowOpacity = style.shadowColor == nil ? 0 : 1
        layerBackedView.shadowOffset = style.shadowOffset ?? .zero
        layerBackedView.shadowRadius = style.shadowRadius ?? 0
    }

    private func makeSystemVisualEffectContentView() -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .toolTip
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        return visualEffectView
    }

    // MARK: - Teardown

    /// Walk the cached panels, swap any `LayerBackedView` content view back to
    /// a fresh `NSVisualEffectView`, restore the saved window chrome, and nil
    /// both draw-view ivars so the system rebuilds them on the next display.
    /// Called from ``uninstall()`` when the ref-count drops to zero, BEFORE
    /// the hook's isa is reverted.
    private func restorePanelsToSystemDefaults(manager: NSToolTipManager) {
        let panelKeys = ["_normalToolTipPanel", "_expansionToolTipPanel"]
        let drawViewKeys = ["_normalToolTipDrawView", "_expansionToolTipDrawView"]
        for (panelKey, drawViewKey) in zip(panelKeys, drawViewKeys) {
            guard let panel = manager.value(forKey: panelKey) as? NSWindow else { continue }
            if panel.contentView is LayerBackedView {
                panel.contentView = makeSystemVisualEffectContentView()
                restoreOriginalChrome(for: panel)
            }
            manager.setValue(nil, forKey: drawViewKey)
        }
    }

    // MARK: - Panel chrome save / restore

    private func saveOriginalChromeIfNeeded(for window: NSWindow) {
        if objc_getAssociatedObject(window, &AssociationKeys.chrome) != nil { return }
        let chrome = OriginalPanelChrome(
            backgroundColor: window.backgroundColor,
            isOpaque: window.isOpaque,
            hasShadow: window.hasShadow
        )
        objc_setAssociatedObject(window, &AssociationKeys.chrome, chrome, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func restoreOriginalChrome(for window: NSWindow) {
        guard let chrome = objc_getAssociatedObject(window, &AssociationKeys.chrome) as? OriginalPanelChrome else { return }
        window.backgroundColor = chrome.backgroundColor
        window.isOpaque = chrome.isOpaque
        window.hasShadow = chrome.hasShadow
    }

    private final class OriginalPanelChrome {
        let backgroundColor: NSColor
        let isOpaque: Bool
        let hasShadow: Bool
        init(backgroundColor: NSColor, isOpaque: Bool, hasShadow: Bool) {
            self.backgroundColor = backgroundColor
            self.isOpaque = isOpaque
            self.hasShadow = hasShadow
        }
    }

    private enum AssociationKeys {
        nonisolated(unsafe) static var chrome: UInt8 = 0
    }
}

#endif
