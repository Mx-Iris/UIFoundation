#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@class NSSceneConfiguration, NSSceneSession, NSSceneConnectionOptions;

API_AVAILABLE(macos(26.0))
@protocol NSApplicationDelegateScenesPrivate <NSApplicationDelegate>

@optional

- (NSSceneConfiguration *)application:(NSApplication *)application configurationForConnectingSceneSession:(NSSceneSession *)session options:(NSSceneConnectionOptions *)options;
- (void)application:(NSApplication *)application didDiscardSceneSessions:(NSSet<NSSceneSession *> *)sessions;

@end

NS_ASSUME_NONNULL_END

#endif
