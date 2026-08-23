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

        // xcode15 and xcode26 share every measurement; only the backdrop differs.
        for style in [WelcomePanelController.Style.xcode15, .xcode26] {
            #expect(style.windowRect == CGRect(x: 0, y: 0, width: 740, height: 460))
            #expect(style.projectViewWidth == 280)
            #expect(style.appImageViewTopSpacing == 52)
            #expect(style.windowCornerRadius == 8)
            #expect(style.actionTableViewHeight == 132)
            #expect(style.actionTableViewCellHeight == 36)
            #expect(style.actionTableViewSpacing == 8)
        }
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

        for style in [WelcomePanelController.Style.xcode15, .xcode26] {
            let pillCell = WelcomePanelController.ActionCellView(style: style)
            #expect(pillCell.cornerRadius == 8)
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

    // MARK: - Known gaps carried over verbatim from WelcomeKit

    // Both tests below pin behaviour the port deliberately did NOT fix (Evolution 0011, 非目标):
    // `.xcode26` was added by appending `, .xcode26` to every `case .xcode15:` and two equality
    // checks were missed. They are canaries — if someone fixes the gap, these fail and the guide's
    // "known issues" section has to be updated in the same batch.

    @Test("KNOWN GAP: the close button has no icon under xcode26")
    func closeButtonIconIsMissingUnderXcode26() {
        guard #available(macOS 11.0, *) else { return }

        #expect(WelcomePanelController.HoverButton(style: .xcode15).image != nil)
        #expect(WelcomePanelController.HoverButton(style: .xcode26).image == nil)
        // xcode14 supplies its icon through `notHoveringImage`, from the asset catalog.
        #expect(WelcomePanelController.HoverButton(style: .xcode14).image == nil)
    }

    @Test("KNOWN GAP: pressing an action cell only highlights under xcode15")
    func actionCellHighlightIsMissingUnderXcode26() throws {
        guard #available(macOS 11.0, *) else { return }

        let mouseDown = try Self.makeMouseEvent(type: .leftMouseDown)

        let xcode15Cell = WelcomePanelController.ActionCellView(style: .xcode15)
        xcode15Cell.mouseDown(with: mouseDown)
        #expect(xcode15Cell.backgroundColor === xcode15Cell.highlightBackgroundColor)

        let xcode26Cell = WelcomePanelController.ActionCellView(style: .xcode26)
        xcode26Cell.mouseDown(with: mouseDown)
        #expect(xcode26Cell.backgroundColor === xcode26Cell.normalBackgroundColor)
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
