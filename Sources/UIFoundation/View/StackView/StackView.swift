#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



extension _NSUIStackView {
    public convenience init(orientationOrAxis: _NSUIStackViewOrientationOrAxis, distribution: _NSUIStackViewDistribution, alignment: _NSUIStackViewAlignment, spacing: CGFloat, views: [_NSUIView]) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.init(views: [])
        self.orientation = orientationOrAxis
        #endif

        #if canImport(UIKit)
        self.init(arrangedSubviews: [])
        self.axis = orientationOrAxis
        #endif

        self.distribution = distribution
        self.alignment = alignment
        self.spacing = spacing

        views.forEach { view in
            view.translatesAutoresizingMaskIntoConstraints = false

            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let gravity = view._gravity {
                self.addView(view, in: gravity)
            } else {
                self.addArrangedSubview(view)
            }
            #endif

            #if canImport(UIKit)
            self.addArrangedSubview(view)
            #endif

            if let spacer = view as? Spacer {
                spacer.orientationOrAxis = orientationOrAxis
            }

            if let maxSpacer = view as? MaxSpacer {
                maxSpacer.setContentHuggingPriority(.fittingSize, for: orientationOrAxis.nsLayoutConstraintOrientationOrAxis)
                maxSpacer.setContentCompressionResistancePriority(.fittingSize, for: orientationOrAxis.nsLayoutConstraintOrientationOrAxis)
            }
        }
    }
}

public class HStackView: _NSUIStackView {
    public convenience init(distribution: _NSUIStackViewDistribution = .defaultValue, alignment: _NSUIStackViewAlignment = .hStackCenter, spacing: CGFloat = 0, @StackViewBuilder views: () -> [StackViewComponent]) {
        self.init(orientationOrAxis: .horizontal, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }
}

public class VStackView: _NSUIStackView {
    public convenience init(distribution: _NSUIStackViewDistribution = .defaultValue, alignment: _NSUIStackViewAlignment = .vStackCenter, spacing: CGFloat = 0, @StackViewBuilder views: () -> [StackViewComponent]) {
        self.init(orientationOrAxis: .vertical, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }
}
