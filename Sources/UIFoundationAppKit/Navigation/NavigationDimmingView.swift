//
//  Ported from the macOS App Store's own navigation stack.
//  Reverse-engineering notes: Researchs/AppStore-Custom-Navigation-Internals.md
//

#if Navigation && os(macOS)

import AppKit

/// The flat colour laid over the view being pushed away.
///
/// The App Store uses its own `BackgroundView` here, but only ever for a solid fill, so this is a
/// plain layer-backed `NSView` instead. It is transparent to the mouse: the view underneath is on
/// its way out and must not appear clickable, and the incoming view sits above this one anyway.
final class NavigationDimmingView: NSView {
    var color: NSColor {
        didSet {
            guard color != oldValue else { return }
            needsDisplay = true
        }
    }

    init(color: NSColor) {
        self.color = color
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        dirtyRect.fill()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }
}

#endif
