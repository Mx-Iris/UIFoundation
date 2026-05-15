//
//  TextFinderDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Created by JH on 2026/4/6.
//

import AppKit
import UIFoundation

// MARK: - Sample Data Model

class FileNode: NSObject {
    let name: String
    let kind: String
    let children: [FileNode]?

    var isFolder: Bool { children != nil }

    init(name: String, kind: String, children: [FileNode]? = nil) {
        self.name = name
        self.kind = kind
        self.children = children
        super.init()
    }

    static let sampleData: [FileNode] = [
        FileNode(name: "Documents", kind: "Folder", children: [
            FileNode(name: "Reports", kind: "Folder", children: [
                FileNode(name: "Annual Report 2024.pdf", kind: "PDF Document"),
                FileNode(name: "Quarterly Summary.docx", kind: "Word Document"),
                FileNode(name: "Budget Analysis.xlsx", kind: "Excel Spreadsheet"),
            ]),
            FileNode(name: "Projects", kind: "Folder", children: [
                FileNode(name: "UIFoundation", kind: "Folder", children: [
                    FileNode(name: "Package.swift", kind: "Swift Source"),
                    FileNode(name: "README.md", kind: "Markdown"),
                    FileNode(name: "TextFinder Implementation Notes.txt", kind: "Text File"),
                ]),
                FileNode(name: "FrameworkToolbox", kind: "Folder", children: [
                    FileNode(name: "Package.swift", kind: "Swift Source"),
                    FileNode(name: "README.md", kind: "Markdown"),
                ]),
            ]),
            FileNode(name: "Notes", kind: "Folder", children: [
                FileNode(name: "Meeting Notes - April 2026.txt", kind: "Text File"),
                FileNode(name: "Todo List.txt", kind: "Text File"),
            ]),
        ]),
        FileNode(name: "Downloads", kind: "Folder", children: [
            FileNode(name: "Xcode_15.2.xip", kind: "Archive"),
            FileNode(name: "swift-testing-guide.pdf", kind: "PDF Document"),
            FileNode(name: "AppKit Best Practices.pdf", kind: "PDF Document"),
        ]),
        FileNode(name: "Desktop", kind: "Folder", children: [
            FileNode(name: "Screenshot 2026-04-06.png", kind: "PNG Image"),
            FileNode(name: "Quick Notes.txt", kind: "Text File"),
        ]),
    ]
}

// MARK: - TextFinderDemoViewController

@available(macOS 12.0, *)
class TextFinderDemoViewController: NSViewController {

    private var scrollView: NSScrollView!
    private var outlineView: NSOutlineView!
    private var textFinderClient: OutlineViewTextFinderClient!

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOutlineView()
        setupTextFinder()
    }

    private func setupOutlineView() {
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("NameColumn"))
        nameColumn.title = "Name"
        nameColumn.width = 300

        let kindColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("KindColumn"))
        kindColumn.title = "Kind"
        kindColumn.width = 200

        outlineView = NSOutlineView()
        outlineView.addTableColumn(nameColumn)
        outlineView.addTableColumn(kindColumn)
        outlineView.outlineTableColumn = nameColumn
        outlineView.style = .inset
        outlineView.rowSizeStyle = .default
        outlineView.delegate = self
        outlineView.dataSource = self
        outlineView.usesAlternatingRowBackgroundColors = true

        scrollView = NSScrollView()
        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isFindBarVisible = false

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // Expand top-level items by default
        for rootNode in FileNode.sampleData {
            outlineView.expandItem(rootNode)
        }
    }

    private func setupTextFinder() {
        textFinderClient = OutlineViewTextFinderClient(outlineView: outlineView, searchScope: .onDemand)
        textFinderClient.dataSource = self
    }

    // MARK: - Responder Chain for Find Bar

    @IBAction override func performTextFinderAction(_ sender: Any?) {
        let tag: Int
        if let menuItem = sender as? NSMenuItem {
            tag = menuItem.tag
        } else {
            tag = NSTextFinder.Action.showFindInterface.rawValue
        }
        textFinderClient.textFinder.performAction(NSTextFinder.Action(rawValue: tag) ?? .showFindInterface)
    }
}

// MARK: - NSOutlineViewDataSource

@available(macOS 12.0, *)
extension TextFinderDemoViewController: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if let fileNode = item as? FileNode {
            return fileNode.children?.count ?? 0
        }
        return FileNode.sampleData.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if let fileNode = item as? FileNode {
            return fileNode.children![index]
        }
        return FileNode.sampleData[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let fileNode = item as? FileNode else { return false }
        return fileNode.isFolder
    }
}

// MARK: - NSOutlineViewDelegate

@available(macOS 12.0, *)
extension TextFinderDemoViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let fileNode = item as? FileNode, let tableColumn else { return nil }

        let cellIdentifier = tableColumn.identifier
        
        let cellView: NSTableCellView = outlineView.box.makeView(identifier: cellIdentifier) {
            let cellView = NSTableCellView()
            cellView.identifier = cellIdentifier

            let textField = NSTextField(labelWithString: "")
            textField.translatesAutoresizingMaskIntoConstraints = false
            cellView.addSubview(textField)
            cellView.textField = textField

            NSLayoutConstraint.activate([
                textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
                textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
                textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
            ])
            return cellView
        }

        if tableColumn.identifier.rawValue == "NameColumn" {
            cellView.textField?.stringValue = fileNode.name
            cellView.imageView?.image = fileNode.isFolder
                ? NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                : NSImage(systemSymbolName: "doc", accessibilityDescription: nil)
        } else {
            cellView.textField?.stringValue = fileNode.kind
        }

        return cellView
    }
}

// MARK: - OutlineViewTextFinderDataSource

@available(macOS 12.0, *)
extension TextFinderDemoViewController: OutlineViewTextFinderDataSource {
    func numberOfSearchableColumns(in client: OutlineViewTextFinderClient) -> Int {
        2
    }

    func textFinderClient(_ client: OutlineViewTextFinderClient, stringForItem item: Any, column: Int) -> String? {
        guard let fileNode = item as? FileNode else { return nil }
        switch column {
        case 0: return fileNode.name
        case 1: return fileNode.kind
        default: return nil
        }
    }

    func textFinderClient(_ client: OutlineViewTextFinderClient, childItemsOfItem item: Any?) -> [Any]? {
        if let fileNode = item as? FileNode {
            return fileNode.children
        }
        return FileNode.sampleData
    }
}
