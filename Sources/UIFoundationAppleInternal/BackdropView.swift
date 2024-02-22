import AppKit
import UIFoundationAppleInternalObjC

/// `NSVisualEffectView`:
///
/// A view that adds translucency and vibrancy effects to the views in your interface.
/// When you want views to be more prominent in your interface, place them in a
/// backdrop view. The backdrop view is partially transparent, allowing some of
/// the underlying content to show through. Typically, you use a backdrop view
/// to blur background content, instead of obscuring it completely. It can also
/// make its contained content more vibrant to ensure that it remains prominent.
///
/// A suggested use in designing visual containers is the use of "cards"; apply
/// a `.light` or `.dark` effect to the backdrop view, set its `cornerRadius = 4.5`,
/// `rimOpacity = 0.25`, and add a `NSView.shadow` (visually similar to `NSWindow`).
///
/// Note: if set as the containing `window`'s `contentView`, the window's
/// `isOpaque` value will be changed. If the window's `contentView` is changed,
/// the original settings are restored. However, unlike `NSVisualEffectView`,
/// no desktop bleed blending will occur. In  addition, `.behindWindow` blending
/// cannot be applied if the view is not the `window`'s `contentView`.
///
/// Note: A NotificationCenter effect is simulated with `kCAFilterColorBrightness @ 0.5`.
@available(macOS 11.0, *)
public final class BackdropView: NSVisualEffectView {
    /// The `Effect` structure describes the parameters used by the `BackdropView`
    /// to produce its effects. Note that these effects do not cascade to any
    /// subviews; that is instead governed by the `BackdropView.effectiveAppearance`.
    public struct Effect {
        /// The `backgroundColor` is and autoclosure used to dynamically blend with
        /// the layers and contents behind the `BackdropView`.
        public let backgroundColor: () -> (NSColor)

        /// The `tintColor` is an autoclosure used to dynamically set the tint color.
        /// This is also the color used when the `BackdropView` is visually inactive.
        public let tintColor: () -> (NSColor)

        /// The `tintFilter` can be any object accepted by `CALayer.compositingFilter`.
        public let tintFilter: Any?

        /// Create a new `BackdropView.Effect` with the provided parameters.
        public init(
            _ backgroundColor: @autoclosure @escaping () -> (NSColor),
            _ tintColor: @autoclosure @escaping () -> (NSColor),
            _ tintFilter: Any?
        ) {
            self.backgroundColor = backgroundColor
            self.tintColor = tintColor
            self.tintFilter = tintFilter
        }

        /// A clear effect (only applies blur and saturation); when inactive,
        /// appears transparent. Not suggested for typical use.
        public static var clear = Effect(
            NSColor(calibratedWhite: 1.00, alpha: 0.05),
            NSColor(calibratedWhite: 1.00, alpha: 0.00),
            nil
        )

        /// A medium light effect.
        public static var mediumLight = Effect(
            NSColor(calibratedWhite: 1.00, alpha: 0.30),
            NSColor(calibratedWhite: 0.94, alpha: 1.00),
            kCAFilterDarkenBlendMode
        )

        /// A light effect.
        public static var light = Effect(
            NSColor(calibratedWhite: 0.97, alpha: 0.70),
            NSColor(calibratedWhite: 0.94, alpha: 1.00),
            kCAFilterDarkenBlendMode
        )

        /// An ultra light effect.
        public static var ultraLight = Effect(
            NSColor(calibratedWhite: 0.97, alpha: 0.85),
            NSColor(calibratedWhite: 0.94, alpha: 1.00),
            kCAFilterDarkenBlendMode
        )

        /// A medium dark effect.
        public static var mediumDark = Effect(
            NSColor(calibratedWhite: 1.00, alpha: 0.40),
            NSColor(calibratedWhite: 0.84, alpha: 1.00),
            kCAFilterDarkenBlendMode
        )

        /// A dark effect.
        public static var dark = Effect(
            NSColor(calibratedWhite: 0.12, alpha: 0.45),
            NSColor(calibratedWhite: 0.16, alpha: 1.00),
            kCAFilterLightenBlendMode
        )

        /// An ultra dark effect.
        public static var ultraDark = Effect(
            NSColor(calibratedWhite: 0.12, alpha: 0.80),
            NSColor(calibratedWhite: 0.01, alpha: 1.00),
            kCAFilterLightenBlendMode
        )

        /// A selection effect that matches the user's current aqua color preference.
        public static var selection = Effect(
            NSColor.keyboardFocusIndicatorColor.withAlphaComponent(0.7),
            NSColor.keyboardFocusIndicatorColor,
            kCAFilterDestOver
        )
        // Note: `keyboardFocusIndicatorColor` was used because it's the only
        // dynamic color that isn't a pattern image color.
    }

    /// If multiple `BackdropView`s within the same layer tree (that is, window)
    /// share the same `BlendGroup`, they will be composited and blended
    /// together as a single continuous backdrop. However, setting different
    /// `effect`s may cause visual disparity; use with caution.
    public final class BlendGroup {
        /// The notification posted upon deinit of a `BlendGroup`.
        fileprivate static let removedNotification = Notification.Name("BackdropView.BlendGroup.deinit")

        /// The internal value used for `CABackdropLayer.groupName`.
        fileprivate let value = UUID().uuidString

        /// Create a new `BlendGroup`.
        public init() {}

        deinit {
            // Alert all `BackdropView`s that we're about to be removed.
            // The `BackdropView` will figure out if it needs to update itself.
            NotificationCenter.default.post(
                name: BlendGroup.removedNotification,
                object: nil,
                userInfo: ["value": self.value]
            )
        }

        /// The `global` BlendGroup, if it is desired that all backdrops share
        /// the same blending group through the layer tree (window).
        public static let global = BlendGroup()

        /// The default internal value used for `CABackdropLayer.groupName`.
        /// This is to be used if no `BlendGroup` is set on the `BackdropView`.
        fileprivate static func `default`() -> String {
            return UUID().uuidString
        }
    }

    /// If `state` is set to `.followsWindowActiveState` or `NSWorkspace`'s
    /// `accessibilityDisplayShouldReduceTransparency` is true, the true visual
    /// state of the `BackdropView` may actually be `.active` or `.inactive`,
    /// and may change without notice. If such a state change occurs, this property
    /// governs whether or not that the visual change is animated.
    ///
    /// Note: this property is disregarded if properties are set within an active
    /// `NSAnimationContext` grouping.
    public var animatesImplicitStateChanges: Bool = false

    /// The visual effect to present within the `BackdropView`. See `BackdropView.Effect`.
    public var effect: BackdropView.Effect = .clear {
        didSet {
            transaction {
                self.backdrop?.backgroundColor = self.effect.backgroundColor().cgColor
                self.tint?.backgroundColor = self.effect.tintColor().cgColor
                self.tint?.compositingFilter = self.effect.tintFilter
            }
        }
    }

    /// If multiple `BackdropView`s within the same layer tree (that is, window)
    /// share the same `BlendGroup`, they will be composited and blended
    /// together as a single continuous backdrop. However, setting different
    /// `effect`s may cause visual disparity; use with caution.
    ///
    /// Note: you must retain any non-`global` `BlendGroup`s yourself.
    public weak var blendingGroup: BlendGroup? = nil {
        didSet {
            transaction {
                self.backdrop?.groupName = self.blendingGroup?.value ?? BlendGroup.default()
            }
        }
    }

    /// The gaussian blur radius of the visual effect. Animatable.
    public var blurRadius: CGFloat {
        get { return backdrop?.value(forKeyPath: "filters.gaussianBlur.inputRadius") as? CGFloat ?? 0 }
        set {
            transaction {
                self.backdrop?.setValue(newValue, forKeyPath: "filters.gaussianBlur.inputRadius")
            }
        }
    }

    /// The background color saturation factor of the visual effect. Animatable.
    public var saturationFactor: CGFloat {
        get { return backdrop?.value(forKeyPath: "filters.colorSaturate.inputAmount") as? CGFloat ?? 0 }
        set {
            transaction {
                self.backdrop?.setValue(newValue, forKeyPath: "filters.colorSaturate.inputAmount")
            }
        }
    }

    /// The corner radius of the view.
    public var cornerRadius: CGFloat = 0.0 {
        didSet {
            transaction {
                self.container?.cornerRadius = self.cornerRadius
                self.rim?.cornerRadius = self.cornerRadius
            }
        }
    }

    /// The `BackdropView`'s rim serves to provide a visual contrast at its edges.
    /// If `rimOpacity > 0.0`, a slight hairline border is rendered around the view.
    ///
    /// Note: this property, along with `shadow` requires the superview to be
    /// layer-backed. The rim is contained 0.5px outside of the view.
    public var rimOpacity: CGFloat = 0.0 {
        didSet {
            transaction {
                self.rim!.opacity = 0.25
            }
        }
    }

    /// Automatically `.behindWindow` if set as the contentView of the window.
    /// Otherwise, the view is ALWAYS `.withinWindow` blended. Thus, it is not
    /// possible to "punch out" the window in specific regions.
    public override var blendingMode: NSVisualEffectView.BlendingMode {
        get { return window?.contentView == self ? .behindWindow : .withinWindow }
        set {}
    }

    /// Always `.appearanceBased`; use `effect` instead.
    public override var material: NSVisualEffectView.Material {
        get { return .appearanceBased }
        set {}
    }

    /// Specify how the `effect` should reflect window activity or accessibility state.
    public override var state: NSVisualEffectView.State {
        get { return _state }
        set { _state = newValue }
    }

    /// We handle the state differently from our superview, which requires `.active`.
    /// Bounce the `state.didSet` onto `reduceTransparencyChanged`.
    private var _state: NSVisualEffectView.State = .active {
        didSet {
            // Don't be called when `commonInit` hasn't finished.
            guard let _ = backdrop else { return }
            reduceTransparencyChanged(nil)
        }
    }

    private var backdrop: CABackdropLayer? = nil
    private var tint: CALayer? = nil
    private var container: CALayer? = nil
    private var rim: CALayer? = nil

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.masksToBounds = false
        layer?.name = "view"

        // Essentially, tell the `NSVisualEffectView` to not do its job:
        super.state = .active
        super.blendingMode = .withinWindow
        super.material = .appearanceBased
        setValue(true, forKey: "clear") // internal material

        // Set up our backdrop view:
        backdrop = CABackdropLayer()
        backdrop?.name = "backdrop"
        backdrop?.allowsGroupBlending = true
        backdrop?.allowsGroupOpacity = true
        backdrop?.allowsEdgeAntialiasing = false
        backdrop?.disablesOccludedBackdropBlurs = true
        backdrop?.ignoresOffscreenGroups = true
        backdrop?.allowsInPlaceFiltering = false // blendgroups don't work otherwise
        backdrop?.scale = 1.0 // 0.25 typically
        backdrop?.bleedAmount = 0.0
        // Set up the backdrop filters:

        let blur = CAFilter(type: kCAFilterGaussianBlur)!
        let saturate = CAFilter(type: kCAFilterColorSaturate)!
        blur.setValue(true, forKey: "inputNormalizeEdges")
        backdrop?.filters = [blur, saturate]

        // Set up the tint and container view:
        tint = CALayer()
        tint?.name = "tint"
        container = CALayer()
        container?.name = "container"
        container?.masksToBounds = true
        container?.allowsGroupBlending = true
        container?.allowsEdgeAntialiasing = false
        container?.sublayers = [backdrop!, tint!]
        layer?.insertSublayer(container!, at: 0)

        // Set up rim:
        rim = CALayer()
        rim?.name = "rim"
        rim?.borderWidth = 0.5
        rim?.opacity = 0.0
        layer?.addSublayer(rim!)

        // Set our effect-related properties:
        _state = .followsWindowActiveState
        blendingGroup = nil
        blurRadius = 30.0
        saturationFactor = 2.5
        effect = .clear

        // [Note] macOS 11+: no longer necessary to call `removeObserver` upon `deinit`.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceTransparencyChanged(_:)),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: NSWorkspace.shared
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorVariantsChanged(_:)),
            name: NSColor.systemColorsDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(blendGroupsChanged(_:)),
            name: BlendGroup.removedNotification,
            object: nil
        )
    }

    /// Update sublayer `frame`.
    public override func layout() {
        super.layout()
        transaction(false) {
            self.container?.frame = self.layer?.bounds ?? .zero
            self.backdrop?.frame = self.layer?.bounds ?? .zero
            self.tint?.frame = self.layer?.bounds ?? .zero
            self.rim?.frame = self.layer?.bounds.insetBy(dx: -0.5, dy: -0.5) ?? .zero
        }
    }

    /// Update sublayer `contentsScale`.
    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        let scale = window?.backingScaleFactor ?? 1.0
        transaction(false) {
            self.layer?.contentsScale = scale
            self.container?.contentsScale = scale
            self.backdrop?.contentsScale = scale
            self.tint?.contentsScale = scale
            self.rim?.contentsScale = scale
        }
    }

    /// Adjust our `BlendGroup` information if we need to.
    @objc private func blendGroupsChanged(_ note: NSNotification!) {
        guard let removed = note.userInfo?["value"] as? String else { return }
        guard let backdrop, backdrop.groupName == removed else { return }

        transaction(animatesImplicitStateChanges) {
            backdrop.groupName = BlendGroup.default() // was nil'd out
        }
    }

    /// Allow dynamic/system colors update themselves.
    @objc private func colorVariantsChanged(_ note: NSNotification!) {
        guard let _ = backdrop else { return }

        DispatchQueue.main.async {
            self.transaction(self.animatesImplicitStateChanges) {
                self.backdrop!.backgroundColor = self.effect.backgroundColor().cgColor
                self.tint?.backgroundColor = self.effect.tintColor().cgColor
            }
        }
    }

    /// Modifies sublayers if the dynamic property `reduceTransparency` has changed.
    @objc private func reduceTransparencyChanged(_ note: NSNotification!) {
        // If `note` is `nil`, it is considered that we invoked this method from
        // `BackdropView.state.didSet` - if so, allow animation of the visual state
        // if called within an `NSAnimationContext` grouping.
        let actions = (
            animatesImplicitStateChanges ||
                (note == nil && (CATransaction.value(forKey: "NSAnimationContextBeganGroup") as? Bool ?? false))
        )
        let reduceTransparency = (
            NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency ||
                _state == .inactive ||
                (_state == .followsWindowActiveState && !(window?.isMainWindow ?? false))
        )

        // Enable/disable the backdrop layer and tint layer's `compositingFilter`.
        transaction(actions) {
            self.backdrop?.isEnabled = !reduceTransparency
            self.tint?.compositingFilter = !reduceTransparency ? self.effect.tintFilter : nil

            // Allows the actual animation to work; `-setEnabled:` isn't animated.
            if reduceTransparency {
                self.backdrop!.removeFromSuperlayer()
            } else {
                self.container!.insertSublayer(self.backdrop!, at: 0)
            }
        }
    }

    /// Creates a nested transaction whose actions are only enabled by default if
    /// called within an active `NSAnimationContext` grouping.
    ///
    /// Note: also sets the current NSAppearance for drawing purposes.
    private func transaction(_ actions: Bool? = nil, _ handler: () -> Void) {
        let actions = actions ?? CATransaction.value(forKey: "NSAnimationContextBeganGroup") as? Bool ?? false

        // NSAnimationContext handles per-thread activation of CATransaction for us.
        NSAnimationContext.beginGrouping()
        CATransaction.setDisableActions(!actions)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            handler()
        }

        NSAnimationContext.endGrouping()
    }

    public override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)

        // Restore our window's settings, if we were the `contentView` only.
        if let oldWindow = window, oldWindow.contentView == self {
            configurator.unapply(from: oldWindow)
        }

        // Unregister window main-ness changes:
        guard let _ = window else { return }
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didBecomeMainNotification,
            object: window!
        )
        NotificationCenter.default.removeObserver(
            self,
            name: NSWindow.didResignMainNotification,
            object: window!
        )
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Adjust the backdrop layer's WindowServer awareness.
        backdrop?.windowServerAware = (window?.contentView == self)

        // Set parent window configuration, if we're the `contentView` only.
        if let newWindow = window, newWindow.contentView == self {
            configurator.apply(to: newWindow)
        }

        // Register for window main-ness changes:
        guard let _ = window else { return }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceTransparencyChanged(_:)),
            name: NSWindow.didBecomeMainNotification,
            object: window!
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceTransparencyChanged(_:)),
            name: NSWindow.didResignMainNotification,
            object: window!
        )
        reduceTransparencyChanged(NSNotification(name: NSWindow.didBecomeMainNotification, object: nil))
    }

    //
    // [Private SPI] HERE LIE DRAGONS!
    //

    private var configurator = WindowConfigurator()

    /// Declared for NSVisualEffectView; affects non-contentView backdrops.
    @objc private func _shouldAutoFlattenLayerTree() -> Bool {
        return false
    }

    /// Controls key `NSWindow` operations if the `BackdropView` is its `contentView`.
    private struct WindowConfigurator {
        private var observer: Any? = nil

        private var shouldAutoFlattenLayerTree = true
        private var canHostLayersInWindowServer = true
        private var isOpaque = false
        private var backgroundColor: NSColor? = nil

        /// Call upon migration to a new window.
        mutating func apply(to newWindow: NSWindow) {
            shouldAutoFlattenLayerTree = newWindow.value(forKey: "shouldAutoFlattenLayerTree") as? Bool ?? true
            canHostLayersInWindowServer = newWindow.value(forKey: "canHostLayersInWindowServer") as? Bool ?? true
            isOpaque = newWindow.isOpaque
            backgroundColor = newWindow.backgroundColor

            // The WindowServer automatically flattens the render layer tree on its
            // end after a delayed duration (currently 1.05s). This is likely to
            // allow higher performance in windows that don't require effects.
            newWindow.setValue(false, forKey: "shouldAutoFlattenLayerTree")

            // `CGSSetSurfaceLayerBackingOptions` needs to be set to prevent layer
            // tree flattening, and `NSWindow` doesn't inform its `NSViewLayerSurface`s
            // to do this, EXCEPT upon initial surface creation, which happens
            // during the first call to `-[NSWindow displayIfNeeded]`, where the layer
            // tree is set up to match the `NSView` tree.
            //
            // A possible fix would be to grab "borderView.layerSurface.surface.surfaceID"
            // and call `CGSSetSurfaceLayerBackingOptions` ourselves, but we don't
            // consider currently set AppKit defaults.
            //
            // Instead, a simple workaround is to toggle `canHostLayersInWindowServer`
            // off and back on again, as this recreates the layer tree immediately
            // in both cases. This is, however, an "expensive" operation, but we
            // don't expect to be swapping `contentView` in and out rapidly anyway.
            newWindow.setValue(false, forKey: "canHostLayersInWindowServer")
            newWindow.setValue(true, forKey: "canHostLayersInWindowServer")

            // If the window is not opaque, the `CABackdropLayer` cannot sample behind it.
            newWindow.isOpaque = false

            // If the window's `backgroundColor` is `.clear`, the theme frame/`borderView`
            // will unfortunately turn off corner masking, which then causes terrible
            // window resize lag. This is likely because without a mask, WindowServer
            // recomputes the "real shape" for any non-opaque windows.
            newWindow.backgroundColor = NSColor.white.withAlphaComponent(0.001)

            // The kCGSNeverFlattenSurfacesDuringSwipesTagBit tells WindowServer to
            // not flatten the layer tree on its end, during Spaces swipes.
            let fixSurfaces: () -> Void = { [weak newWindow] in
                guard let newWindow else { return }

                var x: [Int32] = [0x0, 1 << 23 /* kCGSNeverFlattenSurfacesDuringSwipesTagBit? */ ]
                _ = CGSSetWindowTags(
                    NSApp.value(forKey: "contextID") as! Int32,
                    Int32(newWindow.windowNumber),
                    &x,
                    0x40 // kCGSRealMaximumTagSize
                )
            }

            // Since `_startLiveResize` and the balanced `_endLiveResize` calls made
            // to `NSWindow` add and then reset this tag, respectively, we want to
            // make sure we restore it ourselves upon `_endLiveResize` using this note.
            DispatchQueue.main.async(execute: fixSurfaces)
            observer = NotificationCenter.default.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: newWindow, queue: nil) { _ in
                DispatchQueue.main.async(execute: fixSurfaces)
            }
        }

        /// Call upon migration away from an existing window.
        mutating func unapply(from oldWindow: NSWindow) {
            // See the above notes for the particular order of operations.
            oldWindow.setValue(shouldAutoFlattenLayerTree, forKey: "shouldAutoFlattenLayerTree")
            oldWindow.setValue(false, forKey: "canHostLayersInWindowServer")
            oldWindow.setValue(canHostLayersInWindowServer, forKey: "canHostLayersInWindowServer")
            oldWindow.isOpaque = isOpaque
            oldWindow.backgroundColor = backgroundColor

            // There's no need to clear the kCGSNeverFlattenSurfacesDuringSwipesTagBit
            // window tag, as the window will manage that itself upon resize.
            NotificationCenter.default.removeObserver(observer!)
        }
    }
}

@_silgen_name("CGSSetWindowTags")
func CGSSetWindowTags(_ cid: Int32, _ wid: Int32, _ tags: UnsafePointer<Int32>!, _ maxTagSize: Int) -> CGError
