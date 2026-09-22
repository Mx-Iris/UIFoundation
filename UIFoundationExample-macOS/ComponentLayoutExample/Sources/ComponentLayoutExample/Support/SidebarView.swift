//
//  SidebarView.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app (created by Luke Zhao on
//  11/4/25).
//

import AppKit
import AppKitPlus
import UIFoundationComponent

/// The chapter list.
@available(macOS 14.0, *)
final class SidebarView: ComponentView {
    private let viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        super.init(frame: .zero)
        wantsLayer = true
        layer?.backgroundColor = NSColor.secondarySystemBackground.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard superview != nil else { return }
        setNeedsUpdateProperties()
    }

    override func updateProperties() {
        super.updateProperties()
        let viewModel = viewModel
        let selected = viewModel.selected
        componentEngine.component = VStack {
            for chapter in Chapter.all {
                let isSelected = selected == chapter
                VStack {
                    Text(chapter.title, font: isSelected ? .bodyBold : .body)
                }
                .inset(h: 12, v: 10)
                .size(width: .fill)
                .tappableView { viewModel.selected = chapter }
                .backgroundColor(isSelected ? .secondarySystemFill : .clear)
                .cornerRadius(8)
                .cornerCurve(.continuous)
            }
        }
        .inset(h: 10, v: 20)
        .ignoreHeightConstraint()
        .scrollView()
        .fill()
    }
}
