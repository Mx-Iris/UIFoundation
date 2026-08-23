#if WelcomePanel && canImport(AppKit) && !targetEnvironment(macCatalyst)

import Testing
import AppKit
@testable import UIFoundationAppKit

/// Pins the geometry table, the data-source contract, and the two style gaps the port carried over
/// verbatim (see Evolution 0011).
@Suite("WelcomePanel", .serialized)
@MainActor
struct WelcomePanelTests {
    // MARK: - Style table

    @Test("the three styles keep their measured geometry")
    func styleGeometry() {
        guard #available(macOS 11.0, *) else { return }

        let xcode14 = WelcomePanelController.Style.xcode14
        #expect(xcode14.windowRect == CGRect(x: 0, y: 0, width: 800, height: 460))
        #expect(xcode14.projectViewWidth == 307)
        #expect(xcode14.appImageViewTopSpacing == 40)
        #expect(xcode14.windowCornerRadius == 0)
        #expect(xcode14.actionTableViewHeight == 138)
        #expect(xcode14.actionTableViewCellHeight == 46)
        #expect(xcode14.actionTableViewSpacing == 0)

        // xcode15 and xcode26 share the window size and the action-row metrics.
        for style in [WelcomePanelController.Style.xcode15, .xcode26] {
            #expect(style.windowRect == CGRect(x: 0, y: 0, width: 740, height: 460))
            #expect(style.projectViewWidth == 280)
            #expect(style.appImageViewTopSpacing == 52)
            #expect(style.actionTableViewHeight == 132)
            #expect(style.actionTableViewCellHeight == 36)
            #expect(style.actionTableViewSpacing == 8)
        }

        #expect(WelcomePanelController.Style.xcode15.windowCornerRadius == 8)
        #expect(WelcomePanelController.Style.xcode26.windowCornerRadius == 20)
    }

    @Test("only xcode14 gets window chrome")
    func windowStyleMask() {
        guard #available(macOS 11.0, *) else { return }

        #expect(WelcomePanelController.Style.xcode14.windowStyleMask == [.titled, .fullSizeContentView])
        #expect(WelcomePanelController.Style.xcode15.windowStyleMask == [.borderless])
        #expect(WelcomePanelController.Style.xcode26.windowStyleMask == [.borderless])
    }

    @Test("the welcome label falls back to a style-specific default")
    func welcomeLabelDefaultText() {
        guard #available(macOS 11.0, *) else { return }

        #expect(WelcomePanelController.Style.xcode14.welcomeLabelDefaultText(forName: "Example") == "Welcome to Example")
        #expect(WelcomePanelController.Style.xcode15.welcomeLabelDefaultText(forName: "Example") == "Example")
        #expect(WelcomePanelController.Style.xcode26.welcomeLabelDefaultText(forName: "Example") == "Example")
    }

    // MARK: - Configuration

    @Test("allActions drops the nil slots and keeps primary → secondary → tertiary order")
    func allActionsCompactsAndOrders() {
        guard #available(macOS 11.0, *) else { return }

        var configuration = WelcomePanelController.Configuration(style: .xcode15)
        configuration.primaryAction = .init(title: "first")
        configuration.tertiaryAction = .init(title: "third")

        #expect(configuration.allActions.map(\.title) == ["first", "third"])

        configuration.secondaryAction = .init(title: "second")
        #expect(configuration.allActions.map(\.title) == ["first", "second", "third"])
    }

    // MARK: - Data source contract

    @Test("assigning the data source pulls the list straight away")
    func assigningDataSourceReloads() {
        guard #available(macOS 11.0, *) else { return }

        let dataSource = StubDataSource()
        dataSource.projectURLs = [URL(fileURLWithPath: "/tmp/one")]
        dataSource.projectCount = 1

        let panel = WelcomePanelController(configuration: .init(style: .xcode15))
        panel.dataSource = dataSource

        #expect(dataSource.usesRecentDocumentURLsQueryCount == 1)
        #expect(panel.projectsViewController.recentProjectURLs == [URL(fileURLWithPath: "/tmp/one")])
    }

    @Test("a negative project count is clamped to zero instead of trapping")
    func negativeProjectCountClampsToZero() {
        guard #available(macOS 11.0, *) else { return }

        let dataSource = StubDataSource()
        dataSource.projectCount = -5

        let panel = WelcomePanelController(configuration: .init(style: .xcode15))
        panel.dataSource = dataSource

        #expect(panel.projectsViewController.recentProjectURLs.isEmpty)
        #expect(dataSource.urlForProjectQueryCount == 0)
    }

    @Test("the recent-documents path never asks the host for a list")
    func recentDocumentURLsPathSkipsHostQueries() {
        guard #available(macOS 11.0, *) else { return }

        let dataSource = StubDataSource()
        dataSource.usesRecentDocumentURLs = true

        let panel = WelcomePanelController(configuration: .init(style: .xcode15))
        panel.dataSource = dataSource

        #expect(panel.projectsViewController.usesRecentDocumentURLs)
        #expect(dataSource.numberOfProjectsQueryCount == 0)
        #expect(dataSource.urlForProjectQueryCount == 0)
    }

    // MARK: - Cells

    @Test("the action cell is a rounded pill under xcode15 / xcode26 and flat under xcode14")
    func actionCellBackgroundGeometry() {
        guard #available(macOS 11.0, *) else { return }

        let flatCell = WelcomePanelController.ActionCellView(style: .xcode14)
        #expect(flatCell.cornerRadius == 0)
        #expect(flatCell.backgroundColor == nil)

        let expectedCornerRadii: [(WelcomePanelController.Style, CGFloat)] = [(.xcode15, 8), (.xcode26, 18)]
        for (style, expectedCornerRadius) in expectedCornerRadii {
            let pillCell = WelcomePanelController.ActionCellView(style: style)
            let cornerRadius = pillCell.cornerRadius
            #expect(cornerRadius == expectedCornerRadius, "style \(style)")
            // The library's renderer clips on `clipsToBounds`, which defaults to false for anything
            // linked against macOS 14 or later — the original clipped on `cornerRadius != 0`.
            #expect(pillCell.clipsToBounds)
            #expect(pillCell.backgroundColor === pillCell.normalBackgroundColor)
        }
    }

    @Test("cells carry the reuse identifier the table looks them up by")
    func cellReuseIdentifiers() {
        guard #available(macOS 11.0, *) else { return }

        #expect(WelcomePanelController.ActionCellView(style: .xcode15).identifier?.rawValue == "ActionCellView")
        #expect(WelcomePanelController.ProjectCellView(style: .xcode15).identifier?.rawValue == "ProjectCellView")
    }

    @Test("the project cell takes its fonts from the style")
    func projectCellFonts() {
        guard #available(macOS 11.0, *) else { return }

        let xcode14Cell = WelcomePanelController.ProjectCellView(style: .xcode14)
        #expect(xcode14Cell.titleLabel.font == .systemFont(ofSize: 13, weight: .regular))

        let xcode15Cell = WelcomePanelController.ProjectCellView(style: .xcode15)
        #expect(xcode15Cell.titleLabel.font == .systemFont(ofSize: 13, weight: .semibold))
        #expect(xcode15Cell.detailLabel.font == .systemFont(ofSize: 11, weight: .regular))
    }

    @Test("clicking an action cell reports through didClick under every style")
    func actionCellReportsClicks() throws {
        guard #available(macOS 11.0, *) else { return }

        for style in [WelcomePanelController.Style.xcode14, .xcode15, .xcode26] {
            let cell = WelcomePanelController.ActionCellView(style: style)
            var clickCount = 0
            cell.didClick = { clickCount += 1 }
            cell.mouseUp(with: try Self.makeMouseEvent(type: .leftMouseUp))
            #expect(clickCount == 1, "style \(style)")
        }
    }


    // MARK: - The Xcode 26 replica (Evolution 0012)

    // Every number below was measured off two view-hierarchy captures of Xcode 26's own welcome
    // window; see Researchs/Xcode26-WelcomeWindow-Internals.md.

    @Test("xcode26 uses the material measured off Xcode's own window")
    func xcode26UsesTheMeasuredMaterial() {
        guard #available(macOS 11.0, *) else { return }

        // `.fullScreenUI` is the one material whose backdrop filter chain matches the capture:
        // colorSaturate 1.8, tint 0.1569 @ 0.5, lighten layer 0.095, chameleon 0.05.
        #expect(WelcomePanelController.Style.xcode26.welcomeViewMaterial == .fullScreenUI)
        #expect(WelcomePanelController.Style.xcode26.projectViewMaterial == .fullScreenUI)

        // The older styles keep what they had: xcode14 paints flat, xcode15 keeps its own backdrop.
        #expect(WelcomePanelController.Style.xcode14.welcomeViewMaterial == nil)
        #expect(WelcomePanelController.Style.xcode15.welcomeViewMaterial == .underWindowBackground)
        #expect(WelcomePanelController.Style.xcode15.projectViewMaterial == .underWindowBackground)
    }

    @Test("xcode26 chrome matches the capture, and xcode15's is untouched")
    func xcode26ChromeMatchesTheCapture() {
        guard #available(macOS 11.0, *) else { return }

        let xcode26 = WelcomePanelController.Style.xcode26
        #expect(xcode26.welcomeLabelDefaultFont == .systemFont(ofSize: 36, weight: .bold))
        #expect(xcode26.closeButtonInset == 13)
        #expect(xcode26.actionCellCornerRadius == 18)
        #expect(xcode26.actionCellIconCenterOffset == 19.5)
        #expect(xcode26.actionCellLabelLeading == 38)

        // xcode15's two offsets are the old `leading 11.5 + width 24` and `icon.trailing + 11`
        // expressed against the row's leading edge — same layout, new spelling.
        let xcode15 = WelcomePanelController.Style.xcode15
        #expect(xcode15.welcomeLabelDefaultFont == .systemFont(ofSize: 30, weight: .bold))
        #expect(xcode15.closeButtonInset == 12)
        #expect(xcode15.actionCellCornerRadius == 8)
        #expect(xcode15.actionCellIconCenterOffset == 23.5)
        #expect(xcode15.actionCellLabelLeading == 46.5)
    }

    @Test("the action list starts where the capture puts it")
    func actionListStartsAtTheMeasuredOffset() {
        guard #available(macOS 11.0, *) else { return }

        // The list is pinned to the pane's bottom, so its top edge — where the first row starts —
        // is what the bottom spacing has to produce. Xcode 26 puts it at y = 287.
        func firstRowOffset(_ style: WelcomePanelController.Style) -> CGFloat {
            style.windowRect.height - style.actionTableViewBottomSpacing - style.actionTableViewHeight
        }
        #expect(firstRowOffset(.xcode26) == 287)
        #expect(firstRowOffset(.xcode15) == 278)
    }

    @Test("xcode26 brings its own icon glow")
    func xcode26BringsItsOwnIconGlow() throws {
        guard #available(macOS 11.0, *) else { return }

        #expect(WelcomePanelController.Style.xcode14.appIconDefaultShadow == nil)
        #expect(WelcomePanelController.Style.xcode15.appIconDefaultShadow == nil)

        let glow = try #require(WelcomePanelController.Style.xcode26.appIconDefaultShadow)
        #expect(glow.shadowBlurRadius == 50)
        #expect(glow.shadowOffset == CGSize(width: 0, height: 2))
        let glowColor = try #require(glow.shadowColor?.usingColorSpace(.sRGB))
        #expect(abs(glowColor.redComponent - 0.0902) < 0.001)
        #expect(abs(glowColor.greenComponent - 0.4157) < 0.001)
        #expect(abs(glowColor.blueComponent - 0.8784) < 0.001)
        #expect(abs(glowColor.alphaComponent - 0.55) < 0.001)
    }

    @Test("the project list is a source list, which is where its insets come from")
    func projectListRunsAsASourceList() {
        guard #available(macOS 11.0, *) else { return }

        let panel = WelcomePanelController(configuration: .init(style: .xcode26))
        // Measured: `.sourceList` is what gives the list Xcode's 10 pt first-row inset and 16 pt
        // cell insets — AppKit applies both, and `intercellSpacing.width` is ignored in view-based
        // mode. Change the style and both silently go away.
        #expect(panel.projectsViewController.tableView.style == .sourceList)
        #expect(panel.projectsViewController.tableView.rowHeight == 44)
    }

    // MARK: - The two gaps Evolution 0012 closed

    // Both were carried over verbatim from WelcomeKit by 0011 and fixed by 0012, which rewrote the
    // xcode26 branch anyway. Upstream had written both checks as `style == .xcode15`, so xcode26 —
    // added later by appending `, .xcode26` to every `case .xcode15:` — silently missed them.

    @Test("every titlebar-less style gets a close-button glyph")
    func closeButtonCarriesAGlyphWithoutATitlebar() {
        guard #available(macOS 11.0, *) else { return }

        #expect(WelcomePanelController.HoverButton(style: .xcode15).image != nil)
        #expect(WelcomePanelController.HoverButton(style: .xcode26).image != nil)
        // xcode14 supplies its icon through `notHoveringImage`, from the asset catalog.
        #expect(WelcomePanelController.HoverButton(style: .xcode14).image == nil)
    }

    @Test("pressing an action cell highlights it under every pill style")
    func actionCellHighlightsWhilePressed() throws {
        guard #available(macOS 11.0, *) else { return }

        let mouseDown = try Self.makeMouseEvent(type: .leftMouseDown)
        let mouseUp = try Self.makeMouseEvent(type: .leftMouseUp)

        for style in [WelcomePanelController.Style.xcode15, .xcode26] {
            let cell = WelcomePanelController.ActionCellView(style: style)
            cell.mouseDown(with: mouseDown)
            #expect(cell.backgroundColor === cell.highlightBackgroundColor, "style \(style)")
            cell.mouseUp(with: mouseUp)
            #expect(cell.backgroundColor === cell.normalBackgroundColor, "style \(style)")
        }
    }

    // MARK: - Helpers

    private static func makeMouseEvent(type: NSEvent.EventType) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }
}

@available(macOS 11.0, *)
private final class StubDataSource: WelcomePanelController.DataSource {
    var usesRecentDocumentURLs = false
    var projectCount = 0
    var projectURLs: [URL] = []

    private(set) var usesRecentDocumentURLsQueryCount = 0
    private(set) var numberOfProjectsQueryCount = 0
    private(set) var urlForProjectQueryCount = 0

    func welcomePanelUsesRecentDocumentURLs(_ welcomePanel: WelcomePanelController) -> Bool {
        usesRecentDocumentURLsQueryCount += 1
        return usesRecentDocumentURLs
    }

    func numberOfProjects(in welcomePanel: WelcomePanelController) -> Int {
        numberOfProjectsQueryCount += 1
        return projectCount
    }

    func welcomePanel(_ welcomePanel: WelcomePanelController, urlForProjectAtIndex index: Int) -> URL {
        urlForProjectQueryCount += 1
        return projectURLs[index]
    }
}

#endif
