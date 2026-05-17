#if FilterUI && os(macOS)

import AppKit

/// The cell interface for AppKit filter fields.
@objcMembers open class FilterSearchFieldCell: NSSearchFieldCell {
    private static let padding = CGSize(width: -5, height: 3)
    // var accessoryWidth: CGFloat { rightMargin + ((controlView as? FilterSearchField)?.accessoryView?.bounds.width ?? 0) }
    open var rightMargin = 0.0
    var hasSourceListAppearance = false
    var hasFilteringAppearance = false
    var showsProgressIndicator = false

    public override init(textCell string: String) {
        super.init(textCell: string)

        font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        isScrollable = true
        self.placeholderString = nil

        if let cancelButtonCell {
            if #available(macOS 12.0, *) {
                cancelButtonCell.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!
                    .withSymbolConfiguration(
                        NSImage.SymbolConfiguration(paletteColors: [.textBackgroundColor, .secondaryLabelColor])
                            .applying(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
                    )
                cancelButtonCell.alternateImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!
                    .withSymbolConfiguration(
                        NSImage.SymbolConfiguration(paletteColors: [.textBackgroundColor, .textColor])
                            .applying(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
                    )
            } else if #available(macOS 11.0, *) {
                cancelButtonCell.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
                cancelButtonCell.alternateImage = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: nil)!
                    .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 12, weight: .regular))
            }
        }
    }

    @available(*, unavailable)
    public required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Layout

    open override func cellSize(forBounds rect: NSRect) -> NSSize {
        var size = super.cellSize(forBounds: rect)
        size.height += ((Self.padding.height - (controlSize == .small ? 1 : 0)) * 2)
        return size
    }

    open override func searchTextRect(forBounds rect: NSRect) -> NSRect {
        var rect = super.searchTextRect(forBounds: rect)
        rect.size.width -= rightMargin + (rightMargin > 0 ? 1 : 0)
        return rect
    }

    open override func searchButtonRect(forBounds rect: NSRect) -> NSRect {
        super.searchButtonRect(forBounds: rect).offsetBy(dx: 2, dy: controlSize == .small ? 0 : -0.5)
    }

    open override func cancelButtonRect(forBounds rect: NSRect) -> NSRect {
        guard !showsProgressIndicator else { return .zero }

        var rect = super.cancelButtonRect(forBounds: rect).offsetBy(dx: -4, dy: controlSize == .small ? 0 : -0.5)
        rect.origin.x -= rightMargin + (rightMargin > 0 ? 1 : 0)
        return rect
    }

    open override func titleRect(forBounds rect: NSRect) -> NSRect {
        rect.insetBy(dx: Self.padding.width, dy: Self.padding.height - (controlSize == .small ? 1 : 0))
    }

//      open override func drawingRect(forBounds rect: NSRect) -> NSRect {
//        let insetRect = rect.insetBy(dx: Self.padding.width, dy: Self.padding.height - (controlSize == .small ? 1 : 0))
//        return super.drawingRect(forBounds: insetRect)
//      }

    // MARK: - Shared Drawing

    open class func placeholderAttributedString(for cell: NSTextFieldCell) -> NSAttributedString {
        NSAttributedString(
            string: cell.placeholderString ?? NSLocalizedString("Filter", bundle: .module, comment: ""),
            attributes: [
                .font: cell.font!,
                .foregroundColor: cell.controlView?.effectiveAppearance.allowsVibrancy == true
                    ? NSColor(named: "filterFieldVibrantPlaceholderTextColor", bundle: .module)!
                    : NSColor(named: "filterFieldNonVibrantPlaceholderTextColor", bundle: .module)!,
            ]
        )
    }

    open class func drawBackground(withFrame cellFrame: NSRect, in controlView: NSView, hasActiveFilter: Bool, hasSourceListAppearance: Bool? = false) {
        let shouldIncreaseContrast = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        let allowsVibrancy = controlView.effectiveAppearance.allowsVibrancy || hasSourceListAppearance == true
        let isKeyOrMainWindow = controlView.window?.isKeyWindow == true || controlView.window?.isMainWindow == true
        let hasKeyboardFocus = controlView.window?.firstResponder == (controlView as? NSControl)?.currentEditor()

        if shouldIncreaseContrast || (isKeyOrMainWindow && (hasKeyboardFocus || hasActiveFilter)) {
            NSColor(named: "filterFieldKeyFocusBackgroundColor", bundle: .module)!.setFill()
        } else {
            if allowsVibrancy {
                if isKeyOrMainWindow {
                    NSColor(named: "filterFieldVibrantActiveBackgroundColor", bundle: .module)!.setFill()
                } else {
                    NSColor(named: "filterFieldVibrantInactiveBackgroundColor", bundle: .module)!.setFill()
                }
            } else {
                if isKeyOrMainWindow {
                    NSColor(named: "filterFieldNonVibrantActiveBackgroundColor", bundle: .module)!.setFill()
                } else {
                    NSColor(named: "filterFieldNonVibrantInactiveBackgroundColor", bundle: .module)!.setFill()
                }
            }
        }

        if shouldIncreaseContrast {
            if isKeyOrMainWindow {
                NSColor(named: "filterFieldHighContrastActiveBorderColor", bundle: .module)!.setStroke()
            } else {
                NSColor(named: "filterFieldHighContrastInactiveBorderColor", bundle: .module)!.setStroke()
            }
        } else {
            if allowsVibrancy {
                NSColor(calibratedWhite: 0.5, alpha: 0.25).setStroke()
            } else {
                if isKeyOrMainWindow, hasActiveFilter || hasKeyboardFocus {
                    NSColor(calibratedWhite: 0.5, alpha: 0.7).setStroke()
                } else {
                    NSColor(calibratedWhite: 0.5, alpha: 0.35).setStroke()
                }
            }
        }
        let path: NSBezierPath
        let roundedRect = cellFrame.insetBy(dx: 0.5, dy: 0.5)
        if #available(macOS 26.0, *) {
            path = NSBezierPath(roundedRect: roundedRect, xRadius: roundedRect.height / 2, yRadius: roundedRect.height / 2)
        } else {
            path = NSBezierPath(roundedRect: roundedRect, xRadius: 6, yRadius: 6)
        }

        path.lineWidth = 1
        path.fill()
        path.stroke()
    }

    // MARK: - Drawing

    open var filterImage: NSImage? = Bundle.module.image(forResource: "filter.circle")!
        .tinted(with: .secondaryLabelColor)

    open var activeFilterImage: NSImage? = Bundle.module.image(forResource: "filter.circle.fill")!
        .tinted(with: .controlAccentColor)

    open override var placeholderString: String? {
        didSet { placeholderAttributedString = FilterSearchFieldCell.placeholderAttributedString(for: self) }
    }

    open override func drawFocusRingMask(withFrame cellFrame: NSRect, in controlView: NSView) {}

    open override func draw(withFrame cellFrame: NSRect, in controlView: NSView) {
        FilterSearchFieldCell.drawBackground(
            withFrame: cellFrame,
            in: controlView,
            hasActiveFilter: !stringValue.isEmpty || hasFilteringAppearance,
            hasSourceListAppearance: hasSourceListAppearance
        )

        drawInterior(withFrame: cellFrame, in: controlView)
    }

    open override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        // guard let filterButtonCell = searchButtonCell, let cancelButtonCell = cancelButtonCell else { return }
        guard let filterButtonCell = searchButtonCell else { return }

        filterButtonCell.image = stringValue.isEmpty ? filterImage : activeFilterImage ?? filterImage
        filterButtonCell.alternateImage = searchButtonCell!.image
//    filterButtonCell.draw(withFrame: searchButtonRect(forBounds: cellFrame), in: controlView)

        let insetRect = cellFrame.insetBy(dx: Self.padding.width, dy: Self.padding.height - (controlSize == .small ? 1 : 0))
        super.drawInterior(withFrame: insetRect, in: controlView)

//    if !stringValue.isEmpty {
//      cancelButtonCell.draw(withFrame: cancelButtonRect(forBounds: cellFrame), in: controlView)
//    }
    }

    // MARK: - Editing

    open override func setUpFieldEditorAttributes(_ textObj: NSText) -> NSText {
        let textObj = super.setUpFieldEditorAttributes(textObj)
        guard let textView = textObj as? NSTextView else { return textObj }
        textView.smartInsertDeleteEnabled = false

        // textView.wantsLayer = true
        // textView.layer?.borderWidth = 1
        // //textView.textContainerInset = NSMakeSize(1, 2)
        // textView.layer?.borderColor = NSColor.systemPink.withAlphaComponent(0.2).cgColor

        return textView
    }

    open override func edit(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, event: NSEvent?) {
        let insetRect = rect.insetBy(dx: Self.padding.width, dy: Self.padding.height - (controlSize == .small ? 1 : 0))
        // rect.size.width -= rightMargin + (rightMargin > 0 ? 1 : 0)
        super.edit(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, event: event)
    }

    open override func select(withFrame rect: NSRect, in controlView: NSView, editor textObj: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let insetRect = rect.insetBy(dx: Self.padding.width, dy: Self.padding.height - (controlSize == .small ? 1 : 0))
        super.select(withFrame: insetRect, in: controlView, editor: textObj, delegate: delegate, start: selStart, length: selLength)
    }
}

#endif
