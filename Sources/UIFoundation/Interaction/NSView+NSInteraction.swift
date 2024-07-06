#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import FoundationToolbox

extension NSView {
//    @AssociatedObject(.retain(.nonatomic))
    public private(set) var interactions: [NSInteraction] {
        set {
            objc_setAssociatedObject(self, #function, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        get {
            (objc_getAssociatedObject(self, #function) as? [NSInteraction]) ?? []
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
