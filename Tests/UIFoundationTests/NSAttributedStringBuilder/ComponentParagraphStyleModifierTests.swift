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

@Suite("NSAttributedStringBuilder — paragraph style modifiers")
struct ComponentParagraphStyleModifierTests {
    @Test func setEmptyParagraphStyle() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSParagraphStyle()
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let paragraphStyle = NSParagraphStyle()

        let subject = NSAttributedString {
            AText("Hello world")
                .paragraphStyle(paragraphStyle)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyMutableParagraphStyle() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let mutableParagraphStyle = NSMutableParagraphStyle()
        mutableParagraphStyle.alignment = .right

        let subject = NSAttributedString {
            AText("Hello world")
                .paragraphStyle(mutableParagraphStyle)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyAlignment() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .alignment(.right)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyFirstHeadIndent() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.firstLineHeadIndent = 16

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .firstLineHeadIndent(16)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyHeadIndent() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headIndent = 13

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .headIndent(13)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyTailIndent() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tailIndent = 19

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .tailIndent(19)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyLinebreakMode() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineBreakMode = .byWordWrapping

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .lineBreakeMode(.byWordWrapping)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyLineHeight() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineHeightMultiple = 1
            paragraphStyle.maximumLineHeight = 22
            paragraphStyle.minimumLineHeight = 18

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .lineHeight(multiple: 1, maximum: 22, minimum: 18)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyLineSpacing() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 7

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .lineSpacing(7)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyParagraphSpacing() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.paragraphSpacing = 9.3
            paragraphStyle.paragraphSpacingBefore = 17.2

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .paragraphSpacing(9.3, before: 17.2)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyBaseWritingDirection() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.baseWritingDirection = .rightToLeft

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .baseWritingDirection(.rightToLeft)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyHyphenationFactor() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.hyphenationFactor = 0.3

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .hyphenationFactor(0.3)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @available(iOS 9.0, tvOS 9.0, watchOS 2.0, macOS 10.11, *)
    @Test func allowsDefaultTighteningForTruncation() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.allowsDefaultTighteningForTruncation = true

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .allowsDefaultTighteningForTruncation()
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyTabStops() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tabStops = [NSTextTab(textAlignment: .left, location: 6, options: [:]),
                                       NSTextTab(textAlignment: .right, location: 4, options: [:])]

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .tabsStops([NSTextTab(textAlignment: .left, location: 6, options: [:]),
                            NSTextTab(textAlignment: .right, location: 4, options: [:])])
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    @Test func modifyTextBlocks() {
        let textBlock = NSTextBlock()
        textBlock.setWidth(30, type: .absoluteValueType, for: .border)

        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.textBlocks = [textBlock]

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .textBlocks([textBlock])
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @available(macOS 10.13, *)
    @Test func modifyTextList() {
        let textList = NSTextList(markerFormat: .box, options: 0)

        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.textLists = [textList]

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .textLists([textList])
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyTighteningFactorForTruncation() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.tighteningFactorForTruncation = 0.5

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .tighteningFactorForTruncation(0.5)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func modifyHeaderLevel() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.headerLevel = 2

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .headerLevel(2)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }
    #endif

    @available(iOS 9.0, tvOS 9.0, watchOS 2.0, macOS 10.11, *)
    @Test func chainingAllModifiers() {
        let testData: NSAttributedString = {
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .right
            paragraphStyle.firstLineHeadIndent = 16
            paragraphStyle.headIndent = 13
            paragraphStyle.tailIndent = 19
            paragraphStyle.lineBreakMode = .byWordWrapping
            paragraphStyle.lineHeightMultiple = 1
            paragraphStyle.maximumLineHeight = 22
            paragraphStyle.minimumLineHeight = 18
            paragraphStyle.lineSpacing = 7
            paragraphStyle.paragraphSpacing = 9.3
            paragraphStyle.paragraphSpacingBefore = 17.2
            paragraphStyle.baseWritingDirection = .rightToLeft
            paragraphStyle.hyphenationFactor = 0.3
            paragraphStyle.allowsDefaultTighteningForTruncation = true

            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: paragraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
                .alignment(.right)
                .firstLineHeadIndent(16)
                .headIndent(13)
                .tailIndent(19)
                .lineBreakeMode(.byWordWrapping)
                .lineHeight(multiple: 1, maximum: 22, minimum: 18)
                .lineSpacing(7)
                .paragraphSpacing(9.3, before: 17.2)
                .baseWritingDirection(.rightToLeft)
                .hyphenationFactor(0.3)
                .allowsDefaultTighteningForTruncation()
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @available(iOS 9.0, tvOS 9.0, watchOS 2.0, macOS 10.11, *)
    @Test func randomChainingOrderEqualness() {
        let subject1 = NSAttributedString {
            AText("Hello world")
                .alignment(.right)
                .firstLineHeadIndent(16)
                .headIndent(13)
                .tailIndent(19)
                .lineBreakeMode(.byWordWrapping)
                .lineHeight(multiple: 1, maximum: 22, minimum: 18)
                .lineSpacing(7)
                .paragraphSpacing(9.3, before: 17.2)
                .baseWritingDirection(.rightToLeft)
                .hyphenationFactor(0.3)
                .allowsDefaultTighteningForTruncation()
            AText(" with Swift")
        }

        let subject2 = NSAttributedString {
            AText("Hello world")
                .firstLineHeadIndent(16)
                .headIndent(13)
                .alignment(.right)
                .allowsDefaultTighteningForTruncation()
                .tailIndent(19)
                .lineSpacing(7)
                .lineBreakeMode(.byWordWrapping)
                .hyphenationFactor(0.3)
                .lineHeight(multiple: 1, maximum: 22, minimum: 18)
                .paragraphSpacing(9.3, before: 17.2)
                .baseWritingDirection(.rightToLeft)
            AText(" with Swift")
        }

        #expect(subject1.isEqual(subject2))
    }

    @Test func setEmptyParagraphStyleThenChaining() {
        let testData: NSAttributedString = {
            let mutableParagraphStyle = NSMutableParagraphStyle()
            mutableParagraphStyle.alignment = .justified
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world",
                                                                    attributes: [.paragraphStyle: mutableParagraphStyle])
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let paragraphStyle = NSParagraphStyle()

        let subject = NSAttributedString {
            AText("Hello world")
                .paragraphStyle(paragraphStyle)
                .alignment(.justified)
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }
}

#endif
