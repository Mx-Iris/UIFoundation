#if NSAttributedStringBuilder

import Foundation
import Testing
@testable import UIFoundationShared

@Suite("NSAttributedStringBuilder — ATextGroup")
struct AttributedTextGroupTests {
    @Test func groupAppliesAttributesEquivalentToFlat() {
        let attributedString1 = NSAttributedString {
            AText("111")
                .font(.systemFont(ofSize: 30))
                .foregroundColor(.black)
            AText("222")
                .font(.systemFont(ofSize: 30))
                .foregroundColor(.black)
        }

        let attributedString2 = NSAttributedString {
            ATextGroup {
                AText("111")
                AText("222")
            }
            .font(.systemFont(ofSize: 30))
            .foregroundColor(.black)
        }
        #expect(attributedString1.isEqual(attributedString2))
    }

    @Test func childAttributesTakePrecedence() {
        let attributedString1 = NSAttributedString {
            AText("111")
                .font(.systemFont(ofSize: 30))
                .foregroundColor(.black)
            AText("222")
                .font(.systemFont(ofSize: 30))
                .foregroundColor(.red)
        }

        let attributedString2 = NSAttributedString {
            ATextGroup {
                AText("111")
                    .foregroundColor(.black)
                AText("222")
                    .foregroundColor(.red)
            }
            .font(.systemFont(ofSize: 30))
        }
        #expect(attributedString1.isEqual(attributedString2))
    }

    @Test func nestedGroupsPropagateOuterAttributes() {
        let attributedString1 = NSAttributedString {
            AText("111")
                .backgroundColor(.blue)
            AText("222")
                .font(.systemFont(ofSize: 18, weight: .semibold))
                .backgroundColor(.blue)
            AText("333")
                .font(.systemFont(ofSize: 18, weight: .semibold))
                .backgroundColor(.blue)
        }

        let attributedString2 = NSAttributedString {
            ATextGroup {
                AText("111")
                ATextGroup {
                    AText("222")
                    AText("333")
                }
                .font(.systemFont(ofSize: 18, weight: .semibold))
            }
            .backgroundColor(.blue)
        }
        #expect(attributedString1.isEqual(attributedString2))
    }

    @Test func nestedGroupsMixWithLinkAndSpace() {
        let attributedString1 = NSAttributedString {
            AText("111")
                .backgroundColor(.blue)
            AText("222")
                .font(.systemFont(ofSize: 18, weight: .semibold))
                .backgroundColor(.blue)
            Link("NSAttributedStringBuilder", url: URL(string: "https://github.com/ethanhuang13/NSAttributedStringBuilder")!)
            Space()
            AText("333")
                .font(.systemFont(ofSize: 18, weight: .semibold))
                .backgroundColor(.blue)
        }
        let attributedString2 = NSAttributedString {
            ATextGroup {
                AText("111")
                ATextGroup {
                    AText("222")
                    Link("NSAttributedStringBuilder", url: URL(string: "https://github.com/ethanhuang13/NSAttributedStringBuilder")!)
                    Space()
                    AText("333")
                }
                .font(.systemFont(ofSize: 18, weight: .semibold))
            }
            .backgroundColor(.blue)
        }
        #expect(attributedString1.isEqual(attributedString2))
    }
}

#endif
