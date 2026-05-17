#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

extension NSToolbar {
    /// A toolbar item that contains a search field optimized for text-based searches.
    @available(macOS 11.0, *)
    open class Search: ToolbarItem {

        /// The phase of a search interaction.
        public enum SearchState: String {
            /// Searching did start (the search field gained focus and the user began typing).
            case didStart
            /// Searching did update (the search field's text changed).
            case didUpdate
            /// Searching did end (the search field resigned editing).
            case didEnd
        }

        private lazy var _item = SearchNSToolbarItem(for: self)
        public override var item: NSToolbarItem { _item }

        private var widthConstraints: [NSLayoutConstraint] = []

        /// The handler called when the search text changes.
        open var handler: ((_ stringValue: String, _ state: SearchState) -> Void)?

        /// Sets the handler called when the search text changes.
        @discardableResult
        open func onSearch(_ handler: ((_ stringValue: String, _ state: SearchState) -> Void)?) -> Self {
            self.handler = handler
            return self
        }

        /// The search field of the toolbar item.
        open var searchField: NSSearchField {
            get { _item.searchField }
            set { _item.searchField = newValue }
        }

        /// The string value of the search field.
        open var stringValue: String {
            get { searchField.stringValue }
            set { searchField.stringValue = newValue }
        }

        /// Sets the string value of the search field.
        @discardableResult
        open func stringValue(_ stringValue: String) -> Self {
            self.stringValue = stringValue
            return self
        }

        /// The placeholder string of the search field.
        open var placeholderString: String? {
            get { searchField.placeholderString }
            set { searchField.placeholderString = newValue }
        }

        /// Sets the placeholder string of the search field.
        @discardableResult
        open func placeholderString(_ placeholder: String?) -> Self {
            self.placeholderString = placeholder
            return self
        }

        /// The preferred width for the toolbar item when it has keyboard focus.
        open var preferredWidthWhenFocused: CGFloat {
            get { _item.preferredWidthForSearchField }
            set { _item.preferredWidthForSearchField = newValue }
        }

        /// Sets the preferred width for the toolbar item when it has keyboard focus.
        @discardableResult
        open func preferredWidthWhenFocused(_ width: CGFloat) -> Self {
            self.preferredWidthWhenFocused = width
            return self
        }

        /// A Boolean value that controls whether the cancel button resigns first responder
        /// in addition to clearing the contents.
        open var resignsFirstResponderWithCancel: Bool {
            get { _item.resignsFirstResponderWithCancel }
            set { _item.resignsFirstResponderWithCancel = newValue }
        }

        /// Sets whether the cancel button also resigns first responder.
        @discardableResult
        open func resignsFirstResponderWithCancel(_ resigns: Bool) -> Self {
            self.resignsFirstResponderWithCancel = resigns
            return self
        }

        /// The preferred width of the search field item.
        open var preferredWidth: CGFloat? {
            get { widthConstraints.first?.constant }
            set {
                widthConstraints.forEach { $0.isActive = false }
                widthConstraints = []
                if let newValue = newValue {
                    widthConstraints = [
                        searchField.widthAnchor.constraint(lessThanOrEqualToConstant: newValue),
                        searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 40),
                    ]
                    widthConstraints.forEach { $0.isActive = true }
                }
            }
        }

        /// Sets the preferred width of the search field item.
        @discardableResult
        open func preferredWidth(_ preferredWidth: CGFloat?) -> Self {
            self.preferredWidth = preferredWidth
            return self
        }

        /// Starts a search interaction and moves keyboard focus to the search field.
        open func beginSearchInteraction() {
            _item.beginSearchInteraction()
        }

        /// Ends a search interaction by giving up first responder.
        open func endSearchInteraction() {
            _item.endSearchInteraction()
        }

        // MARK: - Init

        public init(_ identifier: NSToolbarItem.Identifier? = nil, preferredWidth: CGFloat? = nil, handler: ((_ stringValue: String, _ state: SearchState) -> Void)? = nil) {
            super.init(identifier)
            searchField.translatesAutoresizingMaskIntoConstraints = false
            self.preferredWidth = preferredWidth
            self.handler = handler
        }

        public init(_ identifier: NSToolbarItem.Identifier? = nil, searchField: NSSearchField) {
            super.init(identifier)
            searchField.translatesAutoresizingMaskIntoConstraints = false
            _item.searchField = searchField
        }

        fileprivate func dispatchTextDidBeginEditing() {
            handler?(stringValue, .didStart)
        }

        fileprivate func dispatchTextDidChange() {
            handler?(stringValue, .didUpdate)
        }

        fileprivate func dispatchTextDidEndEditing() {
            handler?(stringValue, .didEnd)
        }

        private final class SearchNSToolbarItem: NSSearchToolbarItem, NSSearchFieldDelegate {
            weak var owner: NSToolbar.Search?

            init(for owner: NSToolbar.Search) {
                super.init(itemIdentifier: owner.identifier)
                self.owner = owner
                searchField.delegate = self
            }

            override var searchField: NSSearchField {
                didSet { searchField.delegate = self }
            }

            override func validate() {
                super.validate()
                owner?.validate()
            }

            func controlTextDidBeginEditing(_ obj: Notification) {
                owner?.dispatchTextDidBeginEditing()
            }

            func controlTextDidChange(_ obj: Notification) {
                owner?.dispatchTextDidChange()
            }

            func controlTextDidEndEditing(_ obj: Notification) {
                owner?.dispatchTextDidEndEditing()
            }
        }
    }
}

#endif
