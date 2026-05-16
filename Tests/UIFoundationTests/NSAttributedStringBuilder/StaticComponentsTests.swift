#if NSAttributedStringBuilder

import Foundation
import Testing
@testable import UIFoundationShared

@Suite("NSAttributedStringBuilder — static components")
struct StaticComponentsTests {
    @Test func emptyComponent() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "")
            mutableAttributedString.append(NSAttributedString(string: ""))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            Empty()
            Empty()
        }

        #expect(subject.isEqual(testData))
    }

    @Test func spaceComponent() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: " ")
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            Empty()
            Space()
        }

        #expect(subject.isEqual(testData))
    }

    @Test func lineBreakComponent() {
        let testData: NSAttributedString = {
            let mutableAttributedString = NSMutableAttributedString(string: "")
            mutableAttributedString.append(NSAttributedString(string: "\n"))
            mutableAttributedString.append(NSAttributedString(string: ""))
            return mutableAttributedString
        }()

        let subject = NSAttributedString {
            Empty()
            LineBreak()
            Empty()
        }

        #expect(subject.isEqual(testData))
    }
}

#endif
