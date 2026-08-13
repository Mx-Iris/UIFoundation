#if Settings && os(macOS)

import SwiftUI

/// Reads and writes one property of a ``PersistentSettings`` model from a
/// SwiftUI view.
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
/// SwiftUI observes the property reached by the reference key path. A view
/// reading `general` is therefore unaffected by a change to `appearance`; it
/// does not observe one coarse root value.
@available(macOS 14.0, *)
@MainActor
@propertyWrapper
public struct AppSettings<Root: PersistentSettings, Value> {
    private let keyPath: ReferenceWritableKeyPath<Root, Value>

    public init(_ keyPath: ReferenceWritableKeyPath<Root, Value>) {
        self.keyPath = keyPath
    }

    public var wrappedValue: Value {
        get { Root.store.value[keyPath: keyPath] }
        nonmutating set { Root.store.value[keyPath: keyPath] = newValue }
    }

    /// A key-path binding into the current observable settings object.
    ///
    /// `@Bindable` gives the binding a stable key-path location without
    /// allocating a fresh `Binding(get:set:)` closure pair on every read. A
    /// loaded replacement is picked up because this accessor resolves
    /// `Root.store.value` afresh.
    public var projectedValue: Binding<Value> {
        @Bindable var settings = Root.store.value
        return $settings[dynamicMember: keyPath]
    }
}

#endif
