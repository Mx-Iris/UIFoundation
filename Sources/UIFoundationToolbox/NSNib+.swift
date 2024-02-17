#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSNib {
    public convenience init?(nibClass: AnyClass, bundle: Bundle? = nil) {
        self.init(nibNamed: .init(describing: nibClass), bundle: bundle)
    }
}

#endif
