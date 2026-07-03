#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundation

@Suite("StackView Imperative Configuration")
@MainActor
struct StackViewImperativeConfigurationTests {

    @Test("Arranged subview insertion applies per-component configuration")
    func arrangedSubviewInsertionAppliesPerComponentConfiguration() {
        let stackView = HStackView(alignment: .fill) {}
        stackView.edgeInsets = NSEdgeInsets(top: 4, left: 0, bottom: 6, right: 0)

        let spacer = Spacer(spacing: 12)
        let visibilityPriority = NSStackView.VisibilityPriority(rawValue: 321)
        spacer.stackView.customSpacing(17)
        spacer.stackView.visibilityPriority(visibilityPriority)

        stackView.insertArrangedSubview(spacer, at: 0)

        #expect(spacer.translatesAutoresizingMaskIntoConstraints == false)
        #expect(spacer.intrinsicContentSize.width == 12)
        #expect(stackView.customSpacing(after: spacer) == 17)
        #expect(stackView.visibilityPriority(for: spacer) == visibilityPriority)
        #expect(hasActiveConstraint(in: stackView, connecting: spacer, attribute: .top, constant: 4))
        #expect(hasActiveConstraint(in: stackView, connecting: spacer, attribute: .bottom, constant: -6))

        stackView.removeArrangedSubview(spacer)

        #expect(!hasActiveConstraint(in: stackView, connecting: spacer, attribute: .top))
        #expect(!hasActiveConstraint(in: stackView, connecting: spacer, attribute: .bottom))
    }

    @Test("MaxSpacer uses the current stack axis when added imperatively")
    func maxSpacerUsesCurrentStackAxisWhenAddedImperatively() {
        let stackView = VStackView {}
        let maxSpacer = MaxSpacer()

        stackView.addArrangedSubview(maxSpacer)

        #expect(maxSpacer.contentHuggingPriority(for: .vertical) == .fittingSize)
        #expect(maxSpacer.contentCompressionResistancePriority(for: .vertical) == .fittingSize)
    }

    @Test("Fixed-direction stack views set their direction during frame initialization")
    func fixedDirectionStackViewsSetDirectionDuringFrameInitialization() {
        #expect(HStackView(frame: .zero).orientation == .horizontal)
        #expect(VStackView(frame: .zero).orientation == .vertical)
    }

    @Test("DSL initialization still applies gravity and per-component configuration")
    func dslInitializationStillAppliesGravityAndPerComponentConfiguration() {
        let leadingView = NSView()
        let centerView = NSView()
        centerView.stackView.customSpacing(13)

        let stackView = HStackView(alignment: .fill) {
            leadingView.stackView.gravity(.leading)
            centerView
        }

        #expect(stackView.views(in: .leading).contains { managedView in
            managedView === leadingView
        })
        #expect(stackView.views.contains { managedView in
            managedView === centerView
        })
        #expect(leadingView.translatesAutoresizingMaskIntoConstraints == false)
        #expect(centerView.translatesAutoresizingMaskIntoConstraints == false)
        #expect(stackView.customSpacing(after: centerView) == 13)
        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: leadingView) == 2)
        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: centerView) == 2)
    }

    @Test("Alignment changes synchronize fill constraints without duplicating explicit fill")
    func alignmentChangesSynchronizeFillConstraintsWithoutDuplicatingExplicitFill() {
        let implicitFillView = NSView()
        let explicitFillView = NSView()
        explicitFillView.stackView.fill()

        let stackView = HStackView(alignment: .center) {
            implicitFillView
            explicitFillView
        }

        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: implicitFillView) == 0)
        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: explicitFillView) == 2)

        stackView.box.alignment(.fill)

        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: implicitFillView) == 2)
        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: explicitFillView) == 2)

        stackView.box.alignment(.fill)

        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: implicitFillView) == 2)
        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: explicitFillView) == 2)

        stackView.box.alignment(.center)

        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: implicitFillView) == 0)
        #expect(activeCrossAxisConstraintCount(in: stackView, connecting: explicitFillView) == 2)
    }

    @Test("Gravity-area mutations apply and remove per-component configuration")
    func gravityAreaMutationsApplyAndRemovePerComponentConfiguration() {
        let stackView = HStackView(alignment: .fill) {}
        stackView.edgeInsets = NSEdgeInsets(top: 3, left: 0, bottom: 5, right: 0)

        let leadingView = NSView()
        let visibilityPriority = NSStackView.VisibilityPriority(rawValue: 321)
        leadingView.stackView.visibilityPriority(visibilityPriority)

        stackView.addView(leadingView, in: .leading)

        #expect(stackView.views(in: .leading).contains { managedView in
            managedView === leadingView
        })
        #expect(stackView.visibilityPriority(for: leadingView) == visibilityPriority)
        #expect(hasActiveConstraint(in: stackView, connecting: leadingView, attribute: .top, constant: 3))
        #expect(hasActiveConstraint(in: stackView, connecting: leadingView, attribute: .bottom, constant: -5))

        stackView.removeView(leadingView)

        #expect(!hasActiveConstraint(in: stackView, connecting: leadingView, attribute: .top))
        #expect(!hasActiveConstraint(in: stackView, connecting: leadingView, attribute: .bottom))

        let trailingView = NSView()
        trailingView.stackView.fill()

        stackView.setViews([trailingView], in: .trailing)

        #expect(hasActiveConstraint(in: stackView, connecting: trailingView, attribute: .top, constant: 3))
        #expect(hasActiveConstraint(in: stackView, connecting: trailingView, attribute: .bottom, constant: -5))

        stackView.setViews([], in: .trailing)

        #expect(!hasActiveConstraint(in: stackView, connecting: trailingView, attribute: .top))
        #expect(!hasActiveConstraint(in: stackView, connecting: trailingView, attribute: .bottom))
    }

    private func hasActiveConstraint(in stackView: NSStackView, connecting view: NSView, attribute: NSLayoutConstraint.Attribute, constant expectedConstant: CGFloat? = nil) -> Bool {
        stackView.constraints.contains { constraint in
            guard constraint.isActive else { return false }
            guard let firstView = constraint.firstItem as? NSView, let secondView = constraint.secondItem as? NSView else { return false }
            guard firstView === view, secondView === stackView else { return false }
            guard constraint.firstAttribute == attribute, constraint.secondAttribute == attribute else { return false }

            if let expectedConstant {
                return abs(constraint.constant - expectedConstant) < 0.0001
            }

            return true
        }
    }

    private func activeCrossAxisConstraintCount(in stackView: NSStackView, connecting view: NSView) -> Int {
        stackView.constraints.filter { constraint in
            guard constraint.isActive else { return false }
            guard let firstView = constraint.firstItem as? NSView, let secondView = constraint.secondItem as? NSView else { return false }
            guard firstView === view, secondView === stackView else { return false }
            guard constraint.firstAttribute == constraint.secondAttribute else { return false }
            return constraint.firstAttribute == .top || constraint.firstAttribute == .bottom
        }.count
    }
}

#endif
