#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public protocol XibViewCreating: NSView {
    static var xibBundle: Bundle { get }
}

extension XibViewCreating {
    public static var xibBundle: Bundle { .main }
    public static func create() -> Self {
        var topLevelObjects: NSArray?
        xibBundle.loadNibNamed(.init(describing: Self.self), owner: nil, topLevelObjects: &topLevelObjects)

        guard let view = topLevelObjects?.first(where: { $0 is Self }) as? Self else {
            fatalError("Check that the xib name is the same as the class name")
        }
        return view
    }
}

#endif
