import AppKit

open class DestinationPopUpButton: PopUpButton {
    private static let latestDestinationURLKey = "ClonePopUpButton.latestDestinationURLKey"

    private let contentMenu = NSMenu()

    private(set) var selectedDestinationURL: URL?

    public var didSelectDestination: ((URL) -> Void)? {
        didSet {
            if initialByUserDefaults, let didSelectDestination, let selectedDestinationURL {
                initialByUserDefaults = false
                didSelectDestination(selectedDestinationURL)
            }
        }
    }

    private var initialByUserDefaults = false

    public override init(frame buttonFrame: NSRect, pullsDown flag: Bool) {
        super.init(frame: buttonFrame, pullsDown: flag)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    func commonInit() {
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
            image = (resources?.effectiveIcon as? NSImage)?.toSize(.init(width: 18, height: 18))
        }

        @available(*, unavailable)
        required init(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
    }
}

extension NSImage {
    func toSize(_ targetSize: NSSize) -> NSImage {
        // 假设你已经有了一个 NSImage 实例叫做 originalImage
        let originalImage = self

        // 创建一个新的 NSImage 实例
        let scaledImage = NSImage(size: targetSize)

        scaledImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high

        // 计算宽度和高度的缩放比例
//        let aspectRatio = originalImage.size.width / originalImage.size.height
        let widthRatio = targetSize.width / originalImage.size.width
        let heightRatio = targetSize.height / originalImage.size.height

        // 保持宽高比
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledWidth = originalImage.size.width * scaleFactor
        let scaledHeight = originalImage.size.height * scaleFactor

        // 计算绘制起点，使图像居中
        let x = (targetSize.width - scaledWidth) / 2.0
        let y = (targetSize.height - scaledHeight) / 2.0

        // 绘制图像
        let rect = NSRect(x: x, y: y, width: scaledWidth, height: scaledHeight)
        originalImage.draw(in: rect, from: NSRect(origin: .zero, size: originalImage.size), operation: .copy, fraction: 1.0)

        scaledImage.unlockFocus()

        // 现在 scaledImage 包含了保持宽高比缩放后的图像
        return scaledImage
    }
}
