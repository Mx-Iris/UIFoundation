#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A toolbar item that hosts an `NSSegmentedControl`.
    open class SegmentedControl: ToolbarItem {

        /// The selection mode of the segmented control.
        public enum SelectionMode: UInt, Hashable, Codable {
            /// Only one segment can be selected at a time.
            case selectOne = 0
            /// One or more segments can be selected at a time.
            case selectAny = 1
            /// A segment is selected only while the mouse is pressed within it.
            case momentary = 2
        }

        private lazy var _item = SegmentedNSToolbarItemGroup(for: self)
        public override var item: NSToolbarItem { _item }

        /// The segmented control hosted by the toolbar item.
        public let segmentedControl: NSSegmentedControl

        private var actionTrampoline: ToolbarActionTrampoline?

        /// The selection mode of the segmented control.
        open var selectionMode: SelectionMode {
            get { SelectionMode(rawValue: segmentedControl.trackingMode.rawValue) ?? .selectOne }
            set { segmentedControl.trackingMode = NSSegmentedControl.SwitchTracking(rawValue: newValue.rawValue) ?? .selectOne }
        }

        /// Sets the selection mode of the segmented control.
        @discardableResult
        open func selectionMode(_ mode: SelectionMode) -> Self {
            selectionMode = mode
            return self
        }

        /// A Boolean value indicating whether the segmented control uses the rounded
        /// bezel style.
        open var isBezeled: Bool {
            get { segmentedControl.segmentStyle != .roundRect }
            set { segmentedControl.segmentStyle = newValue ? .roundRect : .automatic }
        }

        /// Sets whether the segmented control is bezeled.
        @discardableResult
        open func isBezeled(_ isBezeled: Bool) -> Self {
            self.isBezeled = isBezeled
            return self
        }

        // MARK: - Action

        /// The handler called when the user clicks a segment.
        public var actionBlock: ((NSToolbar.SegmentedControl) -> Void)? {
            didSet { installAction() }
        }

        /// Sets the handler called when the user clicks a segment.
        @discardableResult
        public func onAction(_ action: ((NSToolbar.SegmentedControl) -> Void)?) -> Self {
            actionBlock = action
            return self
        }

        /// The action selector called when the user clicks a segment.
        public var action: Selector? {
            get { actionTrampoline == nil ? segmentedControl.action : nil }
            set {
                actionBlock = nil
                segmentedControl.action = newValue
            }
        }

        /// The target that receives the action message.
        public var target: AnyObject? {
            get { actionTrampoline == nil ? segmentedControl.target : nil }
            set {
                actionBlock = nil
                segmentedControl.target = newValue
            }
        }

        private func installAction() {
            if let actionBlock = actionBlock {
                let trampoline = ToolbarActionTrampoline { [weak self] in
                    guard let self = self else { return }
                    actionBlock(self)
                }
                actionTrampoline = trampoline
                segmentedControl.target = trampoline
                segmentedControl.action = ToolbarActionTrampoline.invokeSelector
            } else {
                if segmentedControl.action == ToolbarActionTrampoline.invokeSelector {
                    segmentedControl.action = nil
                }
                if segmentedControl.target === actionTrampoline {
                    segmentedControl.target = nil
                }
                actionTrampoline = nil
            }
        }

        // MARK: - Init

        public init(_ identifier: NSToolbarItem.Identifier? = nil, segmentedControl: NSSegmentedControl) {
            self.segmentedControl = segmentedControl
            super.init(identifier)
            commonInit()
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, selectionMode: SelectionMode = .selectOne, labels: [String], action: ((NSToolbar.SegmentedControl) -> Void)? = nil) {
            self.segmentedControl = NSSegmentedControl(labels: labels, trackingMode: NSSegmentedControl.SwitchTracking(rawValue: selectionMode.rawValue) ?? .selectOne, target: nil, action: nil)
            super.init(identifier)
            commonInit()
            self.actionBlock = action
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, selectionMode: SelectionMode = .selectOne, images: [NSImage], action: ((NSToolbar.SegmentedControl) -> Void)? = nil) {
            self.segmentedControl = NSSegmentedControl(images: images, trackingMode: NSSegmentedControl.SwitchTracking(rawValue: selectionMode.rawValue) ?? .selectOne, target: nil, action: nil)
            super.init(identifier)
            commonInit()
            self.actionBlock = action
        }

        private func commonInit() {
            segmentedControl.translatesAutoresizingMaskIntoConstraints = false
            segmentedControl.setContentHuggingPriority(.defaultHigh, for: .horizontal)
            segmentedControl.segmentDistribution = .fillEqually
            _item.view = segmentedControl
        }

        private final class SegmentedNSToolbarItemGroup: NSToolbarItemGroup {
            weak var owner: NSToolbar.SegmentedControl?
            init(for owner: NSToolbar.SegmentedControl) {
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
