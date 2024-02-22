#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

public class Spacer: NSUIView {
    public let spacing: CGFloat

    var orientationOrAxis: NSUIStackViewOrientationOrAxis = .horizontal

    public init(spacing: CGFloat = 5) {
        self.spacing = spacing
        super.init(frame: .zero)
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        wantsLayer = true
        layer?.backgroundColor = .clear
        #endif

        #if canImport(UIKit)
        backgroundColor = .clear
        #endif
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var intrinsicContentSize: CGSize {
        switch orientationOrAxis {
        case .horizontal:
            return .init(width: spacing, height: NSUIView.noIntrinsicMetric)
        case .vertical:
            return .init(width: NSUIView.noIntrinsicMetric, height: spacing)
        @unknown default:
            return super.intrinsicContentSize
        }
    }
}
