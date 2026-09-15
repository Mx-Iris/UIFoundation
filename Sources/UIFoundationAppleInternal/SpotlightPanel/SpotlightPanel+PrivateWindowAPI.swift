//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Reverse-engineering notes: Researchs/Spotlight-Panel-Internals.md
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit
import UIFoundationAppleInternalObjC

// MARK: - Window content blur

extension NSWindow {
    /// The KVC key the content blur animates under.
    ///
    /// `-_setContentBlurRadius:` matches KVC's `_set<Key>:` search form for the key
    /// `contentBlurRadius`, which is why an entry under this name in ``NSWindow/animations``
    /// animates it. Spotlight uses the same string.
    static let spotlightPanelContentBlurRadiusKeyPath = "contentBlurRadius"

    /// Set the blur immediately, with no animation, doing nothing when the private setter is
    /// gone.
    func setSpotlightPanelContentBlurRadius(_ contentBlurRadius: CGFloat) {
        guard SpotlightPanel.isContentBlurSupported else { return }
        _setContentBlurRadius(contentBlurRadius)
    }
}

extension SpotlightPanel {
    /// Whether this build of AppKit still carries the private content-blur setter.
    ///
    /// Checked rather than assumed because the blur runs on the dismissal path: losing the effect
    /// on some future OS is acceptable, crashing on it is not. Exposed so a host can tell the
    /// difference between "the dismissal looks plainer than expected" and a bug of its own.
    public static var isContentBlurSupported: Bool {
        NSWindow.instancesRespond(to: #selector(NSWindow._setContentBlurRadius(_:)))
    }
}

// MARK: - Cursor in background

/// `CGSMainConnectionID` — the window server connection this process already owns.
@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> Int32

/// `CGSSetConnectionProperty` — attaches a key/value to a window server connection.
@_silgen_name("CGSSetConnectionProperty")
private func CGSSetConnectionProperty(
    _ connectionIdentifier: Int32,
    _ targetConnectionIdentifier: Int32,
    _ key: CFString,
    _ value: CFTypeRef
) -> CGError

extension SpotlightPanel {
    /// Let the process set the cursor while it is not the frontmost application.
    ///
    /// Spotlight does this once during panel setup. Without it a panel that takes key focus
    /// without activating its application cannot show an I-beam over its own search field.
    ///
    /// Idempotent and process-wide, so it runs at most once.
    static func enableCursorInBackgroundIfNeeded() {
        guard !hasEnabledCursorInBackground else { return }
        hasEnabledCursorInBackground = true

        let connectionIdentifier = CGSMainConnectionID()
        _ = CGSSetConnectionProperty(
            connectionIdentifier,
            connectionIdentifier,
            "SetsCursorInBackground" as CFString,
            kCFBooleanTrue
        )
    }

    @MainActor
    private static var hasEnabledCursorInBackground = false
}

#endif
