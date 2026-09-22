//
//  TappableView.swift
//  UIFoundation
//
//  Ported from lkzhao/UIComponent (created by Luke Zhao on 6/8/21), with the
//  AppKit half written for this library.
//
//  Upstream is UIKit-only and leans on four things AppKit has no counterpart
//  for: `UIContextMenuInteraction` previews, `UIPointerInteraction`,
//  `UISpringLoadedInteraction` and `UIDropInteraction`. Per Evolution 0024's
//  rule -- degrade where there is a counterpart, offer nothing where there is
//  not -- the AppKit side ships click / double click / long press / highlight,
//  a right-click menu and a cursor, and simply does not declare the rest.
//  Reaching for one on macOS is a compile error rather than a silent no-op.
//

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

/// A view that responds to clicks and presses, and hosts a component of its own.
///
/// Normally created through ``Component/tappableView(_:)`` rather than directly:
///
/// ```swift
/// someComponent.tappableView { view in
///     print("clicked")
/// }
/// ```
///
/// Attach a right-click menu with ``Component/contextMenuProvider(_:)``, and a
/// long-press handler with ``Component/onLongPress(_:)``.
///
/// - Note: **This view is flipped.** It renders a component subtree of its own,
///   and the layout system places children from the top-left downwards -- the
///   same reason ``ComponentView`` is flipped. Without it the engine would
///   insert a flipped container in between, costing a view per tappable area.
open class TappableView: NSView {
    open override var isFlipped: Bool { true }

    /// Behaviour for this view specifically. Falls back to the environment's
    /// value, then to ``TappableViewConfig/default``.
    public var config: TappableViewConfig?

    // MARK: Gesture recognizers

    /// Recognizes a single click. Added only while ``onTap`` is non-nil.
    public private(set) lazy var clickGestureRecognizer = NSClickGestureRecognizer(
        target: self,
        action: #selector(didTap)
    )

    /// Recognizes a double click. Added only while ``onDoubleTap`` is non-nil.
    public private(set) lazy var doubleClickGestureRecognizer: NSClickGestureRecognizer = {
        let recognizer = NSClickGestureRecognizer(target: self, action: #selector(didDoubleTap))
        recognizer.numberOfClicksRequired = 2
        return recognizer
    }()

    /// Drives ``isHighlighted``. Always attached.
    ///
    /// `minimumPressDuration` of zero makes it report `.began` on mouse-down
    /// rather than after a delay, which is what a highlight needs.
    ///
    /// - Note: AppKit needs no counterpart to UIKit's `delaysTouchesBegan = false`
    ///   here: `NSGestureRecognizer.delaysPrimaryMouseButtonEvents` is already
    ///   `false` by default, so this recognizer does not hold back the click.
    public private(set) lazy var highlightGestureRecognizer: NSPressGestureRecognizer = {
        let recognizer = NSPressGestureRecognizer(target: self, action: #selector(didChangeHighlight))
        recognizer.minimumPressDuration = 0
        recognizer.delegate = self
        return recognizer
    }()

    /// Recognizes a press held for the system duration. Added only while
    /// ``onLongPress`` is non-nil.
    public private(set) lazy var longPressGestureRecognizer = NSPressGestureRecognizer(
        target: self,
        action: #selector(didLongPress)
    )

    // MARK: Handlers

    /// Called on a single click.
    public var onTap: ((TappableView) -> Void)? {
        didSet {
            if onTap != nil {
                addGestureRecognizer(clickGestureRecognizer)
            } else {
                removeGestureRecognizer(clickGestureRecognizer)
            }
        }
    }

    /// Called on a double click.
    ///
    /// - Important: A double click also fires ``onTap`` first, because
    ///   `NSClickGestureRecognizer` does not defer a one-click recognizer to a
    ///   two-click one. This matches upstream's UIKit behaviour; a view that
    ///   needs the two to be exclusive should call
    ///   `clickGestureRecognizer.require(toFail: doubleClickGestureRecognizer)`
    ///   itself, accepting the delay that adds to every single click.
    public var onDoubleTap: ((TappableView) -> Void)? {
        didSet {
            if onDoubleTap != nil {
                addGestureRecognizer(doubleClickGestureRecognizer)
            } else {
                removeGestureRecognizer(doubleClickGestureRecognizer)
            }
        }
    }

    /// Called as a long press progresses. Check the recognizer's `state`.
    public var onLongPress: ((TappableView, NSPressGestureRecognizer) -> Void)? {
        didSet {
            if onLongPress != nil {
                addGestureRecognizer(longPressGestureRecognizer)
            } else {
                removeGestureRecognizer(longPressGestureRecognizer)
            }
        }
    }

    /// Supplies the menu shown on a right click (or control-click).
    ///
    /// AppKit presents it; there is no preview stage, so upstream's
    /// `previewProvider` / `onCommitPreview` have no counterpart here.
    public var contextMenuProvider: ((TappableView) -> NSMenu?)?

    /// The cursor shown while the pointer is over this view.
    ///
    /// The AppKit counterpart of upstream's `pointerStyleProvider`, narrowed to
    /// what AppKit actually offers: a cursor, not a morphing pointer effect.
    public var cursor: NSCursor? {
        didSet {
            guard cursor !== oldValue else { return }
            window?.invalidateCursorRects(for: self)
        }
    }

    // MARK: State

    /// Whether the view is being pressed. Assigning notifies the resolved
    /// config's `onHighlightChanged`.
    open var isHighlighted: Bool = false {
        didSet {
            guard isHighlighted != oldValue else { return }
            resolvedConfig.onHighlightChanged?(self, isHighlighted)
        }
    }

    private var resolvedConfig: TappableViewConfig {
        config ?? .default
    }

    // MARK: Init

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityRole(.button)
        addGestureRecognizer(highlightGestureRecognizer)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Accessibility

    // The layout system renders into plain views that draw themselves, so
    // nothing below here is an accessibility element by default -- a tappable
    // area is invisible to VoiceOver and unreachable by any assistive
    // technology or UI test. These four overrides publish it as a button whose
    // label is its own content.

    open override func isAccessibilityElement() -> Bool {
        true
    }

    open override func accessibilityRole() -> NSAccessibility.Role? {
        .button
    }

    /// The text of whatever this view is wrapping.
    ///
    /// Walks the rendered subtree, because the content is a component tree the
    /// engine built -- there is no title property to read.
    open override func accessibilityLabel() -> String? {
        if let explicit = super.accessibilityLabel(), !explicit.isEmpty {
            return explicit
        }
        let collected = Self.accessibilityText(in: self)
        return collected.isEmpty ? nil : collected.joined(separator: " ")
    }

    /// Lets assistive technology -- and a UI test -- activate the view.
    open override func accessibilityPerformPress() -> Bool {
        guard onTap != nil else { return false }
        didTap()
        return true
    }

    private static func accessibilityText(in view: NSView) -> [String] {
        var collected: [String] = []
        for subview in view.subviews {
            if let value = subview.accessibilityValue() as? String, !value.isEmpty {
                collected.append(value)
            } else if let label = subview.accessibilityLabel(), !label.isEmpty {
                collected.append(label)
            } else {
                collected.append(contentsOf: accessibilityText(in: subview))
            }
        }
        return collected
    }

    // MARK: AppKit overrides

    open override func menu(for event: NSEvent) -> NSMenu? {
        contextMenuProvider?(self) ?? super.menu(for: event)
    }

    open override func resetCursorRects() {
        super.resetCursorRects()
        if let cursor {
            addCursorRect(bounds, cursor: cursor)
        }
    }

    // MARK: Actions

    /// Called when a click is recognized.
    @objc open func didTap() {
        resolvedConfig.didTap?(self)
        onTap?(self)
    }

    /// Called when a double click is recognized.
    @objc open func didDoubleTap() {
        onDoubleTap?(self)
    }

    /// Called as a long press progresses.
    @objc open func didLongPress() {
        onLongPress?(self, longPressGestureRecognizer)
    }

    /// Tracks the press that drives ``isHighlighted``.
    @objc open func didChangeHighlight() {
        switch highlightGestureRecognizer.state {
        case .began, .changed:
            isHighlighted = bounds.contains(highlightGestureRecognizer.location(in: self))
        case .ended, .cancelled, .failed:
            isHighlighted = false
        default:
            break
        }
    }
}

extension TappableView: NSGestureRecognizerDelegate {
    /// The highlight recognizer must never exclude another one -- it exists only
    /// to observe the press, not to claim it.
    public func gestureRecognizer(
        _ gestureRecognizer: NSGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: NSGestureRecognizer
    ) -> Bool {
        gestureRecognizer === highlightGestureRecognizer || otherGestureRecognizer === highlightGestureRecognizer
    }
}

#else

/// A view that responds to taps and gestures, and hosts a component of its own.
///
/// Normally created through ``Component/tappableView(_:)`` rather than directly:
///
/// ```swift
/// someComponent.tappableView { view in
///     print("tapped")
/// }
/// ```
open class TappableView: UIView {
    /// Behaviour for this view specifically. Falls back to the environment's
    /// value, then to ``TappableViewConfig/default``.
    public var config: TappableViewConfig?

    // MARK: Gesture recognizers

    /// Recognizes a single tap. Added only while ``onTap`` is non-nil.
    public private(set) lazy var tapGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(didTap)
    )

    /// Drives ``isHighlighted``. Always attached.
    public private(set) lazy var highlightGestureRecognizer: UILongPressGestureRecognizer = {
        let recognizer = UILongPressGestureRecognizer(target: self, action: #selector(didChangeHighlight))
        recognizer.minimumPressDuration = 0
        recognizer.cancelsTouchesInView = false
        recognizer.delaysTouchesBegan = false
        recognizer.delaysTouchesEnded = false
        recognizer.delegate = self
        return recognizer
    }()

    /// Recognizes a double tap. Added only while ``onDoubleTap`` is non-nil.
    public private(set) lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let recognizer = UITapGestureRecognizer(target: self, action: #selector(didDoubleTap))
        recognizer.numberOfTapsRequired = 2
        return recognizer
    }()

    /// Recognizes a press held for the system duration. Added only while
    /// ``onLongPress`` is non-nil.
    public private(set) lazy var longPressGestureRecognizer = UILongPressGestureRecognizer(
        target: self,
        action: #selector(didLongPress)
    )

    // MARK: Handlers

    /// Called on a single tap.
    public var onTap: ((TappableView) -> Void)? {
        didSet {
            if onTap != nil {
                addGestureRecognizer(tapGestureRecognizer)
            } else {
                removeGestureRecognizer(tapGestureRecognizer)
            }
        }
    }

    /// Called on a double tap.
    public var onDoubleTap: ((TappableView) -> Void)? {
        didSet {
            if onDoubleTap != nil {
                addGestureRecognizer(doubleTapGestureRecognizer)
            } else {
                removeGestureRecognizer(doubleTapGestureRecognizer)
            }
        }
    }

    /// Called as a long press progresses. Check the recognizer's `state`.
    public var onLongPress: ((TappableView, UILongPressGestureRecognizer) -> Void)? {
        didSet {
            if onLongPress != nil {
                addGestureRecognizer(longPressGestureRecognizer)
            } else {
                removeGestureRecognizer(longPressGestureRecognizer)
            }
        }
    }

    // MARK: State

    /// Whether the view is being pressed. Assigning notifies the resolved
    /// config's `onHighlightChanged`.
    open var isHighlighted: Bool = false {
        didSet {
            guard isHighlighted != oldValue else { return }
            resolvedConfig.onHighlightChanged?(self, isHighlighted)
        }
    }

    private var resolvedConfig: TappableViewConfig {
        config ?? .default
    }

    // MARK: Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        accessibilityTraits = .button
        addGestureRecognizer(highlightGestureRecognizer)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: UIKit overrides

    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        isHighlighted = true
    }

    open override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        isHighlighted = false
    }

    open override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        isHighlighted = false
    }

    // MARK: Actions

    /// Called when a tap is recognized.
    @objc open func didTap() {
        resolvedConfig.didTap?(self)
        onTap?(self)
    }

    /// Called when a double tap is recognized.
    @objc open func didDoubleTap() {
        onDoubleTap?(self)
    }

    /// Called as a long press progresses.
    @objc open func didLongPress() {
        onLongPress?(self, longPressGestureRecognizer)
    }

    /// Tracks the press that drives ``isHighlighted``.
    @objc open func didChangeHighlight() {
        switch highlightGestureRecognizer.state {
        case .began, .changed:
            isHighlighted = bounds.contains(highlightGestureRecognizer.location(in: self))
        case .ended, .cancelled, .failed:
            isHighlighted = false
        default:
            break
        }
    }
}

extension TappableView: UIGestureRecognizerDelegate {
    /// The highlight recognizer must never exclude another one -- it exists only
    /// to observe the touch, not to claim it.
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        gestureRecognizer === highlightGestureRecognizer || otherGestureRecognizer === highlightGestureRecognizer
    }
}

#endif
