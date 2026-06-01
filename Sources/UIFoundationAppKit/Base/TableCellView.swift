#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox
import UIFoundationUtilities
import UIFoundationShared

open class TableCellView: NSTableCellView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = .init(String(describing: Self.self))
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        setup()
    }

    open func setup() {}

    open func firstLayout() {}

    private lazy var _firstLayout: () -> Void = {
        firstLayout()
        return {}
    }()

    open override func layout() {
        super.layout()
        
        _firstLayout()
    }
}

open class LayerBackedTableCellView: TableCellView, LayerBackgroundProviding {
    open var isLayerBackingEnabled: Bool { false }

    open override func setup() {
        super.setup()

        attachToSelfIfNeeded()
    }

    open override var wantsUpdateLayer: Bool { isLayerBackingEnabled }

    open override func layout() {
        super.layout()

        layoutLayerBackgroundIfNeeded()
    }

    open override func updateLayer() {
        super.updateLayer()

        updateLayerBackgroundIfNeeded()
    }
}

open class ImageTextTableCellView: LayerBackedTableCellView {
    public let _imageView = ImageView()
    public let _textField = Label()

    open override func setup() {
        super.setup()

        imageView = _imageView
        textField = _textField

        addSubview(_imageView)
        addSubview(_textField)

        _imageView.makeConstraints { make in
            make.leftAnchor.constraint(equalTo: leftAnchor)
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
        }

        _textField.makeConstraints { make in
            make.leftAnchor.constraint(equalTo: _imageView.rightAnchor, constant: 10)
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor)
        }

        _textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        _textField.maximumNumberOfLines = 1
    }
}

open class TextTableCellView: LayerBackedTableCellView {
    public let _textField = Label()

    open override func setup() {
        super.setup()

        textField = _textField

        addSubview(_textField)

        _textField.makeConstraints { make in
            make.leftAnchor.constraint(equalTo: leftAnchor)
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor)
        }

        _textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        _textField.maximumNumberOfLines = 1
    }
}

open class DisclosureHeaderCellView: LayerBackedTableCellView {
    private let titleLabel = Label()

    private let disclosureButton = DisclosureButton()

    public var disclosureClickHandler: () -> Void = {}

    public var title: String? {
        didSet {
            titleLabel.stringValue = title ?? ""
        }
    }

    public var titleFont: NSFont = .systemFont(ofSize: 11) {
        didSet {
            titleLabel.font = titleFont
        }
    }

    public var titleColor: NSColor = .tertiaryLabelColor {
        didSet {
            titleLabel.textColor = titleColor
        }
    }

    public var isExpanded: Bool = false {
        didSet {
            disclosureButton.state = isExpanded ? .on : .off
        }
    }

    private lazy var contentStackView = HStackView(distribution: .fill, alignment: .center, spacing: 8) {
        titleLabel
        disclosureButton
    }

    open override func setup() {
        super.setup()

        box.addSubview(contentStackView, fill: true)

        titleLabel.font = titleFont
        titleLabel.textColor = titleColor

        disclosureButton.alphaValue = 0
        disclosureButton.imagePosition = .imageOnly
        disclosureButton.box.setAction { [weak self] _ in
            self?.disclosureClickHandler()
        }
    }

    open override func updateTrackingAreas() {
        super.updateTrackingAreas()

        trackingAreas.forEach(removeTrackingArea(_:))

        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .assumeInside]
        let trackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(trackingArea)
    }

    open override func mouseEntered(with event: NSEvent) {
        disclosureButton.alphaValue = 1
    }

    open override func mouseMoved(with event: NSEvent) {
        if disclosureButton.alphaValue != 1 {
            disclosureButton.alphaValue = 1
        }
    }

    open override func mouseExited(with event: NSEvent) {
        disclosureButton.alphaValue = 0
    }
}

#endif
