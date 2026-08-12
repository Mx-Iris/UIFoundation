#if Settings && os(macOS)

import SwiftUI

/// Reads and writes one slot of a ``PersistentSettings`` model from a SwiftUI
/// view.
///
/// The key path can address a whole section or a single leaf:
///
/// ```swift
/// struct GeneralPage: View {
///     @AppSettings(\Settings.general)
///     private var general
///
///     @AppSettings(\Settings.updates.automaticallyChecks)
///     private var automaticallyChecks
///
///     var body: some View {
///         Toggle("Quit After Closing Last Window", isOn: $general.quitsAfterLastWindowClosed)
///         Toggle("Check for Updates Automatically", isOn: $automaticallyChecks)
///     }
/// }
/// ```
///
/// Declaring a type alias in the host removes the repetition of naming the
/// model at every call site:
///
/// ```swift
/// typealias Setting<Value> = AppSettings<Settings, Value>
/// // …then: @Setting(\.general) private var general
/// ```
///
/// ### What makes the view redraw
///
/// Not this wrapper, and deliberately **not** `DynamicProperty` — it does not
/// conform, and adding the conformance changes nothing (measured: a conforming
/// wrapper, a non-conforming one, and a view reading the store directly all
/// redraw identically). Redraws come from Observation: SwiftUI evaluates `body`
/// inside an observation-tracking scope, so reading `Root.store.value` there is
/// enough to register the dependency, however the value was reached.
///
/// One consequence worth knowing: tracking lands on `store.value` as a whole,
/// so **any** settings change invalidates **every** view that reads settings,
/// including views that read an unrelated field. That is free in a settings
/// window and could matter on a hot path — see `Documentations/SettingsWindow.md`.
@available(macOS 14.0, *)
@MainActor
@propertyWrapper
public struct AppSettings<Root: PersistentSettings, Value> {
    private let keyPath: WritableKeyPath<Root, Value>

    public init(_ keyPath: WritableKeyPath<Root, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        get { Root.store.value[keyPath: keyPath] }
        nonmutating set { Root.store.value[keyPath: keyPath] = newValue }
    }

    /// A key-path binding into the store, not a `Binding(get:set:)`.
    ///
    /// Every control on a settings page goes through here, and `$something` is
    /// read afresh on each body evaluation. The closure form would allocate a
    /// new pair of closures per read and hand out a binding whose location is
    /// new every time — which is what makes a child view holding `@Binding`
    /// look changed on every pass. Derived from the observable store by key
    /// path, the binding's location is stable instead.
    ///
    /// The write still lands as an assignment to `store.value`, which is what
    /// the auto-save hangs off — `AppSettingsTests` pins that down.
    public var projectedValue: Binding<Value> {
        @Bindable var store = Root.store
        return $store.value[dynamicMember: keyPath]
    }
}

#endif
