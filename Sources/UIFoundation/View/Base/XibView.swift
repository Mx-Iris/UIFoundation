#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XibView: View {
    @IBOutlet open var contentView: NSView!

    open override func commonInit() {
        super.commonInit()

        NSNib(nibClass: Self.self)?.instantiate(withOwner: self, topLevelObjects: nil)

        addSubview(contentView)

        contentView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: topAnchor),
            contentView.leftAnchor.constraint(equalTo: leftAnchor),
            contentView.rightAnchor.constraint(equalTo: rightAnchor),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

public protocol XibViewCreator: NSView {
    static var xibBundle: Bundle { get }
}

extension XibViewCreator {
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
