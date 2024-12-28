#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XiblessView: LayerBackedView {
    public override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

#endif
