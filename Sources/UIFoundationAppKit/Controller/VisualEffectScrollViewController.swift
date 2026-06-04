#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

open class VisualEffectScrollViewController<View: NSView>: VisualEffectViewController<View> {
    public let scrollView = NSScrollView()

    open override func loadView() {
        if isVisualEffectEnabled {
            view = visualEffectView
        } else {
            view = NSView()
        }

        view.addSubview(scrollView)
        scrollView.box.pinEdges(to: view)

        scrollView.documentView = contentView
    }

    open override func contentViewDidChange(_ oldContentView: View) {
        scrollView.documentView = contentView
    }
}

#endif
