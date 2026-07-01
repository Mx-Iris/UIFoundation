#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(macos(26.0)) NS_SWIFT_UI_ACTOR
@interface NSSceneConfiguration : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, nullable) Class delegateClass;
@property (nonatomic, nullable) Class sceneClass;

@end

NS_ASSUME_NONNULL_END

#endif
