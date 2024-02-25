#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
//import AssociatedObject
import FoundationToolbox

extension NSView {
//    @AssociatedObject(.retain(.nonatomic))
    public var interactions: [NSInteraction] {
        set {
            set(associatedValue: newValue, key: #function, object: self)
        }
        get {
            getAssociatedValue(key: #function, object: self) ?? []
        }
    }

    public func addInteraction(_ interaction: NSInteraction) {
        interactions.append(interaction)
        _setInteractionView(interaction, self)
    }

    public func removeInteraction(_ interaction: NSInteraction) {
        if let index = interactions.firstIndex(where: { $0 === interaction }) {
            interactions.remove(at: index)
            _setInteractionView(interaction, nil)
        }
    }
}

private func _setInteractionView(_ interaction: NSInteraction, _ view: NSView?) {
    interaction.willMove(to: view)
    interaction.didMove(to: view)
}

#endif
