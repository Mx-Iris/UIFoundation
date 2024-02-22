#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

import UIFoundationTypealias

public protocol StoryboardViewController: NSUIViewController {
    static var storyboard: NSUIStoryboard { get }
    static var storyboardIdentifier: String { get }
}

public extension StoryboardViewController {
    static func create() -> Self {
        return create(nil)
    }

    static func create<ViewController: StoryboardViewController>(_ creator: ((NSCoder) -> ViewController?)? = nil) -> ViewController {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return storyboard.instantiateController(identifier: storyboardIdentifier, creator: creator)
        #endif

        #if canImport(UIKit)
        return storyboard.instantiateViewController(identifier: storyboardIdentifier, creator: creator)
        #endif
    }
}
