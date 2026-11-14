#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
import UIFoundationToolbox
@testable import UIFoundationAppKit

/// What `FlippedClipView` and `NSScrollView.box.makeFlipped()` promise: a document view that is
/// not flipped opens at its top, where AppKit's own clip view opens it at its bottom.
///
/// The plain clip view is the control: without it, the flipped case would pass against a clip view
/// that changed nothing, had AppKit started opening every document at its top.
@Suite("FlippedClipView")
@MainActor
struct FlippedClipViewTests {
    private static let documentHeight: CGFloat = 1000

    @Test("a plain clip view is flipped exactly when its document view is")
    func plainClipViewFollowsItsDocumentView() {
        let unflippedDocument = makeScrollView(clipView: NSClipView(), documentView: NSView())
        #expect(!unflippedDocument.contentView.isFlipped)

        let flippedDocument = makeScrollView(clipView: NSClipView(), documentView: FlippedDocumentView())
        #expect(flippedDocument.contentView.isFlipped)
    }

    @Test("a plain clip view opens a tall unflipped document at its bottom")
    func plainClipViewOpensAtTheBottom() {
        let scrollView = makeScrollView(clipView: NSClipView(), documentView: NSView())

        // An unflipped document's y runs upwards: its bottom is at 0, its top at its height.
        #expect(scrollView.documentVisibleRect.minY == 0)
        #expect(scrollView.documentVisibleRect.maxY < Self.documentHeight)
    }

    @Test("a flipped clip view opens a tall unflipped document at its top")
    func flippedClipViewOpensAtTheTop() {
        let scrollView = makeScrollView(clipView: FlippedClipView(), documentView: NSView())

        #expect(scrollView.contentView.isFlipped)
        #expect(scrollView.documentVisibleRect.maxY == Self.documentHeight)
    }

    @Test("makeFlipped() installs the clip view on the class it is called on")
    func makeFlippedInstallsTheClipView() {
        let scrollView: SelfSizingScrollView = SelfSizingScrollView.box.makeFlipped()

        #expect(type(of: scrollView) == SelfSizingScrollView.self)
        #expect(scrollView.contentView is FlippedClipView)
    }

    @Test("makeFlipped() leaves the background as a plain scroll view has it")
    func makeFlippedKeepsTheBackground() {
        let plainScrollView = NSScrollView()
        let flippedScrollView = NSScrollView.box.makeFlipped()

        #expect(flippedScrollView.drawsBackground == plainScrollView.drawsBackground)
        #expect(flippedScrollView.backgroundColor == plainScrollView.backgroundColor)
    }

    private func makeScrollView(clipView: NSClipView, documentView: NSView) -> NSScrollView {
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 200, height: 300))
        scrollView.contentView = clipView
        documentView.frame = NSRect(x: 0, y: 0, width: 200, height: Self.documentHeight)
        scrollView.documentView = documentView
        scrollView.tile()
        return scrollView
    }
}

private final class FlippedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

#endif
