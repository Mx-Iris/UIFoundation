#import <TargetConditionals.h>

#if TARGET_OS_OSX

#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSWindow ()

/// Blurs everything the window has rendered, in points, on top of whatever it draws.
///
/// Spotlight animates this from 0 to 25 while dismissing, on a curve roughly twice as slow as
/// the one driving `alphaValue`, which is what makes the panel read as blurring out rather than
/// merely fading.
///
/// Declared as the setter alone, deliberately. The getter does exist and is `-_contentBlurRadius`
/// (probed on macOS 26), but nothing here needs to read the value, and not declaring it keeps a
/// future AppKit dropping the getter from becoming a compile-time dependency.
///
/// Note that the **unprefixed** spellings are not selectors at all: `contentBlurRadius` and
/// `setContentBlurRadius:` both return false from `respondsToSelector:`. `contentBlurRadius` is
/// nonetheless the correct **KVC key** in both directions — KVC's setter search includes the
/// `_set<Key>:` form and its getter search includes `_<key>` — and that is what makes an entry
/// under that name in `NSWindow.animations` animate this property.
- (void)_setContentBlurRadius:(CGFloat)contentBlurRadius;

@end

NS_ASSUME_NONNULL_END

#endif
