#if IDEIcons

// Ported from https://github.com/freysie/ide-icons (MIT License, Copyright © 2022-2023 Freya Alminde)
// AppKit/UIKit port with all SwiftUI dependencies removed.

import Foundation
import CoreGraphics
import UIFoundationTypealias

@available(macOS 11.0, iOS 13.0, tvOS 13.0, *)
extension IDEIcon {
    var fontWeight: NSUIFont.Weight {
        switch content {
        case .text(let string):
            switch string {
            case "#": return .light
            case "Ti": return .regular
            default: break
            }

        default:
            break
        }

        return style.fontWeight
    }

    var fontSizeAdjustment: CGFloat {
        switch content {
        case .text(let string):
            switch string {
            case "@": return 1
            case "{}": return -1
            case "⨍": return 0
            case "•": return 2.5
            default: break
            }

        case .systemImage(let name):
            switch name {
            case "puzzlepiece.fill": return -1
            case "rectangle.connected.to.line.below": return -0.1
            default: break
            }

        default:
            break
        }

        return 0
    }

    var yOffsetAdjustment: CGFloat {
        switch content {
        case .text(let string):
            if size <= IDEIconSize.regular {
                switch string {
                case "@": return 1
                case "#": return 0
                case "{}": return 0
                case "⨍": return 1
                case "•": return 1
                default: break
                }
            } else {
                switch string {
                case "@": return 3
                case "#": return 0
                case "•": return 3
                case "{}": return 2
                case "⨍": return 3.5
                default: break
                }
            }

        case .systemImage(let name):
            switch name {
            case "list.bullet": return 1
            case "rectangle.connected.to.line.below": return -0.3
            default: break
            }

        default:
            break
        }

        return 0
    }
}

#endif
