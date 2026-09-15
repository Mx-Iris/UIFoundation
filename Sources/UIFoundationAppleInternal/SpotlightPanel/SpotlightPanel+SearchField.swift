//
//  Replicated from macOS 26's Spotlight.app (26.6.2).
//  Decision record: Documentations/Evolutions/0021-spotlight-panel-replica.md
//

#if SpotlightPanel && os(macOS)

import AppKit

extension SpotlightPanel {
    /// The single-line query field filling the panel's collapsed height.
    ///
    /// Deliberately an `NSTextField` rather than an `NSSearchField`: the search field's bezel,
    /// magnifier and cancel button are all things this design draws itself or leaves out, and
    /// suppressing them is more work than not having them.
    final class SearchField: NSTextField {
        override var focusRingType: NSFocusRingType {
            get { .none }
            set { _ = newValue }
        }

        init(fontSize: CGFloat) {
            super.init(frame: .zero)

            translatesAutoresizingMaskIntoConstraints = false
            font = .systemFont(ofSize: fontSize, weight: .regular)
            textColor = .labelColor
            alignment = .natural
            isEditable = true
            isSelectable = true
            isBordered = false
            isBezeled = false
            drawsBackground = false
            backgroundColor = .clear
            maximumNumberOfLines = 1
            lineBreakMode = .byTruncatingTail
            cell?.wraps = false
            cell?.isScrollable = true
            cell?.usesSingleLineMode = true

            setContentHuggingPriority(.defaultLow, for: .horizontal)
            setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Whether the field editor currently has a non-empty selection.
        ///
        /// The panel asks this before treating ⌘C as "copy the selected result": with text
        /// selected the user means the text.
        var hasSelectedText: Bool {
            guard let fieldEditor = currentEditor() else { return false }
            return fieldEditor.selectedRange.length > 0
        }
    }
}

#endif
