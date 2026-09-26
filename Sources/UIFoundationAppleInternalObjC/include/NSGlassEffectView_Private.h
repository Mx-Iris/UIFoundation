#import <TargetConditionals.h>

#if TARGET_OS_OSX
#import <AppKit/AppKit.h>

#if defined(__MAC_26_0) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_26_0

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

// The type names below are AppKit's own: each survives in AppKit's Swift symbols
// (`__C._NSGlassEffectViewVariant` and so on). Their constant names are not, unless a comment says
// otherwise. C enum constants never reach a binary, and AppKit exports no string constants for the
// subvariant, so every other name here is ours, taken from what AppKit does with the value. The
// numbering was read identically off macOS 26.6 and 27.0, but none of it is contractual. Evidence,
// addresses and what is still open are in `Researchs/AppKit-NSGlassEffectView-PrivateConfiguration.md`.

/// The material recipe `-[NSGlassEffectView _variant]` picks.
///
/// Each constant is named after the glass the value actually renders: `NSGlassEffectView` turns the
/// value into a `DesignLibrary.GlassMaterialProvider.Configuration` with a single `switch`, and every
/// case calls the static configuration of that name. Anything above 20, and anything negative,
/// falls through to regular. To match what the system uses somewhere, copy the value off a live
/// view rather than naming a case.
typedef NS_ENUM(NSInteger, _NSGlassEffectViewVariant) {
    /// Has no case of its own and renders as regular. It is what `-initWithFrame:` stores, and what
    /// AppKit's own `_glassVariant` methods return when nothing calls for a special glass.
    _NSGlassEffectViewVariantDefault = 0,
    /// What the public `style` setter writes for `NSGlassEffectViewStyleRegular`.
    _NSGlassEffectViewVariantRegular = 1,
    /// What the public `style` setter writes for `NSGlassEffectViewStyleClear`. The `style` getter is
    /// derived from this value: it reads `NSGlassEffectViewStyleClear` for 2 and regular otherwise.
    _NSGlassEffectViewVariantClear = 2,
    _NSGlassEffectViewVariantDock = 3,
    _NSGlassEffectViewVariantAppIcons = 4,
    _NSGlassEffectViewVariantWidgets = 5,
    _NSGlassEffectViewVariantText = 6,
    /// DesignLibrary spells it `avplayer`. A toolbar with `_forceAVPlayerGlassVariant` set uses it.
    _NSGlassEffectViewVariantAVPlayer = 7,
    /// DesignLibrary spells it `facetime`.
    _NSGlassEffectViewVariantFaceTime = 8,
    _NSGlassEffectViewVariantControlCenter = 9,
    _NSGlassEffectViewVariantNotificationCenter = 10,
    _NSGlassEffectViewVariantMonogram = 11,
    _NSGlassEffectViewVariantBubbles = 12,
    /// SwiftUI's public `Glass.identity` documents this name as leaving content "as if no glass
    /// effect was applied". The window tab bar gives it to every tab that is not selected.
    _NSGlassEffectViewVariantIdentity = 13,
    _NSGlassEffectViewVariantFocusBorder = 14,
    _NSGlassEffectViewVariantKeyboard = 15,
    /// The plain sidebar glass — which is *not* what the split view's sidebar uses; see 17.
    _NSGlassEffectViewVariantSidebar = 16,
    /// What `NSSplitViewController` gives a sidebar item
    /// (`-[_NSSplitViewItemViewWrapper _glassVariant]`).
    _NSGlassEffectViewVariantAbuttedSidebar = 17,
    /// What `NSSplitViewController` gives an inspector item.
    _NSGlassEffectViewVariantInspector = 18,
    _NSGlassEffectViewVariantLoupe = 19,
    /// What a popover with an anchor edge uses (`-[NSPopoverFrame _glassVariant]`).
    _NSGlassEffectViewVariantCartouchePopover = 20,
};

/// A refinement of the variant, by name.
///
/// AppKit hands the string to DesignLibrary, which accepts exactly the case names of its
/// `GlassMaterialProvider.Subvariant.Kind` — 48 on macOS 27.0 (`tab`, `menu`, `sheet`, `dock`, …),
/// 33 on 26.6 — and the set changes between releases (`track` is gone in 27.0). `nil` and any name
/// the running system does not know leave the variant's own look in place; nothing fails. A name
/// without a constant below is passed the same way, e.g. `_NSGlassEffectViewSubvariant("dock")` in
/// Swift.
typedef NSString *_NSGlassEffectViewSubvariant NS_TYPED_EXTENSIBLE_ENUM;

// **Apple's implementation has no such constants.** AppKit exports no symbol for any subvariant, and
// its own code passes the bare literals (`@"tab"`, `@"menu"`). Every constant below is this
// library's own, defined in `NSGlassEffectView_Private.m` — none is linked from AppKit, and adding
// one here needs a definition there too. They cover exactly the 31 names DesignLibrary accepts on
// both macOS 26.6 and 27.0; a name only one of the two accepts has no constant. Swift sees each as a
// member of `_NSGlassEffectViewSubvariant` (`.tab`, `.menu`, `.sheet`, …).

/// The selected tab of a window tab bar. AppKit pairs it with `_NSGlassEffectViewVariantRegular`;
/// the tabs that are not selected get `_NSGlassEffectViewVariantIdentity` and no subvariant.
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantTab;

/// Context menus, pop-up menus and the text-suggestions window.
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantMenu;

// The other 29, in DesignLibrary's declaration order. AppKit never passes any of them; most name
// iOS, watchOS or tvOS surfaces, and what each looks like on macOS was not examined.
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantLockscreenControls;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantLockscreenNotifications;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenClose;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCamera;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantPosterSwitcher;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenResizeHandle;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCursorAccessory;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenFolder;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantFocusedButtonFill;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantEntryField;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantVolumeSlider;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCustomizeSheet;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFacePhotos;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFacePhotosMini;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFaceFlowStencil;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFaceFlowSolid;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchPasscode;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenAppLibraryPod;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchSmartStack;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchSmartStackAnimatedContent;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantSiriSnippet;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantAlarmSlider;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantMapsSign;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantSheet;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantMessagesTapback;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCluster;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantSecondaryCluster;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchDetuned;
FOUNDATION_EXPORT _NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantTVPortraitClock;

/// How the glass responds to the pointer. Any value outside 0 – 2, negative ones included,
/// terminates the process inside the setter: AppKit rebuilds the glass configuration there and
/// `fatalError`s on an unknown state.
typedef NS_ENUM(NSInteger, _NSGlassEffectViewInteractionState) {
    /// The initial value.
    _NSGlassEffectViewInteractionStateIdle = 0,
    /// Note the order: 1 is pressed, not DesignLibrary's second case (disabled), which AppKit has no
    /// value for.
    _NSGlassEffectViewInteractionStatePressed = 1,
    /// The hover state — what the window tab bar sets under the pointer.
    _NSGlassEffectViewInteractionStateRollover = 2,
};

/// Whether to force DesignLibrary's subdued look — the one DesignLibrary's own types tie to an
/// inactive window. Only 1 does anything; every other value behaves like 0, and there is no value
/// that forces the look off.
typedef NS_ENUM(NSInteger, _NSGlassEffectViewSubduedState) {
    /// The initial value: nothing is forced.
    _NSGlassEffectViewSubduedStateAutomatic = 0,
    /// Adds DesignLibrary's `forceSubdued` option. Toolbar platters in the customization panel use it.
    _NSGlassEffectViewSubduedStateSubdued = 1,
};

/// Whether to force DesignLibrary's scrim material. Only 1 does anything; every other value behaves
/// like 0. Nothing in macOS 26.6 or 27.0 sets it.
typedef NS_ENUM(NSInteger, _NSGlassEffectViewScrimState) {
    /// The initial value: nothing is forced.
    _NSGlassEffectViewScrimStateAutomatic = 0,
    /// Adds DesignLibrary's `forceScrim` option.
    _NSGlassEffectViewScrimStateScrim = 1,
};

/// Whether the glass lenses the content behind it. Only 2 does anything; 0 and 1 behave
/// identically, so their names are a guess, modelled on `_NSGlassEffectViewAdaptiveAppearance`. Any
/// other value is ignored. AppKit itself only ever writes 1, so it never turns lensing on.
typedef NS_ENUM(NSInteger, _NSGlassEffectViewContentLensing) {
    /// The initial value.
    _NSGlassEffectViewContentLensingAutomatic = 0,
    /// What the window tab bar writes on its tabs.
    _NSGlassEffectViewContentLensingOff = 1,
    /// Asks DesignLibrary for its `lense` content effect.
    _NSGlassEffectViewContentLensingOn = 2,
};

/// Whether the glass adapts its light or dark appearance to the luminance of what is behind it.
/// It has nothing to do with the window's key state. **These three names are AppKit's own:**
/// `-[NSGlassEffectView _adaptationDebugDescription]` prints them. Any other value terminates the
/// process inside the setter.
typedef NS_ENUM(NSInteger, _NSGlassEffectViewAdaptiveAppearance) {
    /// Renders exactly like on; only the debug description tells them apart.
    _NSGlassEffectViewAdaptiveAppearanceAutomatic = 0,
    /// No adaptation, and the content's appearance is left alone. The split view's sidebar and
    /// inspector glass, popovers and menus all use it.
    _NSGlassEffectViewAdaptiveAppearanceOff = 1,
    /// The initial value. The glass follows the backdrop, and the content holder view is switched to
    /// the light or dark counterpart of its appearance along with it.
    _NSGlassEffectViewAdaptiveAppearanceOn = 2,
};

/// The private settings `NSGlassEffectView` (macOS 26+) forwards into the SwiftUI-hosted glass
/// renderer behind it. Every accessor here is a real Objective-C method on the class
/// (`_variant` / `set_variant:` and so on) — read off the macOS 27.0 AppKit binary, build
/// 2775.10.103.1, and present in the 26.4 – 26.6 header dumps as well. Setting one of the
/// enum-typed properties to a new value rebuilds the glass configuration synchronously. None of
/// these settings is archived: `-encodeWithCoder:` writes only the content view.
@interface NSGlassEffectView ()

/// The material recipe. The public `style` is a view of this value rather than separate storage:
/// setting `style` overwrites it, and `style` reads back whatever it implies.
@property (nonatomic) _NSGlassEffectViewVariant _variant;

/// A refinement of `_variant`; `nil` on the split view's glass.
@property (nonatomic, copy, nullable) _NSGlassEffectViewSubvariant _subvariant;

/// How the glass responds to the pointer. Values outside the enum terminate the process.
@property (nonatomic) _NSGlassEffectViewInteractionState _interactionState;

@property (nonatomic) _NSGlassEffectViewSubduedState _subduedState;

@property (nonatomic) _NSGlassEffectViewScrimState _scrimState;

@property (nonatomic) _NSGlassEffectViewContentLensing _contentLensing;

/// Light or dark adaptation to the backdrop — not key-state adaptation. AppKit sets
/// `_NSGlassEffectViewAdaptiveAppearanceOff` on the split view's glass. Values outside the enum
/// terminate the process.
@property (nonatomic) _NSGlassEffectViewAdaptiveAppearance _adaptiveAppearance;

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
