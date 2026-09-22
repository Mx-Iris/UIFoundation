//
//  ChapterView.swift
//  ComponentLayoutExample
//
//  The base every chapter derives from.
//

import AppKit
import AppKitPlus
import UIFoundationComponent

/// A chapter's content view.
///
/// Subclasses override ``updateProperties()`` and assign `componentEngine.component`
/// there, exactly as the upstream chapters do. Two things make that work on
/// AppKit, and neither is obvious:
///
///   * **`updateProperties()` is AppKitPlus's**, not AppKit's -- AppKit has no
///     such method (measured: zero hits across the macOS 27 SDK headers). Its
///     category also brings automatic Observation tracking on macOS 14+, so a
///     chapter that reads an `@Observable` view model inside `updateProperties`
///     is re-driven whenever that model changes, with nothing to call by hand.
///   * **The first pass has to be asked for.** AppKitPlus only runs the method
///     after `setNeedsUpdateProperties()`, so a chapter that never asked would
///     render nothing at all. That request happens below, on entering a
///     superview.
open class ChapterView: ComponentView {
    open override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        guard superview != nil else { return }
        setNeedsUpdateProperties()
    }
}
