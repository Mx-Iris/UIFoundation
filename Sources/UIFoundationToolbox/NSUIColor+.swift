// #if canImport(AppKit) && !targetEnvironment(macCatalyst)

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif
import FrameworkToolbox
import UIFoundationTypealias

extension FrameworkToolbox where Base: StringProtocol {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var nsColor: NSColor {
        return NSColor(hexString: String(base)) ?? NSColor.black
    }
    #endif

    #if canImport(UIKit)
    public var uiColor: UIColor {
        return UIColor(hexString: String(base)) ?? UIColor.black
    }
    #endif
    
    public var nsuiColor: NSUIColor {
        return NSUIColor(hexString: String(base)) ?? NSUIColor.black
    }
}

extension FrameworkToolbox where Base: NSUIColor {
    @available(*, deprecated, renamed: "NSUIColor(hexString:)")
    public static func fromHexString(hexString: String) -> NSUIColor {
        return hexString.nsuiColor
    }

    private struct Components {
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        var a: CGFloat = 0.0
    }

    private func components() -> Components {
        var result = Components()
        base.getRed(&result.r, green: &result.g, blue: &result.b, alpha: &result.a)
        return result
    }

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public var contrastingTextColor: NSUIColor {
        if base == NSUIColor.clear {
            return .textColor
        }

        guard let c1 = base.usingColorSpace(.deviceRGB) else {
            return .textColor
        }

        let rgbColor = c1.box.components()

        // Counting the perceptive luminance - human eye favors green color...
        let avgGray: CGFloat = 1 - (0.299 * rgbColor.r + 0.587 * rgbColor.g + 0.114 * rgbColor.b)
        return avgGray > 0.5 ? .white : .black
    }
#endif
}

extension NSUIColor {
    /// Must have "#" at the beginning (examples: #FF00FF / #FF00FFFF (with alpha)
    public convenience init?(hexString: String) {
        guard hexString.hasPrefix("#") else {
            return nil
        }

        let hexString = String(hexString[hexString.index(hexString.startIndex, offsetBy: 1)...])
        var hexValue: UInt64 = 0

        guard Scanner(string: hexString).scanHexInt64(&hexValue) else {
            return nil
        }

        switch hexString.count {
        case 3:
            self.init(hex3: UInt16(hexValue))
        case 4:
            self.init(hex4: UInt16(hexValue))
        case 6:
            self.init(hex6: UInt32(hexValue))
        case 8:
            self.init(hex8: UInt32(hexValue))
        default:
            return nil
        }
    }

    public convenience init(hex3: UInt16, alpha: CGFloat = 1) {
        let divisor = CGFloat(15)
        let red = CGFloat((hex3 & 0xF00) >> 8) / divisor
        let green = CGFloat((hex3 & 0x0F0) >> 4) / divisor
        let blue = CGFloat(hex3 & 0x00F) / divisor
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public convenience init(hex4: UInt16) {
        let divisor = CGFloat(15)
        let red = CGFloat((hex4 & 0xF000) >> 12) / divisor
        let green = CGFloat((hex4 & 0x0F00) >> 8) / divisor
        let blue = CGFloat((hex4 & 0x00F0) >> 4) / divisor
        let alpha = CGFloat(hex4 & 0x000F) / divisor
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public convenience init(hex6: UInt32, alpha: CGFloat = 1) {
        let divisor = CGFloat(255)
        let red = CGFloat((hex6 & 0xFF0000) >> 16) / divisor
        let green = CGFloat((hex6 & 0x00FF00) >> 8) / divisor
        let blue = CGFloat(hex6 & 0x0000FF) / divisor
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }

    public convenience init(hex8: UInt32) {
        let divisor = CGFloat(255)
        let red = CGFloat((hex8 & 0xFF000000) >> 24) / divisor
        let green = CGFloat((hex8 & 0x00FF0000) >> 16) / divisor
        let blue = CGFloat((hex8 & 0x0000FF00) >> 8) / divisor
        let alpha = CGFloat(hex8 & 0x000000FF) / divisor
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}

// #endif
