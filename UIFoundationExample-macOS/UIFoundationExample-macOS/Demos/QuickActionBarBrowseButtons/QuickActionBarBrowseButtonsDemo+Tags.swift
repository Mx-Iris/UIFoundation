//
//  QuickActionBarBrowseButtonsDemo+Tags.swift
//  UIFoundationExample-macOS
//

import AppKit
import UIFoundation

/// Example 3: custom images, and a new set of buttons while the bar is open.
///
/// A browse item takes any image. These are dots in the colours of Finder's tags — not template
/// images, so the bar draws them in their colours — and a colour lists the documents carrying that
/// tag, the way the launcher lists a category. Six colours do not fit four buttons, so More Tags
/// assigns the next set to `browseItems` from its own action: the bar draws the buttons on screen
/// back into the search field and lets the new ones bud out. Back does the same in reverse.
final class TagsBrowseExample: NSObject {
    let quickActionBar = QuickActionBar()

    /// The tag the last click opened. Searched until the query is empty again.
    private var browsedTag: BrowseExampleTag?

    private let log: (String) -> Void

    init(log: @escaping (String) -> Void) {
        self.log = log
        super.init()
        quickActionBar.contentSource = self
    }

    func present(over window: NSWindow?) {
        // A dismissal still in flight turns round rather than starting over.
        if quickActionBar.resumePresentation() {
            return
        }
        browsedTag = nil
        quickActionBar.browseItems = firstSetOfBrowseItems()
        quickActionBar.present(
            parentWindow: window,
            placeholderText: "Search tagged documents",
            width: 640,
            height: 360
        )
    }

    // MARK: - Browse items

    private func firstSetOfBrowseItems() -> [QuickActionBar.BrowseItem] {
        let moreTagsItem = QuickActionBar.BrowseItem(
            title: "More Tags",
            image: BrowseExample.symbol("ellipsis", title: "More Tags")
        ) { [weak self] quickActionBar in
            guard let self else { return }
            log("Tags — More Tags: the next set replaces these buttons")
            quickActionBar.browseItems = secondSetOfBrowseItems()
        }
        let tags: [BrowseExampleTag] = [.red, .orange, .yellow]
        return tags.map { browseItem(for: $0) } + [moreTagsItem]
    }

    private func secondSetOfBrowseItems() -> [QuickActionBar.BrowseItem] {
        let backItem = QuickActionBar.BrowseItem(
            title: "Back",
            image: BrowseExample.symbol("chevron.backward", title: "Back")
        ) { [weak self] quickActionBar in
            guard let self else { return }
            log("Tags — Back: the first set returns")
            quickActionBar.browseItems = firstSetOfBrowseItems()
        }
        let tags: [BrowseExampleTag] = [.green, .blue, .purple]
        return [backItem] + tags.map { browseItem(for: $0) }
    }

    private func browseItem(for tag: BrowseExampleTag) -> QuickActionBar.BrowseItem {
        // Drawn at its own size, unlike a symbol, which the bar sizes to its text style.
        QuickActionBar.BrowseItem(title: tag.title, image: tag.dotImage(diameter: 18)) { [weak self] quickActionBar in
            self?.browse(tag, in: quickActionBar)
        }
    }

    // MARK: - Browsing and searching

    private func browse(_ tag: BrowseExampleTag, in quickActionBar: QuickActionBar) {
        browsedTag = tag
        log("Tags — \(tag.title): every document with the tag, from the button")
        quickActionBar.provideResultIdentifiers(results(taggedWith: tag, matching: ""))
    }

    private func results(for searchTerm: String) -> [AnyHashable] {
        guard !searchTerm.isEmpty else {
            // An empty query leaves the tag, and answering it with nothing brings the buttons out.
            browsedTag = nil
            return []
        }
        if let browsedTag {
            return results(taggedWith: browsedTag, matching: searchTerm)
        }
        return BrowseExampleDocument.all
            .filter { $0.name.localizedCaseInsensitiveContains(searchTerm) }
            .map { AnyHashable($0) }
    }

    /// The documents with the tag that match, under the tag's heading; nothing when none do.
    private func results(taggedWith tag: BrowseExampleTag, matching searchTerm: String) -> [AnyHashable] {
        let matchingDocuments = BrowseExampleDocument.all.filter { document in
            document.tags.contains(tag) && (searchTerm.isEmpty || document.name.localizedCaseInsensitiveContains(searchTerm))
        }
        guard !matchingDocuments.isEmpty else {
            return []
        }
        return [AnyHashable(BrowseExampleHeading(title: tag.title))] + matchingDocuments.map { AnyHashable($0) }
    }
}

// MARK: - Content source

extension TagsBrowseExample: QuickActionBarContentSource {
    func quickActionBar(_ quickActionBar: QuickActionBar, itemsForSearchTermTask task: QuickActionBar.SearchTask) {
        task.complete(with: results(for: task.searchTerm))
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, viewForItem item: AnyHashable, searchTerm: String) -> NSView? {
        switch item.base {
        case let heading as BrowseExampleHeading:
            return BrowseExample.headingRow(heading.title)
        case let document as BrowseExampleDocument:
            return BrowseExample.row(
                icon: document.icon,
                title: document.name,
                detail: document.folder,
                searchTerm: searchTerm,
                tags: document.tags
            )
        default:
            return nil
        }
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, canSelectItem item: AnyHashable) -> Bool {
        !(item.base is BrowseExampleHeading)
    }

    func quickActionBar(_ quickActionBar: QuickActionBar, didActivateItem item: AnyHashable) {
        guard let document = item.base as? BrowseExampleDocument else { return }
        log("Tags — “\(document.name)” is made up, so nothing opens")
    }
}
