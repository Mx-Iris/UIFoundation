#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// What `cornerCurve` promises a `LayerBackedView`, checked on rendered pixels rather than on layer
/// properties: the corners take the requested curve, and a full border keeps to the same curve
/// wherever `borderLocation` puts it.
///
/// The probes read the top rows of a corner, where the two curves part the most. A continuous
/// corner leaves the straight edge 1.53 radii from the corner instead of 1, so it is still almost
/// flat there: at a radius of 20 the first covered pixel of the topmost row sits about five pixels
/// (at 2×) further from the corner than on a circular one.
@Suite("LayerBackgroundRenderer corner curve")
@MainActor
struct LayerBackgroundCornerCurveTests {
    private static let tileSize = NSSize(width: 100, height: 80)
    private static let cornerRadius: CGFloat = 20

    @Test("a continuous curve reshapes the corners of the fill")
    func continuousCurveReshapesTheFill() throws {
        let circularFill = try renderedImage(of: filledTile(curve: .circular))
        let continuousFill = try renderedImage(of: filledTile(curve: .continuous))

        let circularStart = try #require(circularFill.firstCoveredColumn(inRow: 0))
        let continuousStart = try #require(continuousFill.firstCoveredColumn(inRow: 0))
        #expect(continuousStart - circularStart >= 2)
    }

    /// An inside border fills the band between the view's outline and that outline inset by the
    /// border's width, the inset outline having a radius smaller by the same width. Row by row
    /// through the corner, the border must stop where a fill of the inset outline starts.
    ///
    /// The tiles clip, the state AppKit puts any rounded view in anyway (see `unclipped(_:)`), so
    /// the border's outer edge is the fill's own mask and only its inner edge tells which curve
    /// the border itself follows. A border stroked along a circular path inside a continuous
    /// corner stops up to five pixels early in the first rows of the inset outline.
    @Test("a full border keeps to the corner curve", arguments: [CALayerCornerCurve.circular, .continuous])
    func fullBorderKeepsToTheCornerCurve(curve: CALayerCornerCurve) throws {
        let borderWidth: CGFloat = 2
        let insetOutline = try renderedImage(
            of: filledTile(curve: curve, insetBy: borderWidth), margin: borderWidth
        )
        let border = try renderedImage(of: borderedTile(curve: curve, location: .inside, width: borderWidth))

        // A continuous corner spans 1.53 radii; at 2× that is the first 61 rows.
        let cornerRows = 0 ..< Int(Self.cornerRadius * 1.53 * 2)
        let misalignedRows = cornerRows.filter { row in
            // The top rows lie wholly inside the border's top edge, where the inset outline has
            // nothing to compare with.
            guard let insetStart = insetOutline.firstCoveredColumn(inRow: row) else { return false }
            guard let borderStart = border.firstCoveredColumn(inRow: row) else { return true }
            return abs(border.firstUncoveredColumn(inRow: row, from: borderStart) - insetStart) > 1
        }
        let mismatches = misalignedRows.map { row in
            let borderEnd = border.firstCoveredColumn(inRow: row).map {
                border.firstUncoveredColumn(inRow: row, from: $0)
            }
            return "row \(row): border ends at \(borderEnd ?? -1), inset outline starts at "
                + "\(insetOutline.firstCoveredColumn(inRow: row) ?? -1)"
        }
        #expect(misalignedRows.isEmpty, "\(mismatches.joined(separator: "; "))")
    }

    /// Where a 4-point border sits relative to the view's left edge: inside it, straddling it, or
    /// wholly outside it. Read on the middle row, clear of the corners.
    @Test("a full border stays where borderLocation puts it", arguments:
        [CALayerCornerCurve.circular, .continuous], BorderPlacement.allCases
    )
    func fullBorderStaysWhereItsLocationPutsIt(curve: CALayerCornerCurve, placement: BorderPlacement) throws {
        let margin: CGFloat = 10
        let border = try renderedImage(
            of: borderedTile(curve: curve, location: placement.location, width: 4, clips: false), margin: margin
        )

        let borderStart = try #require(border.firstCoveredColumn(inRow: border.height / 2))
        #expect(borderStart == Int((margin + placement.expectedLeftEdge) * 2))
    }

    // MARK: - Fixtures

    /// A filled tile, `inset` points smaller on every side with a radius smaller by as much.
    ///
    /// Fills are drawn clipped. `render(in:)` draws the rounded background of a layer that does
    /// not mask to its bounds up to 1.5 points outside the curve — a circular radius of 20 starts
    /// the top row at column 31 instead of the 34 the geometry gives, and the clipped tile does
    /// give 34 — so only a clipped fill is a trustworthy reference.
    private func filledTile(curve: CALayerCornerCurve, insetBy inset: CGFloat = 0) -> LayerBackedView {
        let tile = LayerBackedView(frame: NSRect(
            x: 0, y: 0, width: Self.tileSize.width - inset * 2, height: Self.tileSize.height - inset * 2
        ))
        tile.cornerRadius = Self.cornerRadius - inset
        tile.cornerCurve = curve
        tile.backgroundColor = .black
        tile.clipsToBounds = true
        return tile
    }

    private func borderedTile(
        curve: CALayerCornerCurve,
        location: LayerBackgroundRenderer.BorderLocation,
        width: CGFloat,
        clips: Bool = true
    ) -> LayerBackedView {
        let tile = LayerBackedView(frame: NSRect(origin: .zero, size: Self.tileSize))
        tile.cornerRadius = Self.cornerRadius
        tile.cornerCurve = curve
        tile.borderPositions = .all
        tile.borderLocation = location
        tile.borderWidth = width
        tile.borderColor = .black
        if clips {
            tile.clipsToBounds = true
            return tile
        }
        return unclipped(tile)
    }

    /// Turns the tile's clipping off for good, which takes waiting until its corner radius has
    /// reached the layer.
    ///
    /// AppKit turns `clipsToBounds` on whenever a backing layer's `cornerRadius` changes (macOS
    /// 27.2, measured; assigning the same radius again leaves it alone), and the renderer copies
    /// `clipsToBounds` into `masksToBounds`. A clipped tile cuts the outer half off a centred or
    /// outside border.
    private func unclipped(_ tile: LayerBackedView) -> LayerBackedView {
        tile.updateLayer()
        tile.clipsToBounds = false
        return tile
    }
}

/// The three `BorderLocation`s, each with where the left edge of a 4-point border should land, in
/// points from the view's own left edge.
enum BorderPlacement: CaseIterable, Sendable {
    case inside
    case center
    case outside

    var location: LayerBackgroundRenderer.BorderLocation {
        switch self {
        case .inside: .inside
        case .center: .center
        case .outside: .outside
        }
    }

    var expectedLeftEdge: CGFloat {
        switch self {
        case .inside: 0
        case .center: -2
        case .outside: -4
        }
    }
}

/// The coverage of a rendered layer tree, one alpha value per pixel, rows from the top.
private struct RenderedImage {
    let width: Int
    let height: Int
    let alphas: [UInt8]

    func isCovered(column: Int, row: Int) -> Bool {
        alphas[row * width + column] >= 128
    }

    /// The first column from the left whose pixel is at least half covered.
    func firstCoveredColumn(inRow row: Int) -> Int? {
        (0 ..< width).first { isCovered(column: $0, row: row) }
    }

    /// The first column at or after `start` whose pixel is less than half covered, or the width.
    func firstUncoveredColumn(inRow row: Int, from start: Int) -> Int {
        (start ..< width).first { !isCovered(column: $0, row: row) } ?? width
    }
}

/// Draws the view's layer tree at 2×, with `margin` points of empty space on every side so that a
/// border drawn outside the view's bounds is captured too.
@MainActor
private func renderedImage(of view: NSView, margin: CGFloat = 0, scale: CGFloat = 2) throws -> RenderedImage {
    view.layoutSubtreeIfNeeded()
    view.updateLayer()
    let layer = try #require(view.layer)

    let width = Int((view.bounds.width + margin * 2) * scale)
    let height = Int((view.bounds.height + margin * 2) * scale)
    let context = try #require(CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.scaleBy(x: scale, y: scale)
    context.translateBy(x: margin, y: margin)
    layer.render(in: context)

    let pixels = try #require(context.data).bindMemory(to: UInt8.self, capacity: width * height * 4)
    let alphas = (0 ..< width * height).map { pixels[$0 * 4 + 3] }
    return RenderedImage(width: width, height: height, alphas: alphas)
}

#endif
