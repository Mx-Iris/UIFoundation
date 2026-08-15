#if Settings && os(macOS)

import AppKit
import SwiftUI
import Testing

@testable import UIFoundationSettingsUI

/// `windowDidLoad` derives the autosave name from the dynamic type, so giving
/// each scenario its own subclass gives it its own defaults slot. That keeps
/// these tests off the shared `SettingsWindowController` slot — which a host
/// app's real window uses — and out of each other's way.
private final class StoredFrameProbeWindowController: SettingsWindowController {}

private final class FirstLaunchProbeWindowController: SettingsWindowController {}

private final class VanishedScreenProbeWindowController: SettingsWindowController {}

@MainActor
@Suite("Settings window frame restoration")
struct SettingsWindowFrameRestorationTests {
    // MARK: - Helpers

    private static func autosaveName(for controllerType: SettingsWindowController.Type) -> String {
        String(describing: controllerType)
    }

    private static func defaultsKey(for autosaveName: String) -> String {
        "NSWindow Frame " + autosaveName
    }

    /// Writes a frame into the defaults slot the controller will read, using a
    /// window built exactly like the controller's own so the stored geometry
    /// round-trips without a style-mask conversion shifting it.
    private static func storeFrame(_ frame: NSRect, under autosaveName: String) {
        let seedWindow = SettingsWindow(
            contentRect: frame,
            styleMask: [.titled, .miniaturizable, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        seedWindow.setFrame(frame, display: false)
        seedWindow.saveFrame(usingName: autosaveName)
    }

    /// A subclass does not inherit the `@SettingsPageBuilder` attribute on the
    /// initializer's parameter, so these tests hand the page list over directly.
    private static func probePages() -> [SettingsPage] {
        [
            SettingsPage("General", id: "general", plainSymbol: "gearshape") {
                Text("General")
            },
        ]
    }

    /// Loads the window the way AppKit does on first display, which is what
    /// runs `windowDidLoad`.
    private static func loadedWindow(of controller: SettingsWindowController) -> NSWindow? {
        controller.window
    }

    // MARK: - Tests

    @Test("a stored frame survives the window load")
    func storedFrameSurvivesWindowLoad() throws {
        let autosaveName = Self.autosaveName(for: StoredFrameProbeWindowController.self)
        let defaultsKey = Self.defaultsKey(for: autosaveName)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: defaultsKey) }

        let storedFrame = NSRect(x: 120, y: 180, width: 640, height: 480)
        Self.storeFrame(storedFrame, under: autosaveName)

        let controller = StoredFrameProbeWindowController(pages: Self.probePages)

        let window = try #require(Self.loadedWindow(of: controller))
        #expect(window.frame.origin == storedFrame.origin)
    }

    @Test("a first launch centres the window")
    func firstLaunchCentresWindow() throws {
        let autosaveName = Self.autosaveName(for: FirstLaunchProbeWindowController.self)
        let defaultsKey = Self.defaultsKey(for: autosaveName)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: defaultsKey) }

        let controller = FirstLaunchProbeWindowController(pages: Self.probePages)

        let window = try #require(Self.loadedWindow(of: controller))
        let visibleFrame = try #require(window.screen ?? NSScreen.main).visibleFrame
        // `center()` places the window slightly above the vertical midpoint, so
        // only the horizontal axis is a stable assertion.
        #expect(abs(window.frame.midX - visibleFrame.midX) < 1)
    }

    @Test("a frame stored on a vanished screen falls back to centring")
    func vanishedScreenFrameFallsBackToCentring() throws {
        let autosaveName = Self.autosaveName(for: VanishedScreenProbeWindowController.self)
        let defaultsKey = Self.defaultsKey(for: autosaveName)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        defer { UserDefaults.standard.removeObject(forKey: defaultsKey) }

        Self.storeFrame(NSRect(x: 99_999, y: 99_999, width: 640, height: 480), under: autosaveName)

        let controller = VanishedScreenProbeWindowController(pages: Self.probePages)

        let window = try #require(Self.loadedWindow(of: controller))
        let isOnSomeScreen = NSScreen.screens.contains { $0.frame.intersects(window.frame) }
        #expect(isOnSomeScreen)
    }
}

#endif
