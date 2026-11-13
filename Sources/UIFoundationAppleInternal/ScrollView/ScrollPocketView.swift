//
//  Read off macOS 27.2's AppKit and Xcode 27.2's DVTUserInterfaceKit and IDEKit, measured on macOS 27.2.
//  Reverse-engineering notes: Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md, section 5
//  Decision record: Documentations/Evolutions/draft-scroll-pockets-across-scroll-views.md
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationAppleInternalObjC

/// A scroll edge effect that stands on its own, outside any scroll view: AppKit's `NSScrollPocket`, filling this view,
/// blurring and dimming whatever is drawn behind it.
///
/// A scroll view's own pocket blurs only that scroll view's content, and AppKit draws the pockets of all scroll views
/// under the title bar from one capture — taken when the first of them is drawn, so a second scroll view beside it is
/// missing (see `NSView.box.titlebarBackdropGroupName`). Lay one of these over several scroll views instead, after them
/// all, and it blurs every one of them, and whatever is drawn over their own pockets, at once. Xcode 27.2 does this with
/// `DVTEdgeOcclusionView`: one over its whole editor area under the toolbar, and one behind each editor bar.
///
/// ```swift
/// let topEdgeEffect = ScrollPocketView(edge: .top)
/// editorAreaView.addSubview(topEdgeEffect.captureView!, positioned: .below, relativeTo: nil)
/// editorAreaView.addSubview(topEdgeEffect)   // after the panes, framed over the toolbar's strip
/// ```
///
/// The pocket replays the background through ``captureView``, a capture-only backdrop: put it **behind** the content
/// the pocket covers, over the same area — a scroll view puts its own pocket's behind its clip view, and Xcode puts its
/// pockets' at the back of the containers they lie over. Keep the two frames together when the layout changes.
///
/// It takes no clicks: they go to whatever lies under it. Before macOS 26, or where AppKit lacks `NSScrollPocket`, it is
/// an empty view and ``captureView`` is `nil`.
open class ScrollPocketView: NSView {
    /// The ``style`` that draws the hard edge effect whatever the pocket covers: the content blurred under a
    /// near-opaque replay of the background — 0.85 opaque measured in a window that was not key, macOS 27.2. It is
    /// what Xcode's pockets use. 0 and 1 leave the choice to the pocket's elements, and a stand-alone pocket has none,
    /// so with them it draws nothing.
    public static let hardStyle = 2

    /// The edge the effect fades towards.
    public let edge: NSScrollView.ScrollPocketEdge

    /// The pocket's style: ``hardStyle`` unless set. Values of 3 and above trap in AppKit on macOS 27.2, so they are
    /// ignored.
    public var style: Int {
        get {
            guard #available(macOS 26.0, *), let pocket else { return Self.hardStyle }
            return pocket.style
        }
        set {
            guard #available(macOS 26.0, *), let pocket, (0 ..< 3).contains(newValue) else { return }
            pocket.style = newValue
        }
    }

    /// Whether a hairline is drawn along the far side of the effect: `false` unless set, as Xcode 27 has it.
    public var allowsSeparator: Bool {
        get {
            guard #available(macOS 26.0, *), let pocket else { return false }
            return pocket.allowsSeparator
        }
        set {
            guard #available(macOS 26.0, *), let pocket else { return }
            pocket.allowsSeparator = newValue
        }
    }

    /// The backdrop group the effect blurs what is behind it in, or `nil` — what it starts with — for a group of its
    /// own that AppKit names. Two effects in one group are drawn from one capture, taken when the first of them is
    /// drawn, so give each its own unless they are meant to share it.
    public var backdropGroupName: String? {
        get {
            guard #available(macOS 26.0, *), let pocket else { return nil }
            return pocket.backdropGroupName
        }
        set {
            guard #available(macOS 26.0, *), let pocket else { return }
            pocket.backdropGroupName = newValue
        }
    }

    /// The capture-only backdrop the effect replays the background from. Put it behind the content this view covers,
    /// over the same area; `nil` where there is no pocket.
    public var captureView: NSView? {
        guard #available(macOS 26.0, *), let pocket else { return nil }
        return pocket.captureView
    }

    /// The `NSScrollPocket`, typed loosely so that the class needs nothing newer than the package's floor.
    private let pocketView: NSView?

    public init(edge: NSScrollView.ScrollPocketEdge) {
        self.edge = edge
        if #available(macOS 26.0, *), let pocketClass = NSClassFromString("NSScrollPocket") as? NSScrollPocket.Type {
            let pocket = pocketClass.init(frame: .zero)
            pocket.edge = edge.rawValue
            pocket.style = Self.hardStyle
            pocket.allowsSeparator = false
            pocketView = pocket
        } else {
            pocketView = nil
        }
        super.init(frame: .zero)
        if let pocketView {
            pocketView.frame = bounds
            pocketView.autoresizingMask = [.width, .height]
            addSubview(pocketView)
        }
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    @available(macOS 26.0, *)
    private var pocket: NSScrollPocket? {
        pocketView as? NSScrollPocket
    }
}

#endif
