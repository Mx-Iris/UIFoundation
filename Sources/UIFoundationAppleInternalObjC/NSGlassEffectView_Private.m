#import <TargetConditionals.h>
#import "NSGlassEffectView_Private.h"

#if TARGET_OS_OSX && defined(__MAC_26_0) && __MAC_OS_X_VERSION_MAX_ALLOWED >= __MAC_26_0

// These constants are this library's, not AppKit's: AppKit exports no subvariant symbols, and its
// own code writes the literals. Each string is a name DesignLibrary's
// `GlassMaterialProvider.Subvariant.init(_:)` accepts on both macOS 26.6 and 27.0 — its
// `Subvariant.Kind` case names. `tab` and `menu` are the two AppKit itself passes
// (`-[NSTabBarViewButton setActive:]`, `-[NSContextMenuImpl loadView]`). See
// `Researchs/AppKit-NSGlassEffectView-PrivateConfiguration.md`.
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantTab = @"tab";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantMenu = @"menu";

_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantLockscreenControls = @"lockscreenControls";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantLockscreenNotifications = @"lockscreenNotifications";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenClose = @"homescreenClose";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCamera = @"camera";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantPosterSwitcher = @"posterSwitcher";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenResizeHandle = @"homescreenResizeHandle";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCursorAccessory = @"cursorAccessory";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenFolder = @"homescreenFolder";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantFocusedButtonFill = @"focusedButtonFill";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantEntryField = @"entryField";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantVolumeSlider = @"volumeSlider";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCustomizeSheet = @"customizeSheet";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFacePhotos = @"watchFacePhotos";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFacePhotosMini = @"watchFacePhotosMini";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFaceFlowStencil = @"watchFaceFlowStencil";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchFaceFlowSolid = @"watchFaceFlowSolid";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchPasscode = @"watchPasscode";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantHomescreenAppLibraryPod = @"homescreenAppLibraryPod";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchSmartStack = @"watchSmartStack";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchSmartStackAnimatedContent = @"watchSmartStackAnimatedContent";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantSiriSnippet = @"siriSnippet";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantAlarmSlider = @"alarmSlider";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantMapsSign = @"mapsSign";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantSheet = @"sheet";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantMessagesTapback = @"messagesTapback";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantCluster = @"cluster";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantSecondaryCluster = @"secondaryCluster";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantWatchDetuned = @"watchDetuned";
_NSGlassEffectViewSubvariant const _NSGlassEffectViewSubvariantTVPortraitClock = @"tvPortraitClock";

#endif
