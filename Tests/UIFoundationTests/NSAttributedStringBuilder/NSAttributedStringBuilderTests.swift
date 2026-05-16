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

@Suite("NSAttributedStringBuilder")
struct NSAttributedStringBuilderTests {
    @Test func initWithTwoAText() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "Hello world")
            mutableAttributedString.append(NSAttributedString(string: " with Swift"))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Hello world")
            AText(" with Swift")
        }

        #expect(subject.isEqual(testData))
    }

    @Test func initWithTextAndLink() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "")
            mutableAttributedString.append(NSAttributedString(string: "Here is a link to ",
                                                              attributes: [.foregroundColor: NSUIColor.brown]))
            mutableAttributedString.append(NSAttributedString(string: "Apple",
                                                              attributes: [.link: URL(string: "https://www.apple.com")!]))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            AText("Here is a link to ")
                .foregroundColor(.brown)
            Link("Apple", url: URL(string: "https://www.apple.com")!)
        }

        #expect(subject.isEqual(testData))
    }
}

#endif
