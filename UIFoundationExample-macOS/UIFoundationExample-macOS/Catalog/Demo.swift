//
//  Demo.swift
//  UIFoundationExample-macOS
//
//  A single entry in the example app's demo catalog.
//

import AppKit

/// Describes one demo shown by the example app.
///
/// Every demo is a self-contained `NSViewController`. To add a new demo, create
/// a view controller under `Demos/` and register one `Demo` value in
/// ``DemoCatalog`` — nothing else in the app needs to change.
struct Demo {
    /// Display name shown in the sidebar.
    let title: String

    /// Group heading the demo is filed under in the sidebar.
    let category: String

    /// One-line description shown above the demo content.
    let summary: String

    /// Minimum macOS version the demo requires. `nil` means no extra requirement
    /// beyond the app's deployment target.
    let minimumMacOS: OperatingSystemVersion?

    /// Builds a fresh view controller each time the demo is selected.
    let makeViewController: () -> NSViewController

    init(
        title: String,
        category: String,
        summary: String = "",
        minimumMacOS: OperatingSystemVersion? = nil,
        makeViewController: @escaping () -> NSViewController
    ) {
        self.title = title
        self.category = category
        self.summary = summary
        self.minimumMacOS = minimumMacOS
        self.makeViewController = makeViewController
    }

    /// Whether the running OS satisfies ``minimumMacOS``.
    var isAvailable: Bool {
        guard let minimumMacOS else { return true }
        return ProcessInfo.processInfo.isOperatingSystemAtLeast(minimumMacOS)
    }
}
