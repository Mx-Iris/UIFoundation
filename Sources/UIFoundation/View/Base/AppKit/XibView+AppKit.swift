#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class XibView: View {
    
    open class var xibBundle: Bundle { .main }
    
    open class var xibClass: AnyClass { Self.self }
    
    @IBOutlet open var contentView: NSView!

    open override func setup() {
        super.setup()
        
        NSNib(nibClass: Self.xibClass, bundle: Self.xibBundle)?.instantiate(withOwner: self, topLevelObjects: nil)

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

#endif
