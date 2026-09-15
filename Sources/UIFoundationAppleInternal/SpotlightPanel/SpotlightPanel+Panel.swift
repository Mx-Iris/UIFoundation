//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Reverse-engineering notes: Researchs/Spotlight-Panel-Internals.md
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// The window itself.
    ///
    /// Configured to match `-[SPSpotlightPanel configureAppearanceAndBehavior]`, with one
    /// deliberate difference: Spotlight leaves `hidesOnDeactivate` off and relies on its own
    /// dismissal paths, whereas this panel's default is to close when it stops being key. A
    /// library's panel is usually raised over someone else's app and has no ⌘Space to come back
    /// through — see ``SpotlightPanel/Configuration/dismissesWhenResigningKey``.
    final class Panel: NSPanel {
        /// Raised when the panel stops being key and the configuration says that dismisses it.
        var resignedKey: (() -> Void)?
        /// Raised for ⌘C when the query field has no selected text.
        var copyRequested: (() -> Bool)?
        /// Raised for ⌘Y.
        var quickLookRequested: (() -> Bool)?

        var dismissesWhenResigningKey = true

        /// `true` while the panel is being taken down, so a late `resignKey` cannot start a
        /// second dismissal on top of the running one.
        var isDismissing = false

        override var canBecomeKey: Bool { true }

        /// Never main. Spotlight sets `becomesKeyOnlyIfNeeded`, which amounts to the same thing:
        /// the panel takes keyboard focus for its field without claiming to be the application's
        /// main window.
        override var canBecomeMain: Bool { false }

        init(contentRect: CGRect) {
            super.init(
                contentRect: contentRect,
                // **`.titled` must stay out of this list.** It buys a heavier drop shadow, and
                // that was the reason it was here for one round, but the price is a second
                // rounded rectangle: a titled window is a real framed window, so the window
                // server strokes its own rounded frame at the *window* bounds and shapes the
                // shadow to them. The platter is inset from those bounds by
                // ``Metrics/animationPadding``, so the frame draws a 40 pt ring around it and
                // the panel reads as two stacked platters. Measured: with `.titled` the window
                // also reserves a 32 pt titlebar (`contentLayoutRect` came back 32 points short
                // of the content rect) and carries an `NSTitlebarContainerView`.
                // `SpotlightPanelWindowChromeTests` keeps a canary on both.
                //
                // Borderless gets its shadow the right way instead: the window server derives it
                // from the composited alpha, so it hugs the platter and follows the present /
                // dismiss scale.
                styleMask: [.nonactivatingPanel, .borderless],
                backing: .buffered,
                defer: false
            )

            configureAppearanceAndBehavior()
        }

        /// `-[SPSpotlightPanel configureAppearanceAndBehavior]`, line for line.
        private func configureAppearanceAndBehavior() {
            becomesKeyOnlyIfNeeded = true
            isReleasedWhenClosed = false
            level = NSWindow.Level(23)
            isOpaque = false
            backgroundColor = .clear
            hidesOnDeactivate = false
            isMovable = false
            isMovableByWindowBackground = false
            autorecalculatesKeyViewLoop = true

            // `titleVisibility` / `titlebarAppearsTransparent` are deliberately absent: they are
            // no-ops without `.titled`, and writing them would suggest there is a titlebar here
            // being hidden rather than one that was never asked for.
            isFloatingPanel = true
            hasShadow = true
            animationBehavior = .none
            collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            SpotlightPanel.enableCursorInBackgroundIfNeeded()
        }

        override func resignKey() {
            super.resignKey()
            guard dismissesWhenResigningKey, !isDismissing else { return }
            resignedKey?()
        }

        /// ⌘C and ⌘Y, which never reach `doCommandBy:` because they are key equivalents rather
        /// than text-editing commands, and which the field editor would otherwise swallow.
        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            guard event.modifierFlags.contains(.command) else {
                return super.performKeyEquivalent(with: event)
            }

            switch event.charactersIgnoringModifiers {
            case "c" where copyRequested?() == true:
                return true
            case "y" where quickLookRequested?() == true:
                return true
            default:
                return super.performKeyEquivalent(with: event)
            }
        }
    }
}

#endif
