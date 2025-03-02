#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox
import UIFoundationUtilities

open class InsetsTextField: TextField {
    @ViewInvalidating(.display, .layout)
    @IBInspectable
    open dynamic var contentInsets: NSEdgeInsets = .box.zero {
        didSet {
            guard let cell = cell as? InsetsTextFieldCell else { return }
            cell.contentInsets = contentInsets
        }
    }
    
    open override class var cellClass: AnyClass? {
        set {}
        get { InsetsTextFieldCell.self }
    }
    
    open override var intrinsicContentSize: NSSize {
        var intrinsicContentSize = super.intrinsicContentSize
        intrinsicContentSize.width += contentInsets.left + contentInsets.right
        intrinsicContentSize.height += contentInsets.top + contentInsets.bottom
        return intrinsicContentSize
    }
}

#endif
