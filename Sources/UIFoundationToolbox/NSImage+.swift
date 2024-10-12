#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox

extension FrameworkToolbox where Base: StringProtocol {
    public var nsImage: NSImage? {
        .init(named: String(base))
    }
}

extension FrameworkToolbox where Base: NSImage {
    public var cgImage: CGImage? {
        guard let imageData = base.tiffRepresentation else { return nil }
        guard let sourceData = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(sourceData, 0, nil)
    }

    public var ciImage: CIImage? {
        guard let imageData = base.tiffRepresentation else { return nil }
        return CIImage(data: imageData)
    }

    public func fill(color: NSColor) -> NSImage {
        let imageSize = base.size
        let imageRect = CGRect(origin: .zero, size: imageSize)

        let tinted = NSImage(size: imageSize)
        tinted.lockFocus()

        base.draw(in: imageRect)

        color.set()
        imageRect.fill(using: .sourceAtop)

        tinted.unlockFocus()

        return tinted
    }

    public static func createMaskedImageWithWhiteBackground(text: String, font: NSFont, size: CGSize) -> NSImage? {
        let image = NSImage(size: size)
        image.lockFocus()

        // Fill with white background
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        // Set up context for clipping (making text transparent)
        let context = NSGraphicsContext.current?.cgContext
        context?.saveGState()
        context?.setBlendMode(.destinationOut)

        // Draw the text
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.black,
        ]

        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: NSPoint(x: (size.width - string.size().width) * 0.5, y: (size.height - string.size().height) * 0.5))

        context?.restoreGState()

        image.unlockFocus()
        return image
    }

    public func image(withTintColor tintColor: NSColor) -> NSImage {
        guard base.isTemplate else {
            return base
        }

        guard let copiedImage = base.copy() as? NSImage else {
            return base
        }

        copiedImage.lockFocus()
        tintColor.set()
        let imageBounds = CGRect(x: 0, y: 0, width: copiedImage.size.width, height: copiedImage.size.height)
        imageBounds.fill(using: .sourceAtop)
        copiedImage.unlockFocus()

        copiedImage.isTemplate = false
        return copiedImage
    }

    public func toSize(_ targetSize: NSSize) -> NSImage {
        // 假设你已经有了一个 NSImage 实例叫做 originalImage
        let originalImage = base

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

extension NSImage {
    public enum BuiltInImageName {
        @available(macOS 10.5, *)
        case addTemplate

        @available(macOS 10.5, *)
        case bluetoothTemplate

        @available(macOS 10.5, *)
        case bonjour

        @available(macOS 10.6, *)
        case bookmarksTemplate

        @available(macOS 10.6, *)
        case caution

        @available(macOS 10.5, *)
        case computer

        @available(macOS 10.5, *)
        case enterFullScreenTemplate

        @available(macOS 10.5, *)
        case exitFullScreenTemplate

        @available(macOS 10.6, *)
        case folder

        @available(macOS 10.5, *)
        case folderBurnable

        @available(macOS 10.5, *)
        case folderSmart

        @available(macOS 10.5, *)
        case followLinkFreestandingTemplate

        @available(macOS 10.6, *)
        case homeTemplate

        @available(macOS 10.5, *)
        case iChatTheaterTemplate

        @available(macOS 10.5, *)
        case lockLockedTemplate

        @available(macOS 10.5, *)
        case lockUnlockedTemplate

        @available(macOS 10.5, *)
        case network

        @available(macOS 10.5, *)
        case pathTemplate

        @available(macOS 10.5, *)
        case quickLookTemplate

        @available(macOS 10.5, *)
        case refreshFreestandingTemplate

        @available(macOS 10.5, *)
        case refreshTemplate

        @available(macOS 10.5, *)
        case removeTemplate

        @available(macOS 10.5, *)
        case revealFreestandingTemplate

        @available(macOS 10.8, *)
        case shareTemplate

        @available(macOS 10.5, *)
        case slideshowTemplate

        @available(macOS 10.6, *)
        case statusAvailable

        @available(macOS 10.6, *)
        case statusNone

        @available(macOS 10.6, *)
        case statusPartiallyAvailable

        @available(macOS 10.6, *)
        case statusUnavailable

        @available(macOS 10.5, *)
        case stopProgressFreestandingTemplate

        @available(macOS 10.5, *)
        case stopProgressTemplate

        @available(macOS 10.6, *)
        case trashEmpty

        @available(macOS 10.6, *)
        case trashFull

        @available(macOS 10.5, *)
        case actionTemplate

        @available(macOS 10.5, *)
        case smartBadgeTemplate

        @available(macOS 10.5, *)
        case iconViewTemplate

        @available(macOS 10.5, *)
        case listViewTemplate

        @available(macOS 10.5, *)
        case columnViewTemplate

        @available(macOS 10.5, *)
        case flowViewTemplate

        @available(macOS 10.5, *)
        case invalidDataFreestandingTemplate

        @available(macOS 10.12, *)
        case goForwardTemplate

        @available(macOS 10.12, *)
        case goBackTemplate

        @available(macOS 10.5, *)
        case goRightTemplate

        @available(macOS 10.5, *)
        case goLeftTemplate

        @available(macOS 10.5, *)
        case rightFacingTriangleTemplate

        @available(macOS 10.5, *)
        case leftFacingTriangleTemplate

        @available(macOS 10.6, *)
        case mobileMe

        @available(macOS 10.5, *)
        case multipleDocuments

        @available(macOS 10.5, *)
        case userAccounts

        @available(macOS 10.5, *)
        case preferencesGeneral

        @available(macOS 10.5, *)
        case advanced

        @available(macOS 10.5, *)
        case info

        @available(macOS 10.5, *)
        case fontPanel

        @available(macOS 10.5, *)
        case colorPanel

        @available(macOS 10.5, *)
        case user

        @available(macOS 10.5, *)
        case userGroup

        @available(macOS 10.5, *)
        case everyone

        @available(macOS 10.6, *)
        case userGuest

        @available(macOS 10.6, *)
        case menuOnStateTemplate

        @available(macOS 10.6, *)
        case menuMixedStateTemplate

        @available(macOS 10.6, *)
        case applicationIcon

        var imageName: NSImage.Name {
            switch self {
            case .addTemplate:
                NSImage.addTemplateName
            case .bluetoothTemplate:
                NSImage.bluetoothTemplateName
            case .bonjour:
                NSImage.bonjourName
            case .bookmarksTemplate:
                NSImage.bookmarksTemplateName
            case .caution:
                NSImage.cautionName
            case .computer:
                NSImage.computerName
            case .enterFullScreenTemplate:
                NSImage.enterFullScreenTemplateName
            case .exitFullScreenTemplate:
                NSImage.exitFullScreenTemplateName
            case .folder:
                NSImage.folderName
            case .folderBurnable:
                NSImage.folderBurnableName
            case .folderSmart:
                NSImage.folderSmartName
            case .followLinkFreestandingTemplate:
                NSImage.followLinkFreestandingTemplateName
            case .homeTemplate:
                NSImage.homeTemplateName
            case .iChatTheaterTemplate:
                NSImage.iChatTheaterTemplateName
            case .lockLockedTemplate:
                NSImage.lockLockedTemplateName
            case .lockUnlockedTemplate:
                NSImage.lockUnlockedTemplateName
            case .network:
                NSImage.networkName
            case .pathTemplate:
                NSImage.pathTemplateName
            case .quickLookTemplate:
                NSImage.quickLookTemplateName
            case .refreshFreestandingTemplate:
                NSImage.refreshFreestandingTemplateName
            case .refreshTemplate:
                NSImage.refreshTemplateName
            case .removeTemplate:
                NSImage.removeTemplateName
            case .revealFreestandingTemplate:
                NSImage.revealFreestandingTemplateName
            case .shareTemplate:
                NSImage.shareTemplateName
            case .slideshowTemplate:
                NSImage.slideshowTemplateName
            case .statusAvailable:
                NSImage.statusAvailableName
            case .statusNone:
                NSImage.statusNoneName
            case .statusPartiallyAvailable:
                NSImage.statusPartiallyAvailableName
            case .statusUnavailable:
                NSImage.statusUnavailableName
            case .stopProgressFreestandingTemplate:
                NSImage.stopProgressFreestandingTemplateName
            case .stopProgressTemplate:
                NSImage.stopProgressTemplateName
            case .trashEmpty:
                NSImage.trashEmptyName
            case .trashFull:
                NSImage.trashFullName
            case .actionTemplate:
                NSImage.actionTemplateName
            case .smartBadgeTemplate:
                NSImage.smartBadgeTemplateName
            case .iconViewTemplate:
                NSImage.iconViewTemplateName
            case .listViewTemplate:
                NSImage.listViewTemplateName
            case .columnViewTemplate:
                NSImage.columnViewTemplateName
            case .flowViewTemplate:
                NSImage.flowViewTemplateName
            case .invalidDataFreestandingTemplate:
                NSImage.invalidDataFreestandingTemplateName
            case .goForwardTemplate:
                NSImage.goForwardTemplateName
            case .goBackTemplate:
                NSImage.goBackTemplateName
            case .goRightTemplate:
                NSImage.goRightTemplateName
            case .goLeftTemplate:
                NSImage.goLeftTemplateName
            case .rightFacingTriangleTemplate:
                NSImage.rightFacingTriangleTemplateName
            case .leftFacingTriangleTemplate:
                NSImage.leftFacingTriangleTemplateName
            case .mobileMe:
                NSImage.mobileMeName
            case .multipleDocuments:
                NSImage.multipleDocumentsName
            case .userAccounts:
                NSImage.userAccountsName
            case .preferencesGeneral:
                NSImage.preferencesGeneralName
            case .advanced:
                NSImage.advancedName
            case .info:
                NSImage.infoName
            case .fontPanel:
                NSImage.fontPanelName
            case .colorPanel:
                NSImage.colorPanelName
            case .user:
                NSImage.userName
            case .userGroup:
                NSImage.userGroupName
            case .everyone:
                NSImage.everyoneName
            case .userGuest:
                NSImage.userGuestName
            case .menuOnStateTemplate:
                NSImage.menuOnStateTemplateName
            case .menuMixedStateTemplate:
                NSImage.menuMixedStateTemplateName
            case .applicationIcon:
                NSImage.applicationIconName
            }
        }
    }

    public convenience init(builtInImageNamed: BuiltInImageName) {
        self.init(named: builtInImageNamed.imageName)!
    }
}

#endif
