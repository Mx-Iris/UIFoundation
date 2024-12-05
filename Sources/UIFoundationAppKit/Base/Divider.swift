#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public final class Divider: Box {
    public init() {
        super.init(frame: .zero)
        boxType = .separator
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

#endif
