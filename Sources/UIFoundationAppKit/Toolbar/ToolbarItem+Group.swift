#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A group of subitems that the system displays as a single toolbar item.
    open class Group: ToolbarItem {

        /// A value indicating how a group item selects its subitems.
        public typealias SelectionMode = NSToolbarItemGroup.SelectionMode

        /// A value that represents how a toolbar displays a group item.
        public typealias ControlRepresentation = NSToolbarItemGroup.ControlRepresentation

        private lazy var _item = GroupNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        private var actionTrampoline: ToolbarActionTrampoline?

        // MARK: - Subitems

        /// The subitems of the group.
        open private(set) var subitems: [ToolbarItem]

        /// Sets the subitems of the group.
        @discardableResult
        open func subitems(_ items: [ToolbarItem]) -> Self {
            subitems = items
            _item.subitems = items.map(\.item)
            return self
        }

        /// Sets the subitems of the group using a builder.
        @discardableResult
        open func subitems(@NSToolbar.Builder _ builder: () -> [ToolbarItem]) -> Self {
            subitems(builder())
        }

        // MARK: - Selection

        /// The selection mode of the group.
        open var selectionMode: SelectionMode {
            get { _item.selectionMode }
            set { _item.selectionMode = newValue }
        }

        /// Sets the selection mode of the group.
        @discardableResult
        open func selectionMode(_ mode: SelectionMode) -> Self {
            _item.selectionMode = mode
            return self
        }

        /// The control representation of the group.
        open var controlRepresentation: ControlRepresentation {
            get { _item.controlRepresentation }
            set { _item.controlRepresentation = newValue }
        }

        /// Sets the control representation of the group.
        @discardableResult
        open func controlRepresentation(_ representation: ControlRepresentation) -> Self {
            _item.controlRepresentation = representation
            return self
        }

        /// The index of the most recently selected subitem, or `nil` if none.
        open var lastSelectedIndex: Int? {
            let index = _item.selectedIndex
            return (index >= 0 && index < subitems.count) ? index : nil
        }

        /// The index values of the selected subitems.
        open var selectedIndexes: [Int] {
            get {
                (0..<subitems.count).filter { _item.isSelected(at: $0) }
            }
            set {
                let upper = subitems.count - 1
                let resolved = Set(newValue.filter { $0 >= 0 && $0 <= upper })
                for index in 0..<subitems.count {
                    _item.setSelected(resolved.contains(index), at: index)
                }
            }
        }

        /// Sets the index values of the selected subitems.
        @discardableResult
        open func selectedIndexes(_ indexes: [Int]) -> Self {
            selectedIndexes = indexes
            return self
        }

        /// Selects the subitem at the specified index by extending the selection.
        @discardableResult
        open func selectItem(at index: Int) -> Self {
            _item.setSelected(true, at: index)
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks the group.
        public var actionBlock: ((NSToolbar.Group) -> Void)? {
            didSet { installAction() }
        }

        /// Sets the handler called when the user clicks the group.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.Group) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        /// The action selector called when the user clicks the group.
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

        public init(_ identifier: NSToolbarItem.Identifier? = nil, selectionMode: SelectionMode = .momentary, items: [ToolbarItem]) {
            self.subitems = items
            super.init(identifier)
            _item.subitems = items.map(\.item)
            _item.selectionMode = selectionMode
        }

        public convenience init(_ identifier: NSToolbarItem.Identifier? = nil, selectionMode: SelectionMode = .momentary, @NSToolbar.Builder _ items: () -> [ToolbarItem]) {
            self.init(identifier, selectionMode: selectionMode, items: items())
        }

        private final class GroupNSToolbarItem: NSToolbarItemGroup {
            weak var owner: NSToolbar.Group?
            init(for owner: NSToolbar.Group) {
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
