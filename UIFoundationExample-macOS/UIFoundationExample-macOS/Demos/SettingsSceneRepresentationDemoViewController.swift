//
//  SettingsSceneRepresentationDemoViewController.swift
//  UIFoundationExample-macOS
//
//  A runnable AppKit-lifecycle use case for NSHostingSceneRepresentation.
//

import AppKit
import SwiftUI
import UIFoundationSettingsUI

enum SettingsSceneRepresentationExamplePage: String {
    case registration
    case activation
}

@MainActor
protocol SettingsSceneRepresentationPresenting: AnyObject {
    func open(page: SettingsSceneRepresentationExamplePage)
}

/// Application-lifetime state for the native SwiftUI Settings scene.
///
/// Apple requires registration during `applicationWillFinishLaunching(_:)`.
/// `AppDelegate` owns this object for the lifetime of the process and the demo
/// controller only asks it to present a page.
@available(macOS 26.0, *)
@MainActor
final class SettingsSceneRepresentationExample: SettingsSceneRepresentationPresenting {
    private let navigator: SettingsNavigator
    private let settingsScene: SettingsScene
    private let sceneRepresentation: NSHostingSceneRepresentation<SettingsScene>

    init() {
        let navigator = SettingsNavigator(initialPageID: SettingsSceneRepresentationExamplePage.registration.rawValue)
        let settingsScene = SettingsScene(
            configuration: SettingsConfiguration(sidebarIconSize: 15),
            navigator: navigator
        ) {
            SettingsPage(
                "Registration",
                id: SettingsSceneRepresentationExamplePage.registration.rawValue,
                plainSymbol: "macwindow"
            ) {
                SettingsSceneRegistrationPage()
            }
            SettingsPage(
                "Activation",
                id: SettingsSceneRepresentationExamplePage.activation.rawValue,
                plainSymbol: "arrow.up.forward.app"
            ) {
                SettingsSceneActivationPage()
            }
        }

        self.navigator = navigator
        self.settingsScene = settingsScene
        self.sceneRepresentation = NSHostingSceneRepresentation {
            settingsScene
        }
    }

    func register(with application: NSApplication) {
        application.addSceneRepresentation(sceneRepresentation)
    }

    func open(page: SettingsSceneRepresentationExamplePage) {
        navigator.navigate(to: page.rawValue)
        sceneRepresentation.environment.openSettings()
    }
}

@available(macOS 26.0, *)
private struct SettingsSceneRegistrationPage: View {
    var body: some View {
        SettingsForm {
            SettingsSceneHostSection()
            SettingsSceneRegistrationTimingSection()
        }
    }
}

@available(macOS 26.0, *)
private struct SettingsSceneHostSection: View {
    var body: some View {
        Section {
            LabeledContent("Application lifecycle", value: "AppKit")
            LabeledContent("SwiftUI scene", value: "SettingsScene")
            LabeledContent("System bridge", value: "NSHostingSceneRepresentation")
        } header: {
            Text("Scene host")
        }
    }
}

@available(macOS 26.0, *)
private struct SettingsSceneRegistrationTimingSection: View {
    var body: some View {
        Section {
            Text("The application creates and retains the scene representation, then registers it during applicationWillFinishLaunching(_:).")
        } header: {
            Text("Registration timing")
        }
    }
}

@available(macOS 26.0, *)
private struct SettingsSceneActivationPage: View {
    var body: some View {
        SettingsForm {
            SettingsScenePresentationSection()
            SettingsSceneNavigationSection()
        }
    }
}

@available(macOS 26.0, *)
private struct SettingsScenePresentationSection: View {
    var body: some View {
        Section {
            LabeledContent("Environment action", value: "environment.openSettings()")
            Text("The representation exposes the environment actions that present its SwiftUI scenes from AppKit code.")
        } header: {
            Text("Presentation")
        }
    }
}

@available(macOS 26.0, *)
private struct SettingsSceneNavigationSection: View {
    var body: some View {
        Section {
            Text("The host calls navigator.navigate(to:) before openSettings(), so commands and deep links can select a specific page.")
        } header: {
            Text("Page navigation")
        }
    }
}

@available(macOS 26.0, *)
@MainActor
final class SettingsSceneRepresentationDemoViewController: NSViewController {
    private static let contentWidth: CGFloat = 680

    private let statusLabel = NSTextField(labelWithString: "The scene representation is registered and ready.")

    override func loadView() {
        view = NSView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let introductionLabel = NSTextField(
            wrappingLabelWithString: """
            This example uses the AppKit application lifecycle. AppDelegate creates and retains an \
            NSHostingSceneRepresentation during applicationWillFinishLaunching(_:), then these buttons \
            open its native SwiftUI Settings scene through representation.environment.openSettings().
            """
        )
        introductionLabel.preferredMaxLayoutWidth = Self.contentWidth

        let codeLabel = NSTextField(
            wrappingLabelWithString: """
            let representation = NSHostingSceneRepresentation { settingsScene }
            NSApplication.shared.addSceneRepresentation(representation)
            representation.environment.openSettings()
            """
        )
        codeLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        codeLabel.isSelectable = true

        let openRegistrationPageButton = NSButton(
            title: "Open Registration Page",
            target: self,
            action: #selector(openRegistrationPage)
        )
        let openActivationPageButton = NSButton(
            title: "Open Activation Page",
            target: self,
            action: #selector(openActivationPage)
        )
        let buttonRow = NSStackView(views: [openRegistrationPageButton, openActivationPageButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 10

        statusLabel.textColor = .secondaryLabelColor
        for compressibleLabel in [introductionLabel, codeLabel, statusLabel] {
            compressibleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }

        let stackView = NSStackView(views: [
            introductionLabel,
            codeLabel,
            buttonRow,
            statusLabel,
        ])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.contentWidth),
        ])
    }

    @objc
    private func openRegistrationPage() {
        open(page: .registration, pageTitle: "Registration")
    }

    @objc
    private func openActivationPage() {
        open(page: .activation, pageTitle: "Activation")
    }

    private func open(page: SettingsSceneRepresentationExamplePage, pageTitle: String) {
        guard let applicationDelegate = NSApplication.shared.delegate as? AppDelegate,
              applicationDelegate.openSettingsSceneRepresentationExample(page: page)
        else {
            statusLabel.stringValue = "The scene representation was not registered during application launch."
            return
        }

        statusLabel.stringValue = "Opened the \(pageTitle) page through representation.environment.openSettings()."
    }
}
