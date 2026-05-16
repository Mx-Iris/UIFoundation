#if NSAttributedStringBuilder

import Testing
@testable import UIFoundationShared
import UIFoundationTypealias

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

@Suite("NSAttributedStringBuilder — basic modifiers")
struct ComponentBasicModifierTests {
    @Test func modifyWithSingleAttribute() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.foregroundColor: NSUIColor.yellow])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .attribute(.foregroundColor, value: NSUIColor.yellow)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyBackgroundColor() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.backgroundColor: NSUIColor.red])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .backgroundColor(.red)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyBaselineOffset() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.baselineOffset: 10])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .baselineOffset(10)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyFontAndColor() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "")
            mutableAttributedString.append(NSAttributedString(string: "Hello world",
                                                              attributes: [
                                                                  .font: NSUIFont.systemFont(ofSize: 20),
                                                                  .foregroundColor: NSUIColor.yellow,
                                                              ]))
            mutableAttributedString.append(NSAttributedString(string: "\n"))
            mutableAttributedString.append(NSAttributedString(string: "Second line",
                                                              attributes: [.font: NSUIFont.systemFont(ofSize: 24)]))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .font(.systemFont(ofSize: 20))
                .foregroundColor(.yellow)
            LineBreak()
            AText("Second line")
                .font(.systemFont(ofSize: 24))
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyExpansion() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.expansion: 1])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .expansion(1)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyKerning() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.kern: 3])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .kerning(3)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyLigature() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.ligature: 0])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .ligature(.none)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyObliqueness() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.obliqueness: 0.5])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .obliqueness(0.5)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyShadow() {
        let testData: NSAttributedString = {
            let shadow = NSShadow()
            shadow.shadowColor = NSUIColor.black
            shadow.shadowBlurRadius = 10
            shadow.shadowOffset = .init(width: 4, height: 4)

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.shadow: shadow])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .shadow(color: .black, radius: 10, x: 4, y: 4)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyStrikethrough() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.strikethroughStyle: NSUnderlineStyle.double.rawValue])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .strikethrough(style: .double)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyStrikethroughWithColor() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.strikethroughStyle: NSUnderlineStyle.patternDash.rawValue,
                                                                                 .strikethroughColor: NSUIColor.black])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .strikethrough(style: .patternDash, color: .black)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyStroke() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.strokeWidth: -2])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .stroke(width: -2)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyStrokeWithColor() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.strokeWidth: -2,
                                                                                 .strokeColor: NSUIColor.green])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .stroke(width: -2, color: .green)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyTextEffect() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.textEffect: NSAttributedString.TextEffectStyle.letterpressStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .textEffect(.letterpressStyle)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyUnderline() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.underlineStyle: NSUnderlineStyle.patternDashDotDot.rawValue])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .underline(.patternDashDotDot)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyUnderlineWithColor() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.underlineStyle: NSUnderlineStyle.patternDashDotDot.rawValue,
                                                                                 .underlineColor: NSUIColor.cyan])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .underline(.patternDashDotDot, color: .cyan)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyWritingDirection() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.writingDirection: NSWritingDirection.rightToLeft.rawValue])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .writingDirection(.rightToLeft)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Test func modifyVertical() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.verticalGlyphForm: 1])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .vertical()
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }
    #endif

    @Test func chainingAllModifiers() {
        let testData: NSAttributedString = {
            let shadow = NSShadow()
            shadow.shadowColor = NSUIColor.black
            shadow.shadowBlurRadius = 10
            shadow.shadowOffset = .init(width: 4, height: 4)

            let mutableAttributedString = NSMutableAttributedString(
                string: "Hello world",
                attributes: [.backgroundColor: NSUIColor.red,
                             .baselineOffset: 10,
                             .font: NSUIFont.systemFont(ofSize: 20),
                             .foregroundColor: NSUIColor.yellow,
                             .expansion: 1,
                             .kern: 3,
                             .ligature: 0,
                             .obliqueness: 0.5,
                             .shadow: shadow,
                             .strikethroughStyle: NSUnderlineStyle.patternDash.rawValue,
                             .strikethroughColor: NSUIColor.black,
                             .strokeWidth: -2,
                             .strokeColor: NSUIColor.green,
                             .textEffect: NSAttributedString.TextEffectStyle.letterpressStyle,
                             .underlineStyle: NSUnderlineStyle.patternDashDotDot.rawValue,
                             .underlineColor: NSUIColor.cyan,
                             .writingDirection: NSWritingDirection.rightToLeft.rawValue]
            )
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .backgroundColor(.red)
                .baselineOffset(10)
                .font(.systemFont(ofSize: 20))
                .foregroundColor(.yellow)
                .expansion(1)
                .kerning(3)
                .ligature(.none)
                .obliqueness(0.5)
                .shadow(color: .black, radius: 10, x: 4, y: 4)
                .strikethrough(style: .patternDash, color: .black)
                .stroke(width: -2, color: .green)
                .textEffect(.letterpressStyle)
                .underline(.patternDashDotDot, color: .cyan)
                .writingDirection(.rightToLeft)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }
}

#endif
