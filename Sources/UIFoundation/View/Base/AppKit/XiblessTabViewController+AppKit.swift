#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XiblessTabViewController: NSTabViewController {
    public init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
