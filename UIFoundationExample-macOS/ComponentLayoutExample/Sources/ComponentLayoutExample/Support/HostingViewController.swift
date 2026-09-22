//
//  HostingViewController.swift
//  ComponentLayoutExample
//
//  Ported from lkzhao/UIComponent's example app -- its generic `ViewController`
//  plus `UIView.parentViewController`.
//

import AppKit

/// Wraps a view as a view controller, so it can be presented.
public final class HostingViewController: NSViewController {
    public init(rootView: NSView) {
        super.init(nibName: nil, bundle: nil)
        view = rootView
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension NSView {
    /// The nearest view controller up the responder chain.
    ///
    /// AppKit wires a view controller into the responder chain the same way
    /// UIKit does, so the walk is identical -- only `next` is spelled
    /// `nextResponder`.
    public var parentViewController: NSViewController? {
        var responder: NSResponder? = self
        while let current = responder {
            if let viewController = current as? NSViewController {
                return viewController
            }
            responder = current.nextResponder
        }
        return nil
    }
}
