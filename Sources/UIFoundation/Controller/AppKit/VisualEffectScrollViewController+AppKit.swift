#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class VisualEffectScrollViewController<View: NSUIView>: NSUIViewController {
    public let contentView: View

    public let visualEffectView = NSVisualEffectView()

    public let scrollView = NSScrollView()
    
    public init(viewGenerator: @autoclosure () -> View) {
        self.contentView = viewGenerator()
        super.init(nibName: nil, bundle: nil)
        commonInit()
    }

    public convenience init() {
        self.init(viewGenerator: View())
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func commonInit() {}

    
    open override func loadView() {
        view = visualEffectView
        visualEffectView.addSubview(scrollView)
        scrollView.makeConstraints { make in
            make.topAnchor.constraint(equalTo: visualEffectView.topAnchor)
            make.leftAnchor.constraint(equalTo: visualEffectView.leftAnchor)
            make.rightAnchor.constraint(equalTo: visualEffectView.rightAnchor)
            make.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor)
        }
        
        scrollView.documentView = contentView
    }
}



#endif
