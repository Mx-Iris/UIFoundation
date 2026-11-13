//
//  QuickActionBar+GlassPlatterView.swift
//  UIFoundation
//

#if QuickActionBar && os(macOS)

import AppKit

extension QuickActionBar {
    /// The search platter's glass on macOS 26 and later, held in a glass container so that the
    /// browse buttons can bud out of it the way Spotlight's do.
    ///
    /// `NSGlassEffectContainerView` draws its member glass views as one material over a smooth
    /// union of their shapes, and its `spacing` is the smoothing distance of that union — the
    /// value Spotlight animates as `mitosisSmoothness`. The container rebuilds each member's shape
    /// from its frame and corner radius on every layout pass and never reads a layer transform,
    /// so everything here that changes shape changes its frame.
    @available(macOS 26.0, *)
    final class GlassPlatterView: NSView {
        /// The view inside the platter's glass; the search field and the results live in it.
        let platterContentView: NSView

        private let glassContainerView = NSGlassEffectContainerView()
        private let glassLayoutView = FlippedContainerView()
        private let platterGlassView = NSGlassEffectView()

        /// The platter's corner radius: half of Spotlight's 56 pt collapsed height, kept when
        /// the results make the platter taller.
        static let platterCornerRadius: CGFloat = 28

        init(platterContentView: NSView) {
            self.platterContentView = platterContentView
            super.init(frame: .zero)
            setup()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setup() {
            wantsLayer = true

            glassContainerView.translatesAutoresizingMaskIntoConstraints = false
            glassContainerView.contentView = glassLayoutView
            addSubview(glassContainerView)
            NSLayoutConstraint.activate([
                glassContainerView.topAnchor.constraint(equalTo: topAnchor),
                glassContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
                glassContainerView.trailingAnchor.constraint(equalTo: trailingAnchor),
                glassContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ])

            platterGlassView.cornerRadius = Self.platterCornerRadius
            platterGlassView.contentView = platterContentView
            glassLayoutView.addSubview(platterGlassView)
        }

        /// The glass view drawing the platter, in the container's content view.
        var platterGlass: NSGlassEffectView {
            platterGlassView
        }

        override func layout() {
            super.layout()
            layoutGlassViews()
        }

        private func layoutGlassViews() {
            platterGlassView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        }
    }
}

#endif
