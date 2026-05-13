#if FilterUI

import AppKit
import FuzzySearch

extension NSMenuItem: @retroactive FuzzySearchable {
    public var fuzzyStringToMatch: String { title }
}

/// A filtering menu.
///
/// If there is only one filter result when the enter key is pressed, that item will be selected and the menu will
/// close.
public class FilteringMenu_WithoutPrivateAPIUsage: NSMenu, NSMenuDelegate, NSSearchFieldDelegate {
  private static var activeMenu: FilteringMenu_WithoutPrivateAPIUsage?
  private static var eventMonitor: Any?

  public private(set) var wrappedDelegate: NSMenuDelegate? // TODO: make private and only expose through `delegate`

  private var initiallyShowsFilterField = true
  
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
  
  /// Initializes and returns a filtering menu having the specified title and with autoenabling of menu items turned on.
  ///
  /// FilteringMenu needs `-[NSMenu highlightItem:]` in order to work correctly.
  /// The existence of this selector is checked on initialization, and if it doesn’t exist, the menu will fall back to
  /// the standard type-select behavior.
  public override init(title: String) {
    super.init(title: title)
    super.delegate = self
    
    guard responds(to: Selector(("highlightItem:"))) else { return }
    
    setUpFilterField(in: self)
    
    // TODO: move somewhere else
    if Self.eventMonitor == nil {
      Self.eventMonitor = NSEvent.addCarbonMonitorForKeyEvents { event in
        guard !ignoredKeyCodes.contains(event.keyCode), let menu = Self.activeMenu else { return false }
        self.setUpFilterField(in: menu)
        self.highlightFilteringItem(in: menu, with: event)
        return false
      }
    }
  }

//  deinit {
//    eventMonitor.map(NSEvent.removeCarbonMonitor)
//  }
  
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  /// Creates a filter field and container view, and inserts it as the first item of the menu unless it already exists.
  ///
  /// This method is public in case you need to use `object_setClass()`.
  public func setUpFilterField(in menu: NSMenu) {
    guard !(menu.items.first is FilteringMenuItem) else { return }

    let item = FilteringMenuItem()
    item.filteringView.filterField.delegate = self
    item.isHidden = !initiallyShowsFilterField
    menu.insertItem(item, at: 0)
    // menu.update()
  }
  
  private func performFiltering(with string: String, in menu: NSMenu) {
    let items = items.dropFirst()
    
    for item in items {
      item.isHidden = !string.isEmpty
    }
    
    guard !string.isEmpty else { return }
    
    for (item, _) in items.fuzzyMatch(string) {
      item.isHidden = false
    }

    // update()
  }
  
  private func highlightFilteringItem(in menu: FilteringMenu_WithoutPrivateAPIUsage, with event: NSEvent) {
    guard let filteringItem = menu.items.first as? FilteringMenuItem else { return }
    guard !(filteringItem.view?.window?.firstResponder is NSText) else { return }
    
    filteringItem.isHidden = false
    menu.highlightItem(filteringItem)

//    //DispatchQueue.main.async {
      filteringItem.filteringView.filterField.becomeFirstResponder()
//    //}

    guard let editor = filteringItem.filteringView.filterField.currentEditor() else { return }
    editor.selectedRange = NSMakeRange(0, editor.string.count)
  }

//  public override func itemChanged(_ item: NSMenuItem) {
//    guard let filteringItem = item as? FilteringMenuItem, !item.isHidden else { return }
////    DispatchQueue.main.async {
//      Self.activeMenu?.highlightItem(filteringItem)
//      filteringItem.filteringView.filterField.becomeFirstResponder()
////    }
//  }

//  - (id)_handleCarbonEvents:(const struct EventTypeSpec { unsigned int x1; unsigned int x2; }*)arg1 count:(unsigned long long)arg2 handler:(id)arg3;

  private func handleCarbonEvents() {
//    perform(T##aSelector: Selector!##Selector!, with: <#T##Any!#>, with: <#T##Any!#>)
    // objc_msgSend(self, Selector(("_handleCarbonEvents:count:handler:")))
  }
  
  private func highlightItem(_ item: NSMenuItem) {
    // TODO: try `CGEvent(keyboardEventSource:virtualKey:keyDown:)` instead of relying on private API? 👹
    perform(Selector(("highlightItem:")), with: item)
  }
  
  // MARK: - NSMenuDelegate
  
  public func menuNeedsUpdate(_ menu: NSMenu) {
    wrappedDelegate?.menuNeedsUpdate?(menu)
  }
  
  public func numberOfItems(in menu: NSMenu) -> Int {
    return wrappedDelegate?.numberOfItems?(in: menu) ?? 0
  }
  
  public func menu(_ menu: NSMenu, update item: NSMenuItem, at index: Int, shouldCancel: Bool) -> Bool {
    return wrappedDelegate?.menu?(menu, update: item, at: index, shouldCancel: shouldCancel) ?? false
  }
  
  public func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>, action: UnsafeMutablePointer<Selector?>) -> Bool {
    return wrappedDelegate?.menuHasKeyEquivalent?(menu, for: event, target: target, action: action) ?? false
  }
  
  public func menuWillOpen(_ menu: NSMenu) {
    wrappedDelegate?.menuWillOpen?(menu)
    Self.activeMenu = menu as? FilteringMenu_WithoutPrivateAPIUsage
//    guard let fiteringItemView = items.first?.view as? FilteringMenuItemView else { return }
//    fiteringItemView.frame.size.height = 0
    // update()
    guard let filteringItem = menu.items.first as? FilteringMenuItem else { return }
    filteringItem.isHidden = !initiallyShowsFilterField
  }
  
  public func menuDidClose(_ menu: NSMenu) {
    wrappedDelegate?.menuDidClose?(menu)

    guard let filteringItem = menu.items.first as? FilteringMenuItem else { return }
    filteringItem.isHidden = true
    filteringItem.filteringView.filterField.stringValue = ""
    performFiltering(with: "", in: menu)
  }
  
  public func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
    Self.activeMenu = menu as? FilteringMenu_WithoutPrivateAPIUsage
    wrappedDelegate?.menu?(menu, willHighlight: item)
  }
  
  public func confinementRect(for menu: NSMenu, on screen: NSScreen?) -> NSRect {
    return wrappedDelegate?.confinementRect?(for: menu, on: screen) ?? .zero
  }
  
  // MARK: - NSControlTextEditingDelegate
  
  public func controlTextDidChange(_ notification: Notification) {
    guard
      let field = notification.object as? FilterSearchField,
      let menu = field.enclosingMenuItem?.menu
    else { return }
    
    // RunLoop.current.perform(inModes: [.eventTracking]) {
      self.performFiltering(with: field.stringValue, in: menu)
    // }
  }
  
  public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
    switch commandSelector {
    case #selector(NSResponder.moveDown(_:)):
      let visibleItems = items.dropFirst().filter { !$0.isHidden }
      guard visibleItems.count > 0 else { return true }
      highlightItem(visibleItems[0])
      return true

    case #selector(NSResponder.insertNewline(_:)):
      let visibleItems = items.dropFirst().filter { !$0.isHidden }
      
      guard
        visibleItems.count == 1,
        let returnKeyEvent = CGEvent(keyboardEventSource: nil, virtualKey: .return, keyDown: true)
      else { return false }
      
      highlightItem(visibleItems[0])
      NSEvent(cgEvent: returnKeyEvent).map(NSApp.sendEvent)
      
      return true

    default:
      return false
    }
  }
}

fileprivate extension CGKeyCode {
  //static let `return`: Self = 36
  static let downArrow: Self = 125
  static let upArrow: Self = 126
}

fileprivate class FilteringMenuItem: NSMenuItem {
  let filteringView = FilteringMenuItemView()

  init() {
    super.init(title: "", action: nil, keyEquivalent: "")
    view = filteringView
  }

  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

//  override var isHidden: Bool {
//    didSet { if isHidden { view = nil } else { view = filteringView } }
//  }

  override var isHidden: Bool {
    didSet { view?.frame.size.height = isHidden ? 0 : 27 }
  }
}

fileprivate class FilteringMenuItemView: NSView {
  static let horizontalPadding: CGFloat = 20

  var filterField: FilterSearchField!
  var menuItem: NSMenuItem!
  
  convenience init() {
    self.init(frame: NSMakeRect(0, 0, 120, 27))
  }
  
  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)

    autoresizingMask = .width

    filterField = FilterSearchField(frame: frameRect.insetBy(dx: Self.horizontalPadding, dy: 4))
    filterField.autoresizingMask = .width
    addSubview(filterField)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func draw(_ dirtyRect: NSRect) {
    super.draw(dirtyRect)
  }
  
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
  }
}

fileprivate let ignoredKeyCodes: [UInt16] = [
  51 , // Backspace
  115, // Home
  117, // Delete
  116, // PgUp
  119, // End
  121, // PgDn
  123, // Left
  124, // Right
  125, // Down
  126, // Up
  49 , // Space
  36 , // Return
  53 , // Esc
  71 , // Clear
  76 , // Insert
  48 , // Tab
  114, // Help
  122, // F1
  120, // F2
  99 , // F3
  118, // F4
  96 , // F5
  97 , // F6
  98 , // F7
  100, // F8
  101, // F9
  109, // F10
  103, // F11
  111, // F12
  105, // F13
  107, // F14
  113, // F15
  106, // F16
  64 , // F17
  79 , // F18
  80 , // F19
]

fileprivate extension NSMenu {
  static let defaultFont = NSMenu().font
  var recursiveFont: NSFont { font == Self.defaultFont ? supermenu?.recursiveFont ?? font : font }
}

#endif
