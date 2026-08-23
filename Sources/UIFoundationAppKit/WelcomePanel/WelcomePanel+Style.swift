#if WelcomePanel && os(macOS)

import AppKit
import UIFoundationToolbox

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// Which Xcode release the panel imitates.
    ///
    /// The three cases differ in window chrome, geometry, typography and colors; every difference
    /// is expressed by the internal properties below rather than being scattered through the views.
    public enum Style {
        /// Xcode 14: a titled window, an always-present "show on launch" checkbox, and action rows
        /// carrying both a title and a subtitle.
        case xcode14
        /// Xcode 15: a borderless rounded window over a vibrancy backdrop, with title-only action rows.
        case xcode15
        /// Xcode 26: the Xcode 15 geometry without the vibrancy backdrop.
        case xcode26

        var actionTableViewHeight: CGFloat {
            switch self {
            case .xcode14:
                138
            case .xcode15, .xcode26:
                132
            }
        }

        var actionTableViewCellHeight: CGFloat {
            switch self {
            case .xcode14:
                46
            case .xcode15, .xcode26:
                36
            }
        }

        var actionTableViewSpacing: CGFloat {
            switch self {
            case .xcode14:
                0
            case .xcode15, .xcode26:
                8
            }
        }

        var windowStyleMask: NSWindow.StyleMask {
            switch self {
            case .xcode14:
                [.titled, .fullSizeContentView]
            case .xcode15, .xcode26:
                [.borderless]
            }
        }

        var windowRect: CGRect {
            switch self {
            case .xcode14:
                .init(x: 0, y: 0, width: 800, height: 460)
            case .xcode15, .xcode26:
                .init(x: 0, y: 0, width: 740, height: 460)
            }
        }

        var projectViewWidth: CGFloat {
            switch self {
            case .xcode14:
                307
            case .xcode15, .xcode26:
                280
            }
        }

        var appImageViewTopSpacing: CGFloat {
            switch self {
            case .xcode14:
                40
            case .xcode15, .xcode26:
                52
            }
        }

        var windowCornerRadius: CGFloat {
            switch self {
            case .xcode14:
                0
            case .xcode15:
                8
            case .xcode26:
                20
            }
        }

        /// The backdrop behind the left pane; `nil` paints the pane flat instead.
        var welcomeViewMaterial: NSVisualEffectView.Material? {
            switch self {
            case .xcode14:
                nil
            case .xcode15:
                .underWindowBackground
            case .xcode26:
                // Measured: Xcode 26's backdrop filter chain is `.fullScreenUI`'s, value for value
                // (see Researchs/Xcode26-WelcomeWindow-Internals.md).
                .fullScreenUI
            }
        }

        /// The backdrop behind the recent-project list.
        var projectViewMaterial: NSVisualEffectView.Material {
            switch self {
            case .xcode14, .xcode15:
                .underWindowBackground
            case .xcode26:
                .fullScreenUI
            }
        }

        var welcomeViewBackgroundColor: NSColor {
            NSColor(name: .init("WelcomeViewBackgroundColor")) { appearance in
                switch self {
                case .xcode14:
                    if appearance.box.isDark {
                        return .windowBackgroundColor
                    } else {
                        return .white
                    }
                case .xcode15:
                    if appearance.box.isDark {
                        return .black.withAlphaComponent(0.2)
                    } else {
                        return .white
                    }
                case .xcode26:
                    // Measured over the material: `windowBackgroundColor` in both appearances, but
                    // at a different alpha in each.
                    return .windowBackgroundColor.withAlphaComponent(appearance.box.isDark ? 0.75 : 0.9)
                }
            }
        }

        var projectViewBackgroundColor: NSColor {
            switch self {
            case .xcode14:
                .clear
            case .xcode15:
                .init(name: "ProjectViewBackgroundColor") { $0.box.isDark ? .clear : .white.withAlphaComponent(0.6) }
            case .xcode26:
                // The dark value sits 4/255 off neutral in the capture; the light one is clean white.
                .init(name: "ProjectViewBackgroundColor.xcode26") { appearance in
                    appearance.box.isDark
                        ? NSColor(srgbRed: 0.1882, green: 0.1725, blue: 0.1843, alpha: 0.5)
                        : .white.withAlphaComponent(0.6)
                }
            }
        }

        var welcomeLabelDefaultFont: NSFont {
            switch self {
            case .xcode14:
                .systemFont(ofSize: 36, weight: .regular)
            case .xcode15:
                .systemFont(ofSize: 30, weight: .bold)
            case .xcode26:
                // Recovered by inversion: 36 pt bold is the only size/weight reproducing both the
                // measured 107 pt width and the 43 pt line box of the title layer.
                .systemFont(ofSize: 36, weight: .bold)
            }
        }

        var versionLabelDefaultFont: NSFont {
            switch self {
            case .xcode14:
                .systemFont(ofSize: 13, weight: .light)
            case .xcode15, .xcode26:
                .systemFont(ofSize: 13)
            }
        }

        var projectCellTitleLabelFont: NSFont {
            switch self {
            case .xcode14:
                .systemFont(ofSize: 13, weight: .regular)
            case .xcode15, .xcode26:
                .systemFont(ofSize: 13, weight: .semibold)
            }
        }

        var projectCellDetailLabelFont: NSFont {
            switch self {
            case .xcode14:
                .systemFont(ofSize: 11, weight: .regular)
            case .xcode15, .xcode26:
                .systemFont(ofSize: 11, weight: .regular)
            }
        }

        // MARK: - Action rows

        var actionCellCornerRadius: CGFloat {
            switch self {
            case .xcode14:
                0
            case .xcode15:
                8
            case .xcode26:
                // 36 pt tall and rounded by half its height: a capsule.
                18
            }
        }

        var actionCellBackgroundColor: NSColor {
            switch self {
            case .xcode14:
                .clear
            case .xcode15:
                .init(name: "WelcomePanel.actionCellBackground.xcode15") {
                    $0.box.isDark ? .white.withAlphaComponent(0.03) : .black.withAlphaComponent(0.05)
                }
            case .xcode26:
                .init(name: "WelcomePanel.actionCellBackground.xcode26") { appearance in
                    appearance.box.isDark
                        ? .white.withAlphaComponent(0.032)
                        : NSColor(srgbRed: 0.3725, green: 0.3725, blue: 0.3725, alpha: 0.096)
                }
            }
        }

        /// A static capture cannot show a pressed row, so the pressed fill is **not** measured: it
        /// applies the same alpha step the `xcode15` style uses between its two states.
        var actionCellHighlightBackgroundColor: NSColor {
            switch self {
            case .xcode14:
                .clear
            case .xcode15:
                .init(name: "WelcomePanel.actionCellHighlight.xcode15") {
                    $0.box.isDark ? .white.withAlphaComponent(0.05) : .black.withAlphaComponent(0.08)
                }
            case .xcode26:
                .init(name: "WelcomePanel.actionCellHighlight.xcode26") { appearance in
                    appearance.box.isDark
                        ? .white.withAlphaComponent(0.052)
                        : NSColor(srgbRed: 0.3725, green: 0.3725, blue: 0.3725, alpha: 0.126)
                }
            }
        }

        /// Distance from the row's leading edge to the centre of its icon.
        var actionCellIconCenterOffset: CGFloat {
            switch self {
            case .xcode14:
                17.5
            case .xcode15:
                23.5
            case .xcode26:
                19.5
            }
        }

        /// Distance from the row's leading edge to the label's leading edge.
        var actionCellLabelLeading: CGFloat {
            switch self {
            case .xcode14:
                50
            case .xcode15:
                46.5
            case .xcode26:
                38
            }
        }

        /// Gap between the action list and the bottom of the pane. Unused by `xcode14`, which pins
        /// the list above its "show on launch" checkbox instead.
        var actionTableViewBottomSpacing: CGFloat {
            switch self {
            case .xcode14, .xcode15:
                50
            case .xcode26:
                // Puts the first row at y = 287, where the capture has it.
                41
            }
        }

        // MARK: - Chrome

        var closeButtonInset: CGFloat {
            switch self {
            case .xcode14, .xcode15:
                12
            case .xcode26:
                13
            }
        }

        /// Applied when the host supplies no `appIconImageShadow` of its own. Only ever drawn in a
        /// dark appearance — the light capture has no shadow layer at all.
        var appIconDefaultShadow: NSShadow? {
            switch self {
            case .xcode14, .xcode15:
                nil
            case .xcode26:
                NSShadow().then {
                    $0.shadowColor = NSColor(srgbRed: 0.0902, green: 0.4157, blue: 0.8784, alpha: 0.55)
                    $0.shadowBlurRadius = 50
                    $0.shadowOffset = .init(width: 0, height: 2)
                }
            }
        }

        func welcomeLabelDefaultText(forName name: String) -> String {
            switch self {
            case .xcode14:
                "Welcome to \(name)"
            case .xcode15, .xcode26:
                name
            }
        }
    }
}

#endif
