// All AppKit / CoreAnimation / NSScene private headers below are macOS-only.
// On iOS / iOS Simulator builds these declarations don't exist and importing
// them crashes the build. Skip the imports there so SPM still produces a
// (empty) UIFoundationAppleInternalObjC module on those platforms, which keeps
// consumers like UIFoundationAppleInternal able to import it without losing
// any reachable symbols (everything that actually uses these types is already
// gated by `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`).
#if TARGET_OS_OSX
#import "NSView_Private.h"
#import "NSButton_Private.h"
#import "NSTableView_Private.h"
#import "NSTableViewStyleData.h"
#import "NSImage_Private.h"
#import "NSScrollView_Private.h"
#import "NSToolTip.h"
#import "NSToolTipManager.h"
#import "NSColor_Private.h"

#import "CALayer_Private.h"
#import "CABackdropLayer.h"
#import "CAFilter.h"


// NSScene
#import "NSScene.h"
#import "NSSceneSession.h"
#import "NSSceneConfiguration.h"
#import "NSSceneConnectionOptions.h"
#import "NSApplicationDelegateScenesPrivate.h"
#endif
