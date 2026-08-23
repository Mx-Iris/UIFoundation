#if WelcomePanel && os(macOS)

import AppKit

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// A scroll view that paints its background through its layer, and hides the vibrancy view
    /// AppKit inserts behind a source-list table.
    ///
    /// The layer detour is what the original WelcomeKit did, and it is kept deliberately:
    /// `NSScrollView` already owns a `backgroundColor` property, so this cannot ride the library's
    /// `LayerBackgroundProviding` pipeline — a protocol-extension property of the same name is
    /// shadowed by the class one at every call site. Overriding the class property instead keeps
    /// `scrollView.backgroundColor = …` meaning what it looks like it means.
    final class BackgroundScrollView: ScrollView {
        override var backgroundColor: NSColor {
            didSet {
                needsDisplay = true
            }
        }

        override var wantsUpdateLayer: Bool { true }

        override func setup() {
            super.setup()

            wantsLayer = true
            layerContentsRedrawPolicy = .onSetNeedsDisplay
            isHiddenVisualEffectView = true
            backgroundColor = .clear
        }

        override func updateLayer() {
            super.updateLayer()

            layer?.backgroundColor = backgroundColor.cgColor
        }
    }
}

#endif
