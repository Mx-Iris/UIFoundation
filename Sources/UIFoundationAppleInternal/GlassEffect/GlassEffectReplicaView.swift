//
//  Measured on macOS 27.0 AppKit (2775.10.103.1).
//  Reverse-engineering notes: Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md
//  Decision record: Documentations/Evolutions/0022-glass-effect-replica-view.md
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import QuartzCore
import UIFoundationAppKit
import UIFoundationAppleInternalObjC

/// An opaque view that renders exactly like the `NSGlassEffectView` it sits inside.
///
/// From macOS 26 the split view wraps a sidebar or inspector item's content in an
/// `NSGlassEffectView`, and the glass's colour is composed by the window server from whatever is
/// behind the window plus a desktop-sampling tint, so it shifts with the window's position and key
/// state. No `NSColor`, no `NSVisualEffectView` material and no second glass view matches it: a
/// glass nested in the content samples the outer glass's output and tints it a second time
/// (measured rgb(41, 41, 45) against rgb(40, 40, 43)).
///
/// This view holds its own `NSGlassEffectView`, copies the enclosing glass's configuration onto it
/// (`matchGlassConfiguration(of:)`) and then puts the two into one Core Animation backdrop group —
/// the group captures its backdrop once and both layers filter the same capture, so the replica is
/// pixel-identical to its surroundings whether the window is key, inactive, moved or resized, and it
/// is opaque: a page that carries it can slide over another page without the two showing through
/// each other. That is what a navigation transition inside a glass sidebar needs. The group name is
/// pinned onto the layer (``GroupPinnedBackdropLayer``), because SwiftUI writes its own name back
/// on some updates — measured on the window becoming key — and a name merely set once is lost then.
///
/// Contracts a host has to know:
///
/// - **It must end up inside an `NSGlassEffectView`'s content.** Outside one it finds nothing to
///   replicate and stays transparent, which is harmless but does nothing.
/// - **The first frame is not yet shared.** SwiftUI builds the glass's layers a run loop turn after
///   the view enters a window, and the group is joined right after that (polled at frame rate for
///   up to two seconds, then re-checked on every `layout()`). Until then the replica renders as an
///   ordinary nested glass, one tint step off. A page pushed from off screen, or uncovered by a
///   page sliding away, never shows that frame.
/// - **Add content above it, not below.** The glass is the bottom-most subview; `addSubview(_:)`
///   keeps it there, `addSubview(_:positioned:relativeTo:)` with `.below` and `nil` does not.
/// - **Everything here is private AppKit and Core Animation.** When
///   ``NSGlassEffectView/isPrivateConfigurationSupported`` turns false the replica still shares the
///   group but can no longer copy the variant; check ``isSharingBackdropGroup`` when diagnosing a
///   sidebar that suddenly looks wrong on a new OS.
@available(macOS 26.0, *)
public final class GlassEffectReplicaView: LayerBackedView {
    /// How often, and for how long, to look for the glass's layers after entering a window.
    ///
    /// A run loop turn or two is the measured norm; two seconds of headroom covers a window that is
    /// slow to display. After that only ``layout()`` keeps trying, which is enough for a view that
    /// is on screen. A timer rather than a `CATransaction` completion block: the latter is not
    /// delivered in every process (a `swift test` host, for one), and the sharing must not depend
    /// on Core Animation choosing to call back.
    private static let backdropGroupShareRetryInterval: TimeInterval = 1.0 / 60.0
    private static let maximumBackdropGroupShareAttempts = 120

    /// The glass that does the rendering. Exposed for inspection only; its configuration is
    /// overwritten whenever the enclosing glass is resolved.
    public let glassEffectView = NSGlassEffectView()

    /// The glass this view currently replicates, or `nil` outside any.
    public private(set) weak var enclosingGlassEffectView: NSGlassEffectView?

    /// `true` once both backdrop layers exist and carry the same group name — the state in which
    /// the replica is pixel-identical to its surroundings.
    public var isSharingBackdropGroup: Bool {
        guard let enclosingGlassEffectView,
              let groupName = enclosingGlassEffectView.glassBackdropGroupName,
              let ownGroupName = glassEffectView.glassBackdropGroupName
        else { return false }
        return groupName == ownGroupName
    }

    private var remainingBackdropGroupShareAttempts = 0

    private var backdropGroupShareTimer: Timer?

    deinit {
        backdropGroupShareTimer?.invalidate()
        windowKeyStateObservers.forEach(NotificationCenter.default.removeObserver)
    }

    public override func setup() {
        super.setup()

        glassEffectView.cornerRadius = 0
        glassEffectView.frame = bounds
        glassEffectView.autoresizingMask = [.width, .height]
        // Transparent until there is a glass to replicate: a replica with nothing to copy would
        // otherwise paint a default glass that matches nothing around it.
        glassEffectView.isHidden = true
        addSubview(glassEffectView, positioned: .below, relativeTo: nil)
    }

    public override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        resolveEnclosingGlassEffectView()
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeWindowKeyState()
        resolveEnclosingGlassEffectView()
    }

    // MARK: - Window key state

    private var windowKeyStateObservers: [NSObjectProtocol] = []

    /// A key-state change is the one update SwiftUI was measured to rewrite the backdrop group
    /// name on. The pinned layer answers that by itself; observing the change as well covers
    /// SwiftUI replacing the layer outright, which a pin on the old instance cannot.
    private func observeWindowKeyState() {
        let notificationCenter = NotificationCenter.default
        windowKeyStateObservers.forEach(notificationCenter.removeObserver)
        windowKeyStateObservers = []
        guard let window else { return }
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            let observer = notificationCenter.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.scheduleBackdropGroupShare()
                }
            }
            windowKeyStateObservers.append(observer)
        }
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        // An appearance change can make SwiftUI rebuild the glass's layer tree, and a rebuilt
        // backdrop layer comes with a fresh, unshared group name.
        scheduleBackdropGroupShare()
    }

    public override func layout() {
        super.layout()
        shareBackdropGroupIfNeeded()
    }

    // MARK: - Replication

    private func resolveEnclosingGlassEffectView() {
        guard let superview, window != nil,
              let enclosingGlassEffectView = NSGlassEffectView.enclosingGlassEffectView(of: superview)
        else {
            self.enclosingGlassEffectView = nil
            glassEffectView.isHidden = true
            stopBackdropGroupShareRetries()
            return
        }
        self.enclosingGlassEffectView = enclosingGlassEffectView
        glassEffectView.matchGlassConfiguration(of: enclosingGlassEffectView)
        glassEffectView.isHidden = false
        scheduleBackdropGroupShare()
    }

    /// The glass's layers appear only after the run loop has turned and SwiftUI has rendered, so
    /// the sharing is retried on a timer for a while. The timer runs its full course even when a
    /// layer is found at once: a page coming back into a window still holds the layers from its
    /// last stay, and SwiftUI replaces them — with unpinned, freshly named ones — a turn or two
    /// later (measured on a navigation pop). Each tick pins whatever layer is current.
    private func scheduleBackdropGroupShare() {
        guard enclosingGlassEffectView != nil else { return }
        stopBackdropGroupShareRetries()
        shareBackdropGroupIfNeeded()
        remainingBackdropGroupShareAttempts = Self.maximumBackdropGroupShareAttempts
        let timer = Timer(timeInterval: Self.backdropGroupShareRetryInterval, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.remainingBackdropGroupShareAttempts -= 1
                self.shareBackdropGroupIfNeeded()
                if self.remainingBackdropGroupShareAttempts <= 0 {
                    self.stopBackdropGroupShareRetries()
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        backdropGroupShareTimer = timer
    }

    private func stopBackdropGroupShareRetries() {
        backdropGroupShareTimer?.invalidate()
        backdropGroupShareTimer = nil
        remainingBackdropGroupShareAttempts = 0
    }

    /// Joins the enclosing glass's backdrop group when both backdrop layers exist, and pins the
    /// name so SwiftUI's later rewrites (measured on the window becoming key) cannot undo it.
    /// Returns whether both layers existed; a `false` means "not built yet", not failure.
    @discardableResult
    private func shareBackdropGroupIfNeeded() -> Bool {
        guard let enclosingGlassEffectView,
              let groupName = enclosingGlassEffectView.glassBackdropGroupName,
              let ownBackdropLayer = glassEffectView.glassBackdropLayer
        else { return false }
        GroupPinnedBackdropLayer.pin(ownBackdropLayer, to: groupName)
        return true
    }
}

#endif
