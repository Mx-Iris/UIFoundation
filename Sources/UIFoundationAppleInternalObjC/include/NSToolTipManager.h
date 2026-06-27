#if TARGET_OS_OSX
#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>
#import "NSToolTip.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSToolTipManager : NSObject

@property (class, readonly, strong) NSToolTipManager *sharedToolTipManager NS_SWIFT_NAME(shared);

// NSToolTipManager exposes only a setter for the delay; the value lives on
// the `_toolTipDelay` ivar (KVC key "toolTipDelay") and is read via KVC.
- (void)setInitialToolTipDelay:(NSTimeInterval)initialToolTipDelay;

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
