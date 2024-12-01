@propertyWrapper
public struct ViewInvalidating<Value: Equatable, InvalidationType: InvalidatingViewProtocol> {
    @available(*, unavailable)
    public var wrappedValue: Value {
        get { fatalError() }
        set { fatalError() }
    }

    private var _wrappedValue: Value

    private let storage: InvalidationType

    public init(wrappedValue: Value, _ invalidation: InvalidationType) {
        self._wrappedValue = wrappedValue
        self.storage = invalidation
    }

    public static subscript<EnclosingSelf>(
        _enclosingInstance observed: EnclosingSelf,
        wrapped wrappedKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Value>,
        storage storageKeyPath: ReferenceWritableKeyPath<EnclosingSelf, Self>
    ) -> Value where EnclosingSelf: InvalidatingViewType {
        get {
            return observed[keyPath: storageKeyPath]._wrappedValue
        }

        set {
            guard observed[keyPath: storageKeyPath]._wrappedValue != newValue else { return }
            observed[keyPath: storageKeyPath]._wrappedValue = newValue
            observed[keyPath: storageKeyPath].storage.invalidate(view: observed)
        }
    }
}
