#if WelcomePanel && os(macOS)

import AppKit
import UIFoundationShared
import UIFoundationToolbox
import UIFoundationUtilities

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// The panel's left-hand side: app icon, name, version, and the action list.
    final class WelcomeViewController: XiblessViewController<LayerBackedView>, NSTableViewDataSource, NSTableViewDelegate {
        let configuration: Configuration

        lazy var appImageView: NSImageView = .init()

        lazy var welcomeLabel: NSTextField = .init(labelWithString: "")

        lazy var versionLabel: NSTextField = .init(labelWithString: "")

        lazy var scrollView = BackgroundScrollView().then {
            $0.documentView = actionTableView
            $0.drawsBackground = false
        }

        lazy var actionTableView: NSTableView = .init().then {
            $0.rowHeight = configuration.style.actionTableViewCellHeight
            $0.intercellSpacing = .init(width: 0, height: configuration.style.actionTableViewSpacing)
            $0.style = .plain
            $0.selectionHighlightStyle = .none
            $0.addTableColumn(NSTableColumn(identifier: .init("DefaultTableColumn")))
            $0.headerView = nil
            $0.dataSource = self
            $0.delegate = self
            $0.focusRingType = .none
            $0.allowsTypeSelect = false
        }

        var didCheckShowOnLaunchCheckbox: (NSButton) -> Void = { _ in }

        lazy var showOnLaunchCheckbox: NSButton = .init(checkboxWithTitle: "Show this window when \(Bundle.main.appName) launches", target: self, action: #selector(showOnLaunchCheckboxAction(_:))).then {
            $0.font = .systemFont(ofSize: 13, weight: .regular)
            $0.state = .on
        }

        lazy var closeButton: HoverButton = .init(style: configuration.style).then {
            $0.hoveringImage = Bundle.module.image(forResource: "WelcomePanelCloseButtonHovered")
            $0.notHoveringImage = Bundle.module.image(forResource: "WelcomePanelCloseButton")
            $0.target = self
            $0.action = #selector(closeButtonAction(_:))
            $0.isBordered = false
        }

        lazy var visualEffectView = NSVisualEffectView().then {
            $0.material = configuration.style.welcomeViewMaterial ?? .underWindowBackground
            $0.blendingMode = .behindWindow
            $0.isEmphasized = false
            $0.state = .followsWindowActiveState
        }

        init(configuration: Configuration) {
            self.configuration = configuration
            super.init()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func loadView() {
            contentView.backgroundColor = configuration.style.welcomeViewBackgroundColor
            if configuration.style.welcomeViewMaterial == nil {
                view = contentView
            } else {
                view = visualEffectView
                visualEffectView.box.addSubview(contentView, fill: true)
            }
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            setup()
            reloadData()
        }

        /// Where the subviews go: straight into the root view, unless a vibrancy backdrop is the
        /// root, in which case they go into the content view layered on top of it.
        var effectView: NSView {
            configuration.style.welcomeViewMaterial == nil ? view : contentView
        }

        func setup() {
            effectView.addSubview(closeButton)
            effectView.addSubview(appImageView)
            effectView.addSubview(welcomeLabel)
            effectView.addSubview(versionLabel)
            effectView.addSubview(scrollView)
            if configuration.style == .xcode14 {
                effectView.addSubview(showOnLaunchCheckbox)
            }
            view.addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil))

            closeButton.makeConstraints { make in
                make.topAnchor.constraint(equalTo: effectView.topAnchor, constant: configuration.style.closeButtonInset)
                make.leftAnchor.constraint(equalTo: effectView.leftAnchor, constant: configuration.style.closeButtonInset)
                make.widthAnchor.constraint(equalToConstant: 15)
                make.heightAnchor.constraint(equalToConstant: 15)
            }

            appImageView.makeConstraints { make in
                make.topAnchor.constraint(equalTo: effectView.topAnchor, constant: configuration.style.appImageViewTopSpacing)
                make.centerXAnchor.constraint(equalTo: effectView.centerXAnchor)
                make.widthAnchor.constraint(equalToConstant: 128)
                make.heightAnchor.constraint(equalToConstant: 128)
            }

            welcomeLabel.makeConstraints { make in
                make.topAnchor.constraint(equalTo: appImageView.bottomAnchor, constant: 2)
                make.centerXAnchor.constraint(equalTo: effectView.centerXAnchor)
            }

            versionLabel.makeConstraints { make in
                make.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 6)
                make.centerXAnchor.constraint(equalTo: effectView.centerXAnchor)
            }

            scrollView.makeConstraints { make in
                if configuration.style == .xcode14 {
                    make.bottomAnchor.constraint(equalTo: showOnLaunchCheckbox.topAnchor, constant: -40)
                    make.leftAnchor.constraint(equalTo: effectView.leftAnchor, constant: 54)
                    make.rightAnchor.constraint(equalTo: effectView.rightAnchor)
                } else {
                    make.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -configuration.style.actionTableViewBottomSpacing)
                    make.leftAnchor.constraint(equalTo: effectView.leftAnchor, constant: 56)
                    make.rightAnchor.constraint(equalTo: effectView.rightAnchor, constant: -56)
                }
                make.heightAnchor.constraint(equalToConstant: configuration.style.actionTableViewHeight)
            }

            if configuration.style == .xcode14 {
                showOnLaunchCheckbox.makeConstraints { make in
                    make.leftAnchor.constraint(equalTo: scrollView.leftAnchor)
                    make.bottomAnchor.constraint(equalTo: effectView.bottomAnchor, constant: -10)
                }
            }
        }

        func reloadData() {
            welcomeLabel.do {
                $0.stringValue = configuration.welcomeLabelText ?? configuration.style.welcomeLabelDefaultText(forName: Bundle.main.appName)
                $0.textColor = configuration.welcomeLabelColor ?? .labelColor
                $0.font = configuration.welcomeLabelFont ?? configuration.style.welcomeLabelDefaultFont
            }
            versionLabel.do {
                $0.stringValue = configuration.versionLabelText ?? "Version \(Bundle.main.appVersion)"
                $0.textColor = configuration.versionLabelColor ?? .secondaryLabelColor
                $0.font = configuration.versionLabelFont ?? configuration.style.versionLabelDefaultFont
            }
            if configuration.style == .xcode14 {
                showOnLaunchCheckbox.state = configuration.checkShowOnLaunch ? .on : .off
            }
            appImageView.image = configuration.appIconImage ?? NSApplication.shared.applicationIconImage
            // Dark only: the light capture of Xcode 26 has no shadow layer at all.
            let iconShadow = configuration.appIconImageShadow ?? configuration.style.appIconDefaultShadow
            appImageView.shadow = NSAppearance.currentDrawing().box.isDark ? iconShadow : nil
            actionTableView.reloadData()
            actionTableView.sizeToFit()
        }

        override func mouseEntered(with event: NSEvent) {
            if configuration.style == .xcode14 {
                closeButton.alphaValue = 1
                showOnLaunchCheckbox.alphaValue = 1
            }
        }

        override func mouseExited(with event: NSEvent) {
            if configuration.style == .xcode14 {
                closeButton.animator().alphaValue = 0
                showOnLaunchCheckbox.animator().alphaValue = 0
            }
        }

        @objc func showOnLaunchCheckboxAction(_ sender: NSButton) {
            didCheckShowOnLaunchCheckbox(sender)
        }

        @objc func closeButtonAction(_ sender: NSButton) {
            view.window?.close()
        }

        // MARK: - NSTableViewDataSource / NSTableViewDelegate

        func numberOfRows(in tableView: NSTableView) -> Int {
            configuration.allActions.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            let cell = tableView.box.makeView(ofClass: ActionCellView.self) {
                ActionCellView(style: self.configuration.style)
            }
            let action = configuration.allActions[row]

            cell.didClick = {
                action.action?(action)
            }

            cell.iconImageView.do {
                $0.image = action.image
                $0.contentTintColor = action.imageTintColor
            }

            switch configuration.style {
            case .xcode14:
                cell.titleLabel.do {
                    $0.stringValue = action.title ?? ""
                    $0.textColor = action.titleColor ?? .labelColor
                    $0.font = action.titleFont ?? .systemFont(ofSize: 13, weight: .bold)
                }

                cell.detailLabel.do {
                    $0.stringValue = action.subtitle ?? ""
                    $0.textColor = action.subtitleColor ?? .labelColor
                    $0.font = action.subtitleFont ?? .systemFont(ofSize: 12, weight: .regular)
                }
            case .xcode15, .xcode26:
                cell.titleLabel.do {
                    $0.stringValue = action.title ?? ""
                    $0.textColor = action.titleColor ?? .labelColor
                    $0.font = action.titleFont ?? .systemFont(ofSize: 13, weight: .semibold)
                }
            }

            return cell
        }
    }
}

#endif
