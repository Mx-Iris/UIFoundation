#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#if defined(__MAC_26_0) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_26_0

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

/// The private settings `NSGlassEffectView` (macOS 26+) forwards into the SwiftUI-hosted glass
/// renderer behind it. Every accessor here is a real Objective-C method on the class
/// (`_variant` / `set_variant:` and so on) — read off the macOS 27.0 AppKit binary, build
/// 2775.10.103.1, and present in the 26.4 – 26.6 header dumps as well.
///
/// `_variant` picks the material recipe. AppKit's own split view uses 17 for a sidebar item and
/// 18 for an inspector item (`-[_NSSplitViewItemViewWrapper _glassVariant]`); the numbering is not
/// contractual, so copy it off a live view rather than hardcoding it. See
/// `Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md`.
@interface NSGlassEffectView ()

/// The material recipe. Sidebar items read 17, inspector items 18 on macOS 27.0.
@property (nonatomic) NSInteger _variant;

/// A refinement of `_variant`; `nil` on the split view's glass.
@property (nonatomic, copy, nullable) NSString *_subvariant;

/// Whether the glass adapts to the window's key state. AppKit sets 1 on the split view's glass.
@property (nonatomic) NSInteger _adaptiveAppearance;

/// Stored, but as of macOS 27.0 **not** what names the backdrop group: SwiftUI assigns its own
/// `CABackdropLayer.groupName` (`SwiftUI:<identity>`) and keeps it whatever this holds. Sharing a
/// group has to happen on the layer itself — see `NSGlassEffectView.glassBackdropGroupName`.
@property (nonatomic, copy, nullable) NSString *_backdropGroupName;

/// Same as `_backdropGroupName`: stored, never reaches the backdrop layer's group name.
@property (nonatomic, copy, nullable) NSString *_groupIdentifier;

@end

NS_HEADER_AUDIT_END(nullability, sendability)

#endif
#endif
