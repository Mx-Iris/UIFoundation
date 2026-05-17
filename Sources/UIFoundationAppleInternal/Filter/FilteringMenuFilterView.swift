#if FilterUI && os(macOS)

import AppKit
import UIFoundationAppKit

protocol FilteringMenuFilterViewDelegate: NSObjectProtocol {
    func filterView(_ filterView: FilteringMenuFilterView, makeFilterFieldKey filterField: FilterSearchField)
}

class FilteringMenuFilterView: NSView {
    static let horizontalPadding: CGFloat = 20

    var initialStringValue: String?
    var filterField: FilterSearchField!
    var menuItem: NSMenuItem!
    weak var delegate: FilteringMenuFilterViewDelegate?

    // override var allowsVibrancy: Bool { true }

    convenience init() {
        self.init(frame: NSMakeRect(0, 0, 120, 27))
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        autoresizingMask = .width

        self.filterField = FilterSearchField(frame: frameRect.insetBy(dx: Self.horizontalPadding, dy: 4))
        // filterField.hasSourceListAppearance = true
        filterField.controlSize = .small
        filterField.autoresizingMask = .width
        addSubview(filterField)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        guard window != nil else { return }

        if let initialStringValue {
            filterField.stringValue = initialStringValue
            self.initialStringValue = nil
        } else {
            filterField.stringValue = ""
        }

        delegate?.filterView(self, makeFilterFieldKey: filterField)

        if let currentEditor = filterField.currentEditor() {
            // currentEditor.selectedRange = NSMakeRange(0, currentEditor.string.count)
            currentEditor.selectedRange = NSMakeRange(currentEditor.string.count, 0)
        }
    }
}

#endif
