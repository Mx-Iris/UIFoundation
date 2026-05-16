//
//  QuickActionBar.swift
//  UIFoundation
//
//  Ported into UIFoundation from DSFQuickActionBar by Darren Ford
//  (https://github.com/dagronf/DSFQuickActionBar).
//
//  MIT License — Copyright (c) 2022 Darren Ford
//

#if QuickActionBar

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

    /// The number of clicks required to activate a row in the results view.
    public var requiredClickCount: RequiredClickCount = .double

    /// The content source for the bar.
    public weak var contentSource: QuickActionBarContentSource?

    /// Row height used when automatic row heights are not available.
    public var rowHeight: CGFloat = 36

    /// The current search text.
    public var currentSearchText: String? {
        quickActionBarWindow?.currentSearchText
    }

    /// Is the quick action bar currently presented on screen?
    public var isPresenting: Bool {
        return self.quickBarController != nil
    }

    /// Create a `QuickActionBar` instance.
    public init() {}

    internal weak var quickActionBarWindow: QuickActionBar.Window?
    internal var quickBarController: NSWindowController?
    internal var onCloseCallback: (() -> Void)?
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
    /// Present a `QuickActionBar`.
    ///
    /// - Parameters:
    ///   - parentWindow: the window to center the quick action bar in, or nil to center on screen
    ///   - placeholderText: the placeholder text to display in the search field
    ///   - searchImage: the image to use as the search image. If nil, uses the default magnifying glass image
    ///   - initialSearchText: the text to initially populate the search field with
    ///   - width: the width of the quick action bar to display
    ///   - height: the height of the quick action bar to display
    ///   - showKeyboardShortcuts: display keyboard shortcuts for the first 10 entries
    ///   - canBecomeMainWindow: whether the panel can become main
    ///   - didClose: A callback to indicate that the quick action bar has closed
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
        self.width = width
        self.height = height
        self.searchImage = {
            if let searchImage = searchImage {
                let scaled = QuickActionBar.scaleImageProportionally(searchImage, to: 64)
                scaled?.isTemplate = searchImage.isTemplate
                return scaled
            } else {
                return Self.DefaultImage
            }
        }()
        self.onCloseCallback = didClose

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
        quickBarWindow.showKeyboardShortcuts = showKeyboardShortcuts

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
        quickBarWindow.currentCanBecomeMainWindow = canBecomeMainWindow
        quickBarWindow.placeholderText = placeholderText ?? ""

        quickBarWindow.didDetectClose = { [weak self] in
            guard
                let self = self,
                let window = self.quickActionBarWindow
            else {
                return
            }

            if window.userDidActivateItem == false {
                self.contentSource?.quickActionBarDidCancel(self)
            }

            self.quickBarController = nil
            self.onCloseCallback?()
        }

        // Make sure the application is frontmost or the panel cannot become first responder.
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }

        quickBarWindow.presentWithAnimation()
    }
}

public extension QuickActionBar {
    /// Cancel an active action bar.
    func cancel() {
        if let wc = self.quickBarController {
            wc.window?.close()
        }
    }
}

public extension QuickActionBar {
    /// Manually push a new set of result identifiers into the bar.
    func provideResultIdentifiers(_ identifiers: [AnyHashable]) {
        self.quickActionBarWindow?.provideResultIdentifiers(identifiers)
    }
}

#endif
