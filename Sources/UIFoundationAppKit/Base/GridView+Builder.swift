#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit

// MARK: - Result builders

/// A result builder that produces an array of ``GridRow`` values for the ``GridView`` DSL.
@resultBuilder
public enum GridContentBuilder {
    public static func buildBlock(_ blocks: [GridRow]...) -> [GridRow] {
        blocks.flatMap { $0 }
    }

    public static func buildOptional(_ rows: [GridRow]?) -> [GridRow] {
        rows ?? []
    }

    public static func buildEither(first: [GridRow]) -> [GridRow] {
        first
    }

    public static func buildEither(second: [GridRow]) -> [GridRow] {
        second
    }

    public static func buildArray(_ components: [[GridRow]]) -> [GridRow] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [GridRow]) -> [GridRow] {
        component
    }

    public static func buildExpression(_ expression: GridRow?) -> [GridRow] {
        expression.map { [$0] } ?? []
    }

    public static func buildExpression(_ expression: [GridRow]?) -> [GridRow] {
        expression ?? []
    }
}

/// A result builder that produces an array of ``GridCell`` values for a ``GridRow``.
///
/// A plain `NSView` expression is folded into a ``GridCell`` (carrying any `gridCell*` modifiers
/// applied to the view); a ``GridCell`` expression is used directly.
@resultBuilder
public enum GridRowContentBuilder {
    public static func buildBlock(_ blocks: [GridCell]...) -> [GridCell] {
        blocks.flatMap { $0 }
    }

    public static func buildOptional(_ cells: [GridCell]?) -> [GridCell] {
        cells ?? []
    }

    public static func buildEither(first: [GridCell]) -> [GridCell] {
        first
    }

    public static func buildEither(second: [GridCell]) -> [GridCell] {
        second
    }

    public static func buildArray(_ components: [[GridCell]]) -> [GridCell] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [GridCell]) -> [GridCell] {
        component
    }

    public static func buildExpression(_ expression: GridCell?) -> [GridCell] {
        expression.map { [$0] } ?? []
    }

    public static func buildExpression(_ expression: NSView?) -> [GridCell] {
        expression.map { [$0._makeGridCell()] } ?? []
    }

    public static func buildExpression(_ expression: [NSView]?) -> [GridCell] {
        (expression ?? []).map { $0._makeGridCell() }
    }
}

/// A result builder that produces an array of ``GridColumn`` values for ``GridView/columns(_:)``.
@resultBuilder
public enum GridColumnBuilder {
    public static func buildBlock(_ blocks: [GridColumn]...) -> [GridColumn] {
        blocks.flatMap { $0 }
    }

    public static func buildOptional(_ columns: [GridColumn]?) -> [GridColumn] {
        columns ?? []
    }

    public static func buildEither(first: [GridColumn]) -> [GridColumn] {
        first
    }

    public static func buildEither(second: [GridColumn]) -> [GridColumn] {
        second
    }

    public static func buildArray(_ components: [[GridColumn]]) -> [GridColumn] {
        components.flatMap { $0 }
    }

    public static func buildLimitedAvailability(_ component: [GridColumn]) -> [GridColumn] {
        component
    }

    public static func buildExpression(_ expression: GridColumn?) -> [GridColumn] {
        expression.map { [$0] } ?? []
    }

    public static func buildExpression(_ expression: [GridColumn]?) -> [GridColumn] {
        expression ?? []
    }
}

// MARK: - NSGridView convenience init & column configuration

extension NSGridView {
    /// Creates a grid view declaratively from rows built with the ``GridContentBuilder`` DSL.
    ///
    /// Cells spanning multiple columns/rows (via `gridCellColumns(_:)` / `gridCellRows(_:)`) are
    /// merged automatically once all rows are in place. Grid-level placement and spacing are
    /// applied up front; because their setters don't invalidate constraints on their own, the
    /// initializer calls `needsUpdateConstraints = true` after assembly.
    ///
    /// - Parameters:
    ///   - rowSpacing: Inter-row spacing. `nil` keeps the system default.
    ///   - columnSpacing: Inter-column spacing. `nil` keeps the system default.
    ///   - xPlacement: The default horizontal placement for all cells.
    ///   - yPlacement: The default vertical placement for all cells.
    ///   - rowAlignment: The default baseline alignment for all rows. When this is anything other
    ///     than `.none`, per-cell `yPlacement` is ignored by `NSGridView`.
    ///   - rows: The grid's rows.
    public convenience init(
        rowSpacing: CGFloat? = nil,
        columnSpacing: CGFloat? = nil,
        xPlacement: NSGridCell.Placement? = nil,
        yPlacement: NSGridCell.Placement? = nil,
        rowAlignment: NSGridRow.Alignment? = nil,
        @GridContentBuilder _ rows: () -> [GridRow]
    ) {
        self.init(frame: .zero)
        if let rowSpacing { self.rowSpacing = rowSpacing }
        if let columnSpacing { self.columnSpacing = columnSpacing }
        if let xPlacement { self.xPlacement = xPlacement }
        if let yPlacement { self.yPlacement = yPlacement }
        if let rowAlignment { self.rowAlignment = rowAlignment }
        _assembleGrid(rows())
        needsUpdateConstraints = true
    }

    /// Applies positional column configuration to the grid.
    ///
    /// The first ``GridColumn`` maps to column `0`, the second to column `1`, and so on. Columns
    /// beyond the grid's column count are ignored. Returns `self` for chaining after the
    /// builder-based initializer.
    @discardableResult
    public func columns(@GridColumnBuilder _ columns: () -> [GridColumn]) -> Self {
        _applyColumns(columns())
        needsUpdateConstraints = true
        return self
    }
}

// MARK: - Assembly

extension NSGridView {
    /// One pending horizontal/vertical merge request, resolved after every row is added.
    private struct PendingMerge {
        var horizontal: NSRange
        var vertical: NSRange
    }

    /// One pending cell configuration, applied to the merge head before merging.
    private struct PendingCell {
        var row: Int
        var column: Int
        var cell: GridCell
    }

    /// Builds the grid from the declared rows, expanding spans into placeholder cells and merging.
    func _assembleGrid(_ rows: [GridRow]) {
        // Tracks `(row, column)` slots reserved by a row-spanning cell declared in an earlier row.
        var occupiedColumnsByRow: [Int: Set<Int>] = [:]
        var pendingMerges: [PendingMerge] = []
        var pendingCells: [PendingCell] = []

        for (rowIndex, gridRow) in rows.enumerated() {
            var rowViews: [NSView] = []
            var columnIndex = 0

            for cell in gridRow.cells {
                // Skip leading columns reserved by a row span from above, padding with empties.
                while occupiedColumnsByRow[rowIndex]?.contains(columnIndex) == true {
                    rowViews.append(NSGridCell.emptyContentView)
                    columnIndex += 1
                }

                let startColumn = columnIndex
                let columnSpan = max(1, cell.columnSpan)
                let rowSpan = max(1, cell.rowSpan)

                rowViews.append(cell.contentView ?? NSGridCell.emptyContentView)
                // Pad this row's own column span with placeholders.
                for _ in 1 ..< columnSpan {
                    rowViews.append(NSGridCell.emptyContentView)
                }

                pendingCells.append(PendingCell(row: rowIndex, column: startColumn, cell: cell))

                if columnSpan > 1 || rowSpan > 1 {
                    pendingMerges.append(
                        PendingMerge(
                            horizontal: NSRange(location: startColumn, length: columnSpan),
                            vertical: NSRange(location: rowIndex, length: rowSpan)
                        )
                    )
                    // Reserve the slots this span covers in the rows below.
                    for reservedRow in (rowIndex + 1) ..< (rowIndex + rowSpan) {
                        for reservedColumn in startColumn ..< (startColumn + columnSpan) {
                            occupiedColumnsByRow[reservedRow, default: []].insert(reservedColumn)
                        }
                    }
                }

                columnIndex = startColumn + columnSpan
            }

            addRow(with: rowViews)
            _applyRow(gridRow, at: rowIndex)
        }

        // Configure every cell before merging — merged children can no longer be configured.
        for pendingCell in pendingCells {
            _applyCell(pendingCell.cell, atColumn: pendingCell.column, row: pendingCell.row)
        }

        // Merge last. Ranges are clamped to the grid's actual dimensions and never overlap.
        for merge in pendingMerges {
            let horizontalLength = min(merge.horizontal.length, numberOfColumns - merge.horizontal.location)
            let verticalLength = min(merge.vertical.length, numberOfRows - merge.vertical.location)
            guard horizontalLength >= 1, verticalLength >= 1, horizontalLength > 1 || verticalLength > 1 else { continue }
            mergeCells(
                inHorizontalRange: NSRange(location: merge.horizontal.location, length: horizontalLength),
                verticalRange: NSRange(location: merge.vertical.location, length: verticalLength)
            )
        }
    }

    private func _applyRow(_ gridRow: GridRow, at index: Int) {
        guard index < numberOfRows else { return }
        let row = row(at: index)
        if let height = gridRow.height { row.height = height }
        if let topPadding = gridRow.topPadding { row.topPadding = topPadding }
        if let bottomPadding = gridRow.bottomPadding { row.bottomPadding = bottomPadding }
        if let yPlacement = gridRow.yPlacement { row.yPlacement = yPlacement }
        if let rowAlignment = gridRow.rowAlignment { row.rowAlignment = rowAlignment }
        if let isHidden = gridRow.isHidden { row.isHidden = isHidden }
    }

    private func _applyCell(_ gridCell: GridCell, atColumn column: Int, row: Int) {
        guard column < numberOfColumns, row < numberOfRows else { return }
        let cell = cell(atColumnIndex: column, rowIndex: row)
        if let xPlacement = gridCell.xPlacement { cell.xPlacement = xPlacement }
        if let yPlacement = gridCell.yPlacement { cell.yPlacement = yPlacement }
        if let rowAlignment = gridCell.rowAlignment { cell.rowAlignment = rowAlignment }
        if let customPlacementConstraints = gridCell.customPlacementConstraints {
            cell.customPlacementConstraints = customPlacementConstraints
        }
    }

    private func _applyColumns(_ columns: [GridColumn]) {
        for (index, gridColumn) in columns.enumerated() where index < numberOfColumns {
            let column = column(at: index)
            if let width = gridColumn.width { column.width = width }
            if let leadingPadding = gridColumn.leadingPadding { column.leadingPadding = leadingPadding }
            if let trailingPadding = gridColumn.trailingPadding { column.trailingPadding = trailingPadding }
            if let xPlacement = gridColumn.xPlacement { column.xPlacement = xPlacement }
            if let isHidden = gridColumn.isHidden { column.isHidden = isHidden }
        }
    }
}

#endif
