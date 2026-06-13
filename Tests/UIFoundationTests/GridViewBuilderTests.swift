#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

@Suite("GridView Builder")
@MainActor
struct GridViewBuilderTests {

    @Test("Basic 2x2 grid maps every cell to its content view")
    func basicGrid() {
        let a = NSView(), b = NSView(), c = NSView(), d = NSView()
        let grid = GridView {
            GridRow { a; b }
            GridRow { c; d }
        }

        #expect(grid.numberOfRows == 2)
        #expect(grid.numberOfColumns == 2)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0).contentView === a)
        #expect(grid.cell(atColumnIndex: 1, rowIndex: 0).contentView === b)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 1).contentView === c)
        #expect(grid.cell(atColumnIndex: 1, rowIndex: 1).contentView === d)
    }

    @Test("GridCell.empty produces a cell with no content view")
    func emptyCell() {
        let a = NSView()
        let grid = GridView {
            GridRow { a; GridCell.empty }
        }

        #expect(grid.numberOfColumns == 2)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0).contentView === a)
        #expect(grid.cell(atColumnIndex: 1, rowIndex: 0).contentView == nil)
    }

    @Test("Column span merges horizontally and the rest of the row stays aligned")
    func columnSpan() {
        let header = NSView(), a = NSView(), b = NSView()
        let grid = GridView {
            GridRow { header.gridView.columns(2) }
            GridRow { a; b }
        }

        #expect(grid.numberOfRows == 2)
        #expect(grid.numberOfColumns == 2)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0).contentView === header)
        // The two spanned slots resolve to the same merged cell.
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0) === grid.cell(atColumnIndex: 1, rowIndex: 0))
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 1).contentView === a)
        #expect(grid.cell(atColumnIndex: 1, rowIndex: 1).contentView === b)
    }

    @Test("A spanning cell pushes its trailing sibling to the correct column")
    func columnSpanAdvancesSiblings() {
        let wide = NSView(), trailing = NSView(), below = NSView()
        let grid = GridView {
            GridRow { wide.gridView.columns(2); trailing }
            GridRow { below }
        }

        #expect(grid.numberOfColumns == 3)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0).contentView === wide)
        #expect(grid.cell(atColumnIndex: 2, rowIndex: 0).contentView === trailing)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0) === grid.cell(atColumnIndex: 1, rowIndex: 0))
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 1).contentView === below)
    }

    @Test("Row span merges vertically and reserves the slot in the row below")
    func rowSpan() {
        let tall = NSView(), beside = NSView(), below = NSView()
        let grid = GridView {
            GridRow { tall.gridView.rows(2); beside }
            GridRow { below }
        }

        #expect(grid.numberOfRows == 2)
        #expect(grid.numberOfColumns == 2)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0).contentView === tall)
        #expect(grid.cell(atColumnIndex: 1, rowIndex: 0).contentView === beside)
        // `below` lands in column 1 because column 0 is reserved by the row span.
        #expect(grid.cell(atColumnIndex: 1, rowIndex: 1).contentView === below)
        // The vertical span resolves to one merged cell.
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0) === grid.cell(atColumnIndex: 0, rowIndex: 1))
    }

    @Test("Row modifiers configure the underlying NSGridRow")
    func rowModifiers() {
        let a = NSView()
        let grid = GridView {
            GridRow { a }
                .height(40)
                .rowAlignment(.firstBaseline)
        }

        #expect(grid.row(at: 0).height == 40)
        #expect(grid.row(at: 0).rowAlignment == .firstBaseline)
    }

    @Test("Cell modifiers configure the underlying NSGridCell")
    func cellModifiers() {
        let label = NSTextField(labelWithString: "Name")
        let grid = GridView {
            GridRow { label.gridView.xPlacement(.trailing) }
        }

        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0).contentView === label)
        #expect(grid.cell(atColumnIndex: 0, rowIndex: 0).xPlacement == .trailing)
    }

    @Test("Grid-level spacing and positional column configuration are applied")
    func gridLevelAndColumns() {
        let a = NSView(), b = NSView()
        let grid = GridView(rowSpacing: 8, columnSpacing: 12) {
            GridRow { a; b }
        }
        .columns {
            GridColumn().width(100)
            GridColumn()
        }

        #expect(grid.rowSpacing == 8)
        #expect(grid.columnSpacing == 12)
        #expect(grid.column(at: 0).width == 100)
    }

    @Test("Optionals and loops inside the builder are flattened")
    func controlFlowInBuilder() {
        let rowsAreVisible = true
        let dynamic = [NSView(), NSView(), NSView()]
        let grid = GridView {
            if rowsAreVisible {
                GridRow { NSView() }
            }
            GridRow {
                for view in dynamic {
                    view
                }
            }
        }

        #expect(grid.numberOfRows == 2)
        #expect(grid.numberOfColumns == 3)
    }
}

#endif
