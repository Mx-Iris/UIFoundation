#if RunningApplication && os(macOS)

import AppKit
import UIFoundationUtilities
import UIFoundationShared
import UIFoundationToolbox

protocol PickerField: RawRepresentable where RawValue == String {
    var title: String { get }
    var preferredWidth: CGFloat { get }
    var minWidth: CGFloat? { get }
    var maxWidth: CGFloat? { get }
    var headerAlignment: NSTextAlignment? { get }
}

@available(macOS 11.0, *)
struct BaseConfiguration {
    var style: RunningPickerTabViewController.Style
    var title: String
    var description: String
    var cancelButtonTitle: String
    var confirmButtonTitle: String
    var rowHeight: CGFloat
    var cellSpacing: CGSize
    var iconSize: CGFloat
    var initialSortFieldIdentifier: String?
    var initialSortAscending: Bool

    init(
        style: RunningPickerTabViewController.Style = .table,
        title: String = "",
        description: String = "",
        cancelButtonTitle: String = "Cancel",
        confirmButtonTitle: String = "Confirm",
        rowHeight: CGFloat = 25,
        cellSpacing: CGSize = .init(width: 0, height: 10),
        iconSize: CGFloat = 20,
        initialSortFieldIdentifier: String? = nil,
        initialSortAscending: Bool = true
    ) {
        self.style = style
        self.title = title
        self.description = description
        self.cancelButtonTitle = cancelButtonTitle
        self.confirmButtonTitle = confirmButtonTitle
        self.rowHeight = rowHeight
        self.cellSpacing = cellSpacing
        self.iconSize = iconSize
        self.initialSortFieldIdentifier = initialSortFieldIdentifier
        self.initialSortAscending = initialSortAscending
    }
}

@available(macOS 11.0, *)
class RunningItemPickerViewController<Item: RunningItem>: XiblessViewController<NSView>, NSTableViewDelegate, NSMenuDelegate {
    private enum Section: CaseIterable {
        case main
    }

    private typealias DataSource = NSTableViewDiffableDataSource<Section, Item>
    private typealias Snapshot = NSDiffableDataSourceSnapshot<Section, Item>

    // MARK: - UI

    let scrollView = NSScrollView()
    let tableView = NSTableView()
    let titleLabel = NSTextField(labelWithString: "")
    let descriptionLabel = NSTextField(labelWithString: "")
    private(set) lazy var cancelButton = NSButton(title: "", target: self, action: #selector(cancelAction))
    private(set) lazy var confirmButton = NSButton(title: "", target: self, action: #selector(confirmAction))
    let topStackView = NSStackView()
    let titleStackView = NSStackView()
    let bottomStackView = NSStackView()
    let searchField = NSSearchField()
    /// Sorting entry point for the list style, which has no column headers to click.
    private(set) lazy var sortControl = NSPopUpButton(frame: .zero, pullsDown: false)
    private let searchRowStackView = NSStackView()

    private lazy var dataSource = makeDataSource()
    private var cachedItems: [Item] = []
    private var sortColumnIdentifier: String?
    private var sortAscending: Bool = true

    /// The list style is a table with one full-width column and no header, which keeps
    /// selection, type-select, context menus and the diffable data source working exactly
    /// as they do in the table style. Its identifier is ``ListRowColumn/identifier``.
    private(set) var presentationStyle: RunningPickerTabViewController.Style = .table
    /// Fields that can be sorted on, in configured order. A field is sortable exactly
    /// when it has a header title -- the same rule the table style uses to decide whether
    /// a column gets a sort descriptor.
    private var sortableFields: [(identifier: String, title: String)] = []
    private var searchFieldWidthConstraint: NSLayoutConstraint?
    private var hasAppliedInitialSort = false
    private var listIconSize: CGFloat = 22
    /// Field identifiers in configured order, used to lay out a list row.
    private var configuredFieldIdentifiers: [String] = []

    private let skeletonCoordinator = SkeletonTableViewCoordinator()
    private var hasShownInitialData = false
    private var skeletonIsVisible = false

    // MARK: - Subclass Hooks

    /// Return the items to display. Called on each reload.
    func loadItems() -> [Item] { [] }

    /// Filter items based on search text. Default implementation matches the name or
    /// the platform, so "sim", "simulator" and "catalyst" all pull up the processes they
    /// describe.
    func filterItems(_ items: [Item], searchText: String) -> [Item] {
        guard !searchText.isEmpty else { return items }
        return items.filter { item in
            item.name.localizedCaseInsensitiveContains(searchText)
                || item.platform?.matches(searchText: searchText) == true
        }
    }

    /// Configure the table columns. Subclasses must call `addTableColumn` for each column.
    func configureColumns() {}

    /// The configuration to apply on load. Pulled by the base class rather than pushed by
    /// the subclass, because columns are built from `presentationStyle` and must therefore
    /// be built *after* the configuration lands -- a subclass calling
    /// `applyBaseConfiguration` from its own `viewDidLoad` runs too late, after
    /// `super.viewDidLoad()` has already built the columns.
    func currentBaseConfiguration() -> BaseConfiguration { .init() }

    /// Return a cell view for the given column and item. Table style only -- the list
    /// style builds its row in the base class so that the layout rules stay uniform.
    func makeCellView(for tableColumn: NSTableColumn, item: Item) -> NSView? { nil }

    /// Return the display string for a field, used to build a list row's subtitle.
    /// Subclasses override to add their own fields and defer to `super` for shared ones.
    func fieldValue(_ fieldIdentifier: String, for item: Item) -> String? {
        switch fieldIdentifier {
        case "pid": "\(item.processIdentifier)"
        case "architecture": item.architecture?.description
        default: nil
        }
    }

    /// Return context menu items for the given item.
    func contextMenuItems(for item: Item) -> [NSMenuItem] { [] }

    /// Called when the user clicks Cancel.
    func didCancel() {}

    /// Called when the user confirms selection.
    func didConfirm(item: Item) {}

    /// Called when selection changes.
    func didSelect(item: Item) {}

    /// Return whether the given item should be selectable.
    func shouldSelect(item: Item) -> Bool { true }

    /// Return the type-select string for the given item. Default returns name.
    func typeSelectString(for item: Item) -> String? { item.name }

    /// Compare two items for sorting by the given column. Return `.orderedSame` for non-sortable columns.
    func compareItems(_ lhs: Item, _ rhs: Item, columnIdentifier: String) -> ComparisonResult { .orderedSame }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(scrollView)
        view.addSubview(topStackView)
        view.addSubview(searchRowStackView)
        view.addSubview(bottomStackView)

        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay

        topStackView.makeConstraints { make in
            make.topAnchor.constraint(equalTo: view.topAnchor)
            make.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            make.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        }

        searchRowStackView.makeConstraints { make in
            make.topAnchor.constraint(equalTo: topStackView.bottomAnchor, constant: 12)
            make.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            make.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        }

        scrollView.makeConstraints { make in
            make.topAnchor.constraint(equalTo: searchRowStackView.bottomAnchor, constant: 12)
            make.bottomAnchor.constraint(equalTo: bottomStackView.topAnchor, constant: -20)
            make.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            make.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        }

        bottomStackView.makeConstraints { make in
            make.leadingAnchor.constraint(equalTo: view.leadingAnchor)
            make.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            make.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        }

        let searchFieldWidth = searchField.widthAnchor.constraint(equalToConstant: 300)
        searchFieldWidth.isActive = true
        searchFieldWidthConstraint = searchFieldWidth

        topStackView.orientation = .horizontal
        topStackView.spacing = 10
        topStackView.distribution = .fill
        topStackView.alignment = .top
        topStackView.addArrangedSubview(titleStackView)
        topStackView.addArrangedSubview(searchField)

        searchRowStackView.orientation = .horizontal
        searchRowStackView.spacing = 10
        searchRowStackView.distribution = .fill
        searchRowStackView.alignment = .centerY
        searchRowStackView.addArrangedSubview(sortControl)
        sortControl.setContentHuggingPriority(.required, for: .horizontal)
        sortControl.setContentCompressionResistancePriority(.required, for: .horizontal)

        titleStackView.orientation = .vertical
        titleStackView.spacing = 10
        titleStackView.distribution = .fill
        titleStackView.alignment = .leading
        titleStackView.addArrangedSubview(titleLabel)
        titleStackView.addArrangedSubview(descriptionLabel)

        bottomStackView.orientation = .horizontal
        bottomStackView.spacing = 10
        bottomStackView.distribution = .gravityAreas
        bottomStackView.alignment = .centerY
        bottomStackView.addView(cancelButton, in: .trailing)
        bottomStackView.addView(confirmButton, in: .trailing)
        bottomStackView.setCustomSpacing(12, after: cancelButton)

        if #available(macOS 26.0, *) {
            searchField.controlSize = .extraLarge
        } else {
            searchField.controlSize = .large
        }
        searchField.refusesFirstResponder = true
        searchField.target = self
        searchField.action = #selector(searchTextFieldDidChange(_:))

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = .labelColor

        descriptionLabel.font = .systemFont(ofSize: 14, weight: .regular)
        descriptionLabel.textColor = .secondaryLabelColor

        cancelButton.keyEquivalent = "\u{1b}"

        confirmButton.keyEquivalent = "\r"
        confirmButton.isEnabled = false

        scrollView.documentView = tableView

        tableView.allowsEmptySelection = false
        tableView.allowsMultipleSelection = false
        tableView.style = .inset
        tableView.dataSource = dataSource
        tableView.delegate = self

        applyBaseConfiguration(currentBaseConfiguration())
        configureColumns()
        setupTableViewMenu()
        reloadData()

        if cachedItems.isEmpty {
            showSkeleton()
        } else {
            hasShownInitialData = true
        }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        if skeletonIsVisible {
            skeletonCoordinator.setAnimating(true, in: tableView)
        }
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        if skeletonIsVisible {
            skeletonCoordinator.setAnimating(false, in: tableView)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        // The single list column tracks the table's width; the table's width is only known
        // after layout.
        if presentationStyle == .list {
            tableView.sizeLastColumnToFit()
        }
        // The placeholder row count follows the visible height, which is only
        // known once the scroll view has been laid out.
        guard skeletonIsVisible else { return }
        if skeletonCoordinator.updatePlaceholderRowCount(for: tableView, visibleHeight: scrollView.contentView.bounds.height) {
            tableView.reloadData()
        }
    }

    // MARK: - Data

    func reloadData() {
        cachedItems = loadItems()
        applyFilter()
    }

    func updateItems(_ items: [Item], animatingDifferences: Bool = false) {
        cachedItems = items
        if !hasShownInitialData, !items.isEmpty {
            hasShownInitialData = true
            hideSkeleton(animated: true)
            return
        }
        applyFilter(animatingDifferences: animatingDifferences)
    }

    // MARK: - Skeleton

    /// Whether the table is currently filled with loading placeholders instead
    /// of real content.
    var isSkeletonVisible: Bool { skeletonIsVisible }

    /// Tunable appearance for the loading skeleton.
    var skeletonAppearance: SkeletonAppearance {
        get { skeletonCoordinator.skeletonAppearance }
        set {
            skeletonCoordinator.skeletonAppearance = newValue
            guard skeletonIsVisible else { return }
            _ = skeletonCoordinator.updatePlaceholderRowCount(for: tableView, visibleHeight: scrollView.contentView.bounds.height)
            tableView.reloadData()
        }
    }

    /// Manually show or hide the skeleton. Once called, the natural
    /// "hide on first data" path is suppressed so the caller owns visibility.
    /// - Parameters:
    ///   - visible: target visibility.
    ///   - animated: cross-fade the table between placeholders and content.
    func setSkeletonVisible(_ visible: Bool, animated: Bool = true) {
        hasShownInitialData = true
        if visible {
            showSkeleton(animated: animated)
        } else {
            hideSkeleton(animated: animated)
        }
    }

    /// Swap the real (diffable) data source out for the placeholder one. Both
    /// the data source and the delegate are swapped together so the table can
    /// never see a row count from one and a cell from the other.
    private func showSkeleton(animated: Bool = false) {
        guard !skeletonIsVisible else { return }
        skeletonIsVisible = true
        _ = skeletonCoordinator.updatePlaceholderRowCount(for: tableView, visibleHeight: scrollView.contentView.bounds.height)
        tableView.dataSource = skeletonCoordinator
        tableView.delegate = skeletonCoordinator
        tableView.deselectAll(nil)
        confirmButton.isEnabled = false
        tableView.reloadData()
        skeletonCoordinator.setAnimating(true, in: tableView)
        if animated {
            crossFadeTableContent()
        }
    }

    private func hideSkeleton(animated: Bool = false) {
        guard skeletonIsVisible else {
            applyFilter(animatingDifferences: false)
            return
        }
        skeletonCoordinator.setAnimating(false, in: tableView)
        skeletonIsVisible = false
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.reloadData()
        // The diffable data source's snapshot was left untouched while the
        // skeleton owned the table, so re-apply it now that it is back in charge.
        applyFilter(animatingDifferences: false)
        if animated {
            crossFadeTableContent()
        }
    }

    private func crossFadeTableContent() {
        let transition = CATransition()
        transition.type = .fade
        transition.duration = 0.2
        transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        tableView.layer?.add(transition, forKey: "skeletonCrossFade")
    }

    func applyFilter(animatingDifferences: Bool = true) {
        // While the skeleton owns the table, the diffable data source is
        // detached — applying a snapshot would mutate a table it no longer
        // drives. Keep `cachedItems` up to date and re-apply on hide.
        guard !skeletonIsVisible else { return }

        let searchText = searchField.stringValue
        var items = filterItems(cachedItems, searchText: searchText)

        if let sortColumnIdentifier {
            let ascending = sortAscending
            items.sort { lhs, rhs in
                let result = compareItems(lhs, rhs, columnIdentifier: sortColumnIdentifier)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            }
        }

        // Preserve selection across snapshot updates
        let selectedItem = tableView.selectedRow >= 0 ? dataSource.itemIdentifier(forRow: tableView.selectedRow) : nil

        var snapshot = Snapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: animatingDifferences)

        if let selectedItem, let row = dataSource.row(forItemIdentifier: selectedItem), row >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
    }

    // MARK: - Configuration

    func applyBaseConfiguration(_ config: BaseConfiguration) {
        titleLabel.stringValue = config.title
        descriptionLabel.stringValue = config.description
        cancelButton.title = config.cancelButtonTitle
        confirmButton.title = config.confirmButtonTitle
        presentationStyle = config.style
        listIconSize = config.iconSize
        if !hasAppliedInitialSort, let identifier = config.initialSortFieldIdentifier {
            hasAppliedInitialSort = true
            sortColumnIdentifier = identifier
            sortAscending = config.initialSortAscending
        }
        tableView.rowHeight = config.rowHeight
        tableView.intercellSpacing = config.cellSpacing
        applyStyleToChrome()
        if skeletonIsVisible,
           skeletonCoordinator.updatePlaceholderRowCount(for: tableView, visibleHeight: scrollView.contentView.bounds.height) {
            tableView.reloadData()
        }
    }

    func configureColumns<Field: PickerField>(_ fields: [Field]) {
        configuredFieldIdentifiers = fields.map(\.rawValue)
        sortableFields = fields.filter { !$0.title.isEmpty }.map { (identifier: $0.rawValue, title: $0.title) }
        rebuildSortMenu()

        for column in tableView.tableColumns {
            tableView.removeTableColumn(column)
        }

        switch presentationStyle {
        case .table:
            for field in fields {
                addTableColumn(
                    identifier: field.rawValue,
                    title: field.title,
                    preferredWidth: field.preferredWidth,
                    minWidth: field.minWidth,
                    maxWidth: field.maxWidth,
                    headerAlignment: field.headerAlignment
                )
            }
            skeletonCoordinator.listRowLayout = nil
            let iconStyleIdentifiers: Set<String> = ["icon", "sandboxed"]
            skeletonCoordinator.columns = fields.map { field in
                SkeletonColumnDescriptor(
                    identifier: field.rawValue,
                    style: iconStyleIdentifiers.contains(field.rawValue) ? .icon : .text,
                    alignment: field.headerAlignment ?? .left
                )
            }

        case .list:
            let column = NSTableColumn(identifier: .init(ListRowColumn.identifier))
            column.title = ""
            column.resizingMask = .autoresizingMask
            // NSTableColumn starts out 100pt wide. Without both an initial width and the
            // sizing pass in `viewDidLayout`, every list row renders 100pt across and its
            // labels truncate to a few characters no matter how wide the window is.
            column.minWidth = 1
            column.maxWidth = .greatestFiniteMagnitude
            column.width = max(1, tableView.bounds.width)
            tableView.addTableColumn(column)
            tableView.sizeLastColumnToFit()

            // A list row is one cell, not one cell per column, so the coordinator vends a
            // composite placeholder. Its two text bars still read `SkeletonAppearance` as
            // column 0 and 1, so every existing shimmer and width knob keeps working and
            // no skeleton API had to grow.
            skeletonCoordinator.columns = []
            skeletonCoordinator.listRowLayout = .init(
                iconSize: listIconSize,
                showsIcon: configuredFieldIdentifiers.contains("icon")
            )
        }

        applyStyleToChrome()
    }

    /// Show or hide the parts of the chrome that only one style uses, and move the search
    /// field between the title row and its own full-width row.
    private func applyStyleToChrome() {
        if presentationStyle.showsColumnHeaders {
            if tableView.headerView == nil {
                tableView.headerView = NSTableHeaderView()
            }
        } else {
            tableView.headerView = nil
        }

        sortControl.isHidden = !presentationStyle.showsSortControl
        searchRowStackView.isHidden = !presentationStyle.searchFieldFillsWidth

        let searchFieldBelongsInSearchRow = presentationStyle.searchFieldFillsWidth
        let currentContainer: NSStackView? = searchField.superview as? NSStackView
        let desiredContainer = searchFieldBelongsInSearchRow ? searchRowStackView : topStackView

        if currentContainer !== desiredContainer {
            currentContainer?.removeArrangedSubview(searchField)
            searchField.removeFromSuperview()
            if searchFieldBelongsInSearchRow {
                desiredContainer.insertArrangedSubview(searchField, at: 0)
            } else {
                desiredContainer.addArrangedSubview(searchField)
            }
        }

        // Fixed width beside the title, full width on its own row.
        searchFieldWidthConstraint?.isActive = !searchFieldBelongsInSearchRow
        updateSortControlTitle()
    }

    // MARK: - Sorting

    private func rebuildSortMenu() {
        let menu = NSMenu()
        for field in sortableFields {
            let menuItem = NSMenuItem(title: field.title, action: #selector(sortFieldSelected(_:)), keyEquivalent: "")
            menuItem.target = self
            menuItem.representedObject = field.identifier
            menu.addItem(menuItem)
        }
        sortControl.menu = menu
        updateSortControlTitle()
    }

    /// Marks the active field with a direction arrow, so the button shows both what the
    /// rows are sorted by and which way without being opened.
    private func updateSortControlTitle() {
        let arrow = sortAscending ? " ↑" : " ↓"
        for menuItem in sortControl.menu?.items ?? [] {
            guard let identifier = menuItem.representedObject as? String,
                  let field = sortableFields.first(where: { $0.identifier == identifier }) else { continue }
            menuItem.title = identifier == sortColumnIdentifier ? field.title + arrow : field.title
        }
        if let sortColumnIdentifier,
           let index = sortableFields.firstIndex(where: { $0.identifier == sortColumnIdentifier }) {
            sortControl.selectItem(at: index)
        }
    }

    @objc private func sortFieldSelected(_ sender: NSMenuItem) {
        guard let identifier = sender.representedObject as? String else { return }
        if sortColumnIdentifier == identifier {
            // Re-picking the active field flips the direction, matching how clicking an
            // already-sorted column header behaves in the table style.
            sortAscending.toggle()
        } else {
            sortColumnIdentifier = identifier
            sortAscending = true
        }
        updateSortControlTitle()
        applyFilter()
    }

    /// Rebuild the table for a new presentation style, preserving what the user can see:
    /// selection, search text and sort survive; scroll position is best-effort, since the
    /// row height changes underneath it — the selected row is scrolled back into view.
    ///
    /// The cell views differ per style, so the table is reloaded rather than diffed.
    func applyStyleChange(baseConfiguration: BaseConfiguration, reconfigureColumns: () -> Void) {
        guard isViewLoaded else {
            applyBaseConfiguration(baseConfiguration)
            return
        }

        let selectedItem = tableView.selectedRow >= 0
            ? dataSource.itemIdentifier(forRow: tableView.selectedRow)
            : nil

        applyBaseConfiguration(baseConfiguration)
        reconfigureColumns()

        if skeletonIsVisible {
            _ = skeletonCoordinator.updatePlaceholderRowCount(
                for: tableView,
                visibleHeight: scrollView.contentView.bounds.height
            )
            tableView.reloadData()
            skeletonCoordinator.setAnimating(true, in: tableView)
            return
        }

        tableView.reloadData()
        applyFilter(animatingDifferences: false)

        if let selectedItem,
           let row = dataSource.row(forItemIdentifier: selectedItem), row >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
            tableView.scrollRowToVisible(row)
        }
    }

    // MARK: - List Rows

    /// Assemble a list row. The rules are fixed rather than configurable: fields are
    /// placed by what they mean, and the order within the subtitle follows the configured
    /// field order.
    private func makeListRowCellView(for item: Item) -> NSView {
        let cell = tableView.box.makeView(ofClass: ListRowTableCellView.self)
        cell.iconSize = listIconSize
        cell.showsIcon = configuredFieldIdentifiers.contains("icon")
        cell.image = item.icon
        cell.title = item.name
        cell.badges = listBadges(for: item)
        cell.subtitle = listSubtitle(for: item)
        return cell
    }

    /// Badges are rendered only when they say something. A host-platform item gets no
    /// platform badge and a non-sandboxed item gets no sandbox badge -- which is the whole
    /// point of this style over a column that must print a value in every single row.
    private func listBadges(for item: Item) -> [ListRowBadge] {
        var badges: [ListRowBadge] = []

        if configuredFieldIdentifiers.contains("platform") {
            if let platform = item.platform {
                // The host platform is the assumption, so it gets no badge; everything
                // else is tinted by OS family.
                if platform != .macOS {
                    badges.append(.init(text: platform.description, color: platform.badgeColor))
                }
            } else {
                // Same tint as an unrecognised platform constant: both mean "could not
                // be pinned down", though for different reasons.
                badges.append(.init(text: "Unknown", color: .systemOrange))
            }
        }

        if configuredFieldIdentifiers.contains("sandboxed"), item.isSandboxed {
            badges.append(.init(text: "Sandboxed", color: .systemGreen))
        }

        return badges
    }

    /// Everything that is neither the icon, the name, nor a badge goes into the subtitle,
    /// in configured order.
    private func listSubtitle(for item: Item) -> String {
        let placedElsewhere: Set<String> = ["icon", "name", "platform", "sandboxed"]
        return configuredFieldIdentifiers
            .filter { !placedElsewhere.contains($0) }
            .compactMap { fieldValue($0, for: item) }
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
    }

    func addTableColumn(identifier: String, title: String, preferredWidth: CGFloat, minWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, headerAlignment: NSTextAlignment? = nil) {
        let column = NSTableColumn(identifier: .init(identifier))
        column.title = title
        column.width = preferredWidth
        if let minWidth { column.minWidth = minWidth }
        if let maxWidth { column.maxWidth = maxWidth }
        if let headerAlignment { column.headerCell.alignment = headerAlignment }
        if !title.isEmpty {
            column.sortDescriptorPrototype = NSSortDescriptor(key: identifier, ascending: true)
        }
        tableView.addTableColumn(column)
    }

    // MARK: - Shared Cell Helpers

    /// Create a cell view for common column types shared across all picker VCs.
    /// Returns nil if the column identifier is not a shared type.
    func makeSharedCellView(columnIdentifier: String, item: Item) -> NSView? {
        switch columnIdentifier {
        case "icon":
            let cell = tableView.box.makeView(ofClass: IconTableCellView.self)
            cell.image = item.icon
            return cell
        case "name":
            let cell = tableView.box.makeView(ofClass: NameTableCellView.self)
            cell.string = item.name
            return cell
        case "pid":
            let cell = tableView.box.makeView(ofClass: PIDTableCellView.self)
            cell.string = "\(item.processIdentifier)"
            return cell
        case "architecture":
            let cell = tableView.box.makeView(ofClass: ArchitectureTableCellView.self)
            cell.badge = item.architecture.map { .init(text: $0.description, color: $0.badgeColor) }
            return cell
        case "platform":
            let cell = tableView.box.makeView(ofClass: PlatformTableCellView.self)
            // Unlike the list style, the table prints a value in every row -- a column
            // of blanks reads as broken. The host platform is pushed into a receded
            // colour instead of being omitted, so anything else still stands out.
            cell.badge = item.platform.map {
                .init(text: $0.description, color: $0 == .macOS ? .secondaryLabelColor : $0.badgeColor)
            }
            return cell
        default:
            return nil
        }
    }

    func makeSandboxedCellView(isSandboxed: Bool, isLoading: Bool = false) -> NSView {
        let cell = tableView.box.makeView(ofClass: StatusIconTableCellView.self)
        if isLoading {
            cell.isLoading = true
        } else {
            cell.isLoading = false
            cell.image = isSandboxed ? .checkmarkImage : .xmarkImage
            cell.tintColor = isSandboxed ? .systemGreen : .systemRed
        }
        return cell
    }

    // MARK: - Shared Comparison Helpers

    /// Compare two items by a common column identifier shared across all picker VCs.
    /// Returns nil if the column identifier is not a shared type.
    func compareSharedItems(_ lhs: Item, _ rhs: Item, columnIdentifier: String) -> ComparisonResult? {
        switch columnIdentifier {
        case "icon":
            return .orderedSame
        case "name":
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name)
        case "pid":
            return compareNumericValues(lhs.processIdentifier, rhs.processIdentifier)
        case "architecture":
            return (lhs.architecture?.description ?? "").compare(rhs.architecture?.description ?? "")
        case "platform":
            return comparePlatforms(lhs.platform, rhs.platform)
        case "sandboxed":
            return compareBooleanValues(lhs.isSandboxed, rhs.isSandboxed)
        default:
            return nil
        }
    }

    func compareNumericValues<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs < rhs ? .orderedAscending : .orderedDescending
    }

    /// Orders by ``Platform/sortOrder``, which ranks simulator platforms first so one
    /// click on the header lifts them to the top. Undetermined platforms sort last.
    func comparePlatforms(_ lhs: Platform?, _ rhs: Platform?) -> ComparisonResult {
        compareNumericValues(lhs?.sortOrder ?? Int.max, rhs?.sortOrder ?? Int.max)
    }

    func compareBooleanValues(_ lhs: Bool, _ rhs: Bool) -> ComparisonResult {
        if lhs == rhs { return .orderedSame }
        return lhs ? .orderedAscending : .orderedDescending
    }

    // MARK: - Shared Context Menu Helpers

    func makeCopyPIDMenuItem(for item: Item) -> NSMenuItem {
        let menuItem = NSMenuItem(title: "Copy PID", action: #selector(copyPIDAction(_:)), keyEquivalent: "")
        menuItem.target = self
        menuItem.representedObject = item
        return menuItem
    }

    @objc private func copyPIDAction(_ sender: NSMenuItem) {
        guard let item = sender.representedObject as? Item else { return }
        copyToPasteboard("\(item.processIdentifier)")
    }

    // MARK: - Actions

    @objc private func cancelAction() {
        didCancel()
    }

    @objc private func confirmAction() {
        guard tableView.selectedRow >= 0,
              let item = dataSource.itemIdentifier(forRow: tableView.selectedRow) else { return }
        didConfirm(item: item)
    }

    @objc private func searchTextFieldDidChange(_ sender: NSSearchField) {
        applyFilter()
    }

    func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    // MARK: - Menu

    private func setupTableViewMenu() {
        let menu = NSMenu()
        menu.delegate = self
        tableView.menu = menu
    }

    // MARK: - DataSource

    private func makeDataSource() -> DataSource {
        DataSource(tableView: tableView) { [weak self] _, tableColumn, _, item in
            guard let self else { return NSView() }
            if self.presentationStyle == .list {
                return self.makeListRowCellView(for: item)
            }
            return self.makeCellView(for: tableColumn, item: item) ?? NSView()
        }
    }

    // MARK: - NSTableViewDelegate

    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        confirmButton.isEnabled = hasSelection
        if hasSelection, let item = dataSource.itemIdentifier(forRow: tableView.selectedRow) {
            didSelect(item: item)
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard let item = dataSource.itemIdentifier(forRow: row) else { return true }
        return shouldSelect(item: item)
    }

    func tableView(_ tableView: NSTableView, typeSelectStringFor tableColumn: NSTableColumn?, row: Int) -> String? {
        guard let item = dataSource.itemIdentifier(forRow: row) else { return nil }
        return typeSelectString(for: item)
    }

    func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        guard tableColumn.sortDescriptorPrototype != nil else { return }
        let columnIdentifier = tableColumn.identifier.rawValue

        if sortColumnIdentifier == columnIdentifier {
            if sortAscending {
                sortAscending = false
            } else {
                sortColumnIdentifier = nil
            }
        } else {
            sortColumnIdentifier = columnIdentifier
            sortAscending = true
        }

        if let sortColumnIdentifier {
            tableView.sortDescriptors = [NSSortDescriptor(key: sortColumnIdentifier, ascending: sortAscending)]
        } else {
            tableView.sortDescriptors = []
        }

        applyFilter(animatingDifferences: false)
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let row = tableView.clickedRow
        guard row >= 0, let item = dataSource.itemIdentifier(forRow: row) else { return }
        for menuItem in contextMenuItems(for: item) {
            menu.addItem(menuItem)
        }
    }

    deinit {
        #if DEBUG
        print("\(Self.self) deinit")
        #endif
    }
}

#endif
