#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit
#if AppKitPlus && canImport(AppKitPlus)
import AppKitPlus
#endif

/// Pins which class `LayerBackedView` inherits from on each side of the `AppKitPlus` trait, and
/// keeps two canaries on the things a future AppKitPlus release could silently take away.
///
/// Both canaries assert that *switching the base class changed nothing* — they must pass with the
/// trait on and off alike. Each one reproduces a real regression measured against an earlier
/// AppKitPlus release, which is why they are worth their weight:
///
/// * through 0.1.6 an `NSView (Appearance)` category declared `backgroundColor`, and an ObjC class
///   member wins name lookup over a protocol extension — `LayerBackgroundProviding`'s pipeline
///   stopped receiving the value entirely, in this module and in every downstream one;
/// * through 0.1.6 the base class also lowered content compression resistance to 500 on both axes,
///   which quietly re-prioritised every existing subclass against its surroundings.
@Suite("LayerBackedView base class")
@MainActor
struct LayerBackedViewBaseClassTests {
    @Test("inherits from NSLayerBackedView exactly when the AppKitPlus trait is on")
    func baseClass() {
        #if AppKitPlus && canImport(AppKitPlus)
        #expect(LayerBackedView.superclass() == NSLayerBackedView.self)
        #else
        #expect(LayerBackedView.superclass() == NSView.self)
        #endif
    }

    @Test("the layer-backing defaults are the same on both sides of the trait")
    func layerBackingDefaults() {
        let view = LayerBackedView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))

        #expect(view.wantsLayer)
        #expect(view.wantsUpdateLayer)
        #expect(view.layerContentsRedrawPolicy == .onSetNeedsDisplay)
    }

    /// Canary: a background colour and a corner radius set on the view end up on its backing
    /// layer, and a layer update does not write them back — whoever owns them. Without the trait
    /// that is `LayerBackgroundRenderer`; with it, AppKitPlus 0.24.0's own members, which took
    /// these names over and left a renderer that still wrote its defaults (0, nil) onto the layer.
    @Test("a background colour and a corner radius set on the view reach its layer")
    func appearanceReachesTheLayer() throws {
        let view = LayerBackedView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        view.backgroundColor = .red
        view.cornerRadius = 8

        view.updateLayer()

        let layer = try #require(view.layer)
        #expect(layer.backgroundColor == NSColor.red.cgColor)
        #expect(layer.cornerRadius == 8)
    }

    /// A colour and a width alone draw no border until the edges are named, on both sides of the
    /// trait. AppKitPlus's own default is every edge; `LayerBackedView` keeps the renderer's.
    @Test("a border colour and width alone draw no border")
    func bordersStayOffUntilEdgesAreNamed() throws {
        let view = LayerBackedView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        view.borderColor = .red
        view.borderWidth = 2

        view.updateLayer()
        view.layout()

        #expect(view.borderPositions.isEmpty)
        let layer = try #require(view.layer)
        #expect(layer.borderWidth == 0)
        let strokingSublayers = (layer.sublayers ?? []).filter { sublayer in
            let strokesItsPath = (sublayer as? CAShapeLayer).map { $0.strokeColor != nil && $0.lineWidth > 0 } ?? false
            return sublayer.borderWidth > 0 || strokesItsPath
        }
        #expect(strokingSublayers.isEmpty)
    }

    #if AppKitPlus && canImport(AppKitPlus)
    /// With the trait on, the five `shadow*` members write through to `shadowProperties`, which
    /// owns the view's shadow there; `nil` for the colour draws no shadow.
    @Test("the shadow members write through to shadowProperties")
    func shadowMembersForwardToShadowProperties() {
        let view = LayerBackedView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        let path = NSBezierPath(rect: NSRect(x: 0, y: 0, width: 10, height: 10))

        view.shadowColor = .systemBlue
        view.shadowOpacity = 0.25
        view.shadowOffset = CGSize(width: 0, height: -3)
        view.shadowRadius = 6
        view.shadowPath = path

        #expect(view.shadowProperties.color == .systemBlue)
        #expect(view.shadowProperties.opacity == 0.25)
        #expect(view.shadowProperties.offset == CGSize(width: 0, height: -3))
        #expect(view.shadowProperties.radius == 6)
        // `shadowProperties` keeps a copy of the path, and `NSBezierPath` compares by identity.
        #expect(view.shadowProperties.path?.bounds == path.bounds)
        #expect(view.shadowPath?.bounds == path.bounds)

        view.shadowColor = nil
        #expect(view.shadowProperties.color == .clear)
    }
    #endif

    /// Canary: `NSLayerBackedView` deliberately leaves compression resistance at AppKit's default.
    /// UXKit's `UXView`, which it is ported from, lowers it to 500.
    @Test("content compression resistance stays at AppKit's default")
    func compressionResistance() {
        let view = LayerBackedView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))

        #expect(view.contentCompressionResistancePriority(for: .horizontal) == .defaultHigh)
        #expect(view.contentCompressionResistancePriority(for: .vertical) == .defaultHigh)
    }
}

#endif
