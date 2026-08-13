//
//  SettingsDemoViewController.swift
//  UIFoundationExample-macOS
//
//  A full settings panel for an imaginary workbench app, built on
//  `UIFoundationSettings` / `UIFoundationSettingsUI`.
//
//  It is deliberately a real panel rather than a toy: seven pages of settings a
//  tool app would actually have, including a page list that changes with the
//  settings themselves. Between them the pages exercise every part of the API —
//  all three page-icon shapes, conditional and repeated page registration, both
//  key-path depths of `@AppSettings`, a custom `SettingsStorage`, explicit
//  saving and loading, and `SettingsPageIcon` used directly.
//
//  The panel opens in its own `SettingsWindowController` window — where a
//  settings panel belongs. Keep it open beside the demo: the counter panels here
//  read the same settings, so editing anything over there moves them, which is
//  what makes three otherwise-invisible properties of the design visible —
//  key-path invalidation, debounced writes, and whole-model replacement.
//
//  Settings land in a temporary directory rather than Application Support, so
//  running the example never disturbs a real app's settings file.
//

import AppKit
import Observation
import SwiftUI
import UIFoundation
import UIFoundationSettings
import UIFoundationSettingsUI

// MARK: - The settings model

/// The workbench app's settings. Note what it does *not* contain: no saving, no
/// file handling, no `didSet`. Declaring the store is the whole contract.
///
/// It is an `@Observable` reference model, so readers track individual
/// top-level properties while ``SettingsStore`` independently observes every
/// persisted property for saving.
@available(macOS 14.0, *)
@Observable
final class WorkbenchSettings: PersistentSettings {
    var general = General()
    var appearance = Appearance()
    var editor = Editor()
    var indexing = Indexing()
    var updates = Updates()
    var advanced = Advanced()
    var workspaces = Workspace.starterSet

    // MARK: General

    struct General: Codable, Sendable {
        var restoresWindowsOnLaunch = true
        var reopensLastProject = false
        var confirmsBeforeQuitting = true
        var recentDocumentCount = 10
        var doubleClickAction: DoubleClickAction = .openInPlace
    }

    enum DoubleClickAction: String, Codable, Sendable, CaseIterable, Identifiable {
        case openInPlace
        case openInNewWindow
        case revealInFinder

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .openInPlace: "Open in Place"
            case .openInNewWindow: "Open in New Window"
            case .revealInFinder: "Reveal in Finder"
            }
        }
    }

    // MARK: Appearance

    struct Appearance: Codable, Sendable {
        var theme: Theme = .system
        var accent: Accent = .multicolor
        var density: Density = .comfortable
        var sidebarIconSize = 20.0
    }

    enum Theme: String, Codable, Sendable, CaseIterable, Identifiable {
        case system
        case light
        case dark

        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
    }

    enum Accent: String, Codable, Sendable, CaseIterable, Identifiable {
        case multicolor
        case blue
        case purple
        case pink
        case orange

        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }

        var color: Color {
            switch self {
            case .multicolor: .accentColor
            case .blue: .blue
            case .purple: .purple
            case .pink: .pink
            case .orange: .orange
            }
        }
    }

    enum Density: String, Codable, Sendable, CaseIterable, Identifiable {
        case comfortable
        case compact

        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
    }

    // MARK: Editor

    struct Editor: Codable, Sendable {
        var fontName: FontChoice = .system
        var fontSize = 13.0
        var showsLineNumbers = true
        var showsInvisibleCharacters = false
        var wrapsLines = false
        var tabWidth = 4
        var indentsUsingSpaces = true
    }

    enum FontChoice: String, Codable, Sendable, CaseIterable, Identifiable {
        case system
        case menlo
        case sfMono

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .system: "System Monospaced"
            case .menlo: "Menlo"
            case .sfMono: "SF Mono"
            }
        }

        func font(size: CGFloat) -> Font {
            switch self {
            case .system: .system(size: size, design: .monospaced)
            case .menlo: .custom("Menlo", size: size)
            case .sfMono: .custom("SF Mono", size: size)
            }
        }
    }

    // MARK: Indexing

    struct Indexing: Codable, Sendable {
        var isEnabled = true
        var maximumConcurrency = 4
        var indexesOnBattery = false
        var excludedPaths: [ExcludedPath] = ExcludedPath.starterSet
    }

    struct ExcludedPath: Codable, Sendable, Identifiable, Hashable {
        var id = UUID().uuidString
        var path: String
        var isEnabled = true

        static let starterSet: [ExcludedPath] = [
            ExcludedPath(path: "~/Library/Caches"),
            ExcludedPath(path: "**/node_modules"),
            ExcludedPath(path: "**/.build", isEnabled: false),
        ]
    }

    // MARK: Updates

    struct Updates: Codable, Sendable {
        var automaticallyChecks = true
        var automaticallyDownloads = false
        var checkInterval: CheckInterval = .daily
        var includesPrereleases = false
    }

    enum CheckInterval: String, Codable, Sendable, CaseIterable, Identifiable {
        case hourly
        case daily
        case weekly

        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
    }

    // MARK: Advanced

    struct Advanced: Codable, Sendable {
        var logLevel: LogLevel = .warning
        var showsDeveloperPage = false
        var showsWorkspacePages = false
        var usesExperimentalRenderer = false
    }

    enum LogLevel: String, Codable, Sendable, CaseIterable, Identifiable {
        case error
        case warning
        case info
        case debug

        var id: String { rawValue }
        var displayName: String { rawValue.capitalized }
    }

    // MARK: Workspaces

    /// Backs the pages generated by a `for` loop in the page builder.
    struct Workspace: Codable, Sendable, Identifiable, Hashable {
        var id: String
        var name: String
        var symbolName: String
        var isIndexed: Bool
        var notes: String

        static let starterSet: [Workspace] = [
            Workspace(id: "client", name: "Client", symbolName: "laptopcomputer", isIndexed: true, notes: ""),
            Workspace(id: "server", name: "Server", symbolName: "server.rack", isIndexed: true, notes: ""),
            Workspace(id: "tooling", name: "Tooling", symbolName: "wrench.and.screwdriver", isIndexed: false, notes: ""),
        ]
    }

    // MARK: Persistence observation and coding

    init() {}

    @MainActor
    func accessPersistedValues() {
        _ = general
        _ = appearance
        _ = editor
        _ = indexing
        _ = updates
        _ = advanced
        _ = workspaces
    }

    private enum CodingKeys: String, CodingKey {
        case general
        case appearance
        case editor
        case indexing
        case updates
        case advanced
        case workspaces
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        general = try container.decodeIfPresent(General.self, forKey: .general) ?? General()
        appearance = try container.decodeIfPresent(Appearance.self, forKey: .appearance) ?? Appearance()
        editor = try container.decodeIfPresent(Editor.self, forKey: .editor) ?? Editor()
        indexing = try container.decodeIfPresent(Indexing.self, forKey: .indexing) ?? Indexing()
        updates = try container.decodeIfPresent(Updates.self, forKey: .updates) ?? Updates()
        advanced = try container.decodeIfPresent(Advanced.self, forKey: .advanced) ?? Advanced()
        workspaces = try container.decodeIfPresent([Workspace].self, forKey: .workspaces) ?? Workspace.starterSet
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(general, forKey: .general)
        try container.encode(appearance, forKey: .appearance)
        try container.encode(editor, forKey: .editor)
        try container.encode(indexing, forKey: .indexing)
        try container.encode(updates, forKey: .updates)
        try container.encode(advanced, forKey: .advanced)
        try container.encode(workspaces, forKey: .workspaces)
    }

    // MARK: Store

    /// Deliberately outside Application Support: this is a demo.
    static let settingsFileURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("UIFoundationWorkbench", isDirectory: true)
        .appendingPathComponent("Settings.json")

    @MainActor
    static let store = SettingsStore(
        defaultValue: WorkbenchSettings(),
        // A custom `SettingsStorage` — the protocol's whole purpose. This one
        // wraps the file storage to count writes.
        storage: CountingSettingsStorage(
            wrapping: FileSystemSettingsStorage(fileURL: settingsFileURL)
        ),
        // Shorter than the default second so a write lands while you are still
        // looking at the counter.
        autoSaveDelay: .milliseconds(400)
    )
}

/// Collapses the model parameter so pages read `@WorkbenchSetting(\.general)`.
@available(macOS 14.0, *)
typealias WorkbenchSetting<Value> = AppSettings<WorkbenchSettings, Value>

// MARK: - Counting storage

/// Passes through to another storage and records each write, so the debounce
/// becomes visible.
private struct CountingSettingsStorage: SettingsStorage {
    let wrapped: any SettingsStorage

    init(wrapping wrapped: any SettingsStorage) {
        self.wrapped = wrapped
    }

    func save(_ data: Data) async throws {
        try await wrapped.save(data)
        await MainActor.run { DemoActivity.recordSave(byteCount: data.count) }
    }

    func load() async throws -> Data {
        try await wrapped.load()
    }
}

// MARK: - Counters

/// Plain (non-`@Observable`) counters.
///
/// Deliberately not observable: the panels bump these from inside `body`, and an
/// observable counter read by a displaying view would invalidate that view,
/// which would bump the counter again. The AppKit label polls instead.
@MainActor
private enum DemoActivity {
    static var generalPanelBodyCount = 0
    static var appearancePanelBodyCount = 0
    static var settingsFreePanelBodyCount = 0

    static var saveCount = 0
    static var lastSavedByteCount = 0

    static func recordSave(byteCount: Int) {
        saveCount += 1
        lastSavedByteCount = byteCount
    }

    static func resetCounters() {
        generalPanelBodyCount = 0
        appearancePanelBodyCount = 0
        settingsFreePanelBodyCount = 0
        saveCount = 0
        lastSavedByteCount = 0
    }

    static var summary: String {
        """
        body evaluations   reads \u{5C}.general: \(generalPanelBodyCount)   \
        reads \u{5C}.appearance: \(appearancePanelBodyCount)   \
        reads nothing: \(settingsFreePanelBodyCount)
        writes to disk     \(saveCount)\(lastSavedByteCount > 0 ? "  (last \(lastSavedByteCount) bytes)" : "")
        """
    }
}

// MARK: - Pages

@available(macOS 14.0, *)
private struct GeneralSettingsPage: View {
    @WorkbenchSetting(\.general)
    private var general

    var body: some View {
        SettingsForm {
            Section {
                Toggle("Restore Windows on Launch", isOn: $general.restoresWindowsOnLaunch)
                Toggle("Reopen Last Project", isOn: $general.reopensLastProject)
                Toggle("Confirm Before Quitting", isOn: $general.confirmsBeforeQuitting)
            } header: {
                Text("Startup")
            }

            Section {
                Picker("Double-Click Action", selection: $general.doubleClickAction) {
                    ForEach(WorkbenchSettings.DoubleClickAction.allCases) { action in
                        Text(action.displayName).tag(action)
                    }
                }
                Stepper(value: $general.recentDocumentCount, in: 0 ... 50) {
                    LabeledContent("Recent Documents", value: "\(general.recentDocumentCount)")
                }
            } header: {
                Text("Documents")
            } footer: {
                Text("Hold the stepper: the value changes on every tick, but the write counter below the panel goes up exactly once.")
            }
        }
    }
}

@available(macOS 14.0, *)
private struct AppearanceSettingsPage: View {
    @WorkbenchSetting(\.appearance)
    private var appearance

    var body: some View {
        SettingsForm {
            Section {
                Picker("Theme", selection: $appearance.theme) {
                    ForEach(WorkbenchSettings.Theme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Accent", selection: $appearance.accent) {
                    ForEach(WorkbenchSettings.Accent.allCases) { accent in
                        HStack {
                            Circle().fill(accent.color).frame(width: 10, height: 10)
                            Text(accent.displayName)
                        }
                        .tag(accent)
                    }
                }

                Picker("Density", selection: $appearance.density) {
                    ForEach(WorkbenchSettings.Density.allCases) { density in
                        Text(density.displayName).tag(density)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                Slider(value: $appearance.sidebarIconSize, in: 14 ... 32, step: 1) {
                    Text("Sidebar Icon Size")
                } minimumValueLabel: {
                    Text("14")
                } maximumValueLabel: {
                    Text("32")
                }

                LabeledContent("Preview") {
                    HStack(spacing: 10) {
                        SettingsPageIcon(
                            .symbol("gearshape", tint: appearance.accent.color),
                            size: appearance.sidebarIconSize
                        )
                        SettingsPageIcon(
                            .symbol("paintpalette", tint: appearance.accent.color),
                            size: appearance.sidebarIconSize
                        )
                    }
                }
            } header: {
                Text("Sidebar")
            } footer: {
                Text("`SettingsPageIcon` is public, so the same badge the sidebar draws can be reused inside a page.")
            }
        }
    }
}

@available(macOS 14.0, *)
private struct EditorSettingsPage: View {
    @WorkbenchSetting(\.editor)
    private var editor

    var body: some View {
        SettingsForm {
            Section {
                Picker("Font", selection: $editor.fontName) {
                    ForEach(WorkbenchSettings.FontChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                Stepper(value: $editor.fontSize, in: 9 ... 24, step: 1) {
                    LabeledContent("Size", value: "\(Int(editor.fontSize)) pt")
                }
            } header: {
                Text("Typography")
            }

            Section {
                Toggle("Show Line Numbers", isOn: $editor.showsLineNumbers)
                Toggle("Show Invisible Characters", isOn: $editor.showsInvisibleCharacters)
                Toggle("Wrap Long Lines", isOn: $editor.wrapsLines)
            } header: {
                Text("Display")
            }

            Section {
                Toggle("Indent Using Spaces", isOn: $editor.indentsUsingSpaces)
                Stepper(value: $editor.tabWidth, in: 1 ... 8) {
                    LabeledContent("Tab Width", value: "\(editor.tabWidth)")
                }
            } header: {
                Text("Indentation")
            }

            Section {
                EditorPreview(editor: editor)
            } header: {
                Text("Preview")
            }
        }
    }
}

/// One line of the editor preview.
///
/// Identity is the line's *role*, not its position or its text. Both of the
/// obvious alternatives are wrong: the offset would tie identity to the array
/// index, and the rendered text changes with almost every setting on the page —
/// either would make SwiftUI treat an edit as "these rows were replaced".
@available(macOS 14.0, *)
private struct EditorPreviewLine: Identifiable {
    enum Role: String {
        case signature
        case statement
        case closing
    }

    let role: Role
    let number: Int
    let text: String

    var id: String { role.rawValue }
}

@available(macOS 14.0, *)
private struct EditorPreview: View {
    let editor: WorkbenchSettings.Editor

    private var indentation: String {
        editor.indentsUsingSpaces
            ? String(repeating: "·", count: editor.tabWidth)
            : "→"
    }

    private var lines: [EditorPreviewLine] {
        [
            EditorPreviewLine(role: .signature, number: 1, text: "func greet(name: String) -> String {"),
            EditorPreviewLine(
                role: .statement,
                number: 2,
                text: "\(indentation)return \"Hello, \\(name)\"" + (editor.showsInvisibleCharacters ? "¶" : "")
            ),
            EditorPreviewLine(role: .closing, number: 3, text: "}"),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(lines) { line in
                HStack(alignment: .top, spacing: 8) {
                    if editor.showsLineNumbers {
                        Text(verbatim: "\(line.number)")
                            .foregroundStyle(.tertiary)
                            .frame(width: 18, alignment: .trailing)
                    }
                    Text(verbatim: line.text)
                        .lineLimit(editor.wrapsLines ? nil : 1)
                }
            }
        }
        .font(editor.fontName.font(size: editor.fontSize))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

@available(macOS 14.0, *)
private struct IndexingSettingsPage: View {
    @WorkbenchSetting(\.indexing)
    private var indexing

    @State private var newExcludedPath = ""

    private var processorCount: Int { ProcessInfo.processInfo.processorCount }

    var body: some View {
        SettingsForm {
            Section {
                Toggle("Index Projects in the Background", isOn: $indexing.isEnabled)
                Stepper(value: $indexing.maximumConcurrency, in: 1 ... processorCount) {
                    LabeledContent("Maximum Concurrency", value: "\(indexing.maximumConcurrency) of \(processorCount)")
                }
                .disabled(!indexing.isEnabled)
                Toggle("Index While on Battery", isOn: $indexing.indexesOnBattery)
                    .disabled(!indexing.isEnabled)
            } header: {
                Text("Background Indexing")
            }

            Section {
                ForEach($indexing.excludedPaths) { $excludedPath in
                    HStack {
                        // A real label even though it is hidden: an empty string
                        // leaves the checkbox unnamed to VoiceOver, and `""`
                        // would go into the string catalog as a key.
                        Toggle("Exclude This Path", isOn: $excludedPath.isEnabled)
                            .labelsHidden()
                        TextField("Pattern", text: $excludedPath.path)
                            .textFieldStyle(.plain)
                        Button {
                            indexing.excludedPaths.removeAll { $0.id == excludedPath.id }
                        } label: {
                            SwiftUI.Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack {
                    TextField("Add a path or glob…", text: $newExcludedPath)
                        .onSubmit(addExcludedPath)
                    Button("Add", action: addExcludedPath)
                        .disabled(newExcludedPath.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Excluded Paths")
            } footer: {
                Text("The observable reference model keeps list edits simple: adding, removing and toggling rows are ordinary property mutations, and each one persists with no extra code.")
            }
            .disabled(!indexing.isEnabled)
        }
    }

    private func addExcludedPath() {
        let trimmedPath = newExcludedPath.trimmingCharacters(in: .whitespaces)
        guard !trimmedPath.isEmpty else { return }
        indexing.excludedPaths.append(WorkbenchSettings.ExcludedPath(path: trimmedPath))
        newExcludedPath = ""
    }
}

/// Reads four leaf key paths rather than one section — the other shape
/// `@AppSettings` supports.
@available(macOS 14.0, *)
private struct UpdatesSettingsPage: View {
    @WorkbenchSetting(\.updates.automaticallyChecks)
    private var automaticallyChecks

    @WorkbenchSetting(\.updates.automaticallyDownloads)
    private var automaticallyDownloads

    @WorkbenchSetting(\.updates.checkInterval)
    private var checkInterval

    @WorkbenchSetting(\.updates.includesPrereleases)
    private var includesPrereleases

    var body: some View {
        SettingsForm {
            Section {
                Toggle("Check for Updates Automatically", isOn: $automaticallyChecks)
                Toggle("Download Updates Automatically", isOn: $automaticallyDownloads)
                    .disabled(!automaticallyChecks)
                Picker("Check", selection: $checkInterval) {
                    ForEach(WorkbenchSettings.CheckInterval.allCases) { interval in
                        Text(interval.displayName).tag(interval)
                    }
                }
                .disabled(!automaticallyChecks)
            }

            Section {
                Toggle("Include Pre-Releases", isOn: $includesPrereleases)
            } footer: {
                Text("Each control here binds a single leaf key path (`\\.updates.automaticallyChecks` and friends) instead of the whole section.")
            }
        }
    }
}

@available(macOS 14.0, *)
private struct WorkspaceSettingsPage: View {
    let workspaceID: String

    @WorkbenchSetting(\.workspaces)
    private var workspaces

    private var workspaceIndex: Int? {
        workspaces.firstIndex { $0.id == workspaceID }
    }

    var body: some View {
        SettingsForm {
            if let workspaceIndex {
                Section {
                    LabeledContent("Identifier", value: workspaces[workspaceIndex].id)
                    Toggle("Index This Workspace", isOn: $workspaces[workspaceIndex].isIndexed)
                    TextField("Notes", text: $workspaces[workspaceIndex].notes, axis: .vertical)
                        .lineLimit(2 ... 4)
                } header: {
                    Text(workspaces[workspaceIndex].name)
                } footer: {
                    Text("This page was produced by a `for` loop in the page builder — one page per workspace.")
                }
            }
        }
    }
}

@available(macOS 14.0, *)
private struct AdvancedSettingsPage: View {
    @WorkbenchSetting(\.advanced)
    private var advanced

    var body: some View {
        SettingsForm {
            Section {
                Picker("Log Level", selection: $advanced.logLevel) {
                    ForEach(WorkbenchSettings.LogLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                Toggle("Use Experimental Renderer", isOn: $advanced.usesExperimentalRenderer)
            } header: {
                Text("Diagnostics")
            }

            Section {
                Toggle("Show Developer Page", isOn: $advanced.showsDeveloperPage)
                Toggle("Show a Page per Workspace", isOn: $advanced.showsWorkspacePages)
            } header: {
                Text("Page List")
            } footer: {
                Text("These two drive the page list itself: the first through an `if` in the page builder, the second through a `for`. Flip one, then close and reopen this window to see the sidebar change.")
            }
        }
    }
}

@available(macOS 14.0, *)
private struct DeveloperSettingsPage: View {
    var body: some View {
        SettingsForm {
            Section {
                Text("Registered inside an `if` in the page builder, so it exists only while “Show Developer Page” is on.")
            } header: {
                Text("Conditional page")
            }
        }
    }
}

@available(macOS 14.0, *)
private struct AboutSettingsPage: View {
    var body: some View {
        SettingsForm {
            Section {
                LabeledContent("Settings file", value: WorkbenchSettings.settingsFileURL.path)
                LabeledContent("Auto-save delay", value: "400 ms after the last change")
                LabeledContent("Storage", value: "FileSystemSettingsStorage, wrapped to count writes")
            } header: {
                Text("Persistence")
            }

            Section {
                LabeledContent("Symbol") {
                    HStack(spacing: 10) {
                        SettingsPageIcon(.symbol("gearshape", tint: nil))
                        SettingsPageIcon(.symbol("ladybug", tint: .red))
                    }
                }
                LabeledContent("Text") {
                    HStack(spacing: 10) {
                        SettingsPageIcon(.text("A", tint: .indigo))
                        SettingsPageIcon(.text("β", tint: .teal))
                    }
                }
                LabeledContent("Image") {
                    SettingsPageIcon(.image(SwiftUI.Image(nsImage: NSApp.applicationIconImage)))
                }
                LabeledContent("Plain symbol") {
                    HStack(spacing: 10) {
                        SettingsPageIcon(.plainSymbol("gearshape"))
                        SettingsPageIcon(.plainSymbol("bell.badge", tint: .secondary))
                    }
                }
            } header: {
                Text("Page icon shapes")
            } footer: {
                Text("All four `SettingsPage.Icon` shapes. The first three draw the System Settings badge; `.plainSymbol` draws the glyph alone, for a sidebar that should read as an icon list rather than a grid of coloured tiles. A symbol name the running system does not know falls back to an asset of the same name.")
            }
        }
    }
}

// MARK: - Page registration

/// The page list, in one place.
///
/// Ids are explicit rather than defaulted from the titles: the titles are
/// display strings, and an id that tracks the title breaks selection the moment
/// they are localized.
@available(macOS 14.0, *)
@SettingsPageBuilder
private func workbenchSettingsPages(
    showsDeveloperPage: Bool,
    workspacesForPages: [WorkbenchSettings.Workspace]
) -> [SettingsPage] {
    SettingsPage("General", id: "general", symbol: "gearshape") {
        GeneralSettingsPage()
    }
    SettingsPage("Appearance", id: "appearance", symbol: "paintpalette", tint: .purple) {
        AppearanceSettingsPage()
    }
    SettingsPage("Editor", id: "editor", symbol: "text.alignleft", tint: .blue) {
        EditorSettingsPage()
    }
    SettingsPage("Indexing", id: "indexing", symbol: "square.stack.3d.down.right", tint: .orange) {
        IndexingSettingsPage()
    }
    SettingsPage("Updates", id: "updates", symbol: "arrow.down.circle", tint: .green) {
        UpdatesSettingsPage()
    }

    // `for` in the builder: one page per workspace.
    for workspace in workspacesForPages {
        SettingsPage(workspace.name, id: "workspace.\(workspace.id)", plainSymbol: workspace.symbolName) {
            WorkspaceSettingsPage(workspaceID: workspace.id)
        }
    }

    SettingsPage("Advanced", id: "advanced", icon: .text("A", tint: .gray)) {
        AdvancedSettingsPage()
    }

    // `if` in the builder.
    if showsDeveloperPage {
        SettingsPage("Developer", id: "developer", symbol: "ladybug", tint: .red) {
            DeveloperSettingsPage()
        }
    }

    SettingsPage("About", id: "about", icon: .image(SwiftUI.Image(nsImage: NSApp.applicationIconImage))) {
        AboutSettingsPage()
    }
}

// MARK: - Counter panels

@available(macOS 14.0, *)
private struct GeneralMirrorPanel: View {
    @WorkbenchSetting(\.general)
    private var general

    var body: some View {
        DemoActivity.generalPanelBodyCount += 1
        return CounterPanel(title: "Reads \u{5C}.general") {
            Text("Recent documents \(general.recentDocumentCount) · quit confirmation \(general.confirmsBeforeQuitting ? "on" : "off")")
        }
    }
}

@available(macOS 14.0, *)
private struct AppearanceMirrorPanel: View {
    @WorkbenchSetting(\.appearance)
    private var appearance

    var body: some View {
        DemoActivity.appearancePanelBodyCount += 1
        return CounterPanel(title: "Reads \u{5C}.appearance") {
            HStack(spacing: 8) {
                Circle().fill(appearance.accent.color).frame(width: 12, height: 12)
                Text("\(appearance.theme.displayName) · \(appearance.density.displayName) · icon \(Int(appearance.sidebarIconSize)) pt")
            }
        }
    }
}

/// The control group: reads no settings, so it must never re-evaluate.
@available(macOS 14.0, *)
private struct SettingsFreePanel: View {
    var body: some View {
        DemoActivity.settingsFreePanelBodyCount += 1
        return CounterPanel(title: "Reads no settings") {
            Text("Never touches the store, so it never re-evaluates.")
                .foregroundStyle(.secondary)
        }
    }
}

@available(macOS 14.0, *)
private struct CounterPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            content
                .font(.callout)
                // Wrap rather than widen: an NSHostingView hands its ideal
                // width to Auto Layout as a hard minimum, so a panel that
                // refuses to wrap becomes the window's minimum width.
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

@available(macOS 14.0, *)
private struct MirrorPanels: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeneralMirrorPanel()
            AppearanceMirrorPanel()
            SettingsFreePanel()
        }
    }
}

// MARK: - Demo controller

@available(macOS 14.0, *)
final class SettingsDemoViewController: NSViewController {
    /// Held for the lifetime of the demo — the library ships no singleton, so
    /// keeping one settings window is the host's job.
    private var settingsWindowController: SettingsWindowController?

    /// Outlives the window controller on purpose. The window is rebuilt on every
    /// open (so the conditional pages track the settings), and handing the same
    /// navigator to each rebuild is what keeps the history across them — while
    /// also exercising the pruning, since turning the workspace pages off deletes
    /// pages the history may still name.
    private let settingsNavigator = SettingsNavigator(initialPageID: "general")

    private let backButton = NSButton(title: "Back", target: nil, action: nil)
    private let forwardButton = NSButton(title: "Forward", target: nil, action: nil)
    private let navigationLabel = NSTextField(labelWithString: "")

    /// Caps how wide the demo's own content grows. Without it the panels stretch
    /// across a wide window and read as a banner rather than a column.
    private static let contentWidth: CGFloat = 640

    private let introductionLabel = NSTextField(
        wrappingLabelWithString: """
        The panel opens in its own window. Keep it open beside this one: the panels \
        below read the same settings, so editing anything over there moves them — and \
        the counters show which views the change actually reached. The navigation row \
        drives that window's back / forward chevrons from out here, through the same \
        navigator object the window uses.
        """
    )

    private let statusLabel = NSTextField(labelWithString: "Loading stored settings…")
    private let counterLabel = NSTextField(labelWithString: "")
    private var counterRefreshTimer: Timer?

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        Task { @MainActor in
            let outcome = await WorkbenchSettings.store.load()
            statusLabel.stringValue = Self.description(for: outcome)
            // Loading must not count as a write; start clean so the counters
            // only reflect what the user does.
            DemoActivity.resetCounters()
        }

        let openWindowButton = NSButton(title: "Open Settings Window", target: self, action: #selector(openSettingsWindow))
        openWindowButton.keyEquivalent = "\r"

        let replacementButton = NSButton(title: "Replace Model", target: self, action: #selector(replaceSettingsObject))
        replacementButton.toolTip = "Replaces the settings object and verifies that observation and persistence move to the replacement."

        let saveNowButton = NSButton(title: "Save Now", target: self, action: #selector(saveNow))
        saveNowButton.toolTip = "Writes immediately instead of waiting out the debounce."

        let revealButton = NSButton(title: "Reveal settings.json", target: self, action: #selector(revealSettingsFile))
        let resetSettingsButton = NSButton(title: "Reset Settings", target: self, action: #selector(resetSettings))
        let resetCountersButton = NSButton(title: "Reset Counters", target: self, action: #selector(resetCounters))

        // Everything the settings window's own chevrons do, driven from here
        // instead — the point being that the host holds the navigator.
        let jumpButton = NSButton(title: "Go to Updates", target: self, action: #selector(jumpToUpdatesPage))
        jumpButton.toolTip = "Sets navigator.currentPageID and opens the window on that page."
        backButton.target = self
        backButton.action = #selector(goBackFromHost)
        forwardButton.target = self
        forwardButton.action = #selector(goForwardFromHost)

        introductionLabel.textColor = .secondaryLabelColor
        introductionLabel.preferredMaxLayoutWidth = Self.contentWidth

        for label in [statusLabel, counterLabel, navigationLabel] {
            label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            label.textColor = .secondaryLabelColor
            label.lineBreakMode = .byWordWrapping
            label.maximumNumberOfLines = 0
        }

        // None of these may dictate the window's minimum width: a label's
        // intrinsic width is its single-line width, and Auto Layout will widen
        // the window to honour it unless told otherwise.
        for compressibleView in [introductionLabel, statusLabel, counterLabel, navigationLabel] {
            compressibleView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        let panelsView = NSHostingView(rootView: MirrorPanels())
        panelsView.translatesAutoresizingMaskIntoConstraints = false
        // Same reasoning as the labels, and more acute: an NSHostingView reports
        // the SwiftUI content's ideal size, which becomes a hard floor.
        panelsView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let primaryRow = NSStackView(views: [openWindowButton, replacementButton, saveNowButton, revealButton])
        primaryRow.orientation = .horizontal
        primaryRow.spacing = 10

        let navigationRow = NSStackView(views: [jumpButton, backButton, forwardButton])
        navigationRow.orientation = .horizontal
        navigationRow.spacing = 10

        let secondaryRow = NSStackView(views: [resetSettingsButton, resetCountersButton])
        secondaryRow.orientation = .horizontal
        secondaryRow.spacing = 10

        let stackView = NSStackView(views: [
            introductionLabel,
            primaryRow,
            navigationRow,
            navigationLabel,
            panelsView,
            counterLabel,
            secondaryRow,
            statusLabel,
        ])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor, constant: -20),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.contentWidth),

            panelsView.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            panelsView.trailingAnchor.constraint(equalTo: stackView.trailingAnchor),
            counterLabel.trailingAnchor.constraint(lessThanOrEqualTo: stackView.trailingAnchor),

            introductionLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            introductionLabel.trailingAnchor.constraint(lessThanOrEqualTo: stackView.trailingAnchor),
            navigationLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            navigationLabel.trailingAnchor.constraint(lessThanOrEqualTo: stackView.trailingAnchor),
            counterLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: stackView.leadingAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: stackView.trailingAnchor),
        ])

        startCounterRefresh()
    }

    deinit {
        counterRefreshTimer?.invalidate()
    }

    /// Polls rather than observing: the counters are bumped from inside `body`,
    /// so making them observable would feed the display back into what it
    /// measures.
    private func startCounterRefresh() {
        counterLabel.stringValue = DemoActivity.summary
        refreshNavigationDisplay()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.counterLabel.stringValue = DemoActivity.summary
                self?.refreshNavigationDisplay()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        counterRefreshTimer = timer
    }

    /// Mirrors the navigator into AppKit. Polled alongside the counters — an
    /// AppKit label is not a SwiftUI view, so observation would not reach it.
    private func refreshNavigationDisplay() {
        backButton.isEnabled = settingsNavigator.canGoBack
        forwardButton.isEnabled = settingsNavigator.canGoForward
        navigationLabel.stringValue = """
        page               \(settingsNavigator.currentPageID ?? "—")
        history            \(settingsNavigator.visitedPageIDs.joined(separator: " → "))
        """
    }

    @objc
    private func openSettingsWindow() {
        showSettingsWindow()
    }

    /// Opens the window on a page chosen in code, which is the whole point of
    /// the navigator being the host's to hold.
    @objc
    private func jumpToUpdatesPage() {
        settingsNavigator.currentPageID = "updates"
        showSettingsWindow()
        statusLabel.stringValue = "Jumped to the Updates page by assigning navigator.currentPageID."
    }

    @objc
    private func goBackFromHost() {
        settingsNavigator.goBack()
        refreshNavigationDisplay()
    }

    @objc
    private func goForwardFromHost() {
        settingsNavigator.goForward()
        refreshNavigationDisplay()
    }

    private func showSettingsWindow() {
        // Rebuilt each time so the conditional pages reflect the current
        // settings; a real app would usually build this once. The navigator is
        // the demo's, not the window's, so the history survives the rebuild.
        settingsWindowController = SettingsWindowController(
            title: "Workbench Settings",
            navigator: settingsNavigator
        ) {
            workbenchSettingsPages(
                showsDeveloperPage: WorkbenchSettings.current.advanced.showsDeveloperPage,
                workspacesForPages: WorkbenchSettings.current.advanced.showsWorkspacePages
                    ? WorkbenchSettings.current.workspaces
                    : []
            )
        }
        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
        refreshNavigationDisplay()
    }

    @objc
    private func replaceSettingsObject() {
        let before = WorkbenchSettings.current.general.recentDocumentCount
        let replacementSettings = WorkbenchSettings()
        replacementSettings.general.recentDocumentCount = 999
        WorkbenchSettings.current = replacementSettings
        let after = WorkbenchSettings.current.general.recentDocumentCount
        statusLabel.stringValue = """
        Replaced the model: recent-document count is now \(after) (was \(before)). \
        Readers and persistence now follow the replacement object.
        """
    }

    @objc
    private func saveNow() {
        Task { @MainActor in
            do {
                try await WorkbenchSettings.store.save()
                statusLabel.stringValue = "Saved immediately, cancelling the pending debounced write."
            } catch {
                statusLabel.stringValue = "Save failed: \(error)"
            }
        }
    }

    @objc
    private func revealSettingsFile() {
        let fileURL = WorkbenchSettings.settingsFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            statusLabel.stringValue = "Nothing written yet — change a setting first."
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([fileURL])
    }

    @objc
    private func resetSettings() {
        WorkbenchSettings.current = WorkbenchSettings()
        statusLabel.stringValue = "Reset to defaults; the change persists like any other."
    }

    @objc
    private func resetCounters() {
        DemoActivity.resetCounters()
        counterLabel.stringValue = DemoActivity.summary
        statusLabel.stringValue = "Counters cleared. Change one setting and watch which panels move."
    }

    private static func description(for outcome: SettingsStore<WorkbenchSettings>.LoadOutcome) -> String {
        switch outcome {
        case .loaded:
            "Loaded stored settings from \(WorkbenchSettings.settingsFileURL.path)"
        case .noStoredData:
            "No settings stored yet — showing defaults."
        case .failed(let error):
            "Could not read stored settings (\(error)); showing defaults."
        }
    }
}
