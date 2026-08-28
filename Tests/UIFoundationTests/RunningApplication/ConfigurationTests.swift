#if RunningApplication && os(macOS)

import AppKit
import Testing
@testable import UIFoundationRunningApplication

/// Covers the pure part of the configuration types: how a style supplies defaults, how an
/// explicit value overrides one, and what survives the trip into `BaseConfiguration`.
///
/// That last one is not hypothetical — the initial sort field was silently dropped on the
/// way into `BaseConfiguration` while everything still compiled, so the picker ignored a
/// configured sort entirely.
@Suite("Configuration")
struct ConfigurationTests {
    typealias ApplicationConfiguration = RunningPickerTabViewController.ApplicationConfiguration
    typealias ProcessConfiguration = RunningPickerTabViewController.ProcessConfiguration

    // MARK: - Style Defaults

    @Test("Style defaults to table so existing callers see no change")
    func defaultStyleIsTable() {
        #expect(ApplicationConfiguration().style == .table)
        #expect(ProcessConfiguration().style == .table)
    }

    @Test("Row height follows the style when it was never set", arguments: [
        (RunningPickerTabViewController.Style.table, CGFloat(28)),
        (.list, CGFloat(44)),
    ])
    func rowHeightFollowsStyle(style: RunningPickerTabViewController.Style, expected: CGFloat) {
        #expect(ApplicationConfiguration(style: style).rowHeight == expected)
        #expect(ProcessConfiguration(style: style).rowHeight == expected)
    }

    @Test("Both tabs use the same icon size for a given style")
    func listIconSizeMatchesAcrossTabs() {
        // These were briefly different per tab, reasoning from how much information the
        // icons carry. Switching between the tabs made that read as a rendering bug, so
        // they were unified.
        #expect(ApplicationConfiguration(style: .list).iconSize == 28)
        #expect(ProcessConfiguration(style: .list).iconSize == 28)
        #expect(ApplicationConfiguration(style: .table).iconSize == 20)
        #expect(ProcessConfiguration(style: .table).iconSize == 20)
    }

    @Test("An explicitly set value wins over the style default")
    func explicitValuesOverrideStyleDefaults() {
        let configuration = ProcessConfiguration(style: .list, rowHeight: 60, cellSpacing: .init(width: 1, height: 7), iconSize: 99)
        #expect(configuration.rowHeight == 60)
        #expect(configuration.cellSpacing == CGSize(width: 1, height: 7))
        #expect(configuration.iconSize == 99)
    }

    @Test("An unset value follows the style when the style is changed afterwards")
    func unsetValuesFollowALaterStyleChange() {
        var configuration = ProcessConfiguration(style: .table)
        #expect(configuration.rowHeight == 28)
        configuration.style = .list
        #expect(configuration.rowHeight == 44)
        #expect(configuration.iconSize == 28)
    }

    @Test("A value set before a style change stays put")
    func explicitValuesSurviveAStyleChange() {
        var configuration = ProcessConfiguration(style: .table, rowHeight: 33)
        configuration.style = .list
        #expect(configuration.rowHeight == 33)
    }

    @Test("Assigning through the public property pins the value")
    func assigningThroughThePropertyPinsTheValue() {
        var configuration = ProcessConfiguration(style: .table)
        configuration.rowHeight = 31
        configuration.style = .list
        #expect(configuration.rowHeight == 31)
    }

    // MARK: - BaseConfiguration Forwarding

    @Test("Every configured value reaches BaseConfiguration")
    func baseConfigurationCarriesEveryValue() {
        let configuration = ProcessConfiguration(
            style: .list,
            title: "T",
            description: "D",
            cancelButtonTitle: "C",
            confirmButtonTitle: "K",
            rowHeight: 50,
            cellSpacing: .init(width: 2, height: 3),
            iconSize: 28,
            initialSortField: .pid,
            initialSortAscending: false
        )
        let base = configuration.baseConfiguration

        #expect(base.style == .list)
        #expect(base.title == "T")
        #expect(base.description == "D")
        #expect(base.cancelButtonTitle == "C")
        #expect(base.confirmButtonTitle == "K")
        #expect(base.rowHeight == 50)
        #expect(base.cellSpacing == CGSize(width: 2, height: 3))
        #expect(base.iconSize == 28)
        // The regression: this pair used to be dropped here.
        #expect(base.initialSortFieldIdentifier == "pid")
        #expect(base.initialSortAscending == false)
    }

    @Test("Application configuration forwards its initial sort too")
    func applicationBaseConfigurationCarriesSort() {
        let base = ApplicationConfiguration(initialSortField: .bundleIdentifier).baseConfiguration
        #expect(base.initialSortFieldIdentifier == "bundleIdentifier")
        #expect(base.initialSortAscending == true)
    }

    @Test("No initial sort means no identifier to apply")
    func absentSortForwardsAsNil() {
        #expect(ProcessConfiguration().baseConfiguration.initialSortFieldIdentifier == nil)
    }

    // MARK: - Field Sortability

    @Test("Only fields with a header title are offered as sort options")
    func onlyTitledFieldsAreSortable() {
        // The list style's sort menu is derived from the same rule the table style uses to
        // decide whether a column gets a sort descriptor, so the icon field is excluded.
        #expect(RunningPickerTabViewController.ProcessField.icon.title.isEmpty)
        #expect(RunningPickerTabViewController.ApplicationField.icon.title.isEmpty)

        let sortableProcessFields = RunningPickerTabViewController.ProcessField.allCases.filter { !$0.title.isEmpty }
        #expect(sortableProcessFields.count == RunningPickerTabViewController.ProcessField.allCases.count - 1)
    }
}

#endif
