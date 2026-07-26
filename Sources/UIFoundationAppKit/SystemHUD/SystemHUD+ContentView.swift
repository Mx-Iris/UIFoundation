//
//  Ported from Mx-Iris/SystemHUD
//  https://github.com/Mx-Iris/SystemHUD
//

#if SystemHUD && os(macOS)

import AppKit

extension SystemHUD {
    /// The panel's content: a vibrancy backdrop hosting an optional glyph above a single-line title.
    ///
    /// The glyph and the title are laid out inside a layout guide whose size is driven from the
    /// outside (``setContentSize(_:)``) rather than from the intrinsic content size, so
    /// ``SystemHUD`` can clamp a long title to the screen width and let it truncate instead of
    /// growing the panel past the display.
    final class ContentView: NSVisualEffectView {
        private let imageView = NSImageView()

        private let titleTextField = NSTextField(labelWithString: "")

        private let contentLayoutGuide = NSLayoutGuide()

        private var imageWidthConstraint: NSLayoutConstraint!
        private var imageHeightConstraint: NSLayoutConstraint!
        private var titleTopConstraint: NSLayoutConstraint!
        private var contentWidthConstraint: NSLayoutConstraint!
        private var contentHeightConstraint: NSLayoutConstraint!
        private var contentCenterXConstraint: NSLayoutConstraint!
        private var contentCenterYConstraint: NSLayoutConstraint!

        var configuration: SystemHUD.Configuration {
            didSet { reloadConfiguration() }
        }

        /// The size the glyph and the title want, before any clamping.
        var preferredContentSize: CGSize {
            let imageSize = configuration.image?.size ?? .zero
            let titleSize = titleTextField.intrinsicContentSize
            return .init(
                width: max(imageSize.width, titleSize.width),
                height: imageSize.height + resolvedImageSpacing + titleSize.height
            )
        }

        /// The image spacing actually applied — an absent image collapses it, so a title-only HUD
        /// does not carry a phantom gap above its text.
        private var resolvedImageSpacing: CGFloat {
            configuration.image == nil ? 0 : configuration.imageSpacing
        }

        init(configuration: SystemHUD.Configuration) {
            self.configuration = configuration
            super.init(frame: .init(origin: .zero, size: configuration.minimumSize))

            material = .hudWindow
            blendingMode = .behindWindow
            state = .active
            wantsLayer = true

            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.imageScaling = .scaleProportionallyUpOrDown

            titleTextField.translatesAutoresizingMaskIntoConstraints = false
            titleTextField.lineBreakMode = .byTruncatingTail
            // Let the title lose to the clamped guide width instead of overflowing the panel.
            titleTextField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

            addLayoutGuide(contentLayoutGuide)
            addSubview(imageView)
            addSubview(titleTextField)

            imageWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: 0)
            imageHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: 0)
            titleTopConstraint = titleTextField.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 0)
            contentWidthConstraint = contentLayoutGuide.widthAnchor.constraint(equalToConstant: 0)
            contentHeightConstraint = contentLayoutGuide.heightAnchor.constraint(equalToConstant: 0)
            contentCenterXConstraint = contentLayoutGuide.centerXAnchor.constraint(equalTo: centerXAnchor)
            contentCenterYConstraint = contentLayoutGuide.centerYAnchor.constraint(equalTo: centerYAnchor)

            NSLayoutConstraint.activate([
                imageWidthConstraint,
                imageHeightConstraint,
                imageView.topAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
                imageView.centerXAnchor.constraint(equalTo: contentLayoutGuide.centerXAnchor),

                titleTopConstraint,
                titleTextField.centerXAnchor.constraint(equalTo: contentLayoutGuide.centerXAnchor),
                titleTextField.leadingAnchor.constraint(greaterThanOrEqualTo: contentLayoutGuide.leadingAnchor),
                titleTextField.trailingAnchor.constraint(lessThanOrEqualTo: contentLayoutGuide.trailingAnchor),
                titleTextField.bottomAnchor.constraint(equalTo: contentLayoutGuide.bottomAnchor),

                contentWidthConstraint,
                contentHeightConstraint,
                contentCenterXConstraint,
                contentCenterYConstraint,
            ])

            reloadConfiguration()
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        /// Pins the layout guide to an explicit size. ``SystemHUD`` drives this so the content can
        /// be clamped to the screen rather than pushing the panel off it.
        func setContentSize(_ contentSize: CGSize) {
            contentWidthConstraint.constant = contentSize.width
            contentHeightConstraint.constant = contentSize.height
            needsLayout = true
        }

        private func reloadConfiguration() {
            titleTextField.stringValue = configuration.title
            titleTextField.textColor = configuration.titleColor
            titleTextField.font = .systemFont(ofSize: configuration.titleFontSize, weight: configuration.titleFontWeight)
            titleTextField.alignment = configuration.titleAlignment

            imageView.image = configuration.image
            let imageSize = configuration.image?.size ?? .zero
            imageWidthConstraint.constant = imageSize.width
            imageHeightConstraint.constant = imageSize.height
            titleTopConstraint.constant = resolvedImageSpacing

            contentCenterXConstraint.constant = configuration.offset.x
            contentCenterYConstraint.constant = configuration.offset.y

            maskImage = Self.makeRoundedMaskImage(cornerRadius: configuration.cornerRadius)

            needsLayout = true
        }

        /// A resizable rounded-rectangle mask. `maskImage` is the documented way to round a
        /// vibrancy view — unlike `layer.cornerRadius` it also clips the backdrop material itself.
        private static func makeRoundedMaskImage(cornerRadius: CGFloat) -> NSImage? {
            guard cornerRadius > 0 else { return nil }

            // One pixel of straight edge between the two corner caps is all the stretchable
            // middle a nine-part image needs.
            let edgeLength = cornerRadius * 2 + 1
            let maskImage = NSImage(size: .init(width: edgeLength, height: edgeLength), flipped: false) { rect in
                NSColor.black.setFill()
                NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
                return true
            }
            maskImage.capInsets = .init(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
            maskImage.resizingMode = .stretch
            return maskImage
        }
    }
}

#endif
