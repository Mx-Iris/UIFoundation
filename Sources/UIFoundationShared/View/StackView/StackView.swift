#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import SwiftStdlibToolbox
import UIFoundationTypealias

extension NSUIStackView {
    public convenience init(orientationOrAxis: NSUIStackViewOrientationOrAxis, distribution: NSUIStackViewDistribution, alignment: NSUIStackViewAlignment, spacing: CGFloat, views: [NSUIView]) {
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
            
            if let customSpacing = view._customSpacing {
                setCustomSpacing(customSpacing, after: view)
            }
            
            if let visibilityPriority = view._visibilityPriority {
                setVisibilityPriority(visibilityPriority, for: view)
            }
        }
    }
}

public final class HStackView: NSUIStackView {
    public convenience init(distribution: NSUIStackViewDistribution = .defaultValue, alignment: NSUIStackViewAlignment = .hStackDefaultValue, spacing: CGFloat = 0, @ArrayBuilder<StackViewComponent> views: () -> [StackViewComponent]) {
        self.init(orientationOrAxis: .horizontal, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }
}

public final class VStackView: NSUIStackView {
    public convenience init(distribution: NSUIStackViewDistribution = .defaultValue, alignment: NSUIStackViewAlignment = .vStackDefaultValue, spacing: CGFloat = 0, @ArrayBuilder<StackViewComponent> views: () -> [StackViewComponent]) {
        self.init(orientationOrAxis: .vertical, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }
}
