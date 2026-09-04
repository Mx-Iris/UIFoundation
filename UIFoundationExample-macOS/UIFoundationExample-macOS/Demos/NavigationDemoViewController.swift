//
//  NavigationDemoViewController.swift
//  UIFoundationExample-macOS
//
//  Playground for `NavigationController`.
//
//  The pane on the right is a live navigation stack. "Push" drives it deeper,
//  "Back" unwinds one level, and a two-finger rightward swipe over the pane
//  pops interactively — drag partway and let go to see it snap back.
//
//  The controls on the left rewrite the container's `NavigationConfiguration`
//  between transitions, so the App Store's shipped numbers can be compared
//  against anything else by eye.
//

import AppKit
import UIFoundation

final class NavigationDemoViewController: NSViewController {

    // MARK: - Navigation

    /// Not named `navigationController`: with the `AppKitPlus` trait on, every
    /// `NSViewController` already has a property by that name, and a stored property
    /// here would be an illegal override of it.
    private let navigationStackController = NavigationController(rootViewController: NavigationDemoPageViewController(level: 1))

    // MARK: - Controls

    private let presetPopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)

    private let durationSlider = NSSlider(value: 0.35, minValue: 0.05, maxValue: 2, target: nil, action: nil)
    private let durationValueField = NSTextField(labelWithString: "")

    private let parallaxSlider = NSSlider(value: 0.3, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let parallaxValueField = NSTextField(labelWithString: "")

    private let dimmingSlider = NSSlider(value: 0.1, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let dimmingValueField = NSTextField(labelWithString: "")

    private let edgeShadowSlider = NSSlider(value: 9, minValue: 0, maxValue: 40, target: nil, action: nil)
    private let edgeShadowValueField = NSTextField(labelWithString: "")

    private let contentInsetSlider = NSSlider(value: 0, minValue: 0, maxValue: 40, target: nil, action: nil)
    private let contentInsetValueField = NSTextField(labelWithString: "")

    private let curvePopUpButton = NSPopUpButton(frame: .zero, pullsDown: false)
    private let transparentPagesCheckbox = NSButton(checkboxWithTitle: "Clear pages (macOS 26 glass)", target: nil, action: nil)
    private let pageBackdropCheckbox = NSButton(checkboxWithTitle: "Backdrop under travelling page", target: nil, action: nil)
    private let interactivePopCheckbox = NSButton(checkboxWithTitle: "Two-finger swipe pops", target: nil, action: nil)
    private let rightToLeftCheckbox = NSButton(checkboxWithTitle: "Right-to-left layout", target: nil, action: nil)

    private let pushButton = NSButton(title: "Push", target: nil, action: nil)
    private let backButton = NSButton(title: "Back", target: nil, action: nil)
    private let popToRootButton = NSButton(title: "Pop to Root", target: nil, action: nil)

    private let stackStatusField = NSTextField(labelWithString: "")

    /// The curves offered by ``curvePopUpButton``, in menu order.
    private let curves: [(title: String, curve: TimingCurve)] = [
        ("Ease in, ease out (UIKit)", .easeInOut),
        ("App Store (0.1878, 0.0023, 0.5399, 0.9629)", .appStoreNavigation),
        ("App Store, reversed", TimingCurve.appStoreNavigation.reversed),
        ("Ease out", .easeOut),
        ("Linear", .linear),
    ]

    /// The presets offered by ``presetPopUpButton``, in menu order.
    private let presets: [(title: String, configuration: NavigationConfiguration)] = [
        ("UIKit", .uiKit),
        ("macOS App Store", .appStore),
    ]

    // MARK: - Lifecycle

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationStackController.delegate = self
        addChild(navigationStackController)
        buildLayout()
        wireControls()
        applyConfiguration()
        updateStackStatus()
    }

    // MARK: - Layout

    private func buildLayout() {
        let navigationHostView = NSView()
        navigationHostView.wantsLayer = true
        // Stands in for a window whose material shows through its content: with "Clear pages" on,
        // this is what a page lets you see.
        let hostMaterialView = NSVisualEffectView()
        hostMaterialView.material = .underPageBackground
        hostMaterialView.blendingMode = .behindWindow
        hostMaterialView.translatesAutoresizingMaskIntoConstraints = false
        navigationHostView.layer?.borderWidth = 1
        navigationHostView.layer?.borderColor = NSColor.separatorColor.cgColor
        navigationHostView.layer?.cornerRadius = 6
        // The pane clips, so a page halfway through sliding in does not spill over the controls.
        navigationHostView.layer?.masksToBounds = true

        let controlsStackView = NSStackView(views: [
            sectionLabel("Transition"),
            labelledControl("Preset", presetPopUpButton, nil),
            labelledControl("Duration", durationSlider, durationValueField),
            labelledControl("Parallax", parallaxSlider, parallaxValueField),
            labelledControl("Dimming", dimmingSlider, dimmingValueField),
            labelledControl("Edge shadow", edgeShadowSlider, edgeShadowValueField),
            labelledControl("Content inset", contentInsetSlider, contentInsetValueField),
            labelledControl("Curve", curvePopUpButton, nil),
            transparentPagesCheckbox,
            pageBackdropCheckbox,
            interactivePopCheckbox,
            rightToLeftCheckbox,
            sectionLabel("Stack"),
            NSStackView(views: [pushButton, backButton, popToRootButton]),
            stackStatusField,
        ])
        controlsStackView.orientation = .vertical
        controlsStackView.alignment = .leading
        controlsStackView.spacing = 10

        let hintField = NSTextField(wrappingLabelWithString:
            "Swipe right with two fingers over the pane to pop interactively. "
            + "Let go before halfway and the gesture snaps back.")
        hintField.font = .preferredFont(forTextStyle: .caption1)
        hintField.textColor = .secondaryLabelColor

        for subview in [controlsStackView, navigationHostView, hintField] {
            subview.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(subview)
        }

        navigationStackController.view.translatesAutoresizingMaskIntoConstraints = false
        navigationHostView.addSubview(hostMaterialView)
        navigationHostView.addSubview(navigationStackController.view)

        NSLayoutConstraint.activate([
            controlsStackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            controlsStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            controlsStackView.widthAnchor.constraint(equalToConstant: 300),

            navigationHostView.topAnchor.constraint(equalTo: view.topAnchor, constant: 20),
            navigationHostView.leadingAnchor.constraint(equalTo: controlsStackView.trailingAnchor, constant: 20),
            navigationHostView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            navigationHostView.bottomAnchor.constraint(equalTo: hintField.topAnchor, constant: -12),
            navigationHostView.widthAnchor.constraint(greaterThanOrEqualToConstant: 320),

            hintField.leadingAnchor.constraint(equalTo: navigationHostView.leadingAnchor),
            hintField.trailingAnchor.constraint(equalTo: navigationHostView.trailingAnchor),
            hintField.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -20),

            hostMaterialView.topAnchor.constraint(equalTo: navigationHostView.topAnchor),
            hostMaterialView.leadingAnchor.constraint(equalTo: navigationHostView.leadingAnchor),
            hostMaterialView.trailingAnchor.constraint(equalTo: navigationHostView.trailingAnchor),
            hostMaterialView.bottomAnchor.constraint(equalTo: navigationHostView.bottomAnchor),

            // Constraining the *container* is fine; its pages are positioned by frame.
            navigationStackController.view.topAnchor.constraint(equalTo: navigationHostView.topAnchor),
            navigationStackController.view.leadingAnchor.constraint(equalTo: navigationHostView.leadingAnchor),
            navigationStackController.view.trailingAnchor.constraint(equalTo: navigationHostView.trailingAnchor),
            navigationStackController.view.bottomAnchor.constraint(equalTo: navigationHostView.bottomAnchor),
        ])
    }

    private func sectionLabel(_ title: String) -> NSTextField {
        let field = NSTextField(labelWithString: title)
        field.font = .preferredFont(forTextStyle: .headline)
        return field
    }

    private func labelledControl(_ title: String, _ control: NSControl, _ valueField: NSTextField?) -> NSView {
        let titleField = NSTextField(labelWithString: title)
        titleField.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        titleField.widthAnchor.constraint(equalToConstant: 100).isActive = true

        var arrangedSubviews: [NSView] = [titleField, control]
        if let valueField {
            valueField.alignment = .right
            valueField.widthAnchor.constraint(equalToConstant: 52).isActive = true
            arrangedSubviews.append(valueField)
        }

        let stackView = NSStackView(views: arrangedSubviews)
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.widthAnchor.constraint(equalToConstant: 300).isActive = true
        return stackView
    }

    // MARK: - Wiring

    private func wireControls() {
        for slider in [durationSlider, parallaxSlider, dimmingSlider, edgeShadowSlider, contentInsetSlider] {
            slider.target = self
            slider.action = #selector(configurationDidChange)
            slider.isContinuous = true
        }

        presetPopUpButton.removeAllItems()
        presetPopUpButton.addItems(withTitles: presets.map(\.title))
        presetPopUpButton.target = self
        presetPopUpButton.action = #selector(presetDidChange)

        curvePopUpButton.removeAllItems()
        curvePopUpButton.addItems(withTitles: curves.map(\.title))
        curvePopUpButton.target = self
        curvePopUpButton.action = #selector(configurationDidChange)

        interactivePopCheckbox.state = .on
        interactivePopCheckbox.target = self
        interactivePopCheckbox.action = #selector(configurationDidChange)

        rightToLeftCheckbox.state = .off
        rightToLeftCheckbox.target = self
        rightToLeftCheckbox.action = #selector(configurationDidChange)

        transparentPagesCheckbox.state = .off
        transparentPagesCheckbox.target = self
        transparentPagesCheckbox.action = #selector(transparencyDidChange)

        pageBackdropCheckbox.state = .on
        pageBackdropCheckbox.target = self
        pageBackdropCheckbox.action = #selector(configurationDidChange)

        pushButton.target = self
        pushButton.action = #selector(pushPage)
        backButton.target = self
        backButton.action = #selector(popPage)
        popToRootButton.target = self
        popToRootButton.action = #selector(popToRoot)
    }

    @objc private func configurationDidChange() {
        applyConfiguration()
    }

    /// Repaints every page already on the stack, so the toggle takes effect without pushing.
    @objc private func transparencyDidChange() {
        let isTransparent = transparentPagesCheckbox.state == .on
        for viewController in navigationStackController.viewControllers {
            (viewController as? NavigationDemoPageViewController)?.isTransparent = isTransparent
        }
        applyConfiguration()
    }

    /// Loads a preset into every control, so the two looks can be flipped between and then
    /// adjusted from there.
    @objc private func presetDidChange() {
        let preset = presets[presetPopUpButton.indexOfSelectedItem].configuration
        durationSlider.doubleValue = preset.timing.duration
        parallaxSlider.doubleValue = Double(preset.parallaxFactor)
        dimmingSlider.doubleValue = Double(preset.dimmingColor.usingColorSpace(.sRGB)?.alphaComponent ?? 0)
        edgeShadowSlider.doubleValue = Double(preset.edgeShadowWidth)
        curvePopUpButton.selectItem(at: curves.firstIndex { $0.curve == preset.timing.curve } ?? 0)
        applyConfiguration()
    }

    private func applyConfiguration() {
        var configuration = NavigationConfiguration()
        configuration.timing = AnimationTiming(
            duration: durationSlider.doubleValue,
            curve: curves[curvePopUpButton.indexOfSelectedItem].curve
        )
        configuration.parallaxFactor = CGFloat(parallaxSlider.doubleValue)
        configuration.dimmingColor = NSColor(srgbRed: 0, green: 0, blue: 0, alpha: CGFloat(dimmingSlider.doubleValue))
        configuration.edgeShadowWidth = CGFloat(edgeShadowSlider.doubleValue)
        configuration.pageBackdrop = pageBackdropCheckbox.state == .on ? .automatic : .none
        let inset = CGFloat(contentInsetSlider.doubleValue)
        configuration.contentInsets = NSEdgeInsets(top: inset, left: inset, bottom: inset, right: inset)
        navigationStackController.configuration = configuration

        navigationStackController.allowsInteractivePop = interactivePopCheckbox.state == .on
        navigationStackController.view.userInterfaceLayoutDirection =
            rightToLeftCheckbox.state == .on ? .rightToLeft : .leftToRight

        durationValueField.stringValue = String(format: "%.2fs", durationSlider.doubleValue)
        parallaxValueField.stringValue = String(format: "%.4f", parallaxSlider.doubleValue)
        dimmingValueField.stringValue = String(format: "%.2f", dimmingSlider.doubleValue)
        edgeShadowValueField.stringValue = String(format: "%.0fpt", edgeShadowSlider.doubleValue)
        contentInsetValueField.stringValue = String(format: "%.0f", contentInsetSlider.doubleValue)
    }

    // MARK: - Actions

    @objc private func pushPage() {
        let level = navigationStackController.viewControllers.count + 1
        let page = NavigationDemoPageViewController(level: level)
        page.isTransparent = transparentPagesCheckbox.state == .on
        navigationStackController.pushViewController(page, animated: true)
    }

    @objc private func popPage() {
        navigationStackController.popViewController(animated: true)
    }

    @objc private func popToRoot() {
        navigationStackController.popToRootViewController(animated: true)
    }

    private func updateStackStatus() {
        let depth = navigationStackController.viewControllers.count
        stackStatusField.stringValue = "Depth \(depth) · back \(navigationStackController.canPop ? "available" : "unavailable")"
        backButton.isEnabled = navigationStackController.canPop
        popToRootButton.isEnabled = navigationStackController.canPop
    }
}

// MARK: - NavigationControllerDelegate

extension NavigationDemoViewController: NavigationControllerDelegate {
    func navigationController(
        _ navigationController: NavigationController,
        didShow viewController: NSViewController,
        animated: Bool
    ) {
        updateStackStatus()
    }
}

// MARK: - Page

/// One level of the demo stack: a tinted page that says how deep it is and can push another.
private final class NavigationDemoPageViewController: NSViewController {

    private let level: Int

    /// When true the page paints no background of its own, the way a page on macOS 26 must if the
    /// window's glass is to show through it. Turn the backdrop off with this on to see what the
    /// transition looks like without one.
    var isTransparent = false {
        didSet {
            guard isViewLoaded, isTransparent != oldValue else { return }
            applyBackground()
        }
    }

    private var tint: NSColor { Self.tints[(level - 1) % Self.tints.count] }

    private static let tints: [NSColor] = [
        .systemBlue, .systemPurple, .systemPink, .systemOrange, .systemGreen, .systemTeal,
    ]

    init(level: Int) {
        self.level = level
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.wantsLayer = true
        applyBackground()

        let titleField = NSTextField(labelWithString: "Level \(level)")
        titleField.font = .systemFont(ofSize: 34, weight: .semibold)
        titleField.textColor = tint

        let bodyField = NSTextField(wrappingLabelWithString:
            "Each level is its own view controller. The container positions this view by frame, "
            + "so lay the page out with constraints inside it and never pin it to anything outside.")
        bodyField.alignment = .center
        bodyField.textColor = .secondaryLabelColor

        let pushButton = NSButton(title: "Push Level \(level + 1)", target: self, action: #selector(pushDeeper))
        pushButton.controlSize = .large

        let stackView = NSStackView(views: [titleField, bodyField, pushButton])
        stackView.orientation = .vertical
        stackView.alignment = .centerX
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
        ])
    }

    private func applyBackground() {
        // Opaque unless asked otherwise: a page that paints nothing lets the one sliding out show
        // straight through it, which is exactly what `NavigationPageBackdrop` exists to fix.
        view.layer?.backgroundColor = isTransparent
            ? NSColor.clear.cgColor
            : NSColor.windowBackgroundColor.blended(withFraction: 0.18, of: tint)?.cgColor
    }

    @objc private func pushDeeper() {
        guard let navigationStackController = parent as? NavigationController else { return }
        let page = NavigationDemoPageViewController(level: level + 1)
        page.isTransparent = isTransparent
        navigationStackController.pushViewController(page, animated: true)
    }
}
