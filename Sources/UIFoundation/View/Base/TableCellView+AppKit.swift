#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class TableCellView: NSTableCellView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = .init(String(describing: Self.self))
        makeUI()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        makeUI()
    }

    open func makeUI() {}

    open func firstLayout() {}

    private lazy var _firstLayout: Void = {
        firstLayout()
    }()

    open override func layout() {
        super.layout()
        _ = _firstLayout
    }
}

open class ImageTextTableCellView: TableCellView {
    public let _imageView = ImageView()
    public let _textField = Label()

    open override func makeUI() {
        super.makeUI()

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
    }
}

open class TextTableCellView: TableCellView {
    public let _textField = Label()

    open override func makeUI() {
        super.makeUI()

        textField = _textField

        addSubview(_textField)

        _textField.makeConstraints { make in
            make.leftAnchor.constraint(equalTo: leftAnchor)
            make.centerYAnchor.constraint(equalTo: centerYAnchor)
            make.rightAnchor.constraint(lessThanOrEqualTo: rightAnchor)
        }
        
        _textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    }
}

#endif
