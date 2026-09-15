#if SpotlightPanel && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppleInternal

/// The window's own chrome.
///
/// The panel is a **borderless** window, and the reason is visual rather than stylistic: the
/// platter is inset from the window's bounds by `Metrics.animationPadding` so the present
/// animation's 1.12 scale has room, which means anything the window draws at its own bounds
/// appears as a second rounded rectangle 40 points outside the platter. `.titled` draws exactly
/// that — a system window frame plus a shadow shaped to the window rect — and the panel reads as
/// two stacked platters.
@Suite("SpotlightPanel window chrome")
@MainActor
struct SpotlightPanelWindowChromeTests {
    private let contentSize = CGSize(width: 760, height: 510)

    private func makePanel() -> SpotlightPanel.Panel {
        SpotlightPanel.Panel(contentRect: CGRect(origin: .zero, size: contentSize))
    }

    // MARK: The regression

    /// `.titled` is the one that puts a frame around the window. `.fullSizeContentView` only
    /// means anything alongside it, so it goes too.
    @Test("The panel window is borderless and never titled")
    func windowIsBorderless() {
        let panel = makePanel()

        #expect(!panel.styleMask.contains(.titled))
        #expect(!panel.styleMask.contains(.fullSizeContentView))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
    }

    /// The observable consequence, and the one that fails loudly: a titled window reserves a
    /// 32-point titlebar, so `contentLayoutRect` comes back 32 points shorter than the content
    /// rect it was built with. Measured on macOS 26 — with `.titled` this read 478 against 510.
    @Test("The whole content rect is laid out, with no titlebar reserved")
    func noTitlebarIsReserved() {
        let panel = makePanel()

        #expect(panel.contentLayoutRect == CGRect(origin: .zero, size: contentSize))
        #expect(panel.contentView?.frame.size == contentSize)
    }

    /// The other half of the same measurement, from the view side: a titled window's frame view
    /// is an `NSThemeFrame` carrying an `NSTitlebarContainerView`. A borderless one is an
    /// `NSNextStepFrame` with nothing but the content view in it.
    @Test("The window's frame view carries no titlebar container")
    func frameViewCarriesNoTitlebar() {
        let panel = makePanel()
        panel.contentView = NSView()

        let frameView = panel.contentView?.superview
        #expect(frameView != nil)

        let titlebarContainers = frameView?.subviews.filter {
            String(describing: type(of: $0)).contains("Titlebar")
        }
        #expect(titlebarContainers?.isEmpty == true)
    }

    // MARK: What borderless makes load-bearing

    /// A borderless window cannot become key on its own — `NSWindow.canBecomeKey` is `false` for
    /// one. The override is therefore the only thing that lets the query field take focus, where
    /// under `.titled` it was merely restating the default. Deleting it as "redundant" would
    /// leave a panel nobody can type into.
    @Test("The borderless panel can still become key")
    func borderlessPanelCanBecomeKey() {
        #expect(makePanel().canBecomeKey)
        #expect(!makePanel().canBecomeMain)
    }

    /// The shadow is still wanted; borderless just derives it from the composited alpha, so it
    /// hugs the platter instead of the window rect.
    @Test("The panel keeps its shadow")
    func panelKeepsItsShadow() {
        #expect(makePanel().hasShadow)
    }
}

#endif
