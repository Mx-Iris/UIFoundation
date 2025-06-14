#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
import FoundationToolbox
import UIFoundationTypealias

extension NSColor: @retroactive Encodable {}
extension NSColor: @retroactive Decodable {}
extension NSUIColor: @retroactive SecureCodingCodable {}
