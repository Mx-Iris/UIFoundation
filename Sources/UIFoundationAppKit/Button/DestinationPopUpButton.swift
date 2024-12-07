#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
@_implementationOnly import UIFoundationToolbox

open class DestinationPopUpButton: PopUpButton {
    private static let latestDestinationURLKey = "ClonePopUpButton.latestDestinationURLKey"

    private let contentMenu = NSMenu()

    public private(set) var selectedDestinationURL: URL?

    public var didSelectDestination: ((URL) -> Void)? {
        didSet {
            if initialByUserDefaults, let didSelectDestination, let selectedDestinationURL {
                initialByUserDefaults = false
                didSelectDestination(selectedDestinationURL)
            }
        }
    }

    private var initialByUserDefaults = false

    open override func setup() {
        super.setup()

        menu = contentMenu
        if let latestDestinationURL = UserDefaults.standard.url(forKey: Self.latestDestinationURLKey) {
            let item = addURLItem(latestDestinationURL)
            itemDidSelectAction(item)
            select(item)
            initialByUserDefaults = true
        }
        contentMenu.addItem(.separator())
        contentMenu.addItem(withTitle: "Select Destination...", action: #selector(selectDestinationAction(_:)), keyEquivalent: "").do {
            $0.target = self
        }
    }

    @objc private func selectDestinationAction(_ menuItem: NSMenuItem) {
        let openPanel = NSOpenPanel().then {
            $0.canChooseDirectories = true
            $0.canChooseFiles = false
            $0.allowsMultipleSelection = false
        }
        let result = openPanel.runModal()
        guard result == .OK, let selectedURL = openPanel.url else { return }
        let item = addURLItem(selectedURL)
        select(item)
        UserDefaults.standard.set(selectedURL, forKey: Self.latestDestinationURLKey)
    }

    @objc private func itemDidSelectAction(_ menuItem: URLMenuItem) {
        let selectedDestinationURL = menuItem.url
        self.selectedDestinationURL = selectedDestinationURL
        didSelectDestination?(selectedDestinationURL)
    }

    @discardableResult
    private func addURLItem(_ url: URL) -> URLMenuItem {
        let item = URLMenuItem(url: url, action: #selector(itemDidSelectAction(_:)), keyEquivalent: "")
        item.target = self
        contentMenu.insertItem(item, at: 0)
        return item
    }

    private class URLMenuItem: NSMenuItem {
        let url: URL

        init(url: URL, action: Selector?, keyEquivalent: String) {
            self.url = url
            super.init(title: url.path, action: action, keyEquivalent: keyEquivalent)
            let resources = try? url.resourceValues(forKeys: [.effectiveIconKey])
            image = (resources?.effectiveIcon as? NSImage)?.box.toSize(.init(width: 18, height: 18))
        }

        @available(*, unavailable)
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}


#endif
