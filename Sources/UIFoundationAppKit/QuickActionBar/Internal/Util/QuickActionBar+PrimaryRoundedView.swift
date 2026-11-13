//
//  QuickActionBar+PrimaryRoundedView.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import AppKit
import Foundation

extension QuickActionBar {
    /// The primary drawing view for the quick action bar.
    internal final class PrimaryRoundedView: NSView {
        override var allowsVibrancy: Bool { true }
        override var wantsUpdateLayer: Bool { true }

        let contentView = NSView()

        /// macOS 26 and later: the platter's glass, with room for the browse buttons.
        @available(macOS 26.0, *)
        var glassPlatterView: GlassPlatterView? {
            glassPlatterViewStorage as? GlassPlatterView
        }

        private var glassPlatterViewStorage: NSView?

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            self.setup()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.setup()
        }

        private func setup() {
            self.wantsLayer = true
            self.translatesAutoresizingMaskIntoConstraints = false

            if #available(macOS 26.0, *) {
                let glassPlatterView = QuickActionBar.GlassPlatterView(platterContentView: contentView)
                glassPlatterView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(glassPlatterView)
                NSLayoutConstraint.activate([
                    topAnchor.constraint(equalTo: glassPlatterView.topAnchor),
                    leadingAnchor.constraint(equalTo: glassPlatterView.leadingAnchor),
                    trailingAnchor.constraint(equalTo: glassPlatterView.trailingAnchor),
                    bottomAnchor.constraint(equalTo: glassPlatterView.bottomAnchor),
                ])
                glassPlatterViewStorage = glassPlatterView
            } else if !NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency {
                let blurView = NSVisualEffectView()
                blurView.translatesAutoresizingMaskIntoConstraints = false
                blurView.wantsLayer = true
                blurView.blendingMode = .behindWindow
                blurView.material = .menu
                blurView.state = .active
                blurView.setContentHuggingPriority(.defaultLow, for: .vertical)
                blurView.setContentHuggingPriority(.defaultLow, for: .horizontal)
                blurView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
                blurView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                self.addSubview(blurView)
                NSLayoutConstraint.activate([
                    topAnchor.constraint(equalTo: blurView.topAnchor),
                    leadingAnchor.constraint(equalTo: blurView.leadingAnchor),
                    trailingAnchor.constraint(equalTo: blurView.trailingAnchor),
                    bottomAnchor.constraint(equalTo: blurView.bottomAnchor),
                ])
                blurView.layer?.mask = self.layer
                contentView.translatesAutoresizingMaskIntoConstraints = false
                blurView.addSubview(contentView)
                NSLayoutConstraint.activate([
                    blurView.topAnchor.constraint(equalTo: contentView.topAnchor),
                    blurView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                    blurView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                    blurView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
                ])
            }
        }

        override func updateLayer() {
            if #unavailable(macOS 26.0) {
                let baseLayer = self.layer!
                baseLayer.cornerRadius = 10
                baseLayer.backgroundColor = NSColor.windowBackgroundColor.cgColor
                // Match the Spotlight panel style.
                let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                if isDark {
                    baseLayer.borderWidth = 1
                    baseLayer.borderColor =
                        NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
                            ? NSColor.secondaryLabelColor.cgColor
                            : NSColor.tertiaryLabelColor.cgColor
                } else {
                    baseLayer.borderWidth = 0
                }
            }
            // macOS 26 and later draw nothing here: the glass carries its own corner radius. A
            // radius on this layer would also turn `clipsToBounds` on (macOS 27.2) and trim the
            // browse buttons, which overshoot past the platter's trailing edge as they settle.
        }
    }
}

#endif
