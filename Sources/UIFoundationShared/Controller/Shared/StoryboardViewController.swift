#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

@_implementationOnly import UIFoundationToolbox
import UIFoundationTypealias

public protocol StoryboardViewController: NSUIViewController {
    static var storyboard: NSUIStoryboard { get }
    static var storyboardIdentifier: String { get }
}

extension StoryboardViewController {
    public static var storyboard: NSUIStoryboard { .box.main }
    public static var storyboardIdentifier: String { .init(describing: self) }
}

@available(iOS 13.0, macOS 10.15, *)
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
