#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class NSScene, NSSceneSession, NSSceneConnectionOptions;

API_AVAILABLE(macos(26.0)) NS_SWIFT_UI_ACTOR
@protocol NSSceneDelegate <NSObject>

- (instancetype)init;

@optional

- (void)sceneDidDisconnect:(NSScene *)scene;
- (void)scene:(NSScene *)scene willConnectToSession:(NSSceneSession *)session options:(NSSceneConnectionOptions *)options;

@end

API_AVAILABLE(macos(26.0)) NS_SWIFT_UI_ACTOR
@interface NSScene : NSResponder

@property (nonatomic, readonly) NSSceneSession *session;
@property (nonatomic, strong, nullable) id<NSSceneDelegate> delegate;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithSession:(NSSceneSession *)session connectionOptions:(NSSceneConnectionOptions *)options;

@end

NS_ASSUME_NONNULL_END

#endif
