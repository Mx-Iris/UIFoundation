#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationShared
import UIFoundationToolbox

open class VisualEffectViewController<View: NSView>: XiblessViewController<View> {
    public let visualEffectView = NSVisualEffectView()
    
    open var isVisualEffectEnabled: Bool { true }
    
    open override func loadView() {
        if isVisualEffectEnabled {
            view = visualEffectView
        } else {
            view = NSView()
        }
        
        addContentView()
    }

    open override func contentViewDidChange(_ oldContentView: View) {
        oldContentView.removeFromSuperview()
        addContentView()
    }

    private func addContentView() {
        view.addSubview(contentView)
        contentView.box.pinEdges(to: view)
    }
}

#endif
