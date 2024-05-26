#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

public final class LoadingIndicator {
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

    public var containerBackgroundColor: NSColor = .black.withAlphaComponent(0.5) {
        didSet {
            containerView.layer?.backgroundColor = containerBackgroundColor.cgColor
        }
    }

    public var containerCornerRadius: CGFloat = 10 {
        didSet {
            containerView.layer?.cornerRadius = containerCornerRadius
        }
    }

    public var indicatorType: IndicatorType = .materialLoading(lineWidth: 3)

    public var indicatorRadius: CGFloat = 20

    public var indicatorColor: NSColor = .controlAccentColor

    public var ignoresMouseEvents: Bool {
        set { contentWindow.ignoresMouseEvents = newValue }
        get { contentWindow.ignoresMouseEvents }
    }

    private var isLoading: Bool = false

    private lazy var contentWindow = ContentWindow(contentView: contentView)

    private lazy var contentView = ContentView()

    private lazy var containerView = NSView()

    private var indicatorView: Indicator!

    private init() {
        contentView.addSubview(containerView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.wantsLayer = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = containerBackgroundColor.cgColor
        containerView.layer?.cornerRadius = containerCornerRadius

        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 80),
            containerView.heightAnchor.constraint(equalToConstant: 80),
        ])

        reloadIndicator()
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
        contentWindow.orderFront(nil)
    }

    public func hide(in mainWindow: NSWindow) {
        guard isLoading else { return }
        isLoading = false
        mainWindow.removeChildWindow(contentWindow)
        indicatorView.stopAnimating()
        contentWindow.close()
    }

    func reloadIndicator() {
        if let indicatorView {
            indicatorView.removeFromSuperview()
        }
        let indicator: Indicator
        switch indicatorType {
        case .ballbeat:
            indicator = BallBeatIndicator(radius: indicatorRadius, color: indicatorColor)
        case .ballPulse:
            indicator = BallPulseIndicator(radius: indicatorRadius, color: indicatorColor)
        case .ballPulseSync:
            indicator = BallPulseSyncIndicator(radius: indicatorRadius, color: indicatorColor)
        case .ballSpinFadeIn:
            indicator = BallSpinFadeIndicator(radius: indicatorRadius, color: indicatorColor)
        case .lineScale:
            indicator = LineScaleIndicator(radius: indicatorRadius, color: indicatorColor)
        case .lineScalePulse:
            indicator = LineScalePulseIndicator(radius: indicatorRadius, color: indicatorColor)
        case .lineSpinFadeLoader:
            indicator = LineSpinFadeLoaderIndicator(radius: indicatorRadius, color: indicatorColor)
        case let .materialLoading(lineWidth):
            indicator = MaterialLoadingIndicator(radius: indicatorRadius, color: indicatorColor).then {
                $0.lineWidth = lineWidth
            }
        }
        indicator.radius = indicatorRadius
        indicator.color = indicatorColor
        indicatorView = indicator
        indicatorView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(indicatorView)
        NSLayoutConstraint.activate([
            indicatorView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
            indicatorView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            indicatorView.widthAnchor.constraint(equalToConstant: 50),
            indicatorView.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
}

#endif
