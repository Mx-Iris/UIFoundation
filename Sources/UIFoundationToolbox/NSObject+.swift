#if canImport(AppKit)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSObject {
    public static var typeNameIdentifier: NSUserInterfaceItemIdentifier {
        .init(String(describing: Base.self))
    }
}

#endif
