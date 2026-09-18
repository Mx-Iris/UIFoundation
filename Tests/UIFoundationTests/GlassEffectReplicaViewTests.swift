#if AppleInternal && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppleInternal

/// The replica's two halves: copying the enclosing glass's configuration, which is synchronous and
/// fully testable, and joining its backdrop group, which waits on SwiftUI building the glass's
/// layers and is only observable in a process that renders.
///
/// **The bug these guard against:** a nested `NSGlassEffectView` that merely *looks* configured
/// like the split view's sidebar glass renders one tint step off (rgb(41, 41, 45) against
/// rgb(40, 40, 43) on macOS 27.0), because it samples the outer glass's output instead of the
/// window's backdrop. Only sharing the `CABackdropLayer` group closes that gap, and the private
/// `_backdropGroupName` / `_groupIdentifier` properties do not reach the layer — so the group has
/// to be written onto the layer itself, after it exists.
@Suite("GlassEffectReplicaView")
@MainActor
struct GlassEffectReplicaViewTests {
    private func makeWindow() -> NSWindow {
        NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
    }

    /// The shape AppKit's `_NSSplitViewItemViewWrapper` builds: a glass whose `contentView` holds
    /// the item's view, here standing in for a page that carries the replica.
    @available(macOS 26.0, *)
    private func makeSidebarGlass(holding replicaView: GlassEffectReplicaView) -> NSGlassEffectView {
        let sidebarGlassEffectView = NSGlassEffectView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        sidebarGlassEffectView.cornerRadius = 0
        if NSGlassEffectView.isPrivateConfigurationSupported {
            sidebarGlassEffectView._variant = 17
            sidebarGlassEffectView._adaptiveAppearance = 1
        }
        let pageView = NSView(frame: sidebarGlassEffectView.bounds)
        replicaView.frame = pageView.bounds
        pageView.addSubview(replicaView)
        sidebarGlassEffectView.contentView = pageView
        return sidebarGlassEffectView
    }

    @Test("Matching copies the public settings and the private variant")
    @available(macOS 26.0, *)
    func matchingCopiesTheConfiguration() {
        let source = NSGlassEffectView()
        source.cornerRadius = 12
        source.style = .clear
        source.tintColor = .systemTeal
        if NSGlassEffectView.isPrivateConfigurationSupported {
            source._variant = 17
            source._subvariant = "probe"
            source._adaptiveAppearance = 1
        }

        let target = NSGlassEffectView()
        target.matchGlassConfiguration(of: source)

        #expect(target.cornerRadius == 12.0)
        // `style` is compared against the source's read-back rather than `.clear`: the setter
        // stores into SwiftUI-side storage and the getter does not necessarily echo it back.
        #expect(target.style == source.style)
        #expect(target.tintColor == .systemTeal)
        if NSGlassEffectView.isPrivateConfigurationSupported {
            #expect(target._variant == 17)
            #expect(target._subvariant == "probe")
            #expect(target._adaptiveAppearance == 1)
        }
    }

    @Test("The enclosing glass is the one around a view, never the view itself")
    @available(macOS 26.0, *)
    func enclosingGlassIsFoundAbove() {
        let outerGlassEffectView = NSGlassEffectView()
        let contentView = NSView()
        outerGlassEffectView.contentView = contentView
        let innerGlassEffectView = NSGlassEffectView()
        contentView.addSubview(innerGlassEffectView)

        #expect(NSGlassEffectView.enclosingGlassEffectView(of: contentView) === outerGlassEffectView)
        #expect(NSGlassEffectView.enclosingGlassEffectView(of: innerGlassEffectView) === outerGlassEffectView)
        #expect(NSGlassEffectView.enclosingGlassEffectView(of: outerGlassEffectView) == nil)
    }

    @Test("Outside any glass the replica stays transparent")
    @available(macOS 26.0, *)
    func replicaOutsideGlassStaysHidden() {
        let window = makeWindow()
        let replicaView = GlassEffectReplicaView(frame: CGRect(x: 0, y: 0, width: 400, height: 300))
        window.contentView?.addSubview(replicaView)

        #expect(replicaView.enclosingGlassEffectView == nil)
        #expect(replicaView.glassEffectView.isHidden)
        #expect(!replicaView.isSharingBackdropGroup)
    }

    @Test("Inside a glass's content the replica shows its glass, configured like the outer one")
    @available(macOS 26.0, *)
    func replicaInsideGlassMatchesIt() {
        let window = makeWindow()
        let replicaView = GlassEffectReplicaView()
        let sidebarGlassEffectView = makeSidebarGlass(holding: replicaView)
        window.contentView = sidebarGlassEffectView

        #expect(replicaView.enclosingGlassEffectView === sidebarGlassEffectView)
        #expect(!replicaView.glassEffectView.isHidden)
        #expect(replicaView.glassEffectView.cornerRadius == 0.0)
        if NSGlassEffectView.isPrivateConfigurationSupported {
            #expect(replicaView.glassEffectView._variant == 17)
            #expect(replicaView.glassEffectView._adaptiveAppearance == 1)
        }
    }

    /// SwiftUI writes its own `SwiftUI:<identity>` name back onto the backdrop layer when the
    /// window becomes key (measured), so a name set once is not enough — the layer has to refuse
    /// the write. This is the synchronous half of that: a pinned layer answers every later
    /// `groupName` write with the pinned name, until the pin is lifted.
    @Test("A pinned backdrop layer keeps its group name through later writes")
    @available(macOS 26.0, *)
    func pinnedLayerRefusesRenames() {
        let backdropLayer = CABackdropLayer()
        backdropLayer.groupName = "SwiftUI:773.00.0"

        #expect(GroupPinnedBackdropLayer.pin(backdropLayer, to: "SwiftUI:485.00.0"))
        #expect(backdropLayer.groupName == "SwiftUI:485.00.0")

        backdropLayer.groupName = "SwiftUI:773.00.0"
        #expect(backdropLayer.groupName == "SwiftUI:485.00.0")

        // Pinning again to a new name follows the enclosing glass, as when its own name changes.
        #expect(GroupPinnedBackdropLayer.pin(backdropLayer, to: "SwiftUI:9.00.0"))
        #expect(backdropLayer.groupName == "SwiftUI:9.00.0")

        (backdropLayer as? GroupPinnedBackdropLayer)?.pinnedGroupName = nil
        backdropLayer.groupName = "free"
        #expect(backdropLayer.groupName == "free")
    }

    /// The half that needs rendering. SwiftUI builds a glass view's layers only once the run loop
    /// has turned with the window displaying, and whether that happens inside `swift test` depends
    /// on the harness; so the assertion is made only if the *outer* glass got its backdrop layer
    /// within the wait. When it did, the replica must have joined its group by the same moment.
    @Test("Once the glass has rendered, the replica shares its backdrop group")
    @available(macOS 26.0, *)
    func replicaSharesTheBackdropGroupOnceRendered() {
        let window = makeWindow()
        let replicaView = GlassEffectReplicaView()
        let sidebarGlassEffectView = makeSidebarGlass(holding: replicaView)
        window.contentView = sidebarGlassEffectView
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }

        let deadline = Date(timeIntervalSinceNow: 2)
        while Date() < deadline, sidebarGlassEffectView.glassBackdropLayer == nil || !replicaView.isSharingBackdropGroup {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        guard let groupName = sidebarGlassEffectView.glassBackdropGroupName else {
            // The harness did not render; the synchronous half is covered above.
            return
        }
        let replicaGlassEffectView = replicaView.glassEffectView
        let diagnostics = "replica backdrop layer: \(String(describing: replicaGlassEffectView.glassBackdropLayer)), hidden: \(replicaGlassEffectView.isHidden), frame: \(replicaGlassEffectView.frame), subviews: \(replicaGlassEffectView.subviews.count)"
        #expect(replicaGlassEffectView.glassBackdropGroupName == groupName, Comment(rawValue: diagnostics))
        #expect(replicaView.isSharingBackdropGroup, Comment(rawValue: diagnostics))

        // What SwiftUI does on the window becoming key, replayed by hand: the shared name survives.
        replicaGlassEffectView.glassBackdropLayer?.groupName = "SwiftUI:773.00.0"
        #expect(replicaGlassEffectView.glassBackdropGroupName == groupName)
        #expect(replicaView.isSharingBackdropGroup)
    }
}

#endif
