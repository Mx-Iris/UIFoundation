//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// The rounded translucent platter everything else sits on.
    ///
    /// Two shells, picked at runtime: `NSGlassEffectView` on macOS 26, which is the material
    /// Spotlight itself wears, and an `NSVisualEffectView` before that. Hosts add their content
    /// to ``contentView`` and never touch either shell.
    ///
    /// This view is also the one the present / dismiss transform is applied to, so it is
    /// deliberately inset from the window edge by ``Metrics/animationPadding`` — scaling up to
    /// 1.12 inside a tight window would clip.
    final class BackgroundView: NSView {
        let contentView = NSView()

        private var cornerRadius: CGFloat

        override var allowsVibrancy: Bool { true }
        override var wantsUpdateLayer: Bool { true }

        init(cornerRadius: CGFloat) {
            self.cornerRadius = cornerRadius
            super.init(frame: .zero)
            setUp()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setUp() {
            wantsLayer = true
            translatesAutoresizingMaskIntoConstraints = false
            contentView.translatesAutoresizingMaskIntoConstraints = false

            // `NSGlassEffectView` does **not** clip its content view to the glass shape — a table
            // view's selection band runs square right through the rounded corners, and the last
            // partly-scrolled row is cut off with a hard edge. Clipping is this view's job.
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = cornerRadius
            contentView.layer?.cornerCurve = .continuous
            contentView.layer?.masksToBounds = true

            if #available(macOS 26.0, *) {
                let glassEffectView = NSGlassEffectView()
                glassEffectView.cornerRadius = cornerRadius
                glassEffectView.contentView = contentView
                glassEffectView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(glassEffectView)
                pin(glassEffectView, toEdgesOf: self)
            } else {
                let visualEffectView = NSVisualEffectView()
                visualEffectView.blendingMode = .behindWindow
                visualEffectView.material = .menu
                visualEffectView.state = .active
                visualEffectView.wantsLayer = true
                visualEffectView.layer?.cornerRadius = cornerRadius
                visualEffectView.layer?.cornerCurve = .continuous
                visualEffectView.layer?.masksToBounds = true
                visualEffectView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(visualEffectView)
                pin(visualEffectView, toEdgesOf: self)

                visualEffectView.addSubview(contentView)
                pin(contentView, toEdgesOf: visualEffectView)
            }
        }

        private func pin(_ view: NSView, toEdgesOf container: NSView) {
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: container.topAnchor),
                view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                view.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
    }
}

#endif
