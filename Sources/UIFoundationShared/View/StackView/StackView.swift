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
        #endif

        #if canImport(UIKit)
        self.init(arrangedSubviews: [])
        #endif

        configureStackView(orientationOrAxis: orientationOrAxis, distribution: distribution, alignment: alignment, spacing: spacing)

        let stackFillsCrossAxis: Bool = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return alignment.requiresCrossAxisFill
            #else
            return false
            #endif
        }()

        for view in views {
            addStackViewComponent(view, stackFillsCrossAxis: stackFillsCrossAxis)
        }
    }

    func configureStackView(orientationOrAxis: NSUIStackViewOrientationOrAxis, distribution: NSUIStackViewDistribution, alignment: StackViewAlignment, spacing: CGFloat) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.orientation = orientationOrAxis
        #endif

        #if canImport(UIKit)
        self.axis = orientationOrAxis
        #endif

        self.distribution = distribution
        self.spacing = spacing
        setStackViewAlignment(alignment)
    }

    @usableFromInline
    func setStackViewAlignment(_ alignment: StackViewAlignment) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        self.alignment = alignment.attribute(for: orientation)
        stackViewShouldApplyCrossAxisFillToArrangedSubviews = alignment.requiresCrossAxisFill
        synchronizeCrossAxisFillConstraintsForManagedViews()
        #endif

        #if canImport(UIKit)
        self.alignment = alignment.uiStackAlignment(for: axis)
        #endif
    }

    private var appliesComponentConfigurationInOverrides: Bool {
        self is StackView
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private var stackViewShouldApplyCrossAxisFillToArrangedSubviews: Bool {
        get {
            if let stackView = self as? StackView {
                return stackView.shouldApplyCrossAxisFillToArrangedSubviews
            }

            return false
        }
        set {
            if let stackView = self as? StackView {
                stackView.shouldApplyCrossAxisFillToArrangedSubviews = newValue
            }
        }
    }
    #endif

    private var currentOrientationOrAxis: NSUIStackViewOrientationOrAxis {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return orientation
        #endif

        #if canImport(UIKit)
        return axis
        #endif
    }

    fileprivate func addStackViewComponent(_ view: NSUIView, stackFillsCrossAxis: Bool) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if let gravity = view._gravity {
            addView(view, in: gravity)
        } else {
            addArrangedSubview(view)
        }
        #endif

        #if canImport(UIKit)
        addArrangedSubview(view)
        #endif

        if !appliesComponentConfigurationInOverrides {
            applyStackViewComponentConfiguration(to: view, stackFillsCrossAxis: stackFillsCrossAxis)
        }
    }

    private func applyStackViewComponentConfiguration(to view: NSUIView, stackFillsCrossAxis: Bool? = nil) {
        view.translatesAutoresizingMaskIntoConstraints = false

        let orientationOrAxis = currentOrientationOrAxis

        if let spacer = view as? Spacer {
            spacer.orientationOrAxis = orientationOrAxis
            spacer.invalidateIntrinsicContentSize()
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

        let shouldFillCrossAxis = stackFillsCrossAxis ?? stackViewShouldApplyCrossAxisFillToArrangedSubviews
        if shouldFillCrossAxis || view._fillsCrossAxis == true {
            activateCrossAxisFillConstraints(for: view, orientation: orientationOrAxis)
        } else {
            deactivateCrossAxisFillConstraints(for: view)
        }
        #endif

        #if canImport(UIKit)
        if view._fillsCrossAxis == true {
            activateCrossAxisFillConstraints(for: view, axis: orientationOrAxis)
        } else {
            deactivateCrossAxisFillConstraints(for: view)
        }
        #endif
    }

    private func removeStackViewComponentConfiguration(from view: NSUIView) {
        deactivateCrossAxisFillConstraints(for: view)
    }

    fileprivate func performArrangedSubviewInsertionApplyingStackViewComponentConfiguration(to view: NSUIView, insertion: () -> Void) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let shouldApplyConfiguration = !stackViewIsPerformingGravityAreaMutation
        #endif

        insertion()

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if shouldApplyConfiguration {
            applyStackViewComponentConfiguration(to: view)
        }
        #endif

        #if canImport(UIKit)
        applyStackViewComponentConfiguration(to: view)
        #endif
    }

    fileprivate func performArrangedSubviewRemovalRemovingStackViewComponentConfiguration(from view: NSUIView, removal: () -> Void) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        let shouldRemoveConfiguration = !stackViewIsPerformingGravityAreaMutation
        #endif

        removal()

        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        if shouldRemoveConfiguration {
            removeStackViewComponentConfiguration(from: view)
        }
        #endif

        #if canImport(UIKit)
        removeStackViewComponentConfiguration(from: view)
        #endif
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    private var stackViewIsPerformingGravityAreaMutation: Bool {
        get {
            if let stackView = self as? StackView {
                return stackView.isPerformingGravityAreaMutation
            }

            return false
        }
        set {
            if let stackView = self as? StackView {
                stackView.isPerformingGravityAreaMutation = newValue
            }
        }
    }

    fileprivate func performGravityAreaInsertionApplyingStackViewComponentConfiguration(to view: NSView, insertion: () -> Void) {
        performGravityAreaMutation(insertion)
        applyStackViewComponentConfiguration(to: view)
    }

    fileprivate func performGravityAreaRemovalRemovingStackViewComponentConfiguration(from view: NSView, removal: () -> Void) {
        performGravityAreaMutation(removal)
        removeStackViewComponentConfiguration(from: view)
    }

    fileprivate func performGravityAreaReplacementApplyingStackViewComponentConfiguration(with newViews: [NSView], in gravity: NSStackView.Gravity, replacement: () -> Void) {
        let previousViews = views(in: gravity)

        performGravityAreaMutation(replacement)

        previousViews
            .filter { previousView in
                !newViews.contains { newView in
                    newView === previousView
                }
            }
            .forEach { previousView in
                removeStackViewComponentConfiguration(from: previousView)
            }

        for view in newViews {
            applyStackViewComponentConfiguration(to: view)
        }
    }

    private func performGravityAreaMutation(_ mutation: () -> Void) {
        stackViewIsPerformingGravityAreaMutation = true
        defer { stackViewIsPerformingGravityAreaMutation = false }

        mutation()
    }

    private func synchronizeCrossAxisFillConstraintsForManagedViews() {
        for view in views {
            if stackViewShouldApplyCrossAxisFillToArrangedSubviews || view._fillsCrossAxis == true {
                activateCrossAxisFillConstraints(for: view, orientation: orientation)
            } else {
                deactivateCrossAxisFillConstraints(for: view)
            }
        }
    }

    private func activateCrossAxisFillConstraints(for view: NSView, orientation: NSUserInterfaceLayoutOrientation) {
        deactivateCrossAxisFillConstraints(for: view)

        let constraints: [NSLayoutConstraint]
        switch orientation {
        case .horizontal:
            constraints = [
                view.topAnchor.constraint(equalTo: self.topAnchor, constant: edgeInsets.top),
                view.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -edgeInsets.bottom),
            ]
        case .vertical:
            constraints = [
                view.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: edgeInsets.left),
                view.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -edgeInsets.right),
            ]
        @unknown default:
            return
        }

        view._stackViewCrossAxisFillConstraints = constraints
        NSLayoutConstraint.activate(constraints)
    }
    #endif

    #if canImport(UIKit)
    private func activateCrossAxisFillConstraints(for view: UIView, axis: NSLayoutConstraint.Axis) {
        deactivateCrossAxisFillConstraints(for: view)

        let constraints: [NSLayoutConstraint]
        switch axis {
        case .horizontal:
            constraints = [
                view.topAnchor.constraint(equalTo: self.topAnchor),
                view.bottomAnchor.constraint(equalTo: self.bottomAnchor),
            ]
        case .vertical:
            constraints = [
                view.leadingAnchor.constraint(equalTo: self.leadingAnchor),
                view.trailingAnchor.constraint(equalTo: self.trailingAnchor),
            ]
        @unknown default:
            return
        }

        view._stackViewCrossAxisFillConstraints = constraints
        NSLayoutConstraint.activate(constraints)
    }
    #endif

    private func deactivateCrossAxisFillConstraints(for view: NSUIView) {
        guard let constraints = view._stackViewCrossAxisFillConstraints else { return }
        NSLayoutConstraint.deactivate(constraints)
        view._stackViewCrossAxisFillConstraints = nil
    }
}

public class StackView: NSUIStackView {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    fileprivate var shouldApplyCrossAxisFillToArrangedSubviews = false
    fileprivate var isPerformingGravityAreaMutation = false
    #endif

    public override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    #endif

    #if canImport(UIKit)
    public required init(coder: NSCoder) {
        super.init(coder: coder)
    }
    #endif

    fileprivate init(fixedOrientationOrAxis orientationOrAxis: NSUIStackViewOrientationOrAxis, distribution: NSUIStackViewDistribution, alignment: StackViewAlignment, spacing: CGFloat, views: [NSUIView]) {
        super.init(frame: .zero)
        configureStackViewBypassingDirectionProperty(orientationOrAxis: orientationOrAxis, distribution: distribution, alignment: alignment, spacing: spacing)

        let stackFillsCrossAxis: Bool = {
            #if canImport(AppKit) && !targetEnvironment(macCatalyst)
            return alignment.requiresCrossAxisFill
            #else
            return false
            #endif
        }()

        for view in views {
            addStackViewComponent(view, stackFillsCrossAxis: stackFillsCrossAxis)
        }
    }

    fileprivate func configureStackViewBypassingDirectionProperty(orientationOrAxis: NSUIStackViewOrientationOrAxis, distribution: NSUIStackViewDistribution, alignment: StackViewAlignment, spacing: CGFloat) {
        setOrientationOrAxisBypassingDirectionProperty(orientationOrAxis)
        self.distribution = distribution
        self.spacing = spacing
        setStackViewAlignment(alignment)
    }

    fileprivate func setOrientationOrAxisBypassingDirectionProperty(_ orientationOrAxis: NSUIStackViewOrientationOrAxis) {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        super.orientation = orientationOrAxis
        #endif

        #if canImport(UIKit)
        super.axis = orientationOrAxis
        #endif
    }

    public override func addArrangedSubview(_ view: NSUIView) {
        performArrangedSubviewInsertionApplyingStackViewComponentConfiguration(to: view) {
            super.addArrangedSubview(view)
        }
    }

    public override func insertArrangedSubview(_ view: NSUIView, at stackIndex: Int) {
        performArrangedSubviewInsertionApplyingStackViewComponentConfiguration(to: view) {
            super.insertArrangedSubview(view, at: stackIndex)
        }
    }

    public override func removeArrangedSubview(_ view: NSUIView) {
        performArrangedSubviewRemovalRemovingStackViewComponentConfiguration(from: view) {
            super.removeArrangedSubview(view)
        }
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public override func addView(_ view: NSView, in gravity: NSStackView.Gravity) {
        performGravityAreaInsertionApplyingStackViewComponentConfiguration(to: view) {
            super.addView(view, in: gravity)
        }
    }

    public override func insertView(_ view: NSView, at index: Int, in gravity: NSStackView.Gravity) {
        performGravityAreaInsertionApplyingStackViewComponentConfiguration(to: view) {
            super.insertView(view, at: index, in: gravity)
        }
    }

    public override func removeView(_ view: NSView) {
        performGravityAreaRemovalRemovingStackViewComponentConfiguration(from: view) {
            super.removeView(view)
        }
    }

    public override func setViews(_ newViews: [NSView], in gravity: NSStackView.Gravity) {
        performGravityAreaReplacementApplyingStackViewComponentConfiguration(with: newViews, in: gravity) {
            super.setViews(newViews, in: gravity)
        }
    }
    #endif
}

public final class HStackView: StackView {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public override var orientation: NSUserInterfaceLayoutOrientation {
        get { super.orientation }
        @available(*, unavailable, message: "HStackView has a fixed horizontal orientation.")
        set {}
    }
    #endif

    #if canImport(UIKit)
    public override var axis: NSLayoutConstraint.Axis {
        get { super.axis }
        @available(*, unavailable, message: "HStackView has a fixed horizontal axis.")
        set {}
    }
    #endif

    public init(distribution: NSUIStackViewDistribution = .defaultValue, alignment: StackViewAlignment = .defaultValue, spacing: CGFloat = 0, @ArrayBuilder<StackViewComponent> views: () -> [StackViewComponent]) {
        super.init(fixedOrientationOrAxis: .horizontal, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }

    public override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setOrientationOrAxisBypassingDirectionProperty(.horizontal)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setOrientationOrAxisBypassingDirectionProperty(.horizontal)
    }
    #endif

    #if canImport(UIKit)
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        setOrientationOrAxisBypassingDirectionProperty(.horizontal)
    }
    #endif
}

public final class VStackView: StackView {
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public override var orientation: NSUserInterfaceLayoutOrientation {
        get { super.orientation }
        @available(*, unavailable, message: "VStackView has a fixed vertical orientation.")
        set {}
    }
    #endif

    #if canImport(UIKit)
    public override var axis: NSLayoutConstraint.Axis {
        get { super.axis }
        @available(*, unavailable, message: "VStackView has a fixed vertical axis.")
        set {}
    }
    #endif

    public init(distribution: NSUIStackViewDistribution = .defaultValue, alignment: StackViewAlignment = .defaultValue, spacing: CGFloat = 0, @ArrayBuilder<StackViewComponent> views: () -> [StackViewComponent]) {
        super.init(fixedOrientationOrAxis: .vertical, distribution: distribution, alignment: alignment, spacing: spacing, views: views())
    }

    public override init(frame frameRect: CGRect) {
        super.init(frame: frameRect)
        setOrientationOrAxisBypassingDirectionProperty(.vertical)
    }

    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setOrientationOrAxisBypassingDirectionProperty(.vertical)
    }
    #endif

    #if canImport(UIKit)
    public required init(coder: NSCoder) {
        super.init(coder: coder)
        setOrientationOrAxisBypassingDirectionProperty(.vertical)
    }
    #endif
}
