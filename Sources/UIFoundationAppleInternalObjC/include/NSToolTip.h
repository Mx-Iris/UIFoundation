#if TARGET_OS_OSX
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSToolTip : NSObject

@property (nonatomic, readonly, nullable) NSView *view;
@property (nonatomic, readonly, nullable) NSCell *cell;
@property (nonatomic, readonly, nullable) NSString *string;
@property (nonatomic, readonly) NSInteger trackingNum;
@property (nonatomic, readonly) BOOL isExpansionToolTip;

@end

NS_ASSUME_NONNULL_END

#endif
#endif
