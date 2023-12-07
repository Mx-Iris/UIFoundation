#if canImport(AppKit) && !targetEnvironment(macCatalyst)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif



//open class StoryboardViewController: _NSUIViewController {
//    open class var storyboard: _NSUIStoryboard { fatalError("Must be overridden in a subclass") }
//
//    open class var storyboardIdentifier: String { fatalError("Must be overridden in a subclass") }
//
//
//}


public protocol StoryboardViewController: _NSUIViewController {
    static var storyboard: _NSUIStoryboard { get }
    static var storyboardIdentifier: String { get }
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
