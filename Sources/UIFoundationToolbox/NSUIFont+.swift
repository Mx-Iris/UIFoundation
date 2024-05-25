#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import FrameworkToolbox
import UIFoundationTypealias

extension FrameworkToolbox where Base == NSUIFont {
    public var defaultLineHeight: CGFloat {
        /// Heavily inspired by WebKit

        let kLineHeightAdjustment: CGFloat = 0.15

        var ascent = CTFontGetAscent(base)
        var descent = CTFontGetDescent(base)
        var lineGap = CTFontGetLeading(base)

        if shouldUseAdjustment(base) {
            // Needs ascent adjustment
            ascent += round((ascent + descent) * kLineHeightAdjustment);
        }

        // Compute line spacing before the line metrics hacks are applied.
        var lineSpacing = round(ascent) + round(descent) + round(lineGap);

        // Hack Hiragino line metrics to allow room for marked text underlines.
        if descent < 3, lineGap >= 3, base.nsuiFamilyName?.hasPrefix("Hiragino") == true {
            lineGap -= 3 - descent
            descent = 3
        }

    #if os(iOS)
        let adjustment = shouldUseAdjustment(base) ? ceil(ascent + descent) * kLineHeightAdjustment : 0
        lineGap = ceil(lineGap)
        lineSpacing = ceil(ascent) + adjustment + ceil(descent) + lineGap
        ascent = ceil((ascent + adjustment))
        descent = ceil(descent)
    #endif

        return lineSpacing
    }

    private func shouldUseAdjustment(_ font: NSUIFont) -> Bool {
        guard let familyName = font.nsuiFamilyName else {
            return false
        }

        return familyName.caseInsensitiveCompare("Times") == .orderedSame
            || familyName.caseInsensitiveCompare("Helvetica") == .orderedSame
            || familyName.caseInsensitiveCompare("Courier") == .orderedSame // macOS only
            || familyName.caseInsensitiveCompare(".Helvetica NeueUI") == .orderedSame
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
extension NSFont {
    var nsuiFamilyName: String? {
        familyName
    }
}
#endif

#if canImport(UIKit)
extension UIFont {
    var nsuiFamilyName: String? {
        familyName
    }
}
#endif
