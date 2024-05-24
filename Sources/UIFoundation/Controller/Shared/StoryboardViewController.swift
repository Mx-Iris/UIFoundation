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

extension StoryboardViewController {
    public static var storyboard: NSUIStoryboard { .main }
    public static var storyboardIdentifier: String { .init(describing: self) }
}

extension NSUIStoryboard {
    static let main = NSUIStoryboard(name: "Main", bundle: .main)
}

extension StoryboardViewController {
    public static func create() -> Self {
        return create(nil)
    }

    public static func create<ViewController: StoryboardViewController>(_ creator: ((NSCoder) -> ViewController?)? = nil) -> ViewController {
        #if canImport(AppKit) && !targetEnvironment(macCatalyst)
        return storyboard.instantiateController(identifier: storyboardIdentifier, creator: creator)
        #endif

        #if canImport(UIKit)
        return storyboard.instantiateViewController(identifier: storyboardIdentifier, creator: creator)
        #endif
    }
}
