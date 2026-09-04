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

    /// Canary: `backgroundColor` and `cornerRadius` must still reach `LayerBackgroundRenderer`,
    /// which is what writes them onto the backing layer from `updateLayer()`.
    @Test("background rendering still routes through LayerBackgroundRenderer")
    func backgroundRoutesThroughRenderer() {
        let view = LayerBackedView(frame: NSRect(x: 0, y: 0, width: 40, height: 40))
        view.backgroundColor = .red
        view.cornerRadius = 8

        view.updateLayer()

        let layer = try? #require(view.layer)
        #expect(layer?.backgroundColor == NSColor.red.cgColor)
        #expect(layer?.cornerRadius == CGFloat(8))
    }

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
