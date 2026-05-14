#if FilterUI

import AppKit
import Carbon
import UIFoundationAppKit
import UIFoundationAppleInternalObjC
private import UIFoundationCarbonInternal
import ObjectiveC

// TODO: support filtering with custom fonts (e.g. monospaced)
// TODO: add customizable inset for filter field

/// A filtering menu.
///
/// If there is only one filter result when the enter key is pressed, that item will be selected and the menu will close.
@objcMembers open class FilteringMenu: NSMenu, NSMenuDelegate, NSSearchFieldDelegate, FilteringMenuFilterViewDelegate {
    static let filterFieldItemTag = 1000
    static var attributedTitleKey = UInt8(0)

    open private(set) var wrappedDelegate: NSMenuDelegate? // TODO: make private and only expose through `delegate`

    open var initiallyShowsFilterField = false
    var carbonMenu: Unmanaged<Menu>?

    private var delegateRespondsToMenuHasKeyEquivalentForEventTargetAction = false
    private var delegateRespondsToMenuUpdateItemAtIndexShouldCancel = false
    private var delegateRespondsToConfinementRectForMenuOnScreen = false
    private var delegateRespondsToMenuWillHighlightItem = false
    private var delegateRespondsToMenuWillOpen = false
    private var delegateRespondsToMenuDidClose = false
    private var delegateRespondsToNumberOfItemsInMenu = false
    private var delegateRespondsToMenuNeedsUpdate = false

    // TODO: fix weird `menuNeedsUpdate` “unrecognized selector sent to instance” bug
    public override var delegate: NSMenuDelegate? {
        get { super.delegate }
        set {
            wrappedDelegate = newValue
            delegateRespondsToMenuHasKeyEquivalentForEventTargetAction = newValue?.responds(to: #selector(NSMenuDelegate.menuHasKeyEquivalent(_:for:target:action:))) ?? false
            delegateRespondsToMenuUpdateItemAtIndexShouldCancel = newValue?.responds(to: #selector(NSMenuDelegate.menu(_:update:at:shouldCancel:))) ?? false
            delegateRespondsToConfinementRectForMenuOnScreen = newValue?.responds(to: #selector(NSMenuDelegate.confinementRect(for:on:))) ?? false
            delegateRespondsToMenuWillHighlightItem = newValue?.responds(to: #selector(NSMenuDelegate.menu(_:willHighlight:))) ?? false
            delegateRespondsToMenuWillOpen = newValue?.responds(to: #selector(NSMenuDelegate.menuWillOpen(_:))) ?? false
            delegateRespondsToMenuDidClose = newValue?.responds(to: #selector(NSMenuDelegate.menuDidClose(_:))) ?? false
            delegateRespondsToNumberOfItemsInMenu = newValue?.responds(to: #selector(NSMenuDelegate.numberOfItems(in:))) ?? false
            delegateRespondsToMenuNeedsUpdate = newValue?.responds(to: #selector(NSMenuDelegate.menuNeedsUpdate(_:))) ?? false
        }
    }

    public static var invertedControlAndSpaceCharacterSet = {
        var set = NSMutableCharacterSet.controlCharacters
        set.insert(charactersIn: " ")
        return set.inverted
    }()

    open var singleVisibleMenuItem: NSMenuItem? {
        let visibleItems = items.filter { $0.tag != Self.filterFieldItemTag && !$0.isHidden }
        return visibleItems.count == 1 ? visibleItems.first! : nil
    }

    /// Initializes and returns a filtering menu.
    ///
    /// FilteringMenu needs `-[NSMenu highlightItem:]` and `-[NSMenu _handleCarbonEvents:count:handler:]` in order to work.
    /// If `NSMenu` doesn’t repsond to these private selectors the menu will fall back to the standard type-select behavior.
    public override init(title: String) {
        super.init(title: title)
        super.delegate = self

        guard responds(to: #selector(highlight(_:))) else { return }
        guard responds(to: #selector(_handleCarbonEvents(_:count:handler:))) else { return }

        let eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuOpening)),
            EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuClosed)),
        ]

        _handleCarbonEvents(eventTypes, count: 2) { menu, handler, event in
            guard let menu = menu as? Self else { return noErr }

            if GetEventClass(event) == kEventClassMenu {
                if GetEventKind(event) == kEventMenuOpening {
                    GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeMenuRef),
                        nil,
                        MemoryLayout.size(ofValue: menu.carbonMenu),
                        nil,
                        &menu.carbonMenu
                    )
                } else if GetEventKind(event) == kEventMenuClosed {
                    menu.carbonMenu = nil
                }
            }

            return noErr
        }
    }

    @available(*, unavailable)
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func makeFilterFieldItem() -> NSMenuItem {
        let view = FilteringMenuFilterView()
        view.delegate = self
        view.filterField.delegate = self

        let item = NSMenuItem()
        item.tag = Self.filterFieldItemTag
        item.view = view
        view.menuItem = item
        return item
    }

    open func setUpFilterField(in menu: NSMenu, with string: String) {
        var targetMenu = menu
        repeat {
            if let submenu = targetMenu.highlightedItem?.submenu {
                if let carbonMenu = (submenu as? Self)?.carbonMenu?.takeUnretainedValue() {
                    var data = MenuTrackingData()
                    if GetMenuTrackingData(carbonMenu, &data) == noErr {
                        targetMenu = submenu
                    }
                }
            }
        } while targetMenu.highlightedItem?.hasSubmenu == true && targetMenu != menu

        var filterFieldItem = targetMenu.item(withTag: Self.filterFieldItemTag)
        if filterFieldItem == nil {
            filterFieldItem = (targetMenu as! Self).makeFilterFieldItem()
            if let view = filterFieldItem!.view as? FilteringMenuFilterView {
                view.setFrameSize(NSMakeSize(max(size.width, 182), view.frame.height))
                view.initialStringValue = string
                filterFieldItem!.title = string
                targetMenu.insertItem(filterFieldItem!, at: 0)
                highlightFilterFieldItem(in: targetMenu)
                performFiltering(with: string, in: targetMenu)
            }
        }

        if isFilterFieldScrolledOutOfView(in: targetMenu) {
            highlightFilterFieldItem(in: targetMenu)
            performFiltering(with: string, in: targetMenu)
        }
    }

    open func highlightFilterFieldItem(in menu: NSMenu) {
        menu.highlight(menu.item(withTag: Self.filterFieldItemTag))
    }

    open func isFilterFieldScrolledOutOfView(in menu: NSMenu) -> Bool {
        guard let menu = menu as? FilteringMenu, let menu = menu.carbonMenu?.takeUnretainedValue() else { return false }

        var data = MenuTrackingData()
        guard GetMenuTrackingData(menu, &data) == noErr else { return false }
        return data.virtualMenuTop < data.itemRect.top
    }

    open func performFiltering(with string: String, in menu: NSMenu) {
        guard let menu = menu as? FilteringMenu else { return }

        // var contentView: Unmanaged<HIView>
        let contentView = UnsafeMutablePointer<Unmanaged<HIView>>.allocate(capacity: 1)
        if let carbonMenu = menu.carbonMenu {
            HIMenuGetContentView(carbonMenu.takeUnretainedValue(), ThemeMenuType(kThemeMenuItemHierarchical), contentView)
            HIViewSetDrawingEnabled(contentView.pointee.takeUnretainedValue(), false)
        }

        let items = menu.items.filter { $0.tag != Self.filterFieldItemTag }

        for item in items {
            item.isHidden = !string.isEmpty

            if let attributedTitle = objc_getAssociatedObject(item, &Self.attributedTitleKey) as? NSAttributedString {
                item.attributedTitle = attributedTitle
                objc_setAssociatedObject(item, &Self.attributedTitleKey, nil, .OBJC_ASSOCIATION_RETAIN)
            } else if objc_getAssociatedObject(item, &Self.attributedTitleKey) is NSNull {
                item.attributedTitle = nil
                objc_setAssociatedObject(item, &Self.attributedTitleKey, nil, .OBJC_ASSOCIATION_RETAIN)
            }
        }

        for (item, result) in items.fuzzyMatch(string) {
            item.isHidden = false

            // TODO: consider turning secondaryLabelColor into tertiaryLabelColor for existing attributed titles while filtering

            let attributedTitle = NSMutableAttributedString(string: item.title, attributes: [
                .foregroundColor: NSColor.secondaryLabelColor, // .withAlphaComponent(0.9)
            ])

            for range in result.parts {
                attributedTitle.addAttributes(
                    [.foregroundColor: NSColor.textColor, .font: NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)],
                    range: range
                )
            }

            objc_setAssociatedObject(item, &Self.attributedTitleKey, item.attributedTitle ?? NSNull(), .OBJC_ASSOCIATION_RETAIN)
            item.attributedTitle = attributedTitle
        }

        HIViewSetDrawingEnabled(contentView.pointee.takeUnretainedValue(), true)
        HIViewSetNeedsDisplay(contentView.pointee.takeUnretainedValue(), true)
    }

    open func filterFieldShouldTakeFocus(_ filterField: FilterSearchField) -> Bool {
        let firstResponder = filterField.window?.firstResponder
        let textView = firstResponder as? NSTextView
        if firstResponder == filterField || (textView?.isFieldEditor == true && textView?.delegate as? Self? == self) {
            return false
        } else {
            filterField.window?.makeFirstResponder(filterField)
            return true
        }

//    let textView = filterField.window?.firstResponder as? NSTextView
//    if textView?.isFieldEditor == false || textView?.delegate as? FilteringMenu != self {
//      filterField.window?.makeFirstResponder(filterField)
//    }
//    return true
    }

    // MARK: - Menu Delegate

    open func menuNeedsUpdate(_ menu: NSMenu) {
        wrappedDelegate?.menuNeedsUpdate?(menu)
    }

    open func numberOfItems(in menu: NSMenu) -> Int {
        return wrappedDelegate?.numberOfItems?(in: menu) ?? 0
    }

    open func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
        return wrappedDelegate?.menu?(menu, update: item, at: index, shouldCancel: shouldCancel) ?? false
    }

    open func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>, action: UnsafeMutablePointer<Selector?>) -> Bool {
        return wrappedDelegate?.menuHasKeyEquivalent?(menu, for: event, target: target, action: action) ?? false
    }

    open func menuWillOpen(_ menu: NSMenu) {
        wrappedDelegate?.menuWillOpen?(menu)

        let filterFieldItem = menu.item(withTag: Self.filterFieldItemTag)
        if initiallyShowsFilterField {
            if filterFieldItem == nil {
                setUpFilterField(in: menu, with: "")
            }
        } else if let filterFieldItem {
            menu.removeItem(filterFieldItem)
        }

        performFiltering(with: "", in: menu)

        if menu.supermenu == nil || !(menu.supermenu is Self) {
            let eventTypes = [
                EventTypeSpec(eventClass: OSType(kEventClassMenu), eventKind: UInt32(kEventMenuMatchKey)),
                EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventRawKeyDown)),
            ]

            menu._handleCarbonEvents(eventTypes, count: 2) { [self] menu, handler, event in
                if GetEventClass(event) == kEventClassMenu, GetEventKind(event) == kEventMenuMatchKey {
                    var textEvent: EventRef!
                    GetEventParameter(event, EventParamName(kEventParamEventRef), typeEventRef, nil, MemoryLayout.size(ofValue: textEvent), nil, &textEvent)

                    var actualSize: size_t = -1
                    GetEventParameter(textEvent, EventParamName(kEventParamKeyUnicodes), typeUnicodeText, nil, 0, &actualSize, nil)
                    let text = UnsafeMutablePointer<UniChar>.allocate(capacity: actualSize)
                    GetEventParameter(textEvent, EventParamName(kEventParamKeyUnicodes), typeUnicodeText, nil, actualSize, nil, text)

                    var modifiers: UInt32 = 0
                    GetEventParameter(textEvent, EventParamName(kEventParamKeyModifiers), typeUInt32, nil, 4, nil, &modifiers)
                    let commandKeyDown = modifiers & UInt32(cmdKey) == UInt32(cmdKey)

                    let string = NSString(characters: text, length: actualSize >> 1) as String
                    text.deallocate()

                    if string.rangeOfCharacter(from: Self.invertedControlAndSpaceCharacterSet) != nil {
                        if !commandKeyDown {
                            setUpFilterField(in: menu, with: string)
                            return OSStatus(menuItemNotFoundErr)
                        }
                    }
                }

                return OSStatus(eventNotHandledErr)
            }
        }
    }

    open func menuDidClose(_ menu: NSMenu) {
        if !initiallyShowsFilterField {
            item(withTag: Self.filterFieldItemTag)?.view = nil
        }

        wrappedDelegate?.menuDidClose?(menu)
    }

    open func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        wrappedDelegate?.menu?(menu, willHighlight: item)
    }

    open func confinementRect(for menu: NSMenu, on screen: NSScreen?) -> NSRect {
        return wrappedDelegate?.confinementRect?(for: menu, on: screen) ?? .zero
    }

    // MARK: - Control Text Editing Delegate

    open func controlTextDidChange(_ notification: Notification) {
        guard
            let field = notification.object as? FilterSearchField,
            let view = field.superview as? FilteringMenuFilterView,
            let menu = view.menuItem.menu
        else { return }

        performFiltering(with: field.stringValue, in: menu)
    }

    open func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            control.nextResponder?.keyDown(with: NSApp.currentEvent!)
            return true

        case #selector(NSResponder.moveLeft(_:)):
            if textView.string.count == 0 {
                control.nextResponder?.keyDown(with: NSApp.currentEvent!)
                return true
            } else {
                return false
            }

        case #selector(NSResponder.insertNewline(_:)):
            if let item = singleVisibleMenuItem {
                highlight(item)
                control.nextResponder?.keyDown(with: NSApp.currentEvent!)
                return true
            } else {
                return false
            }

        default:
            return false
        }
    }

    // MARK: - Filter View Delegate

    func filterView(_ filterView: FilteringMenuFilterView, makeFilterFieldKey filterField: FilterSearchField) {
        guard let window = filterView.window else { fatalError() }

        if !window.isKeyWindow {
            window.makeKey()
            window.acceptsMouseMovedEvents = true
        }

        if filterFieldShouldTakeFocus(filterField) {
            highlightFilterFieldItem(in: filterView.menuItem.menu!)
            // window.makeFirstResponder(nil)
            window.makeFirstResponder(filterField)
        }

        performFiltering(with: filterField.stringValue, in: filterView.menuItem.menu!)
    }
}

#endif
