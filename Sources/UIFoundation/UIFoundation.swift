@_exported import UIFoundationShared
@_exported import UIFoundationTypealias
@_exported import UIFoundationUtilities

#if canImport(AppKit) && !targetEnvironment(macCatalyst)
@_exported import UIFoundationAppKit
#endif

#if canImport(UIKit)
@_exported import UIFoundationUIKit
#endif


#if AppleInternal

@_exported import UIFoundationAppleInternal
@_exported import UIFoundationAppleInternalObjC

#endif
