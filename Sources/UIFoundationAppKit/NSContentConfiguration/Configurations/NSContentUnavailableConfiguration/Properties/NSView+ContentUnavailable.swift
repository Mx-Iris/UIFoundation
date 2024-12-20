//
//  NSView+ContentUnavailable.swift
//
//
//  Created by Florian Zand on 24.06.23.
//

#if os(macOS)
import AppKit

@available(macOS 12.0, *)
extension NSView {
    /// The current content-unavailable configuration of the view.
    ///
    /// Use this property to configure a content-unavailable view that the view displays. The value of this property is commonly an instance of `NSContentUnavailableConfiguration`, but you can use other types of content configuration, including a `NSHostingConfiguration, to display a SwiftUI view.
    public var contentUnavailableConfiguration: NSContentConfiguration? {
        get { getAssociatedValue("NSView_contentUnavailableConfiguration") }
        set {
            setAssociatedValue(newValue, key: "NSView_contentUnavailableConfiguration")
            configurateUnavailableView()
        }
    }

    var unavailableView: (NSView & NSContentView)? {
        get { getAssociatedValue("NSView_unavailableView") }
        set { setAssociatedValue(newValue, key: "NSView_unavailableView")
        }
    }

    func configurateUnavailableView() {
        if let contentUnavailableConfiguration = contentUnavailableConfiguration {
            if let unavailableView = unavailableView, unavailableView.supports(contentUnavailableConfiguration) {
                unavailableView.configuration = contentUnavailableConfiguration
            } else {
                self.unavailableView?.removeFromSuperview()
                let unavailableView = contentUnavailableConfiguration.makeContentView()
                self.unavailableView = unavailableView
                addSubview(withConstraint: unavailableView)
            }
        } else {
            unavailableView?.removeFromSuperview()
            unavailableView = nil
        }
    }

    /// The current configuration state of the content-unavailable view.
    ///
    /// To add your own custom state, see ``NSConfigurationStateCustomKey``.
    public var contentUnavailableConfigurationState: NSContentUnavailableConfigurationState {
        let state = NSContentUnavailableConfigurationState()
        return state
    }

    /// Requests that the system update the content-unavailable configuration for the latest state.
    public func setNeedsUpdateContentUnavailableConfiguration() {
        updateContentUnavailableConfiguration(using: contentUnavailableConfigurationState)
    }

    /// Updates the content-unavailable configuration for the provided state.
    ///
    /// Override this method to update the value of `contentUnavailableConfiguration` as appropriate for the given state.
    ///
    /// Don’t call this method directly. Instead, call `setNeedsUpdateContentUnavailableConfiguration() to tell the system to request an update.
    ///
    /// - Parameter state:  The current configuration state for a content-unavailable view.
    public func updateContentUnavailableConfiguration(using: NSContentUnavailableConfigurationState) {}
}
#endif
