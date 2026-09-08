#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

/// A ``ToolbarItem`` that carries a target/action pair.
///
/// The seven item types a click can reach — ``NSToolbar/Item``, ``NSToolbar/View``,
/// ``NSToolbar/Button``, ``NSToolbar/Menu``, ``NSToolbar/Group``, ``NSToolbar/PopUpButton``
/// and ``NSToolbar/SegmentedControl`` — derive from this class rather than from
/// ``ToolbarItem`` directly, and take their whole target/action surface from here: the two
/// properties, the three chained modifiers, and the trampoline that backs each subclass's
/// typed `actionBlock`.
///
/// ``NSToolbar/Search``, ``NSToolbar/TrackingSeparator`` and ``NSToolbar/Navigation``
/// deliberately do not, which is the reason this class exists at all instead of the same
/// members living on ``ToolbarItem``. `NSToolbarItem` forwards `target` and `action` to its
/// custom view (measured on macOS 26), and `NSToolbar.Navigation`'s custom view *is* the
/// segmented control whose target/action is wired once in `init` and must stay unreachable —
/// a segmented control with menus but no action opens them on a plain click instead of on a
/// long press, losing single-step navigation without any error. Exposing the pair on the
/// common base would hand out exactly the door that item's design closes.
open class ActionableToolbarItem: ToolbarItem {

    // MARK: - Action host

    /// The object that receives `target` / `action` assignments, and that AppKit sends the
    /// action message from.
    ///
    /// Defaults to ``ToolbarItem/item``. Subclasses hosting a control override this to return
    /// that control, so the pair lands where the click actually originates.
    open var actionHost: any TargetActionProvider { item }

    private var actionTrampoline: ToolbarActionTrampoline?

    // MARK: - Target / action

    /// The action selector sent when someone activates the item.
    ///
    /// Reads `nil` while a closure handler is installed; assigning one drops that handler.
    open var action: Selector? {
        get { actionTrampoline == nil ? actionHost.action : nil }
        set {
            detachActionHandler()
            actionHost.action = newValue
        }
    }

    /// Sets the action selector sent when someone activates the item.
    @discardableResult
    open func action(_ action: Selector?) -> Self {
        self.action = action
        return self
    }

    /// The target that receives the action message.
    ///
    /// Reads `nil` while a closure handler is installed; assigning one drops that handler.
    open var target: AnyObject? {
        get { actionTrampoline == nil ? actionHost.target : nil }
        set {
            detachActionHandler()
            actionHost.target = newValue
        }
    }

    /// Sets the target that receives the action message.
    @discardableResult
    open func target(_ target: AnyObject?) -> Self {
        self.target = target
        return self
    }

    /// Sets the target and the action in one call.
    @discardableResult
    open func target(_ target: AnyObject?, action: Selector?) -> Self {
        detachActionHandler()
        actionHost.target = target
        actionHost.action = action
        return self
    }

    // MARK: - Closure handler

    /// Installs a closure handler, replacing whatever target/action is in place, or removes
    /// the installed one when passed `nil`.
    ///
    /// Subclasses expose a typed `actionBlock` on top of this and keep the typed closure in
    /// their own storage — it cannot live here, because `(Self) -> Void` is not a legal
    /// stored-property type on a non-final class.
    public func installActionHandler(_ handler: (() -> Void)?) {
        guard let handler else {
            detachTrampoline()
            return
        }
        let trampoline = ToolbarActionTrampoline(handler: handler)
        actionTrampoline = trampoline
        actionHost.target = trampoline
        actionHost.action = ToolbarActionTrampoline.invokeSelector
    }

    /// Drops the subclass's stored typed closure, called after a target/action is assigned
    /// directly.
    ///
    /// An override must clear its own storage and nothing else — writing `action` or `target`
    /// from here re-enters this method.
    open func clearActionBlockStorage() {}

    private func detachActionHandler() {
        detachTrampoline()
        clearActionBlockStorage()
    }

    private func detachTrampoline() {
        guard actionTrampoline != nil else { return }
        if actionHost.action == ToolbarActionTrampoline.invokeSelector {
            actionHost.action = nil
        }
        if actionHost.target === actionTrampoline {
            actionHost.target = nil
        }
        actionTrampoline = nil
    }
}

#endif
