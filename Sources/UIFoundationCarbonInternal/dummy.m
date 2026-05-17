// `@import Carbon;` inside the headers below is macOS-only; on iOS / iOS
// Simulator builds the Carbon module does not exist and a stray include
// crashes the build with `Module 'Carbon' not found`. Skip the imports there
// so SPM still produces a (empty) UIFoundationCarbonInternal module on those
// platforms, which keeps consumers like UIFoundationAppleInternal able to
// link against it even when none of its declarations are reachable.
#if TARGET_OS_OSX
#import "HIToolbox_Private.h"
#import "NSMenu_FilteringPrivate.h"
#endif
