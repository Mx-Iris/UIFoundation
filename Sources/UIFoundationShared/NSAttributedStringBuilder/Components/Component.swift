#if NSAttributedStringBuilder

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

public protocol Component {
    var string: String { get }
    var attributes: Attributes { get }
    var attributedString: NSAttributedString { get }
    func attributes(_ newAttributes: Attributes) -> Component
}

public enum Ligature: Int {
    case none = 0
    case `default` = 1

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    case all = 2 // Value 2 is unsupported on iOS
    #endif
}

extension Component {
    private func build(_ string: String, attributes: Attributes) -> Component {
        AText(string, attributes: attributes)
    }

    public var attributedString: NSAttributedString {
        NSAttributedString(string: string, attributes: attributes)
    }

    public func attribute(_ newAttribute: NSAttributedString.Key, value: Any) -> Component {
        attributes([newAttribute: value])
    }

    public func attributes(_ newAttributes: Attributes) -> Component {
        var attributes = self.attributes
        for attribute in newAttributes {
            attributes[attribute.key] = attribute.value
        }
        return build(string, attributes: attributes)
    }
}

// MARK: Basic Modifiers

extension Component {
    public func backgroundColor(_ color: NSUIColor) -> Component {
        attributes([.backgroundColor: color])
    }

    public func baselineOffset(_ baselineOffset: CGFloat) -> Component {
        attributes([.baselineOffset: baselineOffset])
    }

    public func font(_ font: NSUIFont) -> Component {
        attributes([.font: font])
    }

    public func foregroundColor(_ color: NSUIColor) -> Component {
        attributes([.foregroundColor: color])
    }

    public func expansion(_ expansion: CGFloat) -> Component {
        attributes([.expansion: expansion])
    }

    public func kerning(_ kern: CGFloat) -> Component {
        attributes([.kern: kern])
    }

    public func ligature(_ ligature: Ligature) -> Component {
        attributes([.ligature: ligature.rawValue])
    }

    public func obliqueness(_ obliqueness: Float) -> Component {
        attributes([.obliqueness: obliqueness])
    }

    public func shadow(color: NSUIColor? = nil, radius: CGFloat, x: CGFloat, y: CGFloat) -> Component {
        let shadow = NSShadow()
        shadow.shadowColor = color
        shadow.shadowBlurRadius = radius
        shadow.shadowOffset = .init(width: x, height: y)
        return attributes([.shadow: shadow])
    }

    public func strikethrough(style: NSUnderlineStyle, color: NSUIColor? = nil) -> Component {
        if let color = color {
            return attributes([.strikethroughStyle: style.rawValue,
                               .strikethroughColor: color])
        } else {
            return attributes([.strikethroughStyle: style.rawValue])
        }
    }

    public func stroke(width: CGFloat, color: NSUIColor? = nil) -> Component {
        if let color = color {
            return attributes([.strokeWidth: width,
                               .strokeColor: color])
        } else {
            return attributes([.strokeWidth: width])
        }
    }

    public func textEffect(_ textEffect: NSAttributedString.TextEffectStyle) -> Component {
        attributes([.textEffect: textEffect])
    }

    public func underline(_ style: NSUnderlineStyle, color: NSUIColor? = nil) -> Component {
        if let color = color {
            return attributes([.underlineStyle: style.rawValue,
                               .underlineColor: color])
        } else {
            return attributes([.underlineStyle: style.rawValue])
        }
    }

    public func writingDirection(_ writingDirection: NSWritingDirection) -> Component {
        attributes([.writingDirection: writingDirection.rawValue])
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public func vertical() -> Component {
        attributes([.verticalGlyphForm: 1])
    }
    #endif
}

// MARK: - Paragraph Style Modifiers

extension Component {
    public func paragraphStyle(_ paragraphStyle: NSParagraphStyle) -> Component {
        attributes([.paragraphStyle: paragraphStyle])
    }

    public func paragraphStyle(_ paragraphStyle: NSMutableParagraphStyle) -> Component {
        attributes([.paragraphStyle: paragraphStyle])
    }

    private func getMutableParagraphStyle() -> NSMutableParagraphStyle {
        if let mutableParagraphStyle = attributes[.paragraphStyle] as? NSMutableParagraphStyle {
            return mutableParagraphStyle
        } else if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle,
                  let mutableParagraphStyle = paragraphStyle.mutableCopy() as? NSMutableParagraphStyle
        {
            return mutableParagraphStyle
        } else {
            return NSMutableParagraphStyle()
        }
    }

    public func alignment(_ alignment: NSTextAlignment) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        return self.paragraphStyle(paragraphStyle)
    }

    public func firstLineHeadIndent(_ indent: CGFloat) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.firstLineHeadIndent = indent
        return self.paragraphStyle(paragraphStyle)
    }

    public func headIndent(_ indent: CGFloat) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.headIndent = indent
        return self.paragraphStyle(paragraphStyle)
    }

    public func tailIndent(_ indent: CGFloat) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.tailIndent = indent
        return self.paragraphStyle(paragraphStyle)
    }

    public func lineBreakeMode(_ lineBreakMode: NSLineBreakMode) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.lineBreakMode = lineBreakMode
        return self.paragraphStyle(paragraphStyle)
    }

    public func lineHeight(multiple: CGFloat = 0, maximum: CGFloat = 0, minimum: CGFloat) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.lineHeightMultiple = multiple
        paragraphStyle.maximumLineHeight = maximum
        paragraphStyle.minimumLineHeight = minimum
        return self.paragraphStyle(paragraphStyle)
    }

    public func lineSpacing(_ spacing: CGFloat) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.lineSpacing = spacing
        return self.paragraphStyle(paragraphStyle)
    }

    public func paragraphSpacing(_ spacing: CGFloat, before: CGFloat = 0) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.paragraphSpacing = spacing
        paragraphStyle.paragraphSpacingBefore = before
        return self.paragraphStyle(paragraphStyle)
    }

    public func baseWritingDirection(_ baseWritingDirection: NSWritingDirection) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.baseWritingDirection = baseWritingDirection
        return self.paragraphStyle(paragraphStyle)
    }

    public func hyphenationFactor(_ hyphenationFactor: Float) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.hyphenationFactor = hyphenationFactor
        return self.paragraphStyle(paragraphStyle)
    }

    @available(iOS 9.0, tvOS 9.0, watchOS 2.0, macOS 10.11, *)
    public func allowsDefaultTighteningForTruncation() -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.allowsDefaultTighteningForTruncation = true
        return self.paragraphStyle(paragraphStyle)
    }

    public func tabsStops(_ tabStops: [NSTextTab], defaultInterval: CGFloat = 0) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.tabStops = tabStops
        paragraphStyle.defaultTabInterval = defaultInterval
        return self.paragraphStyle(paragraphStyle)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public func textBlocks(_ textBlocks: [NSTextBlock]) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.textBlocks = textBlocks
        return self.paragraphStyle(paragraphStyle)
    }

    public func textLists(_ textLists: [NSTextList]) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.textLists = textLists
        return self.paragraphStyle(paragraphStyle)
    }

    public func tighteningFactorForTruncation(_ tighteningFactorForTruncation: Float) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.tighteningFactorForTruncation = tighteningFactorForTruncation
        return self.paragraphStyle(paragraphStyle)
    }

    public func headerLevel(_ headerLevel: Int) -> Component {
        let paragraphStyle = getMutableParagraphStyle()
        paragraphStyle.headerLevel = headerLevel
        return self.paragraphStyle(paragraphStyle)
    }
    #endif
}

#endif
