//
//  ComponentEngine+AppKit.swift
//  UIFoundation
//
//  The two things the engine needs on AppKit that UIKit gives it for free:
//  a coordinate space that grows downwards, and a signal when the user scrolls.
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit

extension ComponentEngine {
    /// Renders into a flipped container when the host view is not flipped.
    ///
    /// The layout system places children from the top-left downwards. AppKit
    /// draws from the bottom-left unless a view is flipped, so an unflipped
    /// host would show the entire layout upside down.
    ///
    /// Flipping one container is enough because rendering is *flat*: the engine
    /// hands `ComponentViewDiffApplier` a single array of renderables carrying
    /// final frames, and they all become direct subviews of one container.
    /// There is no nesting to convert. Flipping each frame instead would mean
    /// undoing the flip again for visible-frame culling, for scroll offsets and
    /// on every content-size change -- three more places to get it wrong.
    ///
    /// A host that is already flipped (``ComponentView``, or any view of yours
    /// overriding `isFlipped`) gets no extra view. A `contentView` you set
    /// yourself is left alone.
    func installFlippedContainerIfNeeded() {
        guard let view, !view.isFlipped, contentView == nil else { return }
        contentView = ComponentFlippedContainerView()
    }

    /// Keeps a scroll observation pointed at the clip view currently scrolling
    /// this content.
    ///
    /// UIKit learns about scrolling through the swizzled `setBounds:` on the
    /// scroll view itself. AppKit scrolls by moving the *clip view's* bounds,
    /// and that view belongs to `NSScrollView`, not to us -- so the signal has
    /// to come from a notification instead.
    ///
    /// Re-points rather than registering once, because the enclosing scroll
    /// view can change over a view's lifetime (or not exist yet at the first
    /// layout pass).
    func updateScrollObservationIfNeeded() {
        let clipView = view?.enclosingScrollView?.contentView
        guard clipView !== observedClipView else { return }

        if let clipViewObservation {
            NotificationCenter.default.removeObserver(clipViewObservation)
            self.clipViewObservation = nil
        }
        observedClipView = clipView

        guard let clipView else { return }
        clipView.postsBoundsChangedNotifications = true
        clipViewObservation = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.setNeedsRender()
        }
    }
}

/// The flipped container the engine renders into when its host is not flipped.
final class ComponentFlippedContainerView: NSView {
    override var isFlipped: Bool { true }
}
#endif
