#if TARGET_OS_OSX
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSColor ()

+ (NSColor *)toolTipColor;

@end

NS_ASSUME_NONNULL_END

#endif
#endif
