//
//  ComponentLayoutDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Hosts the component-layout chapters.
//
//  Deliberately thin: everything it shows lives in the `ComponentLayoutExample`
//  package next to this project. That separation is not tidiness -- the chapters
//  define top-level `Text`, `Image` and `Separator`, and inside this module
//  those names would win over SwiftUI's at every call site, starting with the
//  40-odd bare `Text("…")` in `SettingsDemoViewController`.
//

import AppKit
import ComponentLayoutExample

@available(macOS 14.0, *)
final class ComponentLayoutDemoViewController: NSViewController {
    override func loadView() {
        view = HomeView()
    }
}
