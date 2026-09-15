//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// What lives inside the platter: the query field, the rule under it, and the results.
    ///
    /// It also owns the keyboard table. Spotlight puts those thirteen commands on its
    /// `SearchViewController`; here they arrive through the field editor's
    /// `control(_:textView:doCommandBy:)`, because the query field never gives up first
    /// responder — typing has to keep working while the arrow keys drive the list.
    final class ContentViewController: NSViewController {
        private let metrics: Metrics
        let searchField: SearchField
        let searchFieldContainer = NSView()
        private let separatorView = NSBox()
        let resultsView = ResultsView()

        /// Raised after the search term has settled.
        var searchTermDidChange: ((String) -> Void)?
        /// Raised when Return is pressed or a row is clicked.
        var itemDidActivate: ((AnyHashable) -> Void)?
        /// Raised when the selection moves.
        var selectionDidChange: ((AnyHashable?) -> Void)?
        /// Raised on Escape.
        var cancelRequested: (() -> Void)?
        /// Raised on Tab / Shift-Tab; return `true` to swallow the event.
        var tabPressed: ((Bool) -> Bool)?
        /// Raised on →; return `true` to swallow the event.
        var drillDownRequested: ((AnyHashable) -> Bool)?

        private let searchDebouncer: Debouncer

        private let leadingSymbolName: String?

        init(
            metrics: Metrics,
            searchFieldFontSize: CGFloat,
            searchFieldLeadingSymbolName: String?,
            searchDebounceDelay: TimeInterval
        ) {
            self.metrics = metrics
            self.searchField = SearchField(fontSize: searchFieldFontSize)
            self.leadingSymbolName = searchFieldLeadingSymbolName
            self.searchDebouncer = Debouncer(delay: searchDebounceDelay)
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: Content

        var searchTerm: String {
            get { searchField.stringValue }
            set {
                searchField.stringValue = newValue
                notifySearchTermChanged()
            }
        }

        var placeholderText: String {
            get { searchField.placeholderString ?? "" }
            set { searchField.placeholderString = newValue }
        }

        /// Whether the rule and the result list are showing.
        var showsResults = false {
            didSet {
                guard showsResults != oldValue else { return }
                separatorView.isHidden = !showsResults
                resultsView.isHidden = !showsResults
            }
        }

        func focusSearchField() {
            view.window?.makeFirstResponder(searchField)
        }

        var searchFieldHasSelectedText: Bool { searchField.hasSelectedText }

        // MARK: Layout

        override func loadView() {
            let containerView = NSView()
            containerView.translatesAutoresizingMaskIntoConstraints = false

            searchField.delegate = self

            separatorView.boxType = .separator
            separatorView.translatesAutoresizingMaskIntoConstraints = false
            separatorView.isHidden = true

            resultsView.isHidden = true
            resultsView.canSelectItem = { [weak self] item in
                self?.canSelectItem?(item) ?? true
            }
            resultsView.viewForItem = { [weak self] item in
                self?.viewForItem?(item)
            }
            resultsView.selectionDidChange = { [weak self] item in
                self?.selectionDidChange?(item)
            }
            resultsView.itemDidActivate = { [weak self] item in
                self?.itemDidActivate?(item)
            }

            searchFieldContainer.translatesAutoresizingMaskIntoConstraints = false
            searchFieldContainer.addSubview(searchField)

            let leadingSymbolView: NSImageView? = leadingSymbolName.flatMap { symbolName in
                guard let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) else {
                    return nil
                }
                let imageView = NSImageView()
                imageView.image = image
                imageView.symbolConfiguration = NSImage.SymbolConfiguration(
                    pointSize: metrics.collapsedHeight * 0.36,
                    weight: .regular
                )
                imageView.contentTintColor = .secondaryLabelColor
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.setContentHuggingPriority(.required, for: .horizontal)
                searchFieldContainer.addSubview(imageView)
                return imageView
            }

            containerView.addSubview(searchFieldContainer)
            containerView.addSubview(separatorView)
            containerView.addSubview(resultsView)

            let inset = metrics.horizontalContentInset

            // The field is centred inside a container of the collapsed height rather than being
            // stretched to it. Measured: an `NSTextField`'s intrinsic height for a 24 pt line is
            // 28, but its cell's drawing rect fills whatever height it is given and puts the text
            // at the top of it — so a field pinned to 56 points has its text sitting against the
            // top edge with 28 points of nothing underneath.
            //
            // The 2-point leading correction is the other half of the same story: a borderless,
            // unbezeled `NSTextField` still lays its cell out at x = −2, so without this the query
            // text sits two points left of everything below it.
            NSLayoutConstraint.activate([
                searchFieldContainer.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: inset),
                searchFieldContainer.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -inset),
                searchFieldContainer.topAnchor.constraint(equalTo: containerView.topAnchor),
                searchFieldContainer.heightAnchor.constraint(equalToConstant: metrics.collapsedHeight),

                searchField.trailingAnchor.constraint(equalTo: searchFieldContainer.trailingAnchor),
                searchField.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),

                // Spotlight's rule stops short of the panel's edges rather than running the full
                // width.
                separatorView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: inset),
                separatorView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -inset),
                separatorView.topAnchor.constraint(equalTo: searchFieldContainer.bottomAnchor),
                separatorView.heightAnchor.constraint(equalToConstant: metrics.separatorHeight),

                resultsView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                resultsView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                resultsView.topAnchor.constraint(equalTo: separatorView.bottomAnchor),
                resultsView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            ])

            if let leadingSymbolView {
                NSLayoutConstraint.activate([
                    leadingSymbolView.leadingAnchor.constraint(equalTo: searchFieldContainer.leadingAnchor),
                    leadingSymbolView.centerYAnchor.constraint(equalTo: searchFieldContainer.centerYAnchor),
                    searchField.leadingAnchor.constraint(
                        equalTo: leadingSymbolView.trailingAnchor,
                        constant: metrics.horizontalContentInset * 0.5 + 2
                    ),
                ])
            } else {
                NSLayoutConstraint.activate([
                    searchField.leadingAnchor.constraint(
                        equalTo: searchFieldContainer.leadingAnchor,
                        constant: 2
                    ),
                ])
            }

            view = containerView
        }

        /// Supplied by the panel, forwarded to the results view once it exists.
        var canSelectItem: ((AnyHashable) -> Bool)?
        var viewForItem: ((AnyHashable) -> NSView?)?

        // MARK: Search term

        private func notifySearchTermChanged() {
            searchDebouncer.cancel()
            searchTermDidChange?(searchField.stringValue)
        }
    }
}

// MARK: - The keyboard table

extension SpotlightPanel.ContentViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ notification: Notification) {
        searchDebouncer.schedule { [weak self] in
            guard let self else { return }
            self.searchTermDidChange?(self.searchField.stringValue)
        }
    }

    func control(
        _ control: NSControl,
        textView: NSTextView,
        doCommandBy commandSelector: Selector
    ) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            return resultsView.selectNextSelectableRow()

        case #selector(NSResponder.moveUp(_:)):
            return resultsView.selectPreviousSelectableRow()

        case #selector(NSResponder.insertNewline(_:)):
            guard let selectedItem = resultsView.selectedItem else { return false }
            itemDidActivate?(selectedItem)
            return true

        case #selector(NSResponder.cancelOperation(_:)):
            cancelRequested?()
            return true

        case #selector(NSResponder.insertTab(_:)):
            return tabPressed?(true) ?? false

        case #selector(NSResponder.insertBacktab(_:)):
            return tabPressed?(false) ?? false

        case #selector(NSResponder.moveRight(_:)):
            // Only drills in when the caret is already at the end of the query, so → keeps
            // working as a cursor key while there is still text to move through.
            guard textView.selectedRange.location >= textView.string.count,
                  let selectedItem = resultsView.selectedItem
            else { return false }
            return drillDownRequested?(selectedItem) ?? false

        default:
            // moveLeft:, deleteBackward:, selectAll: and paste: all keep the field editor's own
            // behaviour, which is what Spotlight does with them too.
            return false
        }
    }
}

#endif
