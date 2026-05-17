#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A toolbar item that hosts an arbitrary `NSView`.
    open class View: ToolbarItem {

        private lazy var _item = ViewNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        private var actionTrampoline: ToolbarActionTrampoline?

        /// The view hosted by the toolbar item.
        open var view: NSView? {
            get { _item.view }
            set { _item.view = newValue }
        }

        /// Sets the view hosted by the toolbar item.
        @discardableResult
        open func view(_ view: NSView?) -> Self {
            _item.view = view
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks the item.
        public var actionBlock: ((NSToolbar.View) -> Void)? {
            didSet { installAction() }
        }

        /// Sets the handler called when the user clicks the item.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.View) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        /// The action selector called when the user clicks the item.
        public var action: Selector? {
            get { actionTrampoline == nil ? _item.action : nil }
            set {
                actionBlock = nil
                _item.action = newValue
            }
        }

        /// The target that receives the action message.
        public var target: AnyObject? {
            get { actionTrampoline == nil ? _item.target : nil }
            set {
                actionBlock = nil
                _item.target = newValue
            }
        }

        private func installAction() {
            if let actionBlock = actionBlock {
                let trampoline = ToolbarActionTrampoline { [weak self] in
                    guard let self = self else { return }
                    actionBlock(self)
                }
                actionTrampoline = trampoline
                _item.target = trampoline
                _item.action = ToolbarActionTrampoline.invokeSelector
            } else {
                if _item.action == ToolbarActionTrampoline.invokeSelector {
                    _item.action = nil
                }
                if _item.target === actionTrampoline {
                    _item.target = nil
                }
                actionTrampoline = nil
            }
        }

        // MARK: - Init

        public init(_ identifier: NSToolbarItem.Identifier? = nil, view: NSView) {
            super.init(identifier)
            _item.view = view
        }

        private final class ViewNSToolbarItem: NSToolbarItem {
            weak var owner: NSToolbar.View?
            init(for owner: NSToolbar.View) {
                super.init(itemIdentifier: owner.identifier)
                self.owner = owner
            }
            override func validate() {
                super.validate()
                owner?.validate()
            }
        }
    }
}

#endif
