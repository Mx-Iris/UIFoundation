#if TARGET_OS_OSX
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#import "NSToolTip.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSToolTipManager : NSObject

@property (class, readonly, strong) NSToolTipManager *sharedToolTipManager NS_SWIFT_NAME(shared);

@property NSTimeInterval initialToolTipDelay;

- (NSDictionary<NSAttributedStringKey, id> *)toolTipAttributes;
- (NSColor *)toolTipBackgroundColor;
- (NSColor *)toolTipTextColor;
- (CGSize)toolTipContentMargin;
- (CGFloat)toolTipYOffset;

- (NSWindow *)_newToolTipWindow;

- (void)installContentView:(nullable NSView *)contentView
                forToolTip:(NSToolTip *)toolTip
             toolTipWindow:(NSWindow *)toolTipWindow
                     isNew:(BOOL)isNew;

- (void)displayToolTip:(NSToolTip *)toolTip;

@end

NS_ASSUME_NONNULL_END

#endif
#endif
