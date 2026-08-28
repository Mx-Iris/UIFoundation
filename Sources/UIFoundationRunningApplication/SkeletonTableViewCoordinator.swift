#if RunningApplication && os(macOS)

import AppKit
import UIFoundationToolbox

/// Drives an `NSTableView` while its real content is loading: it vends a fixed
/// number of placeholder rows made of `SkeletonTableCellView`s.
///
/// It acts as both data source and delegate so the picker can swap the real
/// (diffable) data source out and back in wholesale, without the two ever
/// disagreeing about the row count.
@available(macOS 11.0, *)
@MainActor
final class SkeletonTableViewCoordinator: NSObject {
    /// Shape of a list-style placeholder row. Set while the picker is in the list style,
    /// where there is one full-width column and the per-column placeholders do not apply.
    struct ListRowLayout {
        var iconSize: CGFloat
        var showsIcon: Bool
    }

    var columns: [SkeletonColumnDescriptor] = []

    /// When set, one composite placeholder is vended per row instead of one per column.
    var listRowLayout: ListRowLayout?

    var skeletonAppearance: SkeletonAppearance = .init()

    /// Number of placeholder rows currently vended.
    private(set) var numberOfPlaceholderRows: Int = 0

    /// Whether newly created placeholder cells start their shimmer.
    private(set) var isAnimating = false

    private static let fallbackPlaceholderRowCount = 12

    /// Recompute the placeholder row count from the table's visible height.
    /// - Returns: `true` when the count changed and the table needs a reload.
    func updatePlaceholderRowCount(for tableView: NSTableView, visibleHeight: CGFloat) -> Bool {
        let newCount: Int
        if let explicitCount = skeletonAppearance.placeholderRowCount {
            newCount = max(0, explicitCount)
        } else {
            let rowPitch = tableView.rowHeight + tableView.intercellSpacing.height
            if rowPitch > 0, visibleHeight > 0 {
                newCount = max(1, Int(ceil(visibleHeight / rowPitch)))
            } else {
                // Before the first layout pass the clip view has no height yet;
                // vend a plausible screenful so the skeleton isn't empty.
                newCount = Self.fallbackPlaceholderRowCount
            }
        }
        guard newCount != numberOfPlaceholderRows else { return false }
        numberOfPlaceholderRows = newCount
        return true
    }

    /// Start or stop the shimmer on every placeholder cell currently on screen.
    func setAnimating(_ animating: Bool, in tableView: NSTableView) {
        isAnimating = animating
        tableView.enumerateAvailableRowViews { rowView, rowIndex in
            for columnIndex in 0 ..< rowView.numberOfColumns {
                let cellView = rowView.view(atColumn: columnIndex)
                if let listRowCellView = cellView as? SkeletonListRowCellView {
                    if animating {
                        self.startAnimating(listRowCellView, rowIndex: rowIndex)
                    } else {
                        listRowCellView.stopAnimating()
                    }
                    continue
                }
                guard let skeletonCellView = cellView as? SkeletonTableCellView else { continue }
                if animating {
                    skeletonCellView.startAnimating(
                        phaseOffset: skeletonAppearance.shimmerPhaseOffset(rowIndex: rowIndex, columnIndex: columnIndex)
                    )
                } else {
                    skeletonCellView.stopAnimating()
                }
            }
        }
    }

    /// The two text bars of a list row read their shimmer offsets as column 0 and 1, which
    /// is what keeps `shimmerColumnStagger` meaningful in a single-column table.
    private func startAnimating(_ cellView: SkeletonListRowCellView, rowIndex: Int) {
        cellView.startAnimating(
            iconPhase: skeletonAppearance.shimmerPhaseOffset(rowIndex: rowIndex, columnIndex: 0),
            titlePhase: skeletonAppearance.shimmerPhaseOffset(rowIndex: rowIndex, columnIndex: 0),
            subtitlePhase: skeletonAppearance.shimmerPhaseOffset(rowIndex: rowIndex, columnIndex: 1)
        )
    }
}

// MARK: - NSTableViewDataSource

@available(macOS 11.0, *)
extension SkeletonTableViewCoordinator: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        numberOfPlaceholderRows
    }
}

// MARK: - NSTableViewDelegate

@available(macOS 11.0, *)
extension SkeletonTableViewCoordinator: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        if let listRowLayout {
            let cellView = tableView.box.makeView(ofClass: SkeletonListRowCellView.self)
            cellView.skeletonAppearance = skeletonAppearance
            cellView.iconSize = listRowLayout.iconSize
            cellView.showsIcon = listRowLayout.showsIcon
            cellView.titleWidthFraction = skeletonAppearance.textBarWidthFraction(rowIndex: row, columnIndex: 0)
            cellView.subtitleWidthFraction = skeletonAppearance.textBarWidthFraction(rowIndex: row, columnIndex: 1)
            if isAnimating {
                startAnimating(cellView, rowIndex: row)
            }
            return cellView
        }

        guard let tableColumn,
              let columnIndex = columns.firstIndex(where: { $0.identifier == tableColumn.identifier.rawValue })
        else { return nil }

        let descriptor = columns[columnIndex]
        let cellView = tableView.box.makeView(ofClass: SkeletonTableCellView.self)
        cellView.skeletonAppearance = skeletonAppearance
        cellView.style = descriptor.style
        cellView.textAlignment = descriptor.alignment
        cellView.widthFraction = skeletonAppearance.textBarWidthFraction(rowIndex: row, columnIndex: columnIndex)
        if isAnimating {
            cellView.startAnimating(
                phaseOffset: skeletonAppearance.shimmerPhaseOffset(rowIndex: row, columnIndex: columnIndex)
            )
        }
        return cellView
    }

    // Placeholder rows carry no item — never let them become selectable.
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        false
    }

    func selectionShouldChange(in tableView: NSTableView) -> Bool {
        false
    }
}

#endif
