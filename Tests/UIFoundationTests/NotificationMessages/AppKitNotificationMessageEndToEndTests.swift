#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import FoundationToolbox
import UIFoundationToolbox

/// AppKit posting its own notifications, observed through the backport, on every macOS this package
/// supports -- the conversion has to accept the value types AppKit really posts, not only the fixtures'.
///
/// Message types are spelled out rather than written as shorthand: once the tests' deployment target
/// reaches macOS 27, the shorthand resolves to AppKit's own messages, and these tests would quietly test
/// those instead.
@Suite("AppKit notification messages, posted by AppKit")
@MainActor
struct AppKitNotificationMessageEndToEndTests {
    private let center = NotificationCenter.default

    @Test("A menu reports the index of each item added, changed and removed")
    func menuItems() {
        let menu = NSMenu()
        var added: [Int] = []
        var changed: [Int] = []
        var removed: [Int] = []
        let tokens = [
            center.addObserver(of: menu, for: NSMenu.Backport.DidAddItemMessage.self) { added.append($0.itemIndex) },
            center.addObserver(of: menu, for: NSMenu.Backport.DidChangeItemMessage.self) { changed.append($0.itemIndex) },
            center.addObserver(of: menu, for: NSMenu.Backport.DidRemoveItemMessage.self) { removed.append($0.itemIndex) },
        ]

        menu.addItem(withTitle: "First", action: nil, keyEquivalent: "")
        menu.addItem(withTitle: "Second", action: nil, keyEquivalent: "")
        menu.items[1].title = "Renamed"
        menu.removeItem(at: 0)

        withExtendedLifetime(tokens) {}
        #expect(added == [0, 1])
        #expect(changed == [1])
        #expect(removed == [0])
    }

    @Test("A view reports frame and bounds changes")
    func viewGeometry() {
        let view = NSView(frame: .zero)
        view.postsFrameChangedNotifications = true
        view.postsBoundsChangedNotifications = true
        var frameChanges: [NSView] = []
        var boundsChanges: [NSView] = []
        let tokens = [
            center.addObserver(of: view, for: NSView.Backport.FrameDidChangeMessage.self) { frameChanges.append($0.view) },
            center.addObserver(of: view, for: NSView.Backport.BoundsDidChangeMessage.self) { boundsChanges.append($0.view) },
        ]

        view.setFrameOrigin(NSPoint(x: 10, y: 10))
        view.setBoundsOrigin(NSPoint(x: 5, y: 5))

        withExtendedLifetime(tokens) {}
        #expect(frameChanges.count == 1)
        #expect(frameChanges.allSatisfy { $0 === view })
        #expect(boundsChanges.count == 1)
        #expect(boundsChanges.allSatisfy { $0 === view })
    }

    @Test("A window reports resizing, moving and closing")
    func windowLifecycle() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        var events: [String] = []
        let tokens = [
            center.addObserver(of: window, for: NSWindow.Backport.DidResizeMessage.self) { events.append("resize \($0.window === window)") },
            center.addObserver(of: window, for: NSWindow.Backport.DidMoveMessage.self) { events.append("move \($0.window === window)") },
            center.addObserver(of: window, for: NSWindow.Backport.WillCloseMessage.self) { events.append("close \($0.window === window)") },
        ]

        // Measured on a window that was never ordered in: setFrame(_:display:) posts the resize but not the
        // move, setFrameOrigin(_:) posts the move.
        window.setFrame(NSRect(x: 0, y: 0, width: 300, height: 200), display: false)
        window.setFrameOrigin(NSPoint(x: 40, y: 40))
        window.close()

        withExtendedLifetime(tokens) {}
        #expect(events.contains("resize true"))
        #expect(events.contains("move true"))
        #expect(events.last == "close true")
    }

    @Test("A table view reports the columns it moves and resizes")
    func tableColumns() {
        let tableView = NSTableView()
        let first = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("first"))
        first.width = 100
        let second = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("second"))
        tableView.addTableColumn(first)
        tableView.addTableColumn(second)
        var moves: [[Int]] = []
        var resizes: [(NSTableColumn, CGFloat)] = []
        let tokens = [
            center.addObserver(of: tableView, for: NSTableView.Backport.ColumnDidMoveMessage.self) { moves.append([$0.oldColumn, $0.newColumn]) },
            center.addObserver(of: tableView, for: NSTableView.Backport.ColumnDidResizeMessage.self) { resizes.append(($0.tableColumn, $0.oldWidth)) },
        ]

        tableView.moveColumn(0, toColumn: 1)
        first.width = 150

        withExtendedLifetime(tokens) {}
        #expect(moves == [[0, 1]])
        #expect(resizes.count == 1)
        #expect(resizes.first?.0 === first)
        #expect(resizes.first?.1 == 100)
    }

    @Test("An outline view reports the item it expands and collapses")
    func outlineItems() {
        let dataSource = SingleFolderOutlineDataSource()
        let outlineView = NSOutlineView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("tree"))
        outlineView.addTableColumn(column)
        outlineView.outlineTableColumn = column
        outlineView.dataSource = dataSource
        outlineView.reloadData()
        var events: [String] = []
        func record(_ event: String, _ item: Any) {
            events.append("\(event) \((item as AnyObject) === dataSource.folder)")
        }
        let tokens = [
            center.addObserver(of: outlineView, for: NSOutlineView.Backport.ItemWillExpandMessage.self) { record("willExpand", $0.item) },
            center.addObserver(of: outlineView, for: NSOutlineView.Backport.ItemDidExpandMessage.self) { record("didExpand", $0.item) },
            center.addObserver(of: outlineView, for: NSOutlineView.Backport.ItemWillCollapseMessage.self) { record("willCollapse", $0.item) },
            center.addObserver(of: outlineView, for: NSOutlineView.Backport.ItemDidCollapseMessage.self) { record("didCollapse", $0.item) },
        ]

        outlineView.expandItem(dataSource.folder)
        outlineView.collapseItem(dataSource.folder)

        withExtendedLifetime((tokens, dataSource)) {}
        #expect(events == ["willExpand true", "didExpand true", "willCollapse true", "didCollapse true"])
    }

    @Test("A split view reports resizing its subviews")
    func splitViewResize() {
        let splitView = NSSplitView(frame: NSRect(x: 0, y: 0, width: 300, height: 100))
        splitView.isVertical = true
        splitView.addArrangedSubview(NSView())
        splitView.addArrangedSubview(NSView())
        splitView.adjustSubviews()
        var events: [String] = []
        let tokens = [
            center.addObserver(of: splitView, for: NSSplitView.Backport.WillResizeSubviewsMessage.self) {
                events.append("will \($0.splitView === splitView) \(String(describing: $0.dividerIndex)) \($0.userResize)")
            },
            center.addObserver(of: splitView, for: NSSplitView.Backport.DidResizeSubviewsMessage.self) {
                events.append("did \($0.splitView === splitView) \(String(describing: $0.dividerIndex)) \($0.userResize)")
            },
        ]

        splitView.setPosition(120, ofDividerAt: 0)

        withExtendedLifetime(tokens) {}
        #expect(events.first?.hasPrefix("will true") == true)
        #expect(events.last?.hasPrefix("did true") == true)
    }

    @Test("A text view reports the selection it replaces and a change of typing attributes")
    func textViewSelection() {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 200, height: 100))
        textView.string = "Hello, world"
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        var oldRanges: [NSRange?] = []
        var typingAttributeChanges = 0
        let tokens = [
            center.addObserver(of: textView, for: NSTextView.Backport.DidChangeSelectionMessage.self) { oldRanges.append($0.oldSelectedCharacterRange) },
            center.addObserver(of: textView, for: NSTextView.Backport.DidChangeTypingAttributesMessage.self) { _ in typingAttributeChanges += 1 },
        ]

        textView.setSelectedRange(NSRange(location: 2, length: 3))
        textView.typingAttributes = [.foregroundColor: NSColor.systemRed]

        withExtendedLifetime(tokens) {}
        #expect(oldRanges.first == NSRange(location: 0, length: 0))
        #expect(typingAttributeChanges >= 1)
    }

    @Test("A color list reports a change")
    func colorListChange() {
        let colorList = NSColorList(name: "UIFoundationTests.NotificationMessages")
        var changes: [NSColorList] = []
        let token = center.addObserver(of: colorList, for: NSColorList.Backport.DidChangeMessage.self) { changes.append($0.colorList) }

        colorList.setColor(.systemRed, forKey: "Red")

        withExtendedLifetime(token) {}
        #expect(changes.count == 1)
        #expect(changes.first === colorList)
    }

    @Test("A toolbar reports the items it adds and removes")
    func toolbarItems() {
        let delegate = SingleItemToolbarDelegate()
        let toolbar = NSToolbar(identifier: "UIFoundationTests.NotificationMessages")
        toolbar.delegate = delegate
        var added: [(NSToolbarItem.Identifier, Int)] = []
        var removed: [NSToolbarItem.Identifier] = []
        let tokens = [
            center.addObserver(of: toolbar, for: NSToolbar.Backport.WillAddItemMessage.self) { added.append(($0.item.itemIdentifier, $0.newIndex)) },
            center.addObserver(of: toolbar, for: NSToolbar.Backport.DidRemoveItemMessage.self) { removed.append($0.item.itemIdentifier) },
        ]

        // Measured in this test process: an insertion is posted only once something reads `items` after
        // it, while a removal is posted at once.
        toolbar.insertItem(withItemIdentifier: SingleItemToolbarDelegate.itemIdentifier, at: 0)
        _ = toolbar.items
        toolbar.removeItem(at: 0)

        withExtendedLifetime((tokens, delegate)) {}
        #expect(added.map(\.0) == [SingleItemToolbarDelegate.itemIdentifier])
        #expect(added.map(\.1) == [0])
        #expect(removed == [SingleItemToolbarDelegate.itemIdentifier])
    }
}

/// How the shorthand resolves when two identifiers share a name and one subject is a subclass of the
/// other -- `.selectionDidChange` names both `NSTableView`'s message and `NSOutlineView`'s. Passing the
/// outline view's metatype picks `NSOutlineView`'s, exactly as AppKit's own API does. (Passing an outline
/// view *instance* is ambiguous, in AppKit's API and in the backport alike, and cannot be shown in a test
/// that has to compile.) Written as shorthand on purpose; at the tests' macOS 12 deployment target only
/// the backport's identifiers are available.
@Suite("Shorthand resolution with a subclass subject")
@MainActor
struct NotificationMessageShorthandResolutionTests {
    @Test("The outline view's metatype picks NSOutlineView's own selection message")
    func outlineViewMetatype() {
        let center = NotificationCenter.default
        let outlineView = NSOutlineView()
        var received: [String] = []
        let token = center.addObserver(of: NSOutlineView.self, for: .selectionDidChange) { message in
            received.append(String(reflecting: type(of: message)))
        }

        center.post(name: NSTableView.selectionDidChangeNotification, object: outlineView)
        center.post(name: NSOutlineView.selectionDidChangeNotification, object: outlineView)

        withExtendedLifetime(token) {}
        #expect(received.count == 1)
        #expect(received.first?.hasSuffix("NSOutlineView.Backport.SelectionDidChangeMessage") == true)
    }
}

/// One expandable folder at the root, with one leaf inside.
private final class SingleFolderOutlineDataSource: NSObject, NSOutlineViewDataSource {
    let folder: NSString = "Folder"
    let leaf: NSString = "Leaf"

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        item == nil || (item as AnyObject) === folder ? 1 : 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        item == nil ? folder : leaf
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        (item as AnyObject) === folder
    }
}

/// Supplies the one item the toolbar test inserts.
private final class SingleItemToolbarDelegate: NSObject, NSToolbarDelegate {
    static let itemIdentifier = NSToolbarItem.Identifier("UIFoundationTests.NotificationMessages.Item")

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        NSToolbarItem(itemIdentifier: itemIdentifier)
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.itemIdentifier]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        []
    }
}

#endif
