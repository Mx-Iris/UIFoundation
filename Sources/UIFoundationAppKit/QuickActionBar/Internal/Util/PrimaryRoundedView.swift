//
//  PrimaryRoundedView.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

import AppKit
import Foundation

extension QuickActionBar {
    /// The primary drawing view for the quick action bar.
    internal final class PrimaryRoundedView: NSView {
        override var allowsVibrancy: Bool { true }
        override var wantsUpdateLayer: Bool { true }

        let contentView = NSView()

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
                let glassView = NSGlassEffectView()
                glassView.contentView = contentView
                glassView.cornerRadius = 28
                glassView.translatesAutoresizingMaskIntoConstraints = false
                addSubview(glassView)
                NSLayoutConstraint.activate([
                    topAnchor.constraint(equalTo: glassView.topAnchor),
                    leadingAnchor.constraint(equalTo: glassView.leadingAnchor),
                    trailingAnchor.constraint(equalTo: glassView.trailingAnchor),
                    bottomAnchor.constraint(equalTo: glassView.bottomAnchor),
                ])
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
            } else {
                layer?.cornerRadius = bounds.height / 2
            }
        }
    }
}

#endif
