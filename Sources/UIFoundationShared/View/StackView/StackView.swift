#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import SwiftStdlibToolbox
import UIFoundationTypealias

extension NSUIStackView {
    public convenience init(orientationOrAxis: NSUIStackViewOrientationOrAxis, distribution: NSUIStackViewDistribution, alignment: StackViewAlignment, spacing: CGFloat, views: [NSUIView]) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.init(views: [])
        self.orientation = orientationOrAxis
        self.alignment = alignment.attribute(for: orientationOrAxis)
        #endif

        #if canImport(UIKit)
        self.init(arrangedSubviews: [])
        self.axis = orientationOrAxis
        self.alignment = alignment.uiStackAlignment(for: orientationOrAxis)
        #endif

        self.distribution = distribution
        self.spacing = spacing

        let stackFillsCrossAxis: Bool = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return alignment.requiresCrossAxisFill
            #else
            return false
            #endif
        }()

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

            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            if let visibilityPriority = view._visibilityPriority {
                setVisibilityPriority(visibilityPriority, for: view)
            }

            if stackFillsCrossAxis || view._fillsCrossAxis == true {
                activateCrossAxisFillConstraints(for: view, orientation: orientationOrAxis)
            }
            #endif

            #if canImport(UIKit)
            if view._fillsCrossAxis == true {
                activateCrossAxisFillConstraints(for: view, axis: orientationOrAxis)
            }
            #endif
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private func activateCrossAxisFillConstraints(for view: NSView, orientation: NSUserInterfaceLayoutOrientation) {
        switch orientation {
        case .horizontal:
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: self.topAnchor, constant: edgeInsets.top),
                view.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -edgeInsets.bottom),
            ])
        case .vertical:
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: edgeInsets.left),
                view.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -edgeInsets.right),
            ])
        @unknown default:
            break
        }
    }
    #endif

    #if canImport(UIKit)
    private func activateCrossAxisFillConstraints(for view: UIView, axis: NSLayoutConstraint.Axis) {
        switch axis {
        case .horizontal:
            NSLayoutConstraint.activate([
                view.topAnchor.constraint(equalTo: self.topAnchor),
                view.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            ])
        case .vertical:
            NSLayoutConstraint.activate([
                view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            ])
        @unknown default:
            break
        }
    }
    #endif
}

public final class HStackView: NSUIStackView {
    @inlinable
    public convenience init(distribution: NSUIStackViewDistribution = .defaultValue, alignment: StackViewAlignment = .defaultValue, spacing: CGFloat = 0, @ArrayBuilder<StackViewComponent> views: () -> [StackViewComponent]) {
        self.init(orientationOrAxis: .horizontal, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }
}

public final class VStackView: NSUIStackView {
    @inlinable
    public convenience init(distribution: NSUIStackViewDistribution = .defaultValue, alignment: StackViewAlignment = .defaultValue, spacing: CGFloat = 0, @ArrayBuilder<StackViewComponent> views: () -> [StackViewComponent]) {
        self.init(orientationOrAxis: .vertical, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }
}
