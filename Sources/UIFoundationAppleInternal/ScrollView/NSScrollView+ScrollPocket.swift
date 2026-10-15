//
//  Read off macOS 27.0's AppKit and measured on macOS 27.2 (26B5101f).
//  Reverse-engineering notes: Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md
//  Decision record: Documentations/Evolutions/0029-scroll-view-scroll-pockets.md
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FrameworkToolbox
import UIFoundationAppleInternalObjC

extension NSScrollView {
    /// An edge of a scroll view along which AppKit draws a scroll pocket: the scroll edge effect, from macOS 26
    /// on, where content scrolls under a bar.
    public enum ScrollPocketEdge: Int, Sendable, CaseIterable {
        case top = 0
        case bottom = 1
    }

    /// Edges of a scroll view along which AppKit draws a scroll pocket.
    public struct ScrollPocketEdges: OptionSet, Sendable {
        public let rawValue: Int

        public init(rawValue: Int) {
            self.rawValue = rawValue
        }

        public init(edge: ScrollPocketEdge) {
            self.init(rawValue: 1 << edge.rawValue)
        }

        public static let top = ScrollPocketEdges(edge: .top)

        public static let bottom = ScrollPocketEdges(edge: .bottom)
    }
}

extension NSView {
    /// The `_scrollPocketElementStyle` of a bar floating over a scroll view's edge, which a view registered as a
    /// scroll pocket container answers by overriding that property: 2.
    ///
    /// It is what AppKit's wrapper around a split view item accessory answers, and what Xcode's bars answer —
    /// DVTUserInterfaceKit 27.2 calls it the bar style (`NSViewWithScrollPocketElementStyleBar`), and its filter
    /// bar and its navigator chooser both return it.
    ///
    /// ```swift
    /// @available(macOS 26.0, *)
    /// override var _scrollPocketElementStyle: Int {
    ///     NSView.barScrollPocketElementStyle
    /// }
    /// ```
    public static let barScrollPocketElementStyle = 2
}

extension FrameworkToolbox where Base: NSScrollView {
    /// Registers `container`, a view that floats over one of the scroll view's edges, with the scroll pocket on
    /// that edge, which then reaches at least to the far side of the container. A split view item does this
    /// with its accessories and a window with its title bar; a bar of your own that content scrolls under needs
    /// it to get the effect, as Xcode registers the bars over its navigators.
    ///
    /// Unregister a container that stops floating over the edge. Does nothing before macOS 26, or where AppKit
    /// lacks the private calls.
    public func registerScrollPocketContainer(_ container: NSView, on edge: NSScrollView.ScrollPocketEdge) {
        guard #available(macOS 26.0, *), Base.carriesScrollPocketContainers else { return }
        base.registerPocketContainer(container, onEdge: edge.rawValue)
    }

    /// Undoes `registerScrollPocketContainer(_:on:)`.
    public func unregisterScrollPocketContainer(_ container: NSView, on edge: NSScrollView.ScrollPocketEdge) {
        guard #available(macOS 26.0, *), Base.carriesScrollPocketContainers else { return }
        base.unregisterPocketContainer(container, onEdge: edge.rawValue)
    }

    /// The edges whose scroll pocket shows whether or not a container is registered on them, or `nil` where
    /// AppKit lacks the private property. Assigning there does nothing.
    ///
    /// With no container, the pocket on the top edge is as tall as the scroll view's top safe area inset, and
    /// the one on the bottom edge as tall as the scroll view's own bottom content inset — not its clip view's,
    /// so a scroll view whose content is inset through its clip view alone gets a bottom pocket 0 points tall.
    /// That is how a list running under bars of its own gets the effect without registering them: the bars
    /// become the scroll view's safe area, and its automatic content insets follow the safe area.
    public var alwaysShownScrollPocketEdges: NSScrollView.ScrollPocketEdges? {
        get {
            guard Base.carriesAlwaysShownPocketEdges else { return nil }
            return NSScrollView.ScrollPocketEdges(rawValue: Int(base.alwaysShownPocketEdges))
        }
        nonmutating set {
            guard Base.carriesAlwaysShownPocketEdges, let newValue else { return }
            base.alwaysShownPocketEdges = Int64(newValue.rawValue)
        }
    }

    /// The style of the scroll pocket on an edge — 0 until set — or `nil` before macOS 26. What each value
    /// draws has not been worked out: Xcode 27 sets 2 on the top edge of a navigator whose chooser shows a
    /// second level and 0 otherwise, and 2 on both edges on macOS 26.
    public func scrollPocketStyle(on edge: NSScrollView.ScrollPocketEdge) -> Int? {
        guard #available(macOS 26.0, *), Base.carriesScrollPocketStyles else { return nil }
        return base.scrollPocketStyle(onEdge: edge.rawValue)
    }

    /// Sets the style of the scroll pocket on an edge. Does nothing before macOS 26.
    public func setScrollPocketStyle(_ style: Int, on edge: NSScrollView.ScrollPocketEdge) {
        guard #available(macOS 26.0, *), Base.carriesScrollPocketStyles else { return }
        base.setScrollPocketStyle(style, onEdge: edge.rawValue)
    }

    /// The scroll pocket on an edge — an `NSScrollPocket`, a view the scroll view adds to itself — or `nil`
    /// when there is none there. For inspecting what AppKit made; it never makes one.
    public func scrollPocket(on edge: NSScrollView.ScrollPocketEdge) -> NSView? {
        guard #available(macOS 26.0, *), Base.carriesScrollPocketViews else { return nil }
        return base._pocket(forEdge: edge.rawValue, makeIfNeeded: false)
    }
}

extension NSScrollView {
    // Checked rather than assumed, so that an AppKit that drops a private method costs the feature, not a crash.
    // It has happened once already: macOS 27.0's `_registeredPocketContainersOnEdge:` is gone from 27.2.

    @available(macOS 26.0, *)
    fileprivate static var carriesScrollPocketContainers: Bool {
        instancesRespond(to: #selector(NSScrollView.registerPocketContainer(_:onEdge:)))
            && instancesRespond(to: #selector(NSScrollView.unregisterPocketContainer(_:onEdge:)))
    }

    fileprivate static var carriesAlwaysShownPocketEdges: Bool {
        instancesRespond(to: #selector(getter: NSScrollView.alwaysShownPocketEdges))
            && instancesRespond(to: #selector(setter: NSScrollView.alwaysShownPocketEdges))
    }

    @available(macOS 26.0, *)
    fileprivate static var carriesScrollPocketStyles: Bool {
        instancesRespond(to: #selector(NSScrollView.scrollPocketStyle(onEdge:)))
            && instancesRespond(to: #selector(NSScrollView.setScrollPocketStyle(_:onEdge:)))
    }

    @available(macOS 26.0, *)
    fileprivate static var carriesScrollPocketViews: Bool {
        instancesRespond(to: #selector(NSScrollView._pocket(forEdge:makeIfNeeded:)))
    }
}

#endif
