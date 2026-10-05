---
name: uifoundation-settings-layer
description: Wiring an app's settings layer on UIFoundation's PersistentSettings — the Settings root, value-type branches, a SettingsAccess wrapper reached through swift-dependencies, @AppSettings in SwiftUI pages, the launch load and the termination flush, and the first-run gate. Use when adding settings to a new app, when a stored setting silently fails to stick, and before touching an existing SettingsStore.
---

# The settings layer

Every app built on UIFoundation gets the same settings layer. Copy the shape below
rather than inventing one per app — two of the rules here are silent-failure rules,
and both have already cost a debugging session.

The types live in two products, `UIFoundationSettings` (the model: `PersistentSettings`,
`SettingsStore`, `SettingsStorage`) and `UIFoundationSettingsUI` (`@AppSettings` and the
settings window), both macOS 14+ and both behind the package's opt-in `Settings` trait.
For the window and scene themselves, read `Documentations/SettingsWindow.md` in the
UIFoundation repository.

## Canonical layout

Settings live in the module that holds the view models when there are only a handful
of branches, or in a module of their own (`<App>Settings`) once the settings UI grows
its own module. Either way the file split is the same:

| File | Holds |
|---|---|
| `Settings.swift` | `@Observable final class Settings`, its `static let store`, `accessPersistedValues()` |
| `Settings+Types.swift` | One `struct` per branch, each with `static let default = Self()` |
| `SettingsAccess.swift` | `@MainActor @dynamicMemberLookup final class` wrapping the store |
| `InMemorySettingsStorage.swift` | A `SettingsStorage` that never touches the file system |
| `SettingsAccess+DependencyValues.swift` | `@DependencyEntry var settings` |

`SettingsStorage` declares an async and a synchronous `save` / `load` pair; implementing
the synchronous pair is enough, because a synchronous method witnesses its async
counterpart. The in-memory storage has one rule of its own: with nothing stored, `load()`
throws `FileSystemSettingsStorage.LoadError.noStoredData`. The store reads exactly that
error as "nothing written yet" and keeps the defaults; anything else comes back from
`store.load()` as `.failed`.

```swift
final class InMemorySettingsStorage: SettingsStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var storedData: Data?

    func save(_ data: Data) throws {
        lock.lock(); defer { lock.unlock() }
        storedData = data
    }

    func load() throws -> Data {
        lock.lock(); defer { lock.unlock() }
        guard let storedData else { throw FileSystemSettingsStorage.LoadError.noStoredData }
        return storedData
    }

    /// What the last save wrote, for tests asserting that persistence happened.
    func decodedSettings() throws -> Settings? {
        lock.lock(); defer { lock.unlock() }
        guard let storedData else { return nil }
        return try JSONDecoder().decode(Settings.self, from: storedData)
    }
}
```

## Rule 1 — branches are structs, never `@Observable` classes

This is the one that bites. `SettingsStore` arms exactly one observation:

```swift
withObservationTracking {
    value.accessPersistedValues()   // reads `_ = general`, `_ = display`, …
} onChange: { /* debounce, then write the whole model */ }
```

`_ = general` registers the pair `(Settings, \.general)`. With a **struct** branch,
`settings.general.hasCompletedSetup = true` is a write to that very property, so the
change fires. Make the branch an `@Observable` class and the same line mutates a
*different* object's registrar while the root's `general` reference stays put —
nothing fires, the debounced write never gets scheduled, and every setting in the app
silently stops persisting.

```swift
// WRONG — auto-save never runs again
@Observable public final class General { public var hasCompletedSetup = false }

// RIGHT
@Codable @MemberInit public struct General: Sendable {
    @Default(false) public var hasCompletedSetup: Bool
    public static let `default` = Self()
}
```

The pull toward the class version is real: `@Observable` only applies to classes, and
putting it on each branch buys leaf-level observation granularity (a view reading
`showsBranchBadges` is not disturbed by a write to `showsPlatformBadges`). It is not
worth it. Branch-level granularity is what UIFoundation's own `@AppSettings` documents,
settings change at human speed, and the price is that nothing persists at all.

**Symptom to recognise:** settings appear to work all session and reset on the next
launch, and the stored file's modification time only ever advances when the app is
quit normally. The termination flush writes unconditionally, so it masks the bug for
anyone who always quits with ⌘Q — and never for anyone who stops the app from Xcode,
which sends `SIGKILL` and skips `applicationShouldTerminate(_:)` entirely.

**Pin it with a test** against a real store, not against a bare model. A round-trip
`Codable` test passes either way and proves nothing:

```swift
@Test func aNestedWriteReachesStorage() async throws {
    let storage = InMemorySettingsStorage()
    let store = SettingsStore(defaultValue: Settings(), storage: storage, autoSaveDelay: .milliseconds(40))
    store.value.general.hasCompletedSetup = true
    // poll rather than sleep once — the auto-save task is main-actor isolated;
    // pollUntil(timeout:_:) is a small helper of the test target's own
    #expect(await pollUntil(timeout: .seconds(1)) { (try? storage.decodedSettings())?.general.hasCompletedSetup == true })
}
```

`Settings+Types.swift` uses MetaCodable (`@Codable` / `@MemberInit` / `@Default`) so a
branch declares its default once and tolerates a key that an older stored file has
never heard of. Hand-written `init(from:)` with `decodeIfPresent` for every key does
the same job; it just has to be kept in sync by hand in four places per field, and a
missed one is a setting that silently resets.

## Rule 2 — no static convenience accessors; reach settings through the dependency

The tempting shorthand is a static per branch:

```swift
// WRONG — untestable, and parallel tests fight over one object
extension Settings {
    public static var general: General { current.general }
}
```

Anything reading `Settings.general` is welded to the process-wide store, which is
backed by the developer's real settings file. Tests that touch it either scribble on
that file or race each other. `PersistentSettings`'s own static `current` (shorthand for
`store.value`) is the same shortcut, so code under test does not read it either.
Injecting the model through every view-model initialiser works but spreads a
`settings:` parameter through the whole tree.

Wrap the store instead, and publish the wrapper as a dependency:

```swift
@MainActor
@dynamicMemberLookup
public final class SettingsAccess {
    private let store: SettingsStore<Settings>
    fileprivate static let shared = SettingsAccess(store: Settings.store)

    init(store: SettingsStore<Settings>) { self.store = store }

    public var current: Settings {
        get { store.value }
        set { store.value = newValue }
    }

    public subscript<Value>(dynamicMember keyPath: ReferenceWritableKeyPath<Settings, Value>) -> Value {
        get { current[keyPath: keyPath] }
        set { current[keyPath: keyPath] = newValue }
    }

    /// Reads stored settings into the model. Call once at launch, before anything
    /// reads a value — otherwise which service happens to touch settings first
    /// decides whether the app shows the user's values or the defaults, and the
    /// first edit writes those defaults over the stored file.
    public func load() async { … }

    /// Writes immediately and cancels the pending debounced write.
    public func flushSynchronously() { try? store.save() }

    /// An instance that persists nowhere. Backs the preview value, and tests use it.
    static var preview: SettingsAccess {
        SettingsAccess(store: SettingsStore(defaultValue: Settings(), storage: InMemorySettingsStorage()))
    }
}

extension DependencyValues {
    @DependencyEntry(
        liveValue: MainActor.assumeIsolated { SettingsAccess.shared },
        previewValue: MainActor.assumeIsolated { SettingsAccess.preview },
    )
    public var settings: SettingsAccess
}
```

Call sites keep reading `settings.general.hasCompletedSetup` — the dynamic member
subscript forwards through to the store's current object, so observation keeps the
model's own top-level granularity.

`static let store` itself stays. `PersistentSettings` requires it and `@AppSettings`
resolves the model through `Root.store`; it is only the per-branch convenience
accessors that go.

**Deliberately no `testValue`.** Resolving `\.settings` in a test target then fails
loudly, and each test injects its own instance:

```swift
withDependencies { $0.settings = SettingsAccess.preview } operation: { … }
```

A `testValue` would make a forgotten injection pass quietly while several parallel
tests share one cached instance — which is exactly the interference this layer exists
to prevent. Isolation is worth the explicit line.

## SwiftUI pages

Collapse the model parameter once, next to the pages:

```swift
typealias AppSettings<Value> = UIFoundationSettingsUI.AppSettings<MyAppSettings.Settings, Value>
// then: @AppSettings(\.general) private var general
```

The alias also sidesteps `SwiftUI.Settings`, the scene type, which otherwise makes a
bare `Settings` ambiguous in any file that imports both. Where a settings type has to
be spelled out in a signature, qualify it with its module.

## Launch and termination

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    Task { await settings.load() /* then build the first window */ }
}

func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
    settings.flushSynchronously()
    return .terminateNow
}
```

The flush is synchronous on purpose. Auto-save debounces by a second and every edit
restarts that timer, so a change made just before quitting is otherwise lost; and
deferring the write behind `.terminateLater` deadlocks whenever `terminate(_:)` was
itself invoked from a main-queue block, because AppKit waits for the reply in a
nested run loop that cannot drain the main queue.

## The first-run gate

A first-run setup window gated on a stored `hasCompletedSetup` flag has three failure
modes worth designing out up front:

- **Derive the gate from state that is already durable.** "Has the user configured a
  scan root / account / library yet?" is answered by the database or the file system,
  which persisted the moment the user acted. A separate boolean can disagree with it.
- **Flush at the milestone.** Finishing onboarding is exactly the moment not to wait
  out a one-second debounce.
- **Give the window a way out** (`.closable`, or a Skip button). A setup window with
  `styleMask: [.titled]` and one button is a dead end whenever the gate misjudges.

During development the app is normally launched from Xcode and stopped from Xcode,
which never runs `applicationShouldTerminate(_:)`. Anything that only reaches disk at
termination is, for the developer, never persisted at all.

## Checklist for a new app

1. Depend on `UIFoundationSettings` (and `UIFoundationSettingsUI` for the pages) with the
   package's `Settings` trait on — `.package(url: "https://github.com/Mx-Iris/UIFoundation", …, traits: ["Settings"])`.
   Without the trait both modules compile empty and every settings type is missing.
2. `Settings` root: `@Observable final class`, one `var` per branch, `static let store`
   with `FileSystemSettingsStorage(applicationDirectoryName:)` — give debug builds
   their own directory name so they do not share the release build's file.
3. `accessPersistedValues()` reads every encoded branch. Keep it in sync with the
   encoded properties; a branch missing from it still encodes on someone else's save,
   but a change to it alone never triggers one.
4. Branches as structs with `static let default`.
5. `SettingsAccess` + `InMemorySettingsStorage` + the `\.settings` dependency entry.
6. `load()` at launch, `flushSynchronously()` at termination.
7. The `AppSettings` type alias next to the SwiftUI pages.
8. The nested-write persistence test from Rule 1.

## Reference implementation

RuntimeViewer ([MxIris-Reverse-Engineering/RuntimeViewer](https://github.com/MxIris-Reverse-Engineering/RuntimeViewer)),
on its `next` branch until 3.0 ships: `RuntimeViewerPackages/Sources/RuntimeViewerSettings`
holds the full shape, including a one-shot legacy migration run from `load()` (it keeps
`SettingsAccess` and the dependency entry inside `Settings.swift`), and
`RuntimeViewerPackages/Tests/RuntimeViewerApplicationTests/Support/ViewModelTestEnvironment.swift`
shows how view models under test receive an isolated `SettingsAccess`.
