#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class VerticalAlignmentTextField: InsetsTextField {
    public var verticalAlignment: VerticalAlignmentTextFieldCell.VerticalAlignment {
        set {
            guard let cell = cell as? VerticalAlignmentTextFieldCell else { return }
            cell.verticalAlignment = newValue
        }
        get {
            guard let cell = cell as? VerticalAlignmentTextFieldCell else { return .top }
            return cell.verticalAlignment
        }
    }

    open override class var cellClass: AnyClass? {
        set {}
        get { VerticalAlignmentTextFieldCell.self }
    }
}

#endif
