#if canImport(AppKit) && !targetEnvironment(macCatalyst)

import AppKit
import UIFoundationToolbox

public protocol StoryboardWindowController: NSWindowController {
    static var storyboard: NSStoryboard { get }

    static var storyboardIdentifier: String { get }
}

extension StoryboardWindowController {
    public static var storyboard: NSStoryboard { .box.main }

    public static var storyboardIdentifier: String { .init(describing: self) }
}

extension StoryboardWindowController {
    public static func create() -> Self {
        return create(nil)
    }

    public static func create<WindowController: StoryboardWindowController>(_ creator: ((NSCoder) -> WindowController?)? = nil) -> WindowController {
        return storyboard.instantiateController(identifier: storyboardIdentifier, creator: creator)
    }
}

#endif
