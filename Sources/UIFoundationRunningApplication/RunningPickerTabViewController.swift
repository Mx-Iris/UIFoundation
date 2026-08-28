#if RunningApplication && os(macOS)

import AppKit
import UIFoundationUtilities
import UIFoundationShared

@available(macOS 11.0, *)
public final class RunningPickerTabViewController: XiblessViewController<NSView> {
    // MARK: - Configuration

    public struct Configuration {
        public var contentInsets: NSEdgeInsets
        public var applicationTabLabel: String
        public var processTabLabel: String

        public init(
            contentInsets: NSEdgeInsets = .init(top: 20, left: 20, bottom: 20, right: 20),
            applicationTabLabel: String = "Applications",
            processTabLabel: String = "Processes"
        ) {
            self.contentInsets = contentInsets
            self.applicationTabLabel = applicationTabLabel
            self.processTabLabel = processTabLabel
        }
    }

    // MARK: - Application Field

    public enum ApplicationField: String, CaseIterable, PickerField {
        case icon
        case name
        case bundleIdentifier
        case pid
        case architecture
        case sandboxed

        var title: String {
            switch self {
            case .icon: ""
            case .name: "Name"
            case .bundleIdentifier: "Bundle ID"
            case .pid: "PID"
            case .architecture: "Arch"
            case .sandboxed: "Sandbox"
            }
        }

        var preferredWidth: CGFloat {
            switch self {
            case .icon: 50
            case .name: 200
            case .bundleIdentifier: 200
            case .pid: 50
            case .architecture: 50
            case .sandboxed: 70
            }
        }

        var minWidth: CGFloat? {
            switch self {
            case .name, .bundleIdentifier: nil
            default: preferredWidth
            }
        }

        var maxWidth: CGFloat? {
            switch self {
            case .name, .bundleIdentifier: nil
            default: preferredWidth
            }
        }

        var headerAlignment: NSTextAlignment? {
            self == .sandboxed ? .center : nil
        }
    }

    // MARK: - Application Configuration

    public struct ApplicationConfiguration {
        /// How this tab presents its items. Changing it at runtime rebuilds the rows.
        public var style: Style

        public var title: String
        public var description: String
        public var cancelButtonTitle: String
        public var confirmButtonTitle: String
        public var allowsFields: [ApplicationField]


        /// Sort applied when the tab first appears. The user may change it from the sort
        /// pop-up (list style) or by clicking a column header (table style); that change
        /// is not reported back to the caller.
        public var initialSortField: ApplicationField?
        public var initialSortAscending: Bool

        // Style-defaulted values. The public properties below stay non-optional so that
        // nothing about their type changes for callers; the optional backing storage is
        // what lets "never set" fall back to the style's default -- and lets an unset
        // value follow along when the style is switched at runtime.
        private var explicitRowHeight: CGFloat?
        private var explicitCellSpacing: CGSize?
        private var explicitIconSize: CGFloat?

        public var rowHeight: CGFloat {
            get { explicitRowHeight ?? style.defaultRowHeight }
            set { explicitRowHeight = newValue }
        }

        public var cellSpacing: CGSize {
            get { explicitCellSpacing ?? style.defaultCellSpacing }
            set { explicitCellSpacing = newValue }
        }

        /// Icon edge length. Independent of ``rowHeight``: table icons could simply track
        /// the row height, but a list row is tall enough that the two must be decoupled.
        public var iconSize: CGFloat {
            get { explicitIconSize ?? defaultIconSize }
            set { explicitIconSize = newValue }
        }

        /// Both tabs use one list icon size so the two do not look like different
        /// components when switched between. 28pt leaves 8pt of breathing room above and
        /// below in a 44pt list row.
        private var defaultIconSize: CGFloat {
            switch style {
            case .table: 20
            case .list: 28
            }
        }

        public init(
            style: Style = .table,
            title: String = "Running Applications",
            description: String = "Select an application",
            cancelButtonTitle: String = "Cancel",
            confirmButtonTitle: String = "Confirm",
            rowHeight: CGFloat? = nil,
            cellSpacing: CGSize? = nil,
            iconSize: CGFloat? = nil,
            allowsFields: [ApplicationField] = ApplicationField.allCases,
            initialSortField: ApplicationField? = nil,
            initialSortAscending: Bool = true
        ) {
            self.style = style
            self.title = title
            self.description = description
            self.cancelButtonTitle = cancelButtonTitle
            self.confirmButtonTitle = confirmButtonTitle
            self.explicitRowHeight = rowHeight
            self.explicitCellSpacing = cellSpacing
            self.explicitIconSize = iconSize
            self.allowsFields = allowsFields
            self.initialSortField = initialSortField
            self.initialSortAscending = initialSortAscending
        }


        var baseConfiguration: BaseConfiguration {
            .init(
                style: style,
                title: title,
                description: description,
                cancelButtonTitle: cancelButtonTitle,
                confirmButtonTitle: confirmButtonTitle,
                rowHeight: rowHeight,
                cellSpacing: cellSpacing,
                iconSize: iconSize,
                initialSortFieldIdentifier: initialSortField?.rawValue,
                initialSortAscending: initialSortAscending
            )
        }
    }

    // MARK: - Process Field

    public enum ProcessField: String, CaseIterable, PickerField {
        case icon
        case name
        case pid
        case architecture
        case platform
        case sandboxed
        case executablePath

        var title: String {
            switch self {
            case .icon: ""
            case .name: "Name"
            case .pid: "PID"
            case .architecture: "Arch"
            case .platform: "Platform"
            case .sandboxed: "Sandbox"
            case .executablePath: "Path"
            }
        }

        var preferredWidth: CGFloat {
            switch self {
            case .icon: 50
            case .name: 200
            case .pid: 50
            case .architecture: 50
            // Wide enough for "visionOS Simulator", the longest wording that occurs in
            // practice.
            case .platform: 130
            case .sandboxed: 70
            case .executablePath: 300
            }
        }

        var minWidth: CGFloat? {
            switch self {
            case .name, .executablePath: nil
            default: preferredWidth
            }
        }

        var maxWidth: CGFloat? {
            switch self {
            case .name, .executablePath: nil
            default: preferredWidth
            }
        }

        var headerAlignment: NSTextAlignment? {
            self == .sandboxed ? .center : nil
        }
    }

    // MARK: - Process Configuration

    public struct ProcessConfiguration {
        /// How this tab presents its items. Changing it at runtime rebuilds the rows.
        public var style: Style

        public var title: String
        public var description: String
        public var cancelButtonTitle: String
        public var confirmButtonTitle: String
        public var allowsFields: [ProcessField]
        public var refreshInterval: TimeInterval


        /// Sort applied when the tab first appears. The user may change it from the sort
        /// pop-up (list style) or by clicking a column header (table style); that change
        /// is not reported back to the caller.
        public var initialSortField: ProcessField?
        public var initialSortAscending: Bool

        // Style-defaulted values. The public properties below stay non-optional so that
        // nothing about their type changes for callers; the optional backing storage is
        // what lets "never set" fall back to the style's default -- and lets an unset
        // value follow along when the style is switched at runtime.
        private var explicitRowHeight: CGFloat?
        private var explicitCellSpacing: CGSize?
        private var explicitIconSize: CGFloat?

        public var rowHeight: CGFloat {
            get { explicitRowHeight ?? style.defaultRowHeight }
            set { explicitRowHeight = newValue }
        }

        public var cellSpacing: CGSize {
            get { explicitCellSpacing ?? style.defaultCellSpacing }
            set { explicitCellSpacing = newValue }
        }

        /// Icon edge length. Independent of ``rowHeight``: table icons could simply track
        /// the row height, but a list row is tall enough that the two must be decoupled.
        public var iconSize: CGFloat {
            get { explicitIconSize ?? defaultIconSize }
            set { explicitIconSize = newValue }
        }

        /// Matches ``ApplicationConfiguration`` so the two tabs stay visually consistent.
        /// Process icons carry far less information — 400 processes resolve to just two
        /// distinct icons — but a size that changes between tabs reads as a bug.
        private var defaultIconSize: CGFloat {
            switch style {
            case .table: 20
            case .list: 28
            }
        }

        public init(
            style: Style = .table,
            title: String = "Running Processes",
            description: String = "Select a process",
            cancelButtonTitle: String = "Cancel",
            confirmButtonTitle: String = "Confirm",
            rowHeight: CGFloat? = nil,
            cellSpacing: CGSize? = nil,
            iconSize: CGFloat? = nil,
            allowsFields: [ProcessField] = ProcessField.allCases,
            initialSortField: ProcessField? = nil,
            initialSortAscending: Bool = true,
            refreshInterval: TimeInterval = 2.0
        ) {
            self.style = style
            self.title = title
            self.description = description
            self.cancelButtonTitle = cancelButtonTitle
            self.confirmButtonTitle = confirmButtonTitle
            self.explicitRowHeight = rowHeight
            self.explicitCellSpacing = cellSpacing
            self.explicitIconSize = iconSize
            self.allowsFields = allowsFields
            self.initialSortField = initialSortField
            self.initialSortAscending = initialSortAscending
            self.refreshInterval = refreshInterval
        }


        var baseConfiguration: BaseConfiguration {
            .init(
                style: style,
                title: title,
                description: description,
                cancelButtonTitle: cancelButtonTitle,
                confirmButtonTitle: confirmButtonTitle,
                rowHeight: rowHeight,
                cellSpacing: cellSpacing,
                iconSize: iconSize,
                initialSortFieldIdentifier: initialSortField?.rawValue,
                initialSortAscending: initialSortAscending
            )
        }
    }

    // MARK: - Delegate

    @MainActor public protocol Delegate: AnyObject {
        func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, shouldSelectApplication application: RunningApplication) -> Bool
        func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didSelectApplication application: RunningApplication)
        func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didConfirmApplication application: RunningApplication)

        func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, shouldSelectProcess process: RunningProcess) -> Bool
        func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didSelectProcess process: RunningProcess)
        func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didConfirmProcess process: RunningProcess)

        func runningPickerTabViewControllerWasCancelled(_ viewController: RunningPickerTabViewController)
    }

    // MARK: - Properties

    public weak var delegate: Delegate?

    public private(set) var configuration: Configuration

    private let tabViewController = NSTabViewController()
    private let applicationPickerViewController: RunningApplicationPickerViewController
    private let processPickerViewController: RunningProcessPickerViewController

    public init(
        configuration: Configuration = .init(),
        applicationConfiguration: ApplicationConfiguration = .init(),
        processConfiguration: ProcessConfiguration = .init()
    ) {
        self.configuration = configuration
        self.applicationPickerViewController = RunningApplicationPickerViewController(configuration: applicationConfiguration)
        self.processPickerViewController = RunningProcessPickerViewController(configuration: processConfiguration)
        super.init()
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = .init(width: 800, height: 600)

        applicationPickerViewController.delegate = self
        processPickerViewController.delegate = self

        let applicationTabItem = NSTabViewItem(viewController: applicationPickerViewController)
        applicationTabItem.label = configuration.applicationTabLabel

        let processTabItem = NSTabViewItem(viewController: processPickerViewController)
        processTabItem.label = configuration.processTabLabel

        tabViewController.addTabViewItem(applicationTabItem)
        tabViewController.addTabViewItem(processTabItem)

        addChild(tabViewController)
        let tabContainerView = tabViewController.view
        view.addSubview(tabContainerView)
        tabContainerView.makeConstraints { make in
            make.topAnchor.constraint(equalTo: view.topAnchor, constant: configuration.contentInsets.top)
            make.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: configuration.contentInsets.left)
            view.trailingAnchor.constraint(equalTo: make.trailingAnchor, constant: configuration.contentInsets.right)
            view.bottomAnchor.constraint(equalTo: make.bottomAnchor, constant: configuration.contentInsets.bottom)
        }

        // Start loading application + process data in the background immediately so each tab is
        // populated (or mostly populated) by the time NSTabViewController forces its child viewDidLoads
        // via _goodTabViewContentSize, and by the time the user switches tabs.
        applicationPickerViewController.prefetch()
        processPickerViewController.prefetch()
    }

    // MARK: - Presentation Style

    /// Presentation style of the Applications tab. Setting it rebuilds that tab's rows,
    /// preserving selection, search text and sort.
    public var applicationStyle: Style {
        get { applicationPickerViewController.configuration.style }
        set { applicationPickerViewController.updateStyle(newValue) }
    }

    /// Presentation style of the Processes tab.
    public var processStyle: Style {
        get { processPickerViewController.configuration.style }
        set { processPickerViewController.updateStyle(newValue) }
    }

    /// Apply one style to both tabs.
    public func setStyle(_ style: Style) {
        applicationStyle = style
        processStyle = style
    }

    // MARK: - Skeleton

    /// Whether the picker tabs currently show loading placeholders instead of
    /// real content.
    public var isSkeletonVisible: Bool {
        applicationPickerViewController.isSkeletonVisible
    }

    /// Show or hide the loading placeholders on both tabs. Useful as a debug
    /// toggle to flip between skeleton and content states.
    /// - Parameters:
    ///   - visible: whether the placeholders should be visible.
    ///   - animated: cross-fade the table between placeholders and content.
    public func setSkeletonVisible(_ visible: Bool, animated: Bool = true) {
        applicationPickerViewController.setSkeletonVisible(visible, animated: animated)
        processPickerViewController.setSkeletonVisible(visible, animated: animated)
    }

    /// Tunable appearance for the loading skeleton. Setting this
    /// applies the same appearance to both the Applications and Processes tabs.
    public var skeletonAppearance: SkeletonAppearance {
        get { applicationPickerViewController.skeletonAppearance }
        set {
            applicationPickerViewController.skeletonAppearance = newValue
            processPickerViewController.skeletonAppearance = newValue
        }
    }
}

// MARK: - Delegate Default Implementations

@available(macOS 11.0, *)
public extension RunningPickerTabViewController.Delegate {
    func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, shouldSelectApplication application: RunningApplication) -> Bool { true }
    func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didSelectApplication application: RunningApplication) {}
    func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didConfirmApplication application: RunningApplication) {}

    func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, shouldSelectProcess process: RunningProcess) -> Bool { true }
    func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didSelectProcess process: RunningProcess) {}
    func runningPickerTabViewController(_ viewController: RunningPickerTabViewController, didConfirmProcess process: RunningProcess) {}

    func runningPickerTabViewControllerWasCancelled(_ viewController: RunningPickerTabViewController) {}
}

// MARK: - RunningApplicationPickerViewController.Delegate

@available(macOS 11.0, *)
extension RunningPickerTabViewController: RunningApplicationPickerViewController.Delegate {
    func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, shouldSelectApplication application: RunningApplication) -> Bool {
        delegate?.runningPickerTabViewController(self, shouldSelectApplication: application) ?? true
    }

    func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, didSelectApplication application: RunningApplication) {
        delegate?.runningPickerTabViewController(self, didSelectApplication: application)
    }

    func runningApplicationPickerViewController(_ viewController: RunningApplicationPickerViewController, didConfirmApplication application: RunningApplication) {
        delegate?.runningPickerTabViewController(self, didConfirmApplication: application)
    }

    func runningApplicationPickerViewControllerWasCancelled(_ viewController: RunningApplicationPickerViewController) {
        delegate?.runningPickerTabViewControllerWasCancelled(self)
    }
}

// MARK: - RunningProcessPickerViewController.Delegate

@available(macOS 11.0, *)
extension RunningPickerTabViewController: RunningProcessPickerViewController.Delegate {
    func runningProcessPickerViewController(_ viewController: RunningProcessPickerViewController, shouldSelectProcess process: RunningProcess) -> Bool {
        delegate?.runningPickerTabViewController(self, shouldSelectProcess: process) ?? true
    }

    func runningProcessPickerViewController(_ viewController: RunningProcessPickerViewController, didSelectProcess process: RunningProcess) {
        delegate?.runningPickerTabViewController(self, didSelectProcess: process)
    }

    func runningProcessPickerViewController(_ viewController: RunningProcessPickerViewController, didConfirmProcess process: RunningProcess) {
        delegate?.runningPickerTabViewController(self, didConfirmProcess: process)
    }

    func runningProcessPickerViewControllerWasCancelled(_ viewController: RunningProcessPickerViewController) {
        delegate?.runningPickerTabViewControllerWasCancelled(self)
    }
}

#endif
