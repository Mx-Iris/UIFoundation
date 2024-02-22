#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

public class MaxSpacer: NSUIView {
    public init() {
        super.init(frame: .zero)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        wantsLayer = true
        #endif
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
