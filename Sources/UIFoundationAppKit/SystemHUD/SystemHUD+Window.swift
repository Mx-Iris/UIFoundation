//
//  Ported from Mx-Iris/SystemHUD
//  https://github.com/Mx-Iris/SystemHUD
//

#if SystemHUD && os(macOS)

import AppKit

extension SystemHUD {
    /// The borderless panel the HUD content lives in.
    final class Window: NSWindow {
        let hudContentView: ContentView

        init(configuration: SystemHUD.Configuration) {
            self.hudContentView = ContentView(configuration: configuration)
            super.init(
                contentRect: .init(origin: .zero, size: configuration.minimumSize),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )

            isOpaque = false
            hasShadow = false
            backgroundColor = .clear
            level = .floating
            // A HUD is a readout, not a control: it must never swallow a click, not even while it
            // sits fully faded out — the panel is left ordered in between showings.
            ignoresMouseEvents = true
            // Follow the user across spaces and stay put in Mission Control, the way the system
            // volume HUD does.
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            isReleasedWhenClosed = false
            contentView = hudContentView
        }
    }
}

#endif
