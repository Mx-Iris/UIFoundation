#if NSAttributedStringBuilder
#if !os(watchOS)

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

public typealias ImageAttachment = NSAttributedString.ImageAttachment

extension NSAttributedString {
    public struct ImageAttachment: Component {
        public let string: String = ""
        public let attributes: Attributes = [:]

        public var attributedString: NSAttributedString {
            NSAttributedString(attachment: attachment)
        }

        private let attachment: NSTextAttachment

        public init(_ image: NSUIImage, bounds: CGRect? = nil) {
            let attachment = NSTextAttachment()
            attachment.image = image

            if let bounds = bounds {
                attachment.bounds = bounds
            }

            self.attachment = attachment
        }
    }
}

#endif
#endif
