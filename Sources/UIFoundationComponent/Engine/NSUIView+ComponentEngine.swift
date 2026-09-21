//
//  NSUIView+ComponentEngine.swift
//  UIFoundation
//
//  Ported from lkzhao/UIComponent (created by Luke Zhao on 7/17/24), with the
//  AppKit half added.
//
//  The engine attaches itself to a view lazily and then needs three hooks from
//  it: a layout pass to drive reload/render, a signal when the viewport moves,
//  and (on UIKit) a size-that-fits answer. Those are spelled differently enough
//  on the two platforms that the swizzles cannot be shared -- `layoutSubviews`
//  has no AppKit counterpart, `layout()` has no UIKit one.
//

import AssociatedObject

extension NSUIView {
    /// The component engine driving this view, created on first access.
    public var componentEngine: ComponentEngine {
        if let componentEngine = _componentEngine {
            return componentEngine
        }
        let componentEngine = ComponentEngine(view: self)
        _ = NSUIView.swizzle_setBounds
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        _ = NSUIView.swizzle_layout
        #else
        _ = NSUIView.swizzle_layoutSubviews
        _ = NSUIView.swizzle_sizeThatFits
        _ = NSUIScrollView.swizzle_safeAreaInsetsDidChange
        _ = NSUIScrollView.swizzle_setContentInset
        #endif
        _componentEngine = componentEngine
        return componentEngine
    }
}

extension NSUIView {
    /// The engine attached to this view, or nil if it has never been asked for.
    ///
    /// The swizzled hooks read this rather than ``componentEngine`` so that a
    /// layout or bounds change on a view with no engine costs one associated
    /// object lookup instead of creating one.
    @AssociatedObject(.retain(.nonatomic))
    fileprivate var _componentEngine: ComponentEngine? = nil

    /// Both platforms have a `setBounds:`, and on both a bounds change means the
    /// viewport moved or resized.
    static let swizzle_setBounds: Void = {
        guard let originalMethod = class_getInstanceMethod(NSUIView.self, #selector(setter: bounds)),
              let swizzledMethod = class_getInstanceMethod(NSUIView.self, #selector(swizzled_setBounds(_:)))
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc func swizzled_setBounds(_ bounds: CGRect) {
        swizzled_setBounds(bounds)
        _componentEngine?.setNeedsRender()
    }
}

#if canImport(AppKit) && !targetEnvironment(macCatalyst)

extension NSUIView {
    /// AppKit's layout pass. `NSView.layout()` is the counterpart of UIKit's
    /// `layoutSubviews`; without this hook the engine never reloads or renders
    /// on macOS at all.
    static let swizzle_layout: Void = {
        guard let originalMethod = class_getInstanceMethod(NSUIView.self, #selector(NSView.layout as (NSView) -> () -> Void)),
              let swizzledMethod = class_getInstanceMethod(NSUIView.self, #selector(swizzled_layout))
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc func swizzled_layout() {
        swizzled_layout()
        _componentEngine?.layoutSubview()
    }
}

#else

extension NSUIView {
    static let swizzle_sizeThatFits: Void = {
        guard let originalMethod = class_getInstanceMethod(NSUIView.self, #selector(sizeThatFits(_:))),
              let swizzledMethod = class_getInstanceMethod(NSUIView.self, #selector(swizzled_sizeThatFits(_:)))
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc func swizzled_sizeThatFits(_ size: CGSize) -> CGSize {
        _componentEngine?.sizeThatFits(size) ?? swizzled_sizeThatFits(size)
    }

    static let swizzle_layoutSubviews: Void = {
        guard let originalMethod = class_getInstanceMethod(NSUIView.self, #selector(layoutSubviews)),
              let swizzledMethod = class_getInstanceMethod(NSUIView.self, #selector(swizzled_layoutSubviews))
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc func swizzled_layoutSubviews() {
        swizzled_layoutSubviews()
        _componentEngine?.layoutSubview()
    }
}

extension NSUIScrollView {
    static let swizzle_safeAreaInsetsDidChange: Void = {
        guard let originalMethod = class_getInstanceMethod(NSUIScrollView.self, #selector(safeAreaInsetsDidChange)),
              let swizzledMethod = class_getInstanceMethod(NSUIScrollView.self, #selector(swizzled_safeAreaInsetsDidChange))
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    static let swizzle_setContentInset: Void = {
        guard let originalMethod = class_getInstanceMethod(NSUIScrollView.self, #selector(setter: contentInset)),
              let swizzledMethod = class_getInstanceMethod(NSUIScrollView.self, #selector(swizzled_setContentInset(_:)))
        else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }()

    @objc func swizzled_safeAreaInsetsDidChange() {
        guard responds(to: #selector(swizzled_safeAreaInsetsDidChange)) else { return }
        swizzled_safeAreaInsetsDidChange()
        if let componentEngine = _componentEngine, contentInsetAdjustmentBehavior != .never {
            componentEngine.setNeedsReload()
        }
    }

    @objc func swizzled_setContentInset(_ contentInset: NSUIEdgeInsets) {
        // when contentOffset is at the top, and contentSize is set
        // changing contentInset will not trigger a contentOffset change
        // we manually adjust the contentOffset back to the top
        // same for the horizontal axis
        let yAtTop = contentOffset.y <= -adjustedContentInset.top
        let xAtLeft = contentOffset.x <= -adjustedContentInset.left
        swizzled_setContentInset(contentInset)
        var newContentOffset = contentOffset
        if yAtTop {
            newContentOffset.y = -adjustedContentInset.top
        }
        if xAtLeft {
            newContentOffset.x = -adjustedContentInset.left
        }
        if newContentOffset != contentOffset {
            contentOffset = newContentOffset
        }
    }
}

#endif
