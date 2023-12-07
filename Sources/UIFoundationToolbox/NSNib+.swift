#if canImport(AppKit)

import AppKit

extension NSNib {
    public convenience init?(nibClass: (some NSObject).Type) {
        self.init(nibNamed: .init(describing: nibClass), bundle: nil)
    }
}

#endif
