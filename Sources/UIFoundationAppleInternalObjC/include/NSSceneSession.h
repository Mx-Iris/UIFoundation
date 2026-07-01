#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class NSScene, NSSceneConfiguration;

API_AVAILABLE(macos(26.0)) NS_SWIFT_UI_ACTOR
@interface NSSceneSession : NSObject <NSSecureCoding>

@property (nonatomic, readonly) NSString *persistentIdentifier;
@property (nonatomic, readonly) NSScene *scene;
@property (nonatomic, readonly) NSSceneConfiguration *configuration;
@property (nonatomic, copy, nullable) NSDictionary<NSString *, id> *userInfo;


+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPersistentIdentifier:(NSString *)persistentIdentifier;

@end

NS_ASSUME_NONNULL_END

#endif
