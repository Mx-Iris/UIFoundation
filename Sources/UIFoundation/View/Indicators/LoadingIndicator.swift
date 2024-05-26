#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public final class LoadingIndicator: NSWindowController {
    private final class ContentWindow: NSWindow {
        convenience init(contentView: NSView) {
            self.init(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            self.contentView = contentView
            self.backgroundColor = .clear
            self.isOpaque = false
            self.level = .floating
            self.ignoresMouseEvents = false
            self.hasShadow = false
            self.isReleasedWhenClosed = false
        }
    }

    private final class ContentView: NSView {
        override var acceptsFirstResponder: Bool { true }
    }

    public static let shared = LoadingIndicator()

    public var backgroundColor: NSColor = .black.withAlphaComponent(0.8) {
        didSet {
            indicatorMaskView.layer?.backgroundColor = backgroundColor.cgColor
        }
    }

    public var cornerRadius: CGFloat = 10 {
        didSet {
            indicatorMaskView.layer?.cornerRadius = cornerRadius
        }
    }

    private var isLoading: Bool = false

    private lazy var contentWindow = ContentWindow(contentView: contentView)

    private lazy var contentView = ContentView()

    private lazy var indicatorMaskView = NSView()

    public var type: IndicatorType = .materialLoading(lineWidth: 3)

    public var radius: CGFloat = 20

    public var color: NSColor = .controlAccentColor

    private var indicatorView: Indicator!

    private init() {
        super.init(window: nil)

        contentView.addSubview(indicatorMaskView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true

        indicatorMaskView.translatesAutoresizingMaskIntoConstraints = false
        indicatorMaskView.wantsLayer = true
        indicatorMaskView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.5).cgColor
        indicatorMaskView.layer?.cornerRadius = 10

        NSLayoutConstraint.activate([
            indicatorMaskView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            indicatorMaskView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indicatorMaskView.widthAnchor.constraint(equalToConstant: 80),
            indicatorMaskView.heightAnchor.constraint(equalToConstant: 80),
        ])

        reloadIndicator()
    }

    public override var windowNibName: NSNib.Name? { "" }

    public override func loadWindow() {
        window = contentWindow
    }

    @available(*, unavailable)
    public override init(window: NSWindow?) {
        fatalError("use shared instance")
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("use shared instance")
    }

    @available(*, unavailable)
    public override func showWindow(_ sender: Any?) {
        fatalError("call to show(in:) function")
    }

    @available(*, unavailable)
    public override func close() {
        fatalError("call to hide(in:) function")
    }

    public func show(in mainWindow: NSWindow) {
        guard !isLoading else { return }
        isLoading = true
        mainWindow.addChildWindow(contentWindow, ordered: .above)
//        let windowWidth: CGFloat = 80
//        let windowHeight: CGFloat = 80
//        let windowFrame = mainWindow.frame.with {
//            $0.origin.x = $0.origin.x + ($0.size.width - windowWidth) / 2
//            $0.origin.y = $0.origin.y + ($0.size.height - windowHeight) / 2
//            $0.size.width = windowWidth
//            $0.size.height = windowHeight
//        }
        indicatorView.startAnimating()
        contentWindow.setFrame(mainWindow.frame, display: true)
//        contentWindow.orderFront(nil)
        super.showWindow(nil)
    }

    public func hide(in mainWindow: NSWindow) {
        guard isLoading else { return }
        isLoading = false
        mainWindow.removeChildWindow(contentWindow)
        indicatorView.stopAnimating()
//        contentWindow.close()
        super.close()
    }

    func reloadIndicator() {
        if let indicatorView {
            indicatorView.removeFromSuperview()
        }
        let indicator: Indicator
        switch type {
        case .ballbeat:
            indicator = BallBeatIndicator(radius: radius, color: color)
        case .ballPulse:
            indicator = BallPulseIndicator(radius: radius, color: color)
        case .ballPulseSync:
            indicator = BallPulseSyncIndicator(radius: radius, color: color)
        case .ballSpinFadeIn:
            indicator = BallSpinFadeIndicator(radius: radius, color: color)
        case .lineScale:
            indicator = LineScaleIndicator(radius: radius, color: color)
        case .lineScalePulse:
            indicator = LineScalePulseIndicator(radius: radius, color: color)
        case .lineSpinFadeLoader:
            indicator = LineSpinFadeLoaderIndicator(radius: radius, color: color)
        case let .materialLoading(lineWidth):
            indicator = MaterialLoadingIndicator(radius: radius, color: color).then {
                $0.lineWidth = lineWidth
            }
        }
        indicator.radius = radius
        indicator.color = color
        indicatorView = indicator
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        indicatorMaskView.addSubview(indicatorView)
        NSLayoutConstraint.activate([
            indicatorView.centerXAnchor.constraint(equalTo: indicatorMaskView.centerXAnchor),
            indicatorView.centerYAnchor.constraint(equalTo: indicatorMaskView.centerYAnchor),
            indicatorView.widthAnchor.constraint(equalToConstant: 50),
            indicatorView.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
}

#endif
