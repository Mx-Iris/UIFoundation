#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSButton ()

@property (strong, nullable) NSView *contentView;

@end

NS_ASSUME_NONNULL_END

#endif
