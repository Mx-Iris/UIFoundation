#if AppleInternal && os(macOS)

import AppKit
import Testing
import FrameworkToolbox
import UIFoundationAppleInternal

/// Covers `NSToolbar.box.preferredCenteredItemWidthRatio`, and the AppKit behaviour its documentation states: the
/// centered item is laid out at the ratio of the toolbar's width, and takes its maximum width without one.
/// Measured on macOS 27.2.
///
/// The fixture is a window outside every display whose toolbar holds a flexible space, a centered item and another
/// flexible space. The centered item's view is constrained the way Xcode 26 constrains its Activity View: at least
/// 160 points wide, and at most 2000 at priority 450, above the toolbar's measuring pull. Reverse-engineering notes:
/// `Researchs/AppKit-NSToolbar-CenteredItemWidthRatio-Internals.md`.
@Suite("NSToolbar centered item width ratio", .serialized)
@MainActor
struct ToolbarCenteredItemWidthTests {
    @Test("A toolbar starts with −1, no preference, and reads back the ratio assigned")
    func readsBackAssignedRatio() {
        let toolbar = NSToolbar(identifier: "ToolbarCenteredItemWidthTests.readsBackAssignedRatio")

        #expect(toolbar.box.preferredCenteredItemWidthRatio == -1)

        toolbar.box.preferredCenteredItemWidthRatio = 0.4

        #expect(toolbar.box.preferredCenteredItemWidthRatio == 0.4)
    }

    @Test("Assigning nil leaves the ratio as it was")
    func assigningNilChangesNothing() {
        let toolbar = NSToolbar(identifier: "ToolbarCenteredItemWidthTests.assigningNilChangesNothing")
        toolbar.box.preferredCenteredItemWidthRatio = 0.4

        toolbar.box.preferredCenteredItemWidthRatio = nil

        #expect(toolbar.box.preferredCenteredItemWidthRatio == 0.4)
    }

    @Test("The centered item is laid out at the ratio of the toolbar's width")
    func centeredItemTakesRatioOfToolbarWidth() throws {
        let fixture = Fixture(windowWidth: 1200, ratio: 0.4)
        defer { fixture.tearDown() }

        fixture.layOut()

        let toolbarViewWidth = try #require(fixture.toolbarViewWidth)
        #expect(fixture.centeredView.frame.width == (0.4 * toolbarViewWidth).rounded(.up))
    }

    @Test("Without a ratio the centered item takes its maximum width, as far as the room allows")
    func centeredItemWithoutRatioIsWider() throws {
        let withRatio = Fixture(windowWidth: 1200, ratio: 0.4)
        defer { withRatio.tearDown() }
        let withoutRatio = Fixture(windowWidth: 1200, ratio: nil)
        defer { withoutRatio.tearDown() }

        withRatio.layOut()
        withoutRatio.layOut()

        let toolbarViewWidth = try #require(withoutRatio.toolbarViewWidth)
        #expect(withoutRatio.centeredView.frame.width > withRatio.centeredView.frame.width)
        #expect(withoutRatio.centeredView.frame.width > 0.4 * toolbarViewWidth)
    }

    /// Measured on macOS 27.2, the opposite of what macOS 26.6's disassembly was read to say: a width below the
    /// minimum is not raised to it, the preference is dropped. 0.13 × 1200 rounds up to 156, below 160; 0.14 × 1200
    /// rounds up to 169, and is taken.
    @Test("A ratio that would take the centered item below its minimum width is ignored, as no preference is")
    func ratioBelowMinimumWidthIsIgnored() {
        let belowMinimum = Fixture(windowWidth: 1200, ratio: 0.13)
        defer { belowMinimum.tearDown() }
        let withoutRatio = Fixture(windowWidth: 1200, ratio: nil)
        defer { withoutRatio.tearDown() }
        let aboveMinimum = Fixture(windowWidth: 1200, ratio: 0.14)
        defer { aboveMinimum.tearDown() }

        belowMinimum.layOut()
        withoutRatio.layOut()
        aboveMinimum.layOut()

        #expect(belowMinimum.centeredView.frame.width == withoutRatio.centeredView.frame.width)
        #expect(aboveMinimum.centeredView.frame.width == 169)
    }

    @Test("The toolbar applies a ratio assigned after it went into the window at its next layout")
    func ratioAssignedLaterAppliesAtNextLayout() throws {
        let fixture = Fixture(windowWidth: 1200, ratio: nil)
        defer { fixture.tearDown() }
        fixture.layOut()

        fixture.toolbar.box.preferredCenteredItemWidthRatio = 0.4
        fixture.window.setFrame(fixture.window.frame.insetBy(dx: -10, dy: 0), display: false)
        fixture.layOut()

        let toolbarViewWidth = try #require(fixture.toolbarViewWidth)
        #expect(fixture.centeredView.frame.width == (0.4 * toolbarViewWidth).rounded(.up))
    }

    @MainActor
    final class Fixture: NSObject, NSToolbarDelegate {
        static let centeredItemIdentifier = NSToolbarItem.Identifier("ToolbarCenteredItemWidthTests.centered")

        let window: NSWindow
        let toolbar: NSToolbar
        let centeredView: NSView

        init(windowWidth: CGFloat, ratio: CGFloat?) {
            centeredView = NSView()
            centeredView.translatesAutoresizingMaskIntoConstraints = false
            let maximumWidth = centeredView.widthAnchor.constraint(lessThanOrEqualToConstant: 2000)
            maximumWidth.priority = NSLayoutConstraint.Priority(450)
            NSLayoutConstraint.activate([
                centeredView.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
                maximumWidth,
                centeredView.heightAnchor.constraint(equalToConstant: 24),
            ])

            toolbar = NSToolbar(identifier: "ToolbarCenteredItemWidthTests.Fixture")
            window = NSWindow(
                contentRect: NSRect(x: -6000, y: -6000, width: windowWidth, height: 400),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            super.init()

            window.isReleasedWhenClosed = false
            toolbar.delegate = self
            toolbar.allowsUserCustomization = false
            toolbar.displayMode = .iconOnly
            toolbar.centeredItemIdentifiers = [Self.centeredItemIdentifier]
            if let ratio {
                toolbar.box.preferredCenteredItemWidthRatio = ratio
            }
            window.toolbarStyle = .unified
            window.toolbar = toolbar
        }

        func layOut() {
            window.layoutIfNeeded()
            window.contentView?.superview?.layoutSubtreeIfNeeded()
        }

        /// The width of the view the toolbar lays its items out in: the enclosing `NSToolbarView`.
        var toolbarViewWidth: CGFloat? {
            guard let toolbarViewClass = NSClassFromString("NSToolbarView") else { return nil }
            var ancestor = centeredView.superview
            while let view = ancestor {
                if view.isKind(of: toolbarViewClass) {
                    return view.frame.width
                }
                ancestor = view.superview
            }
            return nil
        }

        func tearDown() {
            window.toolbar = nil
            window.close()
        }

        nonisolated func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [.flexibleSpace, Self.centeredItemIdentifier, .flexibleSpace]
        }

        nonisolated func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
            [.flexibleSpace, Self.centeredItemIdentifier]
        }

        nonisolated func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
            MainActor.assumeIsolated {
                guard itemIdentifier == Self.centeredItemIdentifier else { return nil }
                let item = NSToolbarItem(itemIdentifier: itemIdentifier)
                item.view = centeredView
                return item
            }
        }
    }
}

#endif
