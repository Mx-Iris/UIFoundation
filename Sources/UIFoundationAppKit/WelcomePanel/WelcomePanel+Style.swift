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
            case .xcode15, .xcode26:
                8
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
                case .xcode15, .xcode26:
                    if appearance.box.isDark {
                        return .black.withAlphaComponent(0.2)
                    } else {
                        return .white
                    }
                }
            }
        }

        var projectViewBackgroundColor: NSColor {
            switch self {
            case .xcode14:
                .clear
            case .xcode15, .xcode26:
                .init(name: "ProjectViewBackgroundColor") { $0.box.isDark ? .clear : .white.withAlphaComponent(0.6) }
            }
        }

        var welcomeLabelDefaultFont: NSFont {
            switch self {
            case .xcode14:
                .systemFont(ofSize: 36, weight: .regular)
            case .xcode15, .xcode26:
                .systemFont(ofSize: 30, weight: .bold)
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
