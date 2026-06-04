#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

open class VisualEffectScrollViewController<View: NSView>: NSViewController {
    public let contentView: View

    public let visualEffectView = NSVisualEffectView()

    public let scrollView = NSScrollView()
    
    open var isVisualEffectEnabled: Bool { true }

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
        
        if isVisualEffectEnabled {
            view = visualEffectView
            visualEffectView.addSubview(scrollView)
        } else {
            view = NSView()
            view.addSubview(scrollView)
        }
        
        scrollView.makeConstraints { make in
            if #available(macOS 11.0, *) {
                make.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor)
            } else {
                make.topAnchor.constraint(equalTo: view.topAnchor)
            }
            if #available(macOS 11.0, *) {
                make.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor)
            } else {
                make.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            }
            if #available(macOS 11.0, *) {
                make.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor)
            } else {
                make.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            }
            if #available(macOS 11.0, *) {
                make.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
            } else {
                make.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            }
        }

        scrollView.documentView = contentView
    }
}

#endif
