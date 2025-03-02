#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import UIFoundationToolbox
import UIFoundationUtilities

@IBDesignable
open class Label: InsetsTextField {
    open var syncStringValueToolTip: Bool = true

    open override var stringValue: String {
        set {
            super.stringValue = newValue
            if syncStringValueToolTip {
                toolTip = newValue
            }
        }
        get {
            super.stringValue
        }
    }

    open override func setup() {
        isEditable = false
        drawsBackground = false
        isBordered = false
    }
    
    open override class var cellClass: AnyClass? {
        set { }
        get { LabelCell.self }
    }
}

#endif
