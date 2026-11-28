//
//  QuickActionBar.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar && os(macOS)

import AppKit

/// A spotlight-inspired floating action bar.
public final class QuickActionBar {
    /// The default width for a quick action bar.
    public static let DefaultWidth: CGFloat = 640
    /// The default height for a quick action bar.
    public static let DefaultHeight: CGFloat = 320

    /// The default placeholder text to display in the edit field.
    public static let DefaultPlaceholderString: String = "Quick Actions"

    /// Padding around the content view to allow scale animation overflow (like Spotlight).
    internal static let animationPadding: CGFloat = 40

    /// The default image to display in the search field.
    public static let DefaultImage: NSImage = {
        let image = QuickActionBar.DefaultSearchImage()
        image.isTemplate = true
        return image
    }()

    /// Required click count enum.
    public enum RequiredClickCount {
        /// A single mouse/trackpad click is required to activate a row in the results.
        case single
        /// A double mouse/trackpad click is required to activate a row in the results.
        case double
    }

    /// How the bar looks and behaves.
    ///
    /// Read when the bar is presented; a change made while it is open applies to the next
    /// presentation.
    public var configuration: Configuration

    /// The number of clicks required to activate a row in the results view.
    @available(*, deprecated, message: "Set configuration.requiredClickCount instead.")
    public var requiredClickCount: RequiredClickCount {
        get { configuration.requiredClickCount }
        set { configuration.requiredClickCount = newValue }
    }

    /// The content source for the bar.
    public weak var contentSource: QuickActionBarContentSource?

    /// Has no effect: result rows size themselves to their content.
    @available(*, deprecated, message: "Has no effect: result rows size themselves automatically.")
    public var rowHeight: CGFloat = 36

    /// Round buttons beside the search field, the way macOS 26 Spotlight shows Applications,
    /// Files, Actions and Clipboard. None by default, which leaves the bar as it was.
    ///
    /// Each button takes 64 points of the search field at the default height; Spotlight shows four
    /// in a 640-point bar. Changing the list while the bar is open draws the current buttons back
    /// into the field and lets the new ones bud out. Ignored before macOS 26.
    public var browseItems: [BrowseItem] = [] {
        didSet {
            quickActionBarWindow?.browseItemsDidChange()
        }
    }

    /// The current search text.
    public var currentSearchText: String? {
        quickActionBarWindow?.currentSearchText
    }

    /// Is the quick action bar currently presented on screen?
    public var isPresenting: Bool {
        return self.quickBarController != nil
    }

    /// Create a `QuickActionBar` instance.
    ///
    /// - Parameter configuration: how the bar looks and behaves; the defaults when omitted
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.presentedConfiguration = configuration
    }

    /// The configuration of the current presentation, or of the last one once the bar has closed.
    internal private(set) var presentedConfiguration: Configuration

    internal weak var quickActionBarWindow: QuickActionBar.Window?
    internal var quickBarController: NSWindowController?
    internal var width: CGFloat = QuickActionBar.DefaultWidth
    internal var height: CGFloat = QuickActionBar.DefaultHeight
    internal var searchImage: NSImage?
    internal var reuseCellView: NSView?
}

public extension QuickActionBar {
    /// Dequeue and clear the previously-cached reusable cell view, if it matches `ReuseView`.
    func dequeueView<ReuseView>() -> ReuseView? {
        if let reuseView = reuseCellView as? ReuseView {
            reuseCellView = nil
            return reuseView
        } else {
            return nil
        }
    }
}

public extension QuickActionBar {
    /// Present a `QuickActionBar` with the current ``configuration``.
    ///
    /// The bar keeps a copy of ``configuration`` until it closes, so a change made while it is open
    /// applies to the next presentation.
    ///
    /// - Parameters:
    ///   - parentWindow: the window to center the quick action bar in, or nil to center on screen
    ///   - initialSearchText: the text to initially populate the search field with
    ///   - didClose: called once the quick action bar has closed
    func present(
        parentWindow: NSWindow? = nil,
        initialSearchText: String? = nil,
        didClose: (() -> Void)? = nil
    ) {
        presentedConfiguration = configuration
        let mainScreenFrame = NSScreen.main?.frame
        self.width = presentedConfiguration.width
            ?? (mainScreenFrame?.width ?? QuickActionBar.DefaultWidth * 4) / 4
        self.height = presentedConfiguration.resultsHeight
            ?? (mainScreenFrame?.height ?? QuickActionBar.DefaultHeight * 4) / 4
        self.searchImage = {
            let configuredImage = presentedConfiguration.searchImage
            guard configuredImage !== Self.DefaultImage else { return configuredImage }
            let scaledImage = QuickActionBar.scaleImageProportionally(configuredImage, to: 64)
            scaledImage?.isTemplate = configuredImage.isTemplate
            return scaledImage
        }()
        let originRect: CGRect
        if let parentWindow = parentWindow {
            originRect = parentWindow.frame
        } else if let screenFrame = NSScreen.main?.frame {
            originRect = screenFrame
        } else {
            return
        }

        let barWidth: CGFloat = width
        let pad = Self.animationPadding

        let quickBarWindow = QuickActionBar.Window()
        self.quickBarController = NSWindowController(window: quickBarWindow)
        self.quickActionBarWindow = quickBarWindow

        quickBarWindow.quickActionBar = self
        quickBarWindow.showKeyboardShortcuts = presentedConfiguration.showsKeyboardShortcuts

        // Set a temporary frame for setup (need a valid size for layout).
        quickBarWindow.setFrame(CGRect(x: 0, y: 0, width: barWidth + pad * 2, height: 200), display: false)
        quickBarWindow.setup(parentWindow: parentWindow, initialSearchText: initialSearchText)

        // Calculate the collapsed content height to size the initial window.
        let collapsedContentHeight = quickBarWindow.collapsedContentHeight()
        let windowHeight = collapsedContentHeight + 2 * pad

        // Position: centered horizontally, offset upward vertically (Spotlight style).
        let originX = originRect.origin.x + ((originRect.width - barWidth) / 2.0)
        let originY = originRect.origin.y + ((originRect.height - collapsedContentHeight) / 1.3)
        let posRect = CGRect(x: originX - pad, y: originY - pad, width: barWidth + pad * 2, height: windowHeight)
        quickBarWindow.setFrame(posRect, display: true)
        quickBarWindow.currentCanBecomeMainWindow = presentedConfiguration.canBecomeMainWindow
        quickBarWindow.placeholderText = presentedConfiguration.placeholderText

        quickBarWindow.didDetectClose = { [weak self, weak quickBarWindow] in
            guard
                let self = self,
                let quickBarWindow,
                self.quickActionBarWindow === quickBarWindow
            else {
                return
            }

            if quickBarWindow.userDidActivateItem == false {
                self.contentSource?.quickActionBarDidCancel(self)
            }

            self.quickBarController = nil
            didClose?()
        }

        // Make sure the application is frontmost or the panel cannot become first responder.
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        quickBarWindow.presentWithAnimation()
        quickBarWindow.startBrowseButtonsPresentationDelay()
    }

    /// Present a `QuickActionBar`, writing the appearance arguments into ``configuration`` first.
    ///
    /// This overwrites the six configuration fields it has arguments for — every one of them, with
    /// its default when the argument is omitted — and leaves ``Configuration/cornerRadius`` and
    /// ``Configuration/requiredClickCount`` as they are.
    ///
    /// - Parameters:
    ///   - parentWindow: the window to center the quick action bar in, or nil to center on screen
    ///   - placeholderText: the placeholder text to display in the search field
    ///   - searchImage: the image to use as the search image. If nil, uses the default magnifying glass image
    ///   - initialSearchText: the text to initially populate the search field with
    ///   - width: the width of the quick action bar to display
    ///   - height: the height of the results list below the search field
    ///   - showKeyboardShortcuts: display keyboard shortcuts for the first 10 entries
    ///   - canBecomeMainWindow: whether the panel can become main
    ///   - didClose: A callback to indicate that the quick action bar has closed
    @available(*, deprecated, message: "Set the appearance on configuration, then call present(parentWindow:initialSearchText:didClose:).")
    @_disfavoredOverload
    func present(
        parentWindow: NSWindow? = nil,
        placeholderText: String? = QuickActionBar.DefaultPlaceholderString,
        searchImage: NSImage? = nil,
        initialSearchText: String? = nil,
        width: CGFloat = (NSScreen.main?.frame.width ?? (QuickActionBar.DefaultWidth * 4)) / 4.0,
        height: CGFloat = (NSScreen.main?.frame.height ?? (QuickActionBar.DefaultHeight * 4)) / 4.0,
        showKeyboardShortcuts: Bool = false,
        canBecomeMainWindow: Bool = true,
        didClose: (() -> Void)? = nil
    ) {
        configuration.placeholderText = placeholderText ?? ""
        configuration.searchImage = searchImage ?? QuickActionBar.DefaultImage
        configuration.width = width
        configuration.resultsHeight = height
        configuration.showsKeyboardShortcuts = showKeyboardShortcuts
        configuration.canBecomeMainWindow = canBecomeMainWindow
        present(parentWindow: parentWindow, initialSearchText: initialSearchText, didClose: didClose)
    }
}

public extension QuickActionBar {
    /// Cancel an active action bar.
    func cancel() {
        if let windowController = self.quickBarController {
            windowController.window?.close()
        }
    }

    /// Reverse an in-progress dismissal and keep presenting the current action bar.
    ///
    /// - Returns: `true` when an active dismissal was reversed; otherwise, `false`.
    @discardableResult
    func resumePresentation() -> Bool {
        guard let quickActionBarWindow, quickActionBarWindow.resumePresentation() else { return false }
        // A delay that ran out while the bar was leaving brought no buttons out.
        quickActionBarWindow.updateBrowseButtons()
        return true
    }
}

public extension QuickActionBar {
    /// Manually push a new set of result identifiers into the bar.
    func provideResultIdentifiers(_ identifiers: [AnyHashable]) {
        self.quickActionBarWindow?.provideResultIdentifiers(identifiers)
    }
}

#endif
