#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: NSObject {
    @available(*, deprecated, renamed: "classIdentifier")
    public static var typeNameIdentifier: NSUserInterfaceItemIdentifier {
        self.classIdentifier
    }

    public static var classIdentifier: NSUserInterfaceItemIdentifier {
        NSUserInterfaceItemIdentifier(Base.self)
    }
}

#endif
