#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox
import UIFoundationToolbox

/// A toolbar item used with the builder-style `NSToolbar` API.
///
/// Subclass this type, or use one of the provided subclasses (``NSToolbar/Button``,
/// ``NSToolbar/Item``, ``NSToolbar/Group``, ``NSToolbar/Menu``, ``NSToolbar/PopUpButton``,
/// ``NSToolbar/Search``, ``NSToolbar/SegmentedControl``, ``NSToolbar/View``,
/// ``NSToolbar/TrackingSeparator``).
open class ToolbarItem: NSObject {

    /// The identifier of the toolbar item.
    public let identifier: NSToolbarItem.Identifier

    fileprivate lazy var _rootItem = BasicValidateToolbarItem(for: self)

    /// The underlying `NSToolbarItem` managed by this object. Subclasses override
    /// this to return a custom `NSToolbarItem` subclass.
    open var item: NSToolbarItem { _rootItem }

    // MARK: - Layout flags

    /// A Boolean value indicating whether the item is available on the default toolbar.
    open var isDefault: Bool = true

    /// Sets the Boolean value indicating whether the item is available on the default toolbar.
    @discardableResult
    open func isDefault(_ isDefault: Bool) -> Self {
        self.isDefault = isDefault
        return self
    }

    /// A Boolean value indicating whether the item can be selected.
    open var isSelectable: Bool = false

    /// Sets the Boolean value indicating whether the item can be selected.
    @discardableResult
    open func isSelectable(_ isSelectable: Bool) -> Self {
        self.isSelectable = isSelectable
        return self
    }

    /// A Boolean value indicating whether the item can't be removed or rearranged by the user.
    open var isImmovable: Bool = false

    /// Sets the Boolean value indicating whether the item can't be removed or rearranged by the user.
    @discardableResult
    open func isImmovable(_ isImmovable: Bool) -> Self {
        self.isImmovable = isImmovable
        return self
    }

    /// A Boolean value indicating whether the item displays in the center of the toolbar.
    ///
    /// This value is read once when the parent `NSToolbar` is created. Changing it after
    /// the toolbar exists does not synchronize automatically.
    @available(macOS 13.0, *)
    @AvailableMutating()
    open var isCentered: Bool = false

    /// Sets the Boolean value indicating whether the item displays in the center of the toolbar.
    @available(macOS 13.0, *)
    @discardableResult
    open func isCentered(_ isCentered: Bool) -> Self {
        self.isCentered = isCentered
        return self
    }

    // MARK: - Forwarded NSToolbarItem properties

    /// A Boolean value indicating whether the toolbar automatically validates the item.
    open var autovalidates: Bool {
        get { item.autovalidates }
        set { item.autovalidates = newValue }
    }

    /// Sets the Boolean value indicating whether the toolbar automatically validates the item.
    @discardableResult
    open func autovalidates(_ autovalidates: Bool) -> Self {
        item.autovalidates = autovalidates
        return self
    }

    /// The label that appears for this item in the toolbar.
    open var label: String {
        get { item.label }
        set { item.label = newValue }
    }

    /// Sets the label that appears for this item in the toolbar.
    @discardableResult
    open func label(_ label: String?) -> Self {
        item.label = label ?? ""
        return self
    }

    /// The label that appears when the toolbar item is in the customization palette.
    open var paletteLabel: String {
        get { item.paletteLabel }
        set { item.paletteLabel = newValue }
    }

    /// Sets the label that appears when the toolbar item is in the customization palette.
    @discardableResult
    open func paletteLabel(_ paletteLabel: String?) -> Self {
        item.paletteLabel = paletteLabel ?? ""
        return self
    }

    /// The set of labels that the item might display.
    @available(macOS 13.0, *)
    open var possibleLabels: Set<String> {
        get { item.possibleLabels }
        set { item.possibleLabels = newValue }
    }

    /// Sets the set of labels that the item might display.
    @available(macOS 13.0, *)
    @discardableResult
    open func possibleLabels(_ labels: Set<String>) -> Self {
        item.possibleLabels = labels
        return self
    }

    /// A user-defined tag for the item.
    open var tag: Int {
        get { item.tag }
        set { item.tag = newValue }
    }

    /// Sets the user-defined tag for the item.
    @discardableResult
    open func tag(_ tag: Int) -> Self {
        item.tag = tag
        return self
    }

    /// A Boolean value indicating whether the item is enabled.
    open var isEnabled: Bool {
        get { item.isEnabled }
        set { item.isEnabled = newValue }
    }

    /// Sets the Boolean value indicating whether the item is enabled.
    @discardableResult
    open func isEnabled(_ isEnabled: Bool) -> Self {
        item.isEnabled = isEnabled
        return self
    }

    /// The tooltip displayed when someone hovers over the item.
    open var toolTip: String? {
        get { item.toolTip }
        set { item.toolTip = newValue }
    }

    /// Sets the tooltip displayed when someone hovers over the item.
    @discardableResult
    open func toolTip(_ toolTip: String?) -> Self {
        item.toolTip = toolTip
        return self
    }

    /// The display priority of the item.
    open var visibilityPriority: NSToolbarItem.VisibilityPriority {
        get { item.visibilityPriority }
        set { item.visibilityPriority = newValue }
    }

    /// Sets the display priority of the item.
    @discardableResult
    open func visibilityPriority(_ priority: NSToolbarItem.VisibilityPriority) -> Self {
        item.visibilityPriority = priority
        return self
    }

    /// The menu item to use when the toolbar item is in the overflow menu.
    open var menuFormRepresentation: NSMenuItem? {
        get { item.menuFormRepresentation }
        set { item.menuFormRepresentation = newValue }
    }

    /// Sets the menu item to use when the toolbar item is in the overflow menu.
    @discardableResult
    open func menuFormRepresentation(_ menuItem: NSMenuItem?) -> Self {
        item.menuFormRepresentation = menuItem
        return self
    }

    /// A Boolean value indicating whether the item is currently visible in the toolbar
    /// (and not in the overflow menu). Always `false` on macOS 11 and earlier.
    @available(macOS 12.0, *)
    open var isVisible: Bool { item.isVisible }

    /// The toolbar currently displaying this item, if any.
    public var toolbar: NSToolbar? {
        item.toolbar
    }

    // MARK: - Validation

    /// Override to perform custom validation for this item.
    @objc open func validate() {}

    // MARK: - Init

    init(_ identifier: NSToolbarItem.Identifier? = nil) {
        self.identifier = identifier ?? NSToolbar.box.automaticIdentifier(for: "ToolbarItem")
        super.init()
    }
}

/// The default `NSToolbarItem` subclass that forwards `validate()` to the owning ``ToolbarItem``.
class BasicValidateToolbarItem: NSToolbarItem {
    weak var item: ToolbarItem?

    init(for item: ToolbarItem) {
        super.init(itemIdentifier: item.identifier)
        self.item = item
    }

    override func validate() {
        super.validate()
        item?.validate()
    }
}

extension Sequence where Element == ToolbarItem {
    /// The identifiers of the toolbar items.
    public var identifiers: [NSToolbarItem.Identifier] {
        map(\.identifier)
    }

    /// The toolbar item with the specified identifier.
    public subscript(id id: NSToolbarItem.Identifier) -> Element? {
        first(where: { $0.identifier == id })
    }
}

/// An `NSObject` shim that forwards a target/action invocation to a Swift closure.
///
/// Used by ``ToolbarItem`` subclasses to expose closure-based `actionBlock` APIs
/// without depending on KVO or method swizzling.
final class ToolbarActionTrampoline: NSObject {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func invoke(_ sender: Any?) {
        handler()
    }

    static let invokeSelector: Selector = #selector(ToolbarActionTrampoline.invoke(_:))
}

#endif
