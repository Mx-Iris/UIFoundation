#if canImport(UIKit)
import UIKit
import FrameworkToolbox
import FoundationToolbox
import AssociatedObject

private enum Identifiers {
    static var usingSafeArea = "KeyboardLayoutGuideUsingSafeArea"
    static var ignoreSafeArea = "KeyboardLayoutGuideIgnoreSafeArea"
}

extension FrameworkToolbox where Base: UIView {
    /// A layout guide representing the inset for the keyboard.
    /// Use this layout guide’s top anchor to create constraints pinning to the top of the keyboard or the bottom of safe area.
    public var keyboardLayoutGuide: KeyboardLayoutGuide {
        keyboardLayoutGuide(identifier: Identifiers.usingSafeArea, usesSafeArea: true)
    }

    /// A layout guide representing the inset for the keyboard.
    /// Use this layout guide’s top anchor to create constraints pinning to the top of the keyboard or the bottom of the view.
    public var keyboardLayoutGuideIgnoreSafeArea: KeyboardLayoutGuide {
        keyboardLayoutGuide(identifier: Identifiers.ignoreSafeArea, usesSafeArea: false)
    }

    private func keyboardLayoutGuide(identifier: String, usesSafeArea: Bool) -> KeyboardLayoutGuide {
        if let existing = base.layoutGuides.first(where: { $0.identifier == identifier }) as? KeyboardLayoutGuide {
            return existing
        }
        let keyboardLayoutGuide = KeyboardLayoutGuide(usesSafeArea: usesSafeArea)
        keyboardLayoutGuide.identifier = identifier
        base.addLayoutGuide(keyboardLayoutGuide)
        keyboardLayoutGuide.setup()
        return keyboardLayoutGuide
    }
}

public final class KeyboardLayoutGuide: UILayoutGuide, KeyboardListenerDelegate {
    public let usesSafeArea: Bool

    public weak var targetResponder: UIResponder? {
        didSet {
            if let targetResponder {
                keyboardListener.addTargetResponder(targetResponder)
            }
        }
    }

    private var bottomConstraint: NSLayoutConstraint?

    private var heightConstraint: NSLayoutConstraint?

    private lazy var keyboardListener = KeyboardListener()

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(usesSafeArea: Bool) {
        self.usesSafeArea = usesSafeArea
        super.init()
        if usesSafeArea {
            updateBottomAnchor()
        }
        keyboardListener.addDelegate(self)
    }

    func setup() {
        guard let view = owningView else { return }
        let heightConstraint = heightAnchor.constraint(equalToConstant: KeyboardListener.shared.keyboardRect?.height ?? 0)
        heightConstraint.isActive = true
        self.heightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            leftAnchor.constraint(equalTo: view.leftAnchor),
            rightAnchor.constraint(equalTo: view.rightAnchor),
        ])
        updateBottomAnchor()
    }

    private func updateBottomAnchor() {
        if let bottomConstraint = bottomConstraint {
            bottomConstraint.isActive = false
        }

        guard let view = owningView else { return }

        let viewBottomAnchor: NSLayoutYAxisAnchor
        if #available(iOS 11.0, *), usesSafeArea {
            viewBottomAnchor = view.safeAreaLayoutGuide.bottomAnchor
        } else {
            viewBottomAnchor = view.bottomAnchor
        }

        bottomConstraint = bottomAnchor.constraint(equalTo: viewBottomAnchor)
        bottomConstraint?.isActive = true
    }

    private func adjustKeyboard(_ keyboardUserInfo: KeyboardInfo) {
        guard let targetResponder, keyboardUserInfo.targetResponder === targetResponder else { return }
        var height = keyboardUserInfo.frameEnd.height
        let duration = keyboardUserInfo.animationDuration
        if #available(iOS 11.0, *), usesSafeArea, height > 0, let bottom = owningView?.safeAreaInsets.bottom {
            height -= bottom
        }
        heightConstraint?.constant = height
        if duration > 0.0 {
            animate()
        }
    }

    private func animate() {
        if let owningView = owningView, owningView.box.isVisible {
            self.owningView?.layoutIfNeeded()
        } else {
            UIView.performWithoutAnimation {
                self.owningView?.layoutIfNeeded()
            }
        }
    }

    public func keyboardWillChangeFrame(info: KeyboardInfo) {
        adjustKeyboard(info)
    }

    public func keyboardDidChangeFrame(info: KeyboardInfo) {
        adjustKeyboard(info)
    }
}

// MARK: - Helpers

extension FrameworkToolbox where Base: UIView {
    // Credits to John Gibb for this nice helper :)
    // https://stackoverflow.com/questions/1536923/determine-if-uiview-is-visible-to-the-user
    public var isVisible: Bool {
        func isVisible(view: UIView, inView: UIView?) -> Bool {
            guard let inView = inView else { return true }
            let viewFrame = inView.convert(view.bounds, from: view)
            if viewFrame.intersects(inView.bounds) {
                return isVisible(view: view, inView: inView.superview)
            }
            return false
        }
        return isVisible(view: base, inView: base.superview)
    }
}

#endif
