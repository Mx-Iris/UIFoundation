#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/// The width a toolbar gives its centered item — the one `centeredItemIdentifiers` names — as a fraction of the
/// toolbar's own width. Xcode 26's toolbar Activity View sets 0.4.
///
/// Read off macOS 26.6's AppKit: the setter only stores the value, without laying the toolbar out again, and the
/// toolbar view's next layout hands `ceil(ratio × its width)` to the layout of its centre section, or −1 for a
/// ratio of 0 or less, which means no preference. A toolbar starts at −1. Measured on macOS 27.2: the item is laid
/// out that wide, centred on the toolbar's visual centre; a width below the item's minimum drops the preference,
/// so the item takes its maximum width as it does with none, and the room the leading and trailing items leave
/// caps it. See `Researchs/AppKit-NSToolbar-CenteredItemWidthRatio-Internals.md`.
@interface NSToolbar ()

@property CGFloat preferredPrincipalItemWidthRatio;

@end

NS_ASSUME_NONNULL_END

#endif
