//
//  HomeView.swift
//  ComponentLayoutExample
//
//  Sidebar plus the selected chapter, ported from lkzhao/UIComponent's example
//  app (created by Luke Zhao on 11/4/25).
//

import AppKit
import AppKitPlus
import Observation
import UIFoundationComponent

// `@Observable` is macOS 14. The package floor stays at the app's own
// deployment target, so the requirement is expressed here instead -- see
// Package.swift.
@available(macOS 14.0, *)
@Observable
final class HomeViewModel {
    var selected: Chapter = Chapter.all[0]
}

/// The example's root view: a chapter list on the left, the selected chapter on
/// the right.
@available(macOS 14.0, *)
public final class HomeView: ComponentView {
    let viewModel = HomeViewModel()

    private lazy var sidebarView = SidebarView(viewModel: viewModel)

    public init() {
        super.init(frame: .zero)
        // Compiling tree-sitter's `highlights.scm` costs ~78 ms, once per
        // process. Started here it is over long before a chapter is picked;
        // left to the first code block it would land inside a layout pass.
        SwiftSyntaxHighlighter.shared.warmUp()
        // Layer backing is inherited by the whole subtree, and the chapters'
        // `.backgroundColor(…)` writes straight onto a layer -- a view without
        // one silently drops the colour. Turning it on once here covers every
        // sample below.
        wantsLayer = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard superview != nil else { return }
        setNeedsUpdateProperties()
    }

    public override func updateProperties() {
        super.updateProperties()
        // Reading `selected` here is what arms Observation: picking another
        // chapter in the sidebar re-drives this method on its own.
        let chapter = viewModel.selected
        componentEngine.component = HStack {
            sidebarView.size(width: 210, height: .fill)
            Separator()
            ViewComponent(generator: chapter.makeView())
                .id(chapter.identifier)
                .fill()
                .flex()
        }
        .fill()
    }
}
