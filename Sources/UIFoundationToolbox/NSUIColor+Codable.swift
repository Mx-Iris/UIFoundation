#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import FoundationToolbox
import UIFoundationTypealias

extension NSUIColor: SecureCodingCodable {}
