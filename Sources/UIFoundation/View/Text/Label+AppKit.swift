#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
import UIFoundationToolbox

open class Label: NSTextField {
    @Invalidating(.display)
    open var contentInsets: NSEdgeInsets = .zero {
        didSet {
            guard let cell = cell as? LabelCell else { return }
            cell.contentInsets = contentInsets
        }
    }

    public convenience init(_ stringValue: String) {
        self.init(frame: .zero)
        self.stringValue = stringValue
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isEditable = false
        drawsBackground = false
        isBordered = false
    }

    open override class var cellClass: AnyClass? {
        set {}
        get { LabelCell.self }
    }

    open override var intrinsicContentSize: NSSize {
        var intrinsicContentSize = super.intrinsicContentSize
        intrinsicContentSize.width += contentInsets.left + contentInsets.right
        intrinsicContentSize.height += contentInsets.top + contentInsets.bottom
        return intrinsicContentSize
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif



