#if FilterUI

import AppKit
import Combine

// FIXME: cancel button highlight glitch (the right edge’s highlight gets stuck when moving the mouse outside while holding down the mouse button)
// FIXME: another cancel button highlight glitch (top and bottom edges gets cut off when highlighted in FilteringMenu’s smaller filter field)
// TODO: consider changing cancel button / progress indicator size to match filter icon (12 pt → 13 pt)

open class ProgressIndicator: NSProgressIndicator {
    open override var allowsVibrancy: Bool { true }
}

/// An AppKit filter field.
@objcMembers open class FilterSearchField: NSSearchField, CALayerDelegate {
    open override class var cellClass: AnyClass? { get { FilterSearchFieldCell.self } set {} }
    public static let indeterminateProgress: Double = -1

    private var hasText = false
    private var subscriptions = Set<AnyCancellable>()
    private var filterButtonSubscriptions = Set<AnyCancellable>()

    open var isHovered = false
    open var progressIndicator = ProgressIndicator()
    open var progress: Double? { didSet { updateProgressIndicator() } }
    open var accessoryView = NSStackView()
    open var accessoryViewCenterYConstraint: NSLayoutConstraint!

    open var trackingTag: TrackingRectTag?

    // open override var allowsVibrancy: Bool { !hasFilteringAppearance }

    open var hasActiveFilter: Bool {
        // hasText || filterButtons.contains { $0.state == .on }
        stringValue != "" || filterButtons.contains { $0.state == .on }
    }

    open override var allowsVibrancy: Bool {
        let isFirstResponder = window?.firstResponder == currentEditor()
        return !(isFirstResponder || hasActiveFilter)
    }

    //  open override var stringValue: String {
//    didSet { hasText = !stringValue.isEmpty }
    //  }

//    open override var controlSize: NSControl.ControlSize {
//        didSet { invalidateIntrinsicContentSize() }
//    }

    open override var intrinsicContentSize: NSSize {
        switch controlSize {
        case .mini: return NSMakeSize(NSView.noIntrinsicMetric, 16)
        case .small: return NSMakeSize(NSView.noIntrinsicMetric, 19)
        case .regular: return NSMakeSize(NSView.noIntrinsicMetric, 22)
        case .large: return NSMakeSize(NSView.noIntrinsicMetric, 24)
        case .extraLarge: return NSMakeSize(NSView.noIntrinsicMetric, 30)
        @unknown default: return .zero
        }
    }

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        font = .systemFont(ofSize: NSFont.smallSystemFontSize)

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.usesThreadedAnimation = true
        progressIndicator.maxValue = 1
        progressIndicator.isHidden = true
        progressIndicator.isIndeterminate = false
        progressIndicator.translatesAutoresizingMaskIntoConstraints = false
        progressIndicator.wantsLayer = true
        // TODO: tweak for retina
        progressIndicator.layer?.sublayerTransform = CATransform3DTranslate(CATransform3DMakeScale(12 / 16, 12 / 16, 1), 16 / 12 * 2, 16 / 12 * 2, 0)
        addSubview(progressIndicator)

        self.accessoryView = NSStackView()
        accessoryView.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 10, right: 0)
        accessoryView.spacing = 0
        accessoryView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accessoryView)
        self.accessoryViewCenterYConstraint = accessoryView.centerYAnchor.constraint(
            equalTo: centerYAnchor,
            constant: (NSScreen.main?.backingScaleFactor ?? 1) < 2 ? -1 : 0
        )

        let accessoryViewTrailingConstant: CGFloat = if #available(macOS 26.0, *) { -8 } else { -4 }
        
        NSLayoutConstraint.activate([
            progressIndicator.widthAnchor.constraint(equalToConstant: 16),
            progressIndicator.heightAnchor.constraint(equalToConstant: 16),
            progressIndicator.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            progressIndicator.centerYAnchor.constraint(equalTo: centerYAnchor),

            accessoryView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: accessoryViewTrailingConstant),
            accessoryViewCenterYConstraint,
            // accessoryView.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            // _accessoryView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -1),
        ])

        Publishers.MergeMany(
            NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification, object: nil),
            NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification, object: nil)
        )
        .sink { [weak self] _ in self?.needsDisplay = true }
        .store(in: &subscriptions)

        Publishers.MergeMany(
            NotificationCenter.default.publisher(for: NSWindow.didChangeScreenProfileNotification, object: nil)
        )
        .sink { [weak self] _ in self?.needsDisplay = true }
        .store(in: &subscriptions)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewWillDraw() {
        guard let cell = cell as? FilterSearchFieldCell else { return }
        cell.hasSourceListAppearance = hasSourceListAppearance
        cell.hasFilteringAppearance = hasFilteringAppearance || hasActiveFilter
        accessoryViewCenterYConstraint.constant = (window?.screen?.backingScaleFactor ?? 1) < 2 ? -1 : 0
    }

    /// Whether accessory views are filtering.
    open var isFiltering = false {
        didSet {
            needsDisplay = true
            layer?.setNeedsDisplay()
        }
    }

    open var hasSourceListAppearance = false

    open var hasFilteringAppearance: Bool {
        isFiltering || !stringValue.isEmpty || window?.firstResponder == currentEditor()
    }

    open func updateProgressIndicator() {
        guard let cell = cell as? FilterSearchFieldCell else { return }

        progressIndicator.isHidden = progress == nil || (isHovered && stringValue != "")
        progressIndicator.isIndeterminate = progress == Self.indeterminateProgress
        progressIndicator.doubleValue = progress ?? 0

        if progress == Self.indeterminateProgress {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }

        cell.showsProgressIndicator = !progressIndicator.isHidden
        updateCell(cell)
    }

    open override func mouseEntered(with event: NSEvent) {
        isHovered = true
        updateProgressIndicator()
    }

    open override func mouseExited(with event: NSEvent) {
        isHovered = false
        updateProgressIndicator()
    }

    open override func viewWillMove(toWindow newWindow: NSWindow?) {
        if newWindow == nil, let trackingTag {
            removeTrackingRect(trackingTag)
        }
    }

    open override func viewDidMoveToWindow() {
        if window != nil {
            trackingTag = addTrackingRect(bounds, owner: self, userData: nil, assumeInside: false)
        }
    }

    // MARK: - Filter Buttons

    open var filterButtons = [NSButton]()

    @discardableResult
    open func addFilterButton(image: NSImage?, alternateImage: NSImage?, toolTip: String, accessibilityDescription: String? = nil) -> NSButton {
        // print(image.size)
        // let imageSize = 16
        // image.size = NSSize(width: imageSize, height: imageSize)
        // alternateImage.size = NSSize(width: imageSize, height: imageSize)

        let button = FilterFieldButton()
        button.setButtonType(.pushOnPushOff)
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        // (button.cell as? NSButtonCell)?.showsStateBy = [.contentsCellMask, .changeGrayCellMask, .changeBackgroundCellMask]
        (button.cell as? NSButtonCell)?.showsStateBy = [.contentsCellMask]
        // button.imageScaling = .scaleProportionallyDown
        button.imageScaling = .scaleNone
        button.imagePosition = .imageOnly
        button.image = image
        button.alternateImage = alternateImage
        button.toolTip = toolTip
        button.setAccessibilityTitle(accessibilityDescription)

        button.cell?.publisher(for: \.state)
            .sink { [weak self, weak button] in
                button?.contentTintColor = $0 == .on ? .controlAccentColor : nil
                self?.needsLayout = true
            }
            .store(in: &filterButtonSubscriptions)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 17),
            button.heightAnchor.constraint(equalToConstant: 15),
        ])

        // button.wantsLayer = true
        // button.layer?.borderColor = NSColor.systemPink.cgColor
        // button.layer?.borderWidth = 1

        accessoryView.addArrangedSubview(button)
        filterButtons.append(button)
        updateAccessoryControlsFrames()

        return button
    }

    @available(macOS 12.0, *)
    @discardableResult
    open func addFilterButton(systemSymbolName: String, toolTip: String, accessibilityDescription: String? = nil, symbolConfiguration: NSImage.SymbolConfiguration = .init(pointSize: 16, weight: .regular, scale: .small)) -> NSButton {
        // FIXME: make the point size behave like in SwiftUI somehow

        let image = NSImage(systemSymbolName: systemSymbolName, accessibilityDescription: nil)?.withSymbolConfiguration(symbolConfiguration)

        let alternateImage = (NSImage(systemSymbolName: systemSymbolName + ".fill", accessibilityDescription: nil) ?? image)?.withSymbolConfiguration(symbolConfiguration.applying(.init(pointSize: 16, weight: .semibold, scale: .small)))

        return addFilterButton(image: image, alternateImage: alternateImage, toolTip: toolTip, accessibilityDescription: accessibilityDescription)
    }

    open func removeAllFilterButtons() {
        filterButtons.forEach { $0.removeFromSuperview() }
        filterButtons = []
        filterButtonSubscriptions = []
        updateAccessoryControlsFrames()
    }

    open func updateAccessoryControlsFrames() {
        guard let cell = cell as? FilterSearchFieldCell else { return }
        cell.rightMargin = filterButtons.map { $0.intrinsicContentSize.width }.reduce(0, +)
        if !filterButtons.isEmpty { cell.rightMargin += 3 }
        // updateCell(cell)
    }
}

class FilterFieldButton: NSButton {
    override var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }
}

// MARK: -

extension FilterSearchField {
    @discardableResult
    open func addFilterButton(symbolName: String, toolTip: String, accessibilityDescription: String? = nil) -> NSButton {
        let image = Bundle.module.image(forResource: symbolName) ?? NSImage()
        let alternateName = symbolName.replacingOccurrences(of: ".raster", with: ".fill.raster")
        let alternateImage = Bundle.module.image(forResource: alternateName) ?? image
        return addFilterButton(image: image, alternateImage: alternateImage, toolTip: toolTip, accessibilityDescription: accessibilityDescription)
    }
}

import SwiftUI

@available(macOS 12.0, *)
struct FilterSearchField_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            NSViewPreview { FilterSearchField() }

            NSViewPreview<FilterSearchField> { f in
                f.placeholderString = "Custom Placeholder"
            }

            NSViewPreview<FilterSearchField> { f in
                f.stringValue = "Lorem Ipsum"
            }

            NSViewPreview<FilterSearchField> { f in
                f.addFilterButton(systemSymbolName: "clock", toolTip: "Show only recent items")
                f.addFilterButton(systemSymbolName: "doc", toolTip: "Show only project-defined items")
                // f.addFilterButton(systemSymbolName: "tag.square", toolTip: "Show only tagged items")
                // f.addFilterButton(systemSymbolName: "square", toolTip: "")
                // f.addFilterButton(systemSymbolName: "c.square", toolTip: "")
            }

            NSViewPreview<FilterSearchField> { f in
                f.addFilterButton(symbolName: "clock.raster", toolTip: "Show only recent items")
                f.addFilterButton(symbolName: "doc.raster", toolTip: "Show only project-defined items")
                // f.addFilterButton(symbolName: "tag.raster", toolTip: "Show only tagged items")
            }

            NSViewPreview<FilterSearchField> { f in
                f.stringValue = "Lorem Ipsum"
                f.addFilterButton(symbolName: "clock.raster", toolTip: "").state = .on
                f.addFilterButton(symbolName: "doc.raster", toolTip: "")
            }

            NSViewPreview<FilterSearchField> { f in
                f.progress = FilterSearchField.indeterminateProgress
//                f.controlSize = .mini
            }

            NSViewPreview<FilterSearchField> { f in
                f.progress = 0
                Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
                    if let p = f.progress { f.progress = p >= 1 ? 0 : p + 0.05 }
                }
            }
        }
        .frame(maxWidth: 300)
        .padding()
    }
}

#endif
