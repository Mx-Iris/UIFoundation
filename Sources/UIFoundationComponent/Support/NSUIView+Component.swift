//
//  NSUIView+Component.swift
//  UIFoundation
//
//  Ported from lkzhao/UIComponent (created by Luke Zhao on 2017-07-24).
//

import AssociatedObject

extension NSUIView {
    /// The reuse bookkeeping attached to this view, if it has ever been given any.
    ///
    /// Stays optional so that asking the question never allocates: the engine
    /// checks it on every view it recycles, including ones that never opted
    /// into reuse.
    @AssociatedObject(.retain(.nonatomic))
    internal var existingComponentReuseContext: ComponentReuseContext? = nil

    /// The reuse bookkeeping attached to this view, created on first use.
    internal var componentReuseContext: ComponentReuseContext {
        if let context = existingComponentReuseContext {
            return context
        }
        let context = ComponentReuseContext()
        existingComponentReuseContext = context
        return context
    }
}

@objc extension NSUIView {
    /// Returns the view to its reuse pool, or removes it when it has none.
    func recycleForComponentReuse() {
        if let existingComponentReuseContext,
            let reuseIdentifier = existingComponentReuseContext.reuseIdentifier,
            let reuseManager = existingComponentReuseContext.reuseManager
        {
            reuseManager.enqueue(identifier: reuseIdentifier, view: self)
        } else {
            removeFromSuperview()
        }
    }
}

/// What a reused view remembers: which pool it belongs to, and under which key.
class ComponentReuseContext {
    var reuseIdentifier: String?
    var reuseManager: ReuseManager?
}
