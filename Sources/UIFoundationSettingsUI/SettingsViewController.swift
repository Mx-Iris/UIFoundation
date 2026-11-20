#if Settings && (os(iOS) || os(visionOS))

import SwiftUI
import UIKit

/// Presents the settings pages from a UIKit app — the counterpart of the
/// macOS `SettingsWindowController`.
///
/// Subclass it to give the pages once, then present an instance; its Done
/// button dismisses it:
///
/// ```swift
/// final class AppSettingsViewController: SettingsViewController {
///     init() {
///         super.init {
///             SettingsPage("Theme", plainSymbol: "paintpalette") { ThemeSettingsView() }
///         }
///     }
/// }
///
/// present(AppSettingsViewController(), animated: true)
/// ```
///
/// The pages are a ``SettingsNavigationStack`` hosted as a child view
/// controller, so a subclass never names the hosting controller's root view
/// type.
@available(iOS 17.0, macCatalyst 17.0, visionOS 1.0, *)
@MainActor
open class SettingsViewController: UIViewController {
    /// The pages, in the order the list shows them.
    public let pages: [SettingsPage]

    private let settingsTitle: String

    /// - Parameters:
    ///   - title: The list's navigation title. Localize this in the host
    ///     application.
    ///   - pages: The list's rows, in order.
    public init(title: String = "Settings", @SettingsPageBuilder pages: () -> [SettingsPage]) {
        self.pages = pages()
        self.settingsTitle = title
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        let navigationStack = SettingsNavigationStack(title: settingsTitle, onDone: { [weak self] in
            guard let self else { return }
            dismiss(animated: true)
        }, pages: pages)
        let hostingController = UIHostingController(rootView: navigationStack)
        addChild(hostingController)
        let hostedView: UIView = hostingController.view
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: view.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostedView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        hostingController.didMove(toParent: self)
    }
}

#endif
