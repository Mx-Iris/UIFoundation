//
//  QuickActionBarBrowseButtonsDemo+Launcher.swift
//  UIFoundationExample-macOS
//

import AppKit
import UIFoundation

/// Example 1: Spotlight's four browse buttons, each listing a category.
///
/// A click pushes the whole category into the bar with `provideResultIdentifiers(_:)`, and the
/// results arriving draw the buttons back into the search field. The content source remembers the
/// category and searches only inside it until the query is empty again; answering the empty query
/// with nothing collapses the results and brings the buttons back out, which is the way back to
/// them. Escape on an empty query closes the bar instead: the bar has no browse mode for Escape to
/// leave first, as Spotlight's has.
final class LauncherBrowseExample: NSObject {
    enum Category: CaseIterable {
        case applications
        case files
        case actions
        case clipboard

        var title: String {
            switch self {
            case .applications: "Applications"
            case .files: "Files"
            case .actions: "Actions"
            case .clipboard: "Clipboard"
            }
        }

        /// Spotlight's own symbol, or a close public one on a system that lacks it.
        var image: NSImage {
            switch self {
            case .applications: BrowseExample.symbol("appstore", fallback: "square.grid.2x2", title: title)
            case .files: BrowseExample.symbol("folder", title: title)
            case .actions: BrowseExample.symbol("app.2.stack.3d", fallback: "square.stack.3d.up", title: title)
            case .clipboard: BrowseExample.symbol("document.on.document", fallback: "doc.on.doc", title: title)
            }
        }
    }

    /// An application in one of the folders every Mac has.
    private struct Application: Hashable {
        let url: URL
        let name: String
    }

    /// Something to do to the window the bar was opened over.
    private enum Action: CaseIterable, Hashable {
        case toggleFullScreen
        case zoomWindow
        case switchAppearance
        case clearEventLog

        var title: String {
            switch self {
            case .toggleFullScreen: "Toggle Full Screen"
            case .zoomWindow: "Zoom Window"
            case .switchAppearance: "Switch Appearance"
            case .clearEventLog: "Clear Event Log"
            }
        }

        var detail: String {
            switch self {
            case .toggleFullScreen: "Fill the display with this window, or give it back"
            case .zoomWindow: "Grow this window to fill the screen, or shrink it back"
            case .switchAppearance: "Show this window in the other appearance, or follow the system again"
            case .clearEventLog: "Empty the event log on this page"
            }
        }

        var symbolName: String {
            switch self {
            case .toggleFullScreen: "arrow.up.left.and.arrow.down.right"
            case .zoomWindow: "macwindow"
            case .switchAppearance: "circle.lefthalf.filled"
            case .clearEventLog: "trash"
            }
        }
    }

    /// A piece of text the Clipboard category copies.
    private struct Snippet: Hashable {
        let text: String
        let symbolName: String
    }

    let quickActionBar = QuickActionBar()

    /// The category the last click opened. Searched until the query is empty again.
    private var browsedCategory: Category?

    /// An action picked from the list. It runs once the bar has gone and the window it was opened
    /// over is in front again.
    private var pendingAction: Action?

    private weak var hostWindow: NSWindow?

    private lazy var applications: [Application] = Self.installedApplications()
    private var applicationIcons: [URL: NSImage] = [:]

    /// Most recently copied first, the way a clipboard history lists them. The example only ever
    /// writes to the clipboard: reading it from code makes the system ask the user first.
    private var snippets: [Snippet] = [
        Snippet(text: "https://github.com/Mx-Iris/UIFoundation", symbolName: "link"),
        Snippet(text: "Thanks — I'll take a look this afternoon.", symbolName: "text.quote"),
        Snippet(text: "let quickActionBar = QuickActionBar()", symbolName: "chevron.left.forwardslash.chevron.right"),
        Snippet(text: "#0A84FF", symbolName: "paintpalette"),
        Snippet(text: "Meet at 10:30 in the atrium", symbolName: "calendar"),
    ]

    private let log: (String) -> Void
    private let clearEventLog: () -> Void

    init(log: @escaping (String) -> Void, clearEventLog: @escaping () -> Void) {
        self.log = log
        self.clearEventLog = clearEventLog
        super.init()
        quickActionBar.contentSource = self
        quickActionBar.browseItems = Category.allCases.map { category in
            QuickActionBar.BrowseItem(title: category.title, image: category.image) { [weak self] quickActionBar in
                self?.browse(category, in: quickActionBar)
            }
        }
    }

    func present(over window: NSWindow?) {
        // A dismissal still in flight turns round rather than starting over.
        if quickActionBar.resumePresentation() {
            return
        }
        hostWindow = window
        browsedCategory = nil
        pendingAction = nil
        quickActionBar.present(
            parentWindow: window,
            placeholderText: "Search applications, files, actions and snippets",
            width: 640,
            height: 420,
            showKeyboardShortcuts: true,
            didClose: { [weak self] in
                self?.performPendingAction()
            }
        )
    }

    // MARK: - Browsing and searching

    private func browse(_ category: Category, in quickActionBar: QuickActionBar) {
        browsedCategory = category
        log("Launcher — \(category.title): the whole category, from the button")
        quickActionBar.provideResultIdentifiers(results(in: category, matching: "", limit: nil))
    }

    private func results(for searchTerm: String) -> [AnyHashable] {
        guard !searchTerm.isEmpty else {
            // An empty query leaves the category. Answering it with nothing collapses the results,
            // and that brings the buttons back out.
            browsedCategory = nil
            return []
        }
        if let browsedCategory {
            return results(in: browsedCategory, matching: searchTerm, limit: nil)
        }
        // No category open: every category, a few rows each, as Spotlight's own results are.
        return Category.allCases.flatMap { results(in: $0, matching: searchTerm, limit: 5) }
    }

    /// The category's items that match, under the category's heading; nothing when none do.
    private func results(in category: Category, matching searchTerm: String, limit: Int?) -> [AnyHashable] {
        let matchingItems: [AnyHashable]
        switch category {
        case .applications:
            matchingItems = applications.filter { isMatch($0.name, for: searchTerm) }.map { AnyHashable($0) }
        case .files:
            matchingItems = BrowseExampleDocument.all.filter { isMatch($0.name, for: searchTerm) }.map { AnyHashable($0) }
        case .actions:
            matchingItems = Action.allCases.filter { isMatch($0.title, for: searchTerm) }.map { AnyHashable($0) }
        case .clipboard:
            matchingItems = snippets.filter { isMatch($0.text, for: searchTerm) }.map { AnyHashable($0) }
        }
        guard !matchingItems.isEmpty else {
            return []
        }
        let shownItems = limit.map { Array(matchingItems.prefix($0)) } ?? matchingItems
        return [AnyHashable(BrowseExampleHeading(title: category.title))] + shownItems
    }

    private func isMatch(_ text: String, for searchTerm: String) -> Bool {
        searchTerm.isEmpty || text.localizedCaseInsensitiveContains(searchTerm)
    }

    // MARK: - Applications

    /// The applications in the folders every Mac has, by name. The sandbox lets the app read them.
    private static func installedApplications() -> [Application] {
        let fileManager = FileManager.default
        let folderPaths = ["/Applications", "/System/Applications", "/System/Applications/Utilities"]
        let applications = folderPaths.flatMap { folderPath -> [Application] in
            let folderURL = URL(fileURLWithPath: folderPath, isDirectory: true)
            let folderContents = (try? fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )) ?? []
            return folderContents
                .filter { $0.pathExtension == "app" }
                .map { applicationURL in
                    // The name Finder shows, which keeps the extension only when the user asked
                    // Finder to show every extension.
                    let displayName = fileManager.displayName(atPath: applicationURL.path)
                    let name = displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
                    return Application(url: applicationURL, name: name)
                }
        }
        return applications.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func icon(for application: Application) -> NSImage {
        if let cachedIcon = applicationIcons[application.url] {
            return cachedIcon
        }
        let icon = NSWorkspace.shared.icon(forFile: application.url.path)
        applicationIcons[application.url] = icon
        return icon
    }

    private func open(_ application: Application) {
        log("Launcher — opening \(application.name)")
        NSWorkspace.shared.openApplication(
            at: application.url,
            configuration: NSWorkspace.OpenConfiguration()
        ) { [weak self] _, error in
            guard let error else { return }
            DispatchQueue.main.async {
                self?.log("Launcher — \(application.name) did not open: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Actions and snippets

    private func performPendingAction() {
        guard let action = pendingAction else { return }
        pendingAction = nil
        switch action {
        case .toggleFullScreen:
            hostWindow?.toggleFullScreen(nil)
        case .zoomWindow:
            hostWindow?.zoom(nil)
        case .switchAppearance:
            switchAppearance()
        case .clearEventLog:
            clearEventLog()
        }
        log("Launcher — \(action.title), once the bar had closed")
    }

    /// From following the system to the appearance it is not showing, and back to following it.
    private func switchAppearance() {
        guard let hostWindow else { return }
        if hostWindow.appearance != nil {
            hostWindow.appearance = nil
        } else {
            let isDark = hostWindow.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            hostWindow.appearance = NSAppearance(named: isDark ? .aqua : .darkAqua)
        }
    }

    private func copy(_ snippet: Snippet) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(snippet.text, forType: .string)
        snippets.removeAll { $0 == snippet }
        snippets.insert(snippet, at: 0)
        log("Launcher — copied “\(snippet.text)” to the clipboard")
    }
}

// MARK: - Content source

extension LauncherBrowseExample: QuickActionBarContentSource {
    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask) {
        task.complete(with: results(for: task.searchTerm))
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        switch item.base {
        case let heading as BrowseExampleHeading:
            return BrowseExample.headingRow(heading.title)
        case let application as Application:
            return BrowseExample.row(
                icon: icon(for: application),
                title: application.name,
                detail: application.url.deletingLastPathComponent().path,
                searchTerm: searchTerm
            )
        case let document as BrowseExampleDocument:
            return BrowseExample.row(icon: document.icon, title: document.name, detail: document.folder, searchTerm: searchTerm)
        case let action as Action:
            return BrowseExample.row(
                icon: BrowseExample.symbol(action.symbolName, title: action.title),
                title: action.title,
                detail: action.detail,
                searchTerm: searchTerm
            )
        case let snippet as Snippet:
            return BrowseExample.row(
                icon: BrowseExample.symbol(snippet.symbolName, title: "Snippet"),
                title: snippet.text,
                detail: "Copy to the clipboard",
                searchTerm: searchTerm
            )
        default:
            return nil
        }
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, canSelectItem item: AnyHashable) -> Bool {
        !(item.base is BrowseExampleHeading)
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable) {
        switch item.base {
        case let application as Application:
            open(application)
        case let document as BrowseExampleDocument:
            log("Launcher — “\(document.name)” is made up, so nothing opens")
        case let action as Action:
            pendingAction = action
        case let snippet as Snippet:
            copy(snippet)
        default:
            break
        }
    }
}
