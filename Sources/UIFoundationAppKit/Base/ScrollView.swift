#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class ScrollView: NSScrollView {
    public var isHiddenVisualEffectView: Bool = false

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
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

    open override var drawsBackground: Bool {
        set {}
        get { false }
    }

    open override func didAddSubview(_ subview: NSView) {
        super.didAddSubview(subview)

        if isHiddenVisualEffectView, subview is NSVisualEffectView {
            subview.isHidden = true
        }
    }
}

open class GenericScrollView<DocumentView: NSView>: ScrollView {
    public let genericDocumentView: DocumentView

    public init(documentView: DocumentView, frame: NSRect = .zero) {
        self.genericDocumentView = documentView
        super.init(frame: frame)
        self.documentView = documentView
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
