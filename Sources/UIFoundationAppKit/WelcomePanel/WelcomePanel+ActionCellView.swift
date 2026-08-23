#if WelcomePanel && os(macOS)

import AppKit
import UIFoundationToolbox
import UIFoundationUtilities

@available(macOS 11.0, *)
extension WelcomePanelController {
    /// One row of the action list on the panel's left-hand side.
    ///
    /// `xcode14` draws an icon with a title and a subtitle over no background; the other styles
    /// draw a rounded tinted pill with a title only.
    final class ActionCellView: LayerBackedTableCellView {
        override var isLayerBackingEnabled: Bool { true }

        lazy var iconImageView = NSImageView()

        lazy var titleLabel = NSTextField(labelWithString: "")

        lazy var detailLabel = NSTextField(labelWithString: "")

        let style: Style

        let normalBackgroundColor = NSColor(name: "WelcomeActionCellView.normalBackgroundColor") {
            $0.box.isDark ? .white.withAlphaComponent(0.03) : .black.withAlphaComponent(0.05)
        }

        let highlightBackgroundColor = NSColor(name: "WelcomeActionCellView.highlightBackgroundColor") {
            $0.box.isDark ? .white.withAlphaComponent(0.05) : .black.withAlphaComponent(0.08)
        }

        var didClick: () -> Void = {}

        init(style: Style) {
            self.style = style
            super.init(frame: .zero)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func setup() {
            super.setup()

            switch style {
            case .xcode14:
                addSubview(iconImageView)
                addSubview(titleLabel)
                addSubview(detailLabel)

                iconImageView.makeConstraints { make in
                    make.leftAnchor.constraint(equalTo: leftAnchor)
                    make.centerYAnchor.constraint(equalTo: centerYAnchor)
                    make.widthAnchor.constraint(equalToConstant: 35)
                    make.heightAnchor.constraint(equalToConstant: 35)
                }

                titleLabel.makeConstraints { make in
                    make.leftAnchor.constraint(equalTo: iconImageView.rightAnchor, constant: 15)
                    make.topAnchor.constraint(equalTo: topAnchor, constant: 9)
                    make.rightAnchor.constraint(equalTo: rightAnchor)
                }

                detailLabel.makeConstraints { make in
                    make.leftAnchor.constraint(equalTo: titleLabel.leftAnchor)
                    make.topAnchor.constraint(equalTo: titleLabel.bottomAnchor)
                    make.rightAnchor.constraint(equalTo: rightAnchor)
                }

                iconImageView.do {
                    $0.contentTintColor = .controlAccentColor
                }

                titleLabel.do {
                    $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                }

                detailLabel.do {
                    $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                }

            case .xcode15, .xcode26:
                addSubview(iconImageView)
                addSubview(titleLabel)

                cornerRadius = 8
                // The original painted `masksToBounds = cornerRadius != 0` from its own
                // `updateLayer()`; the library's renderer reads `clipsToBounds` instead, whose
                // default is `false` for anything linked against macOS 14 or later.
                clipsToBounds = true
                backgroundColor = normalBackgroundColor
                iconImageView.makeConstraints { make in
                    make.leftAnchor.constraint(equalTo: leftAnchor, constant: 11.5)
                    make.centerYAnchor.constraint(equalTo: centerYAnchor)
                    make.widthAnchor.constraint(equalToConstant: 24)
                }

                titleLabel.makeConstraints { make in
                    make.leftAnchor.constraint(equalTo: iconImageView.rightAnchor, constant: 11)
                    make.centerYAnchor.constraint(equalTo: centerYAnchor)
                    make.rightAnchor.constraint(equalTo: rightAnchor)
                }

                titleLabel.do {
                    $0.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                }
            }
        }

        override func mouseDown(with event: NSEvent) {
            if style == .xcode15 {
                backgroundColor = highlightBackgroundColor
            }
        }

        override func mouseUp(with event: NSEvent) {
            if style == .xcode15 {
                backgroundColor = normalBackgroundColor
            }
            didClick()
        }
    }
}

#endif
