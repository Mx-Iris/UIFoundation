#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(26.0)) NS_SWIFT_UI_ACTOR
@interface NSSceneConnectionOptions : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

#endif
