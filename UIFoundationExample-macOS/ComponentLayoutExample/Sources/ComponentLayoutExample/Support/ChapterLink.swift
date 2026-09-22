//
//  ChapterLink.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/6/25).
//

import AppKit
import AppKitPlus
import UIFoundationComponent

/// A tappable row that jumps to another chapter, optionally scrolling to a
/// specific anchor inside it.
///
/// - Note: Upstream addresses the target by metatype (`viewType:`). Here it is
///   the chapter's identifier, because ``Chapter`` holds a factory closure
///   rather than a metatype -- `NSView.init()` is not `required`, so a metatype
///   cannot be called.
@available(macOS 14.0, *)
public struct ChapterLink: Component {
    let title: String
    let chapterIdentifier: String
    let anchorId: String?

    public init(title: String, chapterIdentifier: String, anchorId: String? = nil) {
        self.title = title
        self.chapterIdentifier = chapterIdentifier
        self.anchorId = anchorId
    }

    public func layout(_ constraint: Constraint) -> some RenderNode {
        let chapterIdentifier = chapterIdentifier
        let anchorId = anchorId
        return HStack(spacing: 8, alignItems: .center) {
            Text(title, font: .bodyBold)
            Image(systemName: "arrow.up.right").tintColor(.label)
        }
        .inset(h: 16, v: 12)
        .tappableView { view in
            guard
                let homeView = view.enclosingHomeView,
                let chapter = Chapter.all.first(where: { $0.identifier == chapterIdentifier })
            else { return }

            homeView.viewModel.selected = chapter
            // Observation would re-drive this on the next run loop turn, but the
            // anchor below needs the new chapter's views to exist *now*.
            homeView.updateProperties()
            homeView.componentEngine.reloadData()

            if let anchorId {
                homeView.subviews
                    .compactMap { $0 as? ChapterView }
                    .first?
                    .scrollToComponent(id: anchorId)
            }
        }
        .view()
        .codeBlockStyle()
        .eraseToAnyComponent()
        .layout(constraint)
    }
}

extension NSView {
    /// Walks up to the example's root view.
    @available(macOS 14.0, *)
    fileprivate var enclosingHomeView: HomeView? {
        var candidate: NSView? = self
        while let current = candidate {
            if let homeView = current as? HomeView { return homeView }
            candidate = current.superview
        }
        return nil
    }

    /// Scrolls this chapter's scroll view so a component with `id` is near the top.
    fileprivate func scrollToComponent(id: String) {
        guard
            let scrollView = subviews.compactMap({ $0 as? ComponentScrollView }).first,
            let frame = scrollView.renderingEngine.frame(id: id)
        else { return }
        // AppKit scrolls a document view, so the offset is applied to the clip
        // view's bounds origin rather than to the scroll view itself.
        scrollView.contentView.setBoundsOrigin(CGPoint(x: 0, y: frame.minY - 20))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}
