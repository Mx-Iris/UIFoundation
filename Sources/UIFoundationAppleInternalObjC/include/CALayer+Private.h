#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>

NS_ASSUME_NONNULL_BEGIN

@interface CALayer ()

@property BOOL allowsGroupBlending;

@end

NS_ASSUME_NONNULL_END

#endif
