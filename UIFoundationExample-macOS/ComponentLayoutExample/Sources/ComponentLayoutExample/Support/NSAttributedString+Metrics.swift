//
//  NSAttributedString+Metrics.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's `NSAttributedString+UIComponent.swift`
//  (created by Huy on 11/5/25). That file is one of the pieces UIFoundation
//  deliberately left behind with the leaf components, so it lives here.
//

import AppKit

extension NSAttributedString {
    /// Distance from the top of the first line to its baseline, honouring a
    /// paragraph style's line height if one is set.
    ///
    /// Feeds `TextRenderNode.ascender`, which is what makes `.baselineFirst`
    /// align by the baseline rather than by the box.
    public var ascender: CGFloat {
        guard length > 0 else { return 0 }
        guard let font = attribute(.font, at: 0, effectiveRange: nil) as? NSFont else {
            return 0
        }
        guard let paragraphStyle = attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle else {
            return font.ascender
        }

        var lineHeight = max(font.componentLineHeight, paragraphStyle.minimumLineHeight)
        if paragraphStyle.maximumLineHeight > 0 {
            lineHeight = min(lineHeight, paragraphStyle.maximumLineHeight)
        }
        return lineHeight + font.descender
    }

    /// Distance from the last line's baseline to its bottom. Negative, as AppKit
    /// reports it.
    public var descender: CGFloat {
        guard length > 0 else { return 0 }
        guard let font = attribute(.font, at: length - 1, effectiveRange: nil) as? NSFont else {
            return 0
        }
        return font.descender
    }
}

extension NSFont {
    /// `UIFont.lineHeight` has no AppKit counterpart -- `NSFont` exposes the
    /// three parts and leaves the sum to the caller. `descender` is negative, so
    /// this subtracts it.
    ///
    /// Named with a prefix rather than `lineHeight` on purpose: a bare
    /// `lineHeight` on `NSFont` is exactly the kind of name a framework may add
    /// later, and an extension property that collides with one becomes an
    /// illegal override rather than a shadow.
    var componentLineHeight: CGFloat {
        ascender - descender + leading
    }
}
