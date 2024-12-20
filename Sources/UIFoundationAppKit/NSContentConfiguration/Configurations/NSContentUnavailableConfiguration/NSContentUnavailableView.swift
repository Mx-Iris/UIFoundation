//
//  NSContentUnavailableView.swift
//
//
//  Created by Florian Zand on 24.06.23.
//

#if os(macOS)
import AppKit
@_implementationOnly import SwiftUI
import UIFoundationToolbox

/// A view that indicates there’s no content to display.
///
/// Use a content-unavailable view to indicate that your app can’t display content. For example, content may not be available if a search returns no results or your app is loading data over the network.
@available(macOS 12.0, *)
public class NSContentUnavailableView: NSView, NSContentView {
    /// The content-unavailable configuration.
    public var configuration: NSContentConfiguration {
        get { appliedConfiguration }
        set {
            if let newValue = newValue as? NSContentUnavailableConfiguration {
                appliedConfiguration = newValue
            }
        }
    }

    public override func layout() {
        super.layout()

        hostingView.frame.size.height = bounds.height - appliedConfiguration.directionalLayoutMargins.box.height
        hostingView.frame.size.width = bounds.width - appliedConfiguration.directionalLayoutMargins.box.width
        backgroundView.frame = hostingView.frame
    }

    /// Determines whether the view is compatible with the provided configuration.
    public func supports(_ configuration: NSContentConfiguration) -> Bool {
        configuration is NSContentUnavailableConfiguration
    }

    /// Creates a new content-unavailable view with the specified configuration.
    public init(configuration: NSContentUnavailableConfiguration) {
        self.appliedConfiguration = configuration
        super.init(frame: .zero)
        addSubview(backgroundView)
        addSubview(hostingView)
        updateConfiguration()
    }

    lazy var backgroundView: (NSView & NSContentView) = appliedConfiguration.background.makeContentView()

    var appliedConfiguration: NSContentUnavailableConfiguration {
        didSet {
            if oldValue != appliedConfiguration {
                updateConfiguration()
            }
        }
    }

    func updateConfiguration() {
        backgroundView.configuration = appliedConfiguration.background
        hostingView.rootView = ContentView(configuration: appliedConfiguration)

        hostingView.frame.origin.x = appliedConfiguration.directionalLayoutMargins.leading
        hostingView.frame.origin.y = appliedConfiguration.directionalLayoutMargins.bottom
        hostingView.frame.size.height = bounds.height - appliedConfiguration.directionalLayoutMargins.box.height
        hostingView.frame.size.width = bounds.width - appliedConfiguration.directionalLayoutMargins.box.width
        backgroundView.frame = hostingView.frame
    }

    lazy var hostingView = NSHostingView(rootView: ContentView(configuration: self.appliedConfiguration))

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

@available(macOS 12.0, *)
extension NSContentUnavailableView {
    struct ContentView: SwiftUI.View {
        let configuration: NSContentUnavailableConfiguration

        @ViewBuilder
        var buttonItem: some SwiftUI.View {
            if let configuration = configuration.button, configuration.hasContent {
                ButtonItem(configuration: configuration)
            }
        }

        @ViewBuilder
        var secondaryButton: some SwiftUI.View {
            if let configuration = configuration.secondaryButton, configuration.hasContent {
                ButtonItem(configuration: configuration)
            }
        }

        @ViewBuilder
        var buttonItems: some SwiftUI.View {
            if configuration.buttonOrientation == .vertical {
                VStack(spacing: configuration.buttonToSecondaryButtonPadding) {
                    buttonItem
                    secondaryButton
                }
            } else {
                HStack(spacing: configuration.buttonToSecondaryButtonPadding) {
                    buttonItem
                    secondaryButton
                }
            }
        }

        @ViewBuilder
        var imageItem: some SwiftUI.View {
            if let image = configuration.image {
                SwiftUI.Image(nsImage: image)
                    .scaling(configuration.imageProperties.scaling)
                    .frame(maxWidth: configuration.imageProperties.maximumWidth, maxHeight: configuration.imageProperties.maximumHeight)
                    .foregroundColor(configuration.imageProperties.tintColor?.swiftUI)
                    .symbolConfiguration(configuration.imageProperties.symbolConfiguration)
                    .cornerRadius(configuration.imageProperties.cornerRadius)
                    .shadow(configuration.imageProperties.shadow)
            }
        }

        @ViewBuilder
        var textItems: some SwiftUI.View {
            VStack(spacing: configuration.textToSecondaryTextPadding) {
                TextItem(text: configuration.text, attributedText: configuration.attributedText, properties: configuration.textProperties)
                TextItem(text: configuration.secondaryText, attributedText: configuration.secondaryAttributedText, properties: configuration.secondaryTextProperties)
            }
        }

        @ViewBuilder
        var loadingIndicatorItem: some SwiftUI.View {
            if let loadingIndicator = configuration.loadingIndicator {
                switch loadingIndicator {
                case let .spinning(size):
                    SwiftUI.ProgressView()
                        .controlSize(size.swiftUI)
                case let .bar(value, total, text, textStyle, textColor, size, width):
                    if let text = text {
                        SwiftUI.ProgressView(value: value, total: total) {
                            SwiftUI.Text(text)
                                .font(.system(textStyle.swiftUI))
                                .foregroundStyle(Color(textColor))
                        }
                        .progressViewStyle(.linear)
                        .controlSize(size.swiftUI)
                        .frame(width: width)
                    } else {
                        SwiftUI.ProgressView(value: value, total: total)
                            .progressViewStyle(.linear)
                            .controlSize(size.swiftUI)
                            .frame(maxWidth: width)
                    }
                case let .circular(value, total, text, textStyle, textColor, size):
                    if let text = text {
                        SwiftUI.ProgressView(value: value, total: total) {
                            Text(text)
                                .font(.system(textStyle.swiftUI))
                                .foregroundStyle(Color(textColor))
                        }
                        .progressViewStyle(.circular)
                        .controlSize(size.swiftUI)
                    } else {
                        SwiftUI.ProgressView(value: value, total: total)
                            .progressViewStyle(.circular)
                            .controlSize(size.swiftUI)
                    }
                }
            }
        }

        @ViewBuilder
        var imageTextStack: some SwiftUI.View {
            SwiftUI.VStack(spacing: configuration.imageToTextPadding) {
                loadingIndicatorItem
                imageItem
                textItems
            }
        }

        @ViewBuilder
        var stack: some SwiftUI.View {
            SwiftUI.VStack(spacing: configuration.textToButtonPadding) {
                imageTextStack
                buttonItems
            }
        }

        var body: some SwiftUI.View {
            stack
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    struct ButtonItem: SwiftUI.View {
        let configuration: NSContentUnavailableConfiguration.ButtonConfiguration

        var body: some SwiftUI.View {
            SwiftUI.Button {
                configuration.action?()
            } label: {
                if let atributedTitle = configuration.atributedTitle {
                    if let image = configuration.image {
                        SwiftUI.Label { SwiftUI.Text(atributedTitle) } icon: {
                            SwiftUI.Image(nsImage: image)
                                .resizable()
                            // .frame(width: configuration.size.size?.width, height: configuration.size.size?.height)
                        }
                    } else {
                        SwiftUI.Text(atributedTitle)
                    }
                } else if let title = configuration.title {
                    if let image = configuration.image {
                        SwiftUI.Label { SwiftUI.Text(title) } icon: {
                            SwiftUI.Image(nsImage: image)
                                .resizable()
                            //   .frame(width: configuration.size.size?.width, height: configuration.size.size?.height)
                        }
                    } else {
                        SwiftUI.Text(title)
                    }
                } else if let image = configuration.image {
                    SwiftUI.Image(nsImage: image)
                        .resizable()
                    // .frame(width: configuration.size.size?.width, height: configuration.size.size?.height)
                }
            }.buttonStyling(configuration.style)
                .foregroundColor(configuration.contentTintColor?.swiftUI)
                .symbolConfiguration(configuration.symbolConfiguration)
                .controlSize(configuration.size.swiftUI)
                .frame(width: configuration.image != nil && configuration.style == .borderless ? configuration.size.size?.width : nil, height: configuration.image != nil && configuration.style == .borderless ? configuration.size.size?.height : nil)
        }
    }

    struct TextItem: SwiftUI.View {
        let text: String?
        let attributedText: NSAttributedString?
        let properties: NSContentUnavailableConfiguration.TextProperties

        init(text: String?, attributedText: NSAttributedString?, properties: NSContentUnavailableConfiguration.TextProperties) {
            self.text = text
            self.attributedText = attributedText
            self.properties = properties
        }

        @ViewBuilder
        var item: some SwiftUI.View {
            if let attributedText = attributedText {
                Text(AttributedString(attributedText))
            } else if let text = text {
                Text(text)
            }
        }

        var body: some SwiftUI.View {
            item
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .font(properties.font.swiftUI)
                .lineLimit(properties._maxNumberOfLines)
                .foregroundColor(properties.color.swiftUI)
                .minimumScaleFactor(properties.minimumScaleFactor)
        }
    }
}

 @available(macOS 12.0, *)
extension SwiftUI.View {
    @ViewBuilder
    func buttonStyling(_ style: NSContentUnavailableConfiguration.ButtonConfiguration.Style) -> some SwiftUI.View {
        switch style {
        case .plain: buttonStyle(.plain)
        case .borderless: buttonStyle(.borderless)
        case .bordered: buttonStyle(.bordered)
        case .link: buttonStyle(.link)
        }
    }
 }
#endif
