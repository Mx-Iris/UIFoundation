#if QuickActionBar && os(macOS)

import AppKit
import Testing
@testable import UIFoundationAppKit

@Suite("QuickActionBar Presentation", .serialized)
@MainActor
struct QuickActionBarPresentationTests {
    @Test("Resuming a dismissal keeps the existing presentation alive")
    func resumingDismissalKeepsExistingPresentationAlive() async throws {
        guard NSScreen.main != nil else { return }

        _ = NSApplication.shared
        let actionBar = QuickActionBar()
        actionBar.present(width: 320, height: 240)

        #expect(actionBar.isPresenting)

        actionBar.cancel()
        #expect(actionBar.resumePresentation())

        for _ in 0..<4 {
            try await ContinuousClock().sleep(for: .milliseconds(30))
            actionBar.cancel()
            try await ContinuousClock().sleep(for: .milliseconds(30))
            #expect(actionBar.resumePresentation())
        }

        try await ContinuousClock().sleep(for: .milliseconds(350))
        #expect(actionBar.isPresenting)

        actionBar.cancel()
        try await ContinuousClock().sleep(for: .milliseconds(350))
        #expect(!actionBar.isPresenting)
    }
}

#endif
