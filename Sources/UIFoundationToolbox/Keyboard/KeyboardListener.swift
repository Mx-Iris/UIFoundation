#if canImport(UIKit)

import UIKit

public final class KeyboardListener {
    public static let shared = KeyboardListener()

    public private(set) var isKeyboardVisible: Bool = false

    public private(set) var keyboardRect: CGRect?

    private var delegates = NSHashTable<AnyObject>.weakObjects()

    private var targetResponders = NSHashTable<UIResponder>.weakObjects()

    public func addDelegate(_ delegate: KeyboardListenerDelegate) {
        delegates.add(delegate)
    }

    public func addTargetResponder(_ targetResponder: UIResponder) {
        targetResponders.add(targetResponder)
    }

    public init() {
        subscribeToKeyboardNotifications()
    }

    public var ignoreApplicationState: Bool = false

    private var isAppActive: Bool {
        if ignoreApplicationState {
            return true
        }
        if UIApplication.shared.applicationState == .active {
            return true
        }
        return false
    }

    @objc
    private func keyboardWillShow(_ notification: Notification) {
        guard var info = KeyboardInfo(notification) else { return }
        guard isAppActive else { return }
        guard shouldReceiveShowNotification(setCurrentResponder: true) else { return }

        keyboardRect = info.frameEnd
        isKeyboardVisible = true
        info.targetResponder = currentResponder
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillShow(info: info)
        }
    }

    @objc
    private func keyboardDidShow(_ notification: Notification) {
        guard var info = KeyboardInfo(notification) else { return }
        guard isAppActive else { return }
        guard shouldReceiveShowNotification(setCurrentResponder: false) else { return }
        keyboardRect = info.frameEnd
        info.targetResponder = currentResponder
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidShow(info: info)
        }
    }

    @objc
    private func keyboardWillChangeFrame(_ notification: Notification) {
        guard var info = KeyboardInfo(notification) else { return }
        guard isAppActive else { return }
        guard shouldReceiveShowNotification(setCurrentResponder: false) || shouldReceiveHideNotification() else { return }
        keyboardRect = info.frameEnd
        info.targetResponder = currentResponder
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillChangeFrame(info: info)
        }
    }

    @objc
    private func keyboardDidChangeFrame(_ notification: Notification) {
        guard var info = KeyboardInfo(notification) else { return }
        guard isAppActive else { return }
        guard shouldReceiveShowNotification(setCurrentResponder: false) || shouldReceiveHideNotification() else { return }
        keyboardRect = info.frameEnd
        info.targetResponder = currentResponder
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidChangeFrame(info: info)
        }
    }

    @objc
    private func keyboardWillHide(_ notification: Notification) {
        guard var info = KeyboardInfo(notification) else { return }
        guard isAppActive else { return }
        keyboardRect = info.frameEnd
        info.targetResponder = currentResponder
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardWillHide(info: info)
        }
    }

    @objc
    private func keyboardDidHide(_ notification: Notification) {
        guard var info = KeyboardInfo(notification) else { return }
        guard isAppActive else { return }
        keyboardRect = info.frameEnd
        isKeyboardVisible = false
        info.targetResponder = currentResponder
        delegates.allObjects.compactMap { $0 as? KeyboardListenerDelegate }.forEach {
            $0.keyboardDidHide(info: info)
        }
        currentResponder = nil
    }

    private func subscribeToKeyboardNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidShow(_:)),
            name: UIResponder.keyboardDidShowNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidHide(_:)),
            name: UIResponder.keyboardDidHideNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardDidChangeFrame(_:)),
            name: UIResponder.keyboardDidChangeFrameNotification,
            object: nil
        )
    }

    weak var currentResponder: UIResponder?

    private func shouldReceiveShowNotification(setCurrentResponder: Bool) -> Bool {
        let firstResponder = firstResponderInWindows()
        if setCurrentResponder {
            currentResponder = firstResponder
        }
        if targetResponders.count == 0 {
            return true
        } else {
            return firstResponder != nil && targetResponders.contains(firstResponder)
        }
    }

    private func shouldReceiveHideNotification() -> Bool {
        if targetResponders.count == 0 {
            return true
        } else {
            return currentResponder != nil && targetResponders.contains(currentResponder)
        }
    }

    private func firstResponderInWindows() -> UIResponder? {
        if let firstResponder = UIApplication.shared.keyWindow?.findFirstResponder {
            return firstResponder
        }
        for window in UIApplication.shared.windows {
            if let firstResponder = window.findFirstResponder {
                return firstResponder
            }
        }
        return nil
    }
}

extension Notification {
    var isLocalKeyboard: Bool {
        if userInfo?[UIResponder.keyboardIsLocalUserInfoKey] as? Bool == true {
            return true
        }
        return false
    }
}

extension UIView {
    fileprivate var findFirstResponder: UIResponder? {
        if isFirstResponder {
            return self
        }
        for subview in subviews {
            if let responder = subview.findFirstResponder {
                return responder
            }
        }
        return nil
    }
}

#endif
