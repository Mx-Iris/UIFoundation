# AppKit NSGlassEffectView Private Configuration

> Based on reverse engineering macOS 27.0 (26A428) AppKit 2775.10.103.1 (arm64e) via IDA Pro
> decompilation of AppKit extracted from `dyld_shared_cache_arm64e`, cross-checked against macOS 26.6
> (AppKit 2685.70.101), DesignLibrary's Swift metadata (`swift-section`), and the RuntimeViewer dumps
> under `/Volumes/DyldSharedCaches/macOS/{27.0,26.6}/`. The archived 27.0 cache is the running OS's
> (same UUID). The results are declared in
> `Sources/UIFoundationAppleInternalObjC/include/NSGlassEffectView_Private.h`.

## 1. The question

`NSGlassEffectView` (macOS 26+) has seven private settings that change how its glass renders:
`_variant`, `_subvariant`, `_interactionState`, `_subduedState`, `_scrimState`, `_contentLensing`
and `_adaptiveAppearance`. AppKit's own Swift code types them as imported C types — the RuntimeViewer
dump of `__C.NSGlassEffectView+Extension.swiftinterface` reads `var _variant:
__C._NSGlassEffectViewVariant`, `var _subvariant: __C._NSGlassEffectViewSubvariant?`, and so on — but
the macOS SDK declares none of them. This report records what every value does, where each name in
the header comes from, and what could not be recovered.

## 2. Where the names come from

### 2.1 Type names survive; constant names do not

The type names are in AppKit's Swift symbols. The `_variant` setter is
`$sSo17NSGlassEffectViewC6AppKitE8_variantSo01_abC7VariantVvs`, which demangles to a
`__C._NSGlassEffectViewVariant`. The subvariant getter in the SDK's `AppKit.tbd` is
`$sSo17NSGlassEffectViewC6AppKitE11_subvariantSo01_abC10SubvariantaSgvg`. Its trailing `a` marks a
Clang typedef promoted to a Swift nominal type, which only `NS_TYPED_ENUM` /
`NS_TYPED_EXTENSIBLE_ENUM` produce; which of the two it is cannot be told from the binary.

Constant names are another matter. C enum constants never reach a binary, and no image in either
cache carries a symbol or string containing `GlassEffectViewVariant` or `GlassEffectViewSubvariant`
beyond the Swift type names — exported, local, or in the SDK's `.tbd` files.

What does reach the binary is how AppKit consumes each value. `NSGlassEffectView` is written in
Swift (`@objc @implementation`), and one function, the configuration builder, turns every setting into
a `DesignLibrary.GlassMaterialProvider.Configuration` (DesignLibrary is the private framework that
defines the system's glass materials):

| macOS | Configuration builder | Integer-property setter helper | `-initWithFrame:` body |
|---|---|---|---|
| 27.0 | `0x185DDA3D4` | `0x185DDC748` | `0x185DDBB04` |
| 26.6 | `0x184E1852C` | `0x184E1A910` | `0x184E19B4C` |

The setter helper stores the new value, returns if it equals the old one, and otherwise sends
`setNeedsLayout:` to the view and its enclosing container and rebuilds the configuration on the spot.
So a value the builder rejects is rejected inside the setter call.

Each constant in the header is named after what the builder does with its value — usually the
DesignLibrary API it calls. The one exception is `_NSGlassEffectViewAdaptiveAppearance`, whose names
AppKit prints itself (section 3.7).

### 2.2 Could AppKit use named constants that the compiler folded away?

AppKit's Objective-C code passes the subvariants as literals: `-[NSTabBarViewButton setActive:]`
materialises `"tab"` with `ADRL X8, cfstr_Tab_0` (`0x185A90E30`). Three spellings of a named constant
would compile to that same instruction, and two of them leave no trace at all:

- **A macro** (`#define _NSGlassEffectViewSubvariantTab @"tab"`) is gone before the compiler runs.
- **A `static` constant in a header** (`static NSString *const … = @"tab";`) has a known initialiser
  in every translation unit, so the compiler folds every load into the literal.
- **An `extern` constant** is the one that would survive — and it does not match what AppKit does
  with its own. AppKit loads its exported string constants through the global: `NSAppearanceNameAqua`
  (`0x1E06E5888`) and `NSAppearanceNameDarkAqua` (`0x1E06E58D8`) each have more than 40 `ADRP`/`LDR`
  data references from AppKit code (`-[NSSystemAppearanceProxy init]`, `-[NSView _setSuperview:]`,
  …), so the build does not fold extern constants into their literals. An extern `"tab"` would have
  been loaded the same way.

The Swift side agrees. `_NSSuggestionsMenuWindowController` gets its `"menu"` from a lazily
initialised global: `sub_185DD79CC` bridges the small-string immediate `0x756E656D` ("menu") to an
`NSString` and stores it into `qword_1E45759A8` — the shape of a Swift `static let` of the typed
struct. Had an importable Objective-C constant existed, the Swift code would have referenced it
rather than rebuilt it. That constant's own name is a stripped local symbol.

So if Apple's private header names these strings, it does so with macros or header-level statics,
and those names are unrecoverable from any binary. There are no symbols to link against either.
The constants this project's header declares are therefore the library's own, defined in
`NSGlassEffectView_Private.m`: one for each of the 31 names DesignLibrary accepts on both macOS 26.6
and 27.0, `_NSGlassEffectViewSubvariantTab` and `…Menu` among them. **Apple's implementation has
nothing of the kind**, and the header says so.

## 3. The seven settings

### 3.1 `_variant` — `_NSGlassEffectViewVariant`

The builder hands the value to one `switch` (27.0 `0x185DD7534`, 26.6 `0x184E165B4`): a 21-slot
jump table (`CMP X0, #0x14` / `B.HI default` — an unsigned compare, so negatives take the default
branch too) whose slots tail-call one static getter each on `GlassMaterialProvider.Configuration`. The
getter's name is the only name a value has. On 27.0 all twenty targets were checked beyond IDA's
stub names: each stub's GOT slot holds exactly the getter address `swift-section` reads out of
DesignLibrary's metadata. The 26.6 table is identical.

| Value | DesignLibrary configuration | AppKit's own use (27.0 addresses) |
|---|---|---|
| 0 | — (default branch, renders `regular`) | `-initWithFrame:` stores it; the three `_glassVariant` methods below return it when nothing special applies |
| 1 | `regular` | the public `style` setter, for `.regular`; the selected window tab |
| 2 | `clear` | the public `style` setter, for `.clear` |
| 3 | `dock` | |
| 4 | `appIcons` | |
| 5 | `widgets` | |
| 6 | `text` | |
| 7 | `avplayer` | `-[NSToolbarView _glassVariant]` (`0x1858F7ACC`), while the toolbar's `_forceAVPlayerGlassVariant` is set |
| 8 | `facetime` | |
| 9 | `controlCenter` | |
| 10 | `notificationCenter` | |
| 11 | `monogram` | |
| 12 | `bubbles` | |
| 13 | `identity` | every window tab that is not selected (`-[NSTabBarViewButton setActive:]`, `0x185A90DC4`); on 27.0 also substituted for `_variant` while an `Int` AppKit reads from an associated object on the view is above zero (`0x185DD73C4`) |
| 14 | `focusBorder` | |
| 15 | `keyboard` | |
| 16 | `sidebar` | |
| 17 | `abuttedSidebar` | `-[_NSSplitViewItemViewWrapper _glassVariant]` (`0x185A836E8`), for a sidebar item |
| 18 | `inspector` | the same method, for an inspector item |
| 19 | `loupe` | |
| 20 | `cartouchePopover` | `-[NSPopoverFrame _glassVariant]` (`0x185BEC908`), when the popover has an anchor edge |
| > 20, < 0 | — (default branch, renders `regular`) | |

`-[NSToolbarView _glassVariant]` is a direct method, so the RuntimeViewer dump does not list it and
its address comes from the symbol table. `-initWithFrame:` comes from the class's Objective-C method
list, because the dump strips constructors.

- **The split view's sidebar glass is not the one called `sidebar`.** That is 16; the split view
  asks for 17, `abuttedSidebar`.
- **`style` is a view of `_variant`, not storage of its own.** `style.getter` (`0x185DDC5FC`) is
  `_variant == 2`; `style.setter` (`0x185DDC640`) writes 1 for `.regular`, 2 for `.clear`, and
  nothing for any other value — the same on 26.6. Assigning `_variant` after `style`, which is what
  `matchGlassConfiguration(of:)` does, leaves `style` reading whatever the variant implies.
- **0 and 1 render the same but are not the same value.** A new view holds 0; only an explicit
  `style = .regular` stores 1.
- **Why these names are probably Apple's too.** DesignLibrary's own list,
  `GlassMaterialProvider.Configuration.Base`, is longer, but its cases without a payload run in the
  same order as the C values, minus `control`, `slider` and `camera`, which the C enum skips. It
  continues past `cartouchePopover` with `menu`, `siriSnippet`, `siri` and `carplayUltra`, and its
  payload cases are `text`, `focusBorder`, `vibrantFill` and `mix`. None of the extra ones is
  reachable through `_variant`. The order match suggests the C enum was written from this list; it
  remains an inference.
- **Identity still carries the interaction state.** On 26.6, `layout()` special-cases
  `_variant == 13 && _interactionState == 0` into a glass-less root state (`0x184E1D390`). On 27.0
  that state became `materialEffectDisabled(interactionState:path:)`, chosen when
  `sub_185DD73C4() > 0 || _variant == 13`. Reading this as "a hover or press fill without glass" is
  an inference; AppKit has a `GlassInteractionFill` view that fits it.

### 3.2 `_subvariant` — `_NSGlassEffectViewSubvariant` (string)

AppKit recognises no names itself. The builder skips `nil` (27.0 `CBZ X0` at `0x185DDA944`) and
otherwise passes the string through the converter (27.0 `sub_185DD75B0`, 26.6 `sub_184E16630`) to
DesignLibrary's `GlassMaterialProvider.Subvariant.init(_: String) -> Subvariant?` (27.0 `0x23F4A5DCC`,
reached through the stub at `0x1880FB1B0`). That initialiser is a string `switch`, and the strings it
accepts are exactly the case names of `Subvariant.Kind` except `default`.

The DesignLibrary side was read with `ipsw`'s disassembler: there is no DesignLibrary IDA database.
The accepted set matches the `Kind` case names in the Swift metadata one for one.

- **Accepted on 27.0 (48):** `lockscreenControls`, `lockscreenNotifications`, `homescreenClose`,
  `camera`, `posterSwitcher`, `homescreenResizeHandle`, `cursorAccessory`, `transientCanvas`,
  `listening`, `thinking`, `response`, `spotlightField`, `searchResults`, `homescreenFolder`, `tab`,
  `focusedButtonFill`, `entryField`, `volumeSlider`, `customizeSheet`, `watchFacePhotos`,
  `watchFacePhotosMini`, `watchFaceFlowStencil`, `watchFaceFlowSolid`, `watchPasscode`,
  `homescreenAppLibraryPod`, `menu`, `watchSmartStack`, `watchSmartStackFace`,
  `watchSmartStackAnimatedContent`, `siriSnippet`, `alarmSlider`, `alarmSliderRed`,
  `contactsQuickAction`, `mapsSign`, `mapsNavigationSign`, `sheet`, `messagesTapback`, `cluster`,
  `secondaryCluster`, `dock`, `appSwitcher`, `watchDetuned`, `homeModularFace`, `homeFaceFlow`,
  `tvPortraitClock`, `hdr`, `campoCard`, `homeLiveActivity`.
- **On 26.6 (33):** 31 of the above, plus `track` and `iOSNotificationCenter`. Absent on 26.6:
  `transientCanvas`, `listening`, `thinking`, `response`, `spotlightField`, `searchResults`,
  `watchSmartStackFace`, `alarmSliderRed`, `contactsQuickAction`, `mapsNavigationSign`, `dock`,
  `appSwitcher`, `homeModularFace`, `homeFaceFlow`, `hdr`, `campoCard` and `homeLiveActivity`.
- **The 31 both releases accept** are the ones the header gives a constant (section 2.2). The
  intersection was taken from the two releases' `Kind` metadata and agrees with the strings the two
  initialisers compare against; the longest names were also found as C strings in both builds'
  DesignLibrary.

`nil` leaves the configuration's preset in place (`Kind.default`, written by DesignLibrary's shared
initialiser). An unknown name — `"default"` included — returns `nil` on customer installs, so it
also changes nothing. On a 27.0 internal install it becomes `.unsupported(UnsupportedID)` instead,
with an `os_log` fault logged once per name: `unsupported subvariant "%s" requested`. The setter's
observer (27.0 `sub_185DDC420`) ignores a value equal to the current one.

| Who sets it (27.0) | Address | Value |
|---|---|---|
| `-[NSTabBarViewButton setActive:]`, Solarium tabs only | `0x185A90DC4` | selected: `_variant` 1 + `"tab"`; not selected: `_variant` 13 + `nil` |
| `-[NSContextMenuImpl loadView]`, `-viewWillAppear` | `0x18546691C`, `0x18546709C` | `"menu"` |
| `-[NSPopupMenuWindow initWithContextMenuImpl:]` | `0x18558DF08` | `"menu"` |
| `_NSSuggestionsMenuWindowController.windowDidLoad` | `sub_185FA0A74` | `"menu"`, from the Swift global in section 2.2 |
| `-[NSTabButton tabImageOfSize:]` | `0x185C217D4` | copies the tab glass's value onto the drag image's glass |

On 26.6 the window tab bar's track glass also set `"track"` (`sub_184F7A52C`). On 27.0 the track
draws with `NSSubduedGlassEffectView`, which is now an `NSView` subclass, and `"track"` no longer
exists. Outside AppKit, the 26.6 Safari image carries the `set_subvariant:` selector; it was not
examined.

### 3.3 `_interactionState` — `_NSGlassEffectViewInteractionState`

The builder compares the value unsigned against 3 (27.0 `CMP X0, #3; B.CS` at `0x185DDAA28`). Any
larger value, negatives included, goes to `_assertionFailure("Fatal error", …,
"AppKit/NSGlassEffectView.swift", 49)` — line 35 on 26.6. Otherwise it indexes the table
`off_1E06E6248` (26.6 `off_1E6675328`) and injects the enum case it finds into a
`DesignLibrary.InteractionState` through the value-witness slot at `+0x68`,
`destructiveInjectEnumTag` (ptrauth discriminator `0xB2E4`). The three table entries are
DesignLibrary's own case-tag symbols, which settles the mapping:

| Value | Table entry (27.0) | DesignLibrary case (its tag) | Who sets it |
|---|---|---|---|
| 0 | `$s13DesignLibrary16InteractionStateO4idleyA2CmFWC` (`0x23F5FD894`) | `idle` (0) | the initial value |
| 1 | `…O7pressedyA2CmFWC` (`0x23F5FD8A0`) | `pressed` (3) | `_NSCampoTextFormattingBackgroundView`, pressed state (27.0 only) |
| 2 | `…O8rolloveryA2CmFWC` (`0x23F5FD89C`) | `rollover` (2) | `-[NSTabBarViewButton setHasMouseOverHighlight:animated:]` (`0x185A91378`) under the pointer; the Campo background when hovered |

- **AppKit's numbering is not DesignLibrary's declaration order.** DesignLibrary declares `idle`,
  `disabled`, `rollover`, `pressed`, `deeplyPressed` (tags 0–4); AppKit exposes three of them, and 1
  means `pressed`. `disabled` and `deeplyPressed` have no value.
- **The same check guards every other reader,** with the same trap line: `layout()`, the container
  view's `layout()` (which preloads `rollover` / `pressed` / `idle` from their GOT slots), and the
  per-child state builder.
- **`SwiftUI.PlatformGlassInteractionState` is unrelated.** It is the press-deformation geometry
  (`scale`, `translation`, `isActive`), which belongs with `_flexInteractionDirectGestureState`.

### 3.4 `_subduedState` — `_NSGlassEffectViewSubduedState`

Only 1 does anything: the builder compares against 1 (27.0 `0x185DDABD8`, 26.6 `0x184E18CB4`) and
inserts `GlassMaterialProvider.Options.forceSubdued` (bit `0x40`). Every other value renders like 0;
nothing traps. No reader anywhere tells 0 from 2, so the "0 automatic / 1 on / 2 off" shape the
adaptive appearance has does not apply. DesignLibrary does have the opposite switch,
`Options.forceActiveAppearance` (`0x10000000`), but AppKit never sets it from this property.

What "subdued" means comes from DesignLibrary's type names only: `InactiveCondition { subdued: Bool }`,
`ApplyLegacySubvariant.remapSubduedToInactive` and `RegularRecipe.Inactive` tie it to the look of an
inactive window. Its code was not traced.

Who sets it, every writer passing 0 or 1:

- **Toolbar platters (27.0).** `_NSToolbarConfigurePlattersOnItems` (`0x185B08400`) creates each
  platter with `setSubduedState:` set to `-[NSToolbarView _inConfigPanel]`, so only the customization
  panel's platters are subdued. It reuses a platter only when `subduedState` and `variant` both match.
  `-[NSToolbarPlatterView setSubduedState:]` (`0x185B09AD8`) forwards to its glass view. On 26.6 the
  same logic is the method `-[NSToolbarView _configurePlattersOnItems:reusablePlatters:]`, driven by
  `_isPaletteView`.
- **Campo text-formatting background (27.0 only):** `sub_18609A9C0` writes 0 in a key window,
  otherwise `!prefersActiveAppearance`.
- **26.6 only:** `-[NSToolbarCollectionViewItem loadView]` (1, for the customization palette's items)
  and the window tab bar's track glass (1).
- **Outside AppKit:** AVKit and AVKitMacHelper,
  `-[AVControlsContainerViewController _updateGlassContainerSubduedStateIfNeeded]`, which writes
  `!_isViewOccupyingFullWindow`.

### 3.5 `_scrimState` — `_NSGlassEffectViewScrimState`

The same shape as the subdued state: only 1 does anything, adding `Options.forceScrim` (bit `0x20`;
27.0 `CMP X0, #1` at `0x185DDAC68`, 26.6 `0x184E18D38`). The two options are independent, so both
can be forced at once. **Nothing in either build sets it.** In the whole 27.0 cache the only code
sending `set_scrimState:` is the property's exported key-path accessor. DesignLibrary has a `scrim`
case in `ResolvedConfiguration.Base` and a `ScrimRecipe`, so forcing it likely swaps the glass for
a scrim material; that is inferred from names, not traced.

### 3.6 `_contentLensing` — `_NSGlassEffectViewContentLensing`

Only 2 does anything. On 27.0 the builder's `CMP X0, #2; B.NE` (`0x185DDAA70`) asks for
`GlassMaterialProvider.ContentEffect.lense` and applies it with `Configuration.contentEffect(_:)`; on
26.6 (`0x184E18BA4`) it inserts `Options.contentLensing` instead. 0, 1 and every other value request
nothing, and nothing traps. The content holder, the portal layer and the clip predicate never read
the value.

**AppKit itself only ever writes 1**, so it never turns lensing on. The window tab bar's
`-[NSTabBarViewButton _makeTabButtonGlassView]` writes 1 (27.0 `0x185A90A94`, 26.6 `0x185860EA8`),
and so did 26.6's tab track glass. Because 0 and 1 behave identically, their names cannot come from
behaviour; the header models them on the adaptive appearance (`automatic` / `off` / `on`).
Everywhere else in the system, lensing is a plain `Bool`: `_UIViewGlass.contentLensing` and
SwiftUI's `contentLensing(_:)`.

### 3.7 `_adaptiveAppearance` — `_NSGlassEffectViewAdaptiveAppearance`

**The names are AppKit's own.** `-[NSGlassEffectView _adaptationDebugDescription]` (27.0 IMP
`0x185DE6658` → `sub_185DE66C4`; 26.6 `0x184E1F238`) prints ` adaptiveAppearance=` followed by:

```
CMP X0, #2 → B.EQ   "on"         (MOV W8, #0x6E6F,      length 2)
CMP X0, #1 → B.EQ   "off"        (MOV W8, #0x66666F,    length 3)
CBNZ X0    → …      "unknown(" + value + ")"
fall through        "automatic"  (MOV X8, #0x6974616D6F747561 + 'c', length 9)
```

| Value | AppKit's name | What the builder does | What happens to the content |
|---|---|---|---|
| 0 | `automatic` | exactly what it does for 2 | exactly what happens for 2 |
| 1 | `off` | `Configuration.adaptive(false)` (`0x185DDADC0`); the colour-scheme and animatable steps are skipped | the content holder view's `appearance` is set to `nil` (`0x185DD9DA4`) |
| 2 | `on` — the initial value | `adaptive(true)` (`0x185DDAE00`), then `adaptive(colorScheme:)` from `effectiveAppearance` when there is a material backdrop context, and `adaptive(animatable: false)` when that context has appearance animations disabled | the content holder view gets the light or dark counterpart of its appearance, with a `CATransition` when animations are on |

- **Out-of-range values trap.** Anything else hits `fatalError` in the builder (line 736; 424 on
  26.6), and the content colour-scheme handler (27.0 `sub_185DD9B5C`) traps the same way.
- **It is not about key state.** No reader touches the window's key state. DesignLibrary's
  vocabulary for it is luminance and colour scheme:
  `HysteresisRange.modifyColorScheme(_:context: (luminance, colorScheme))`,
  `State.adaptedColorScheme`, `adaptiveLuminance(initial:/fixed:)`. The glass decides light or dark
  from what is behind it. This project's header used to describe it as key-state adaptation, which
  was wrong.
- **Nothing tells 0 from 2 except the debug description.** The glass-effect container's per-glass
  identity (`sub_185DE7BD0`) collapses them before anything downstream sees them: `0x100 >> (8 * v)`
  maps 0 and 2 to `.automatic` and 1 to `.off`.
- **Who sets it — every writer passes 1** (27.0 call sites):
  - `-[_NSSplitViewItemViewWrapper wrapView]` (`0x184F71B70`)
  - `-[NSPopoverFrame _commonPopoverInit]` (`0x185103678`)
  - `-[NSContextMenuImpl loadView]` and `-viewWillAppear` (`0x185466BE4`, `0x1854671F4`)
  - `-[NSPopupMenuWindow initWithContextMenuImpl:]` (`0x18558E21C`)
  - `-[NSThemeFrame _updateContentContainerView]` (`0x1858919A4`)
  - the text-suggestions window (`0x185FA0C6C`)

  The one writer of 2 was 26.6's tab track glass.

## 4. Initial values and out-of-range values

All seven are initialised by both `-initWithFrame:` and `-initWithCoder:`, and none is archived:
`encode(with:)` writes only `"ContentView"`.

| Setting | Initial value | Outside the declared values |
|---|---|---|
| `_variant` | 0 | falls through to `regular` |
| `_subvariant` | `nil` | an unknown name changes nothing (27.0 internal installs log a fault) |
| `_interactionState` | 0 (`idle`) | **terminates the process** inside the setter |
| `_subduedState` | 0 | ignored |
| `_scrimState` | 0 | ignored |
| `_contentLensing` | 0 | ignored |
| `_adaptiveAppearance` | 2 (`on`) | **terminates the process** inside the setter |

The rest of the initialiser, for reference (27.0 `0x185DDBB04`): `_tintOpacityReduced`,
`_useReducedShadowRadius`, `_inverseMeshed` and `effectIsInteractive` start `false`,
`___flexInteractionSources` starts at 3, and the corner radius at 8.

## 5. macOS 26.6 against 27.0

- **Unchanged:** every numeric mapping (variant, interaction state, subdued, scrim, lensing and
  adaptive appearance), the valid ranges, the `style` ↔ `_variant` relationship, and the setter
  behaviour. Only the `fatalError` line numbers moved.
- **Content lensing** changed mechanism, not meaning: `Options.contentLensing` became
  `ContentEffect.lense`.
- **Subvariants:** `Subvariant.Kind` grew from 34 cases to 50, gained the `unsupported` payload case
  and the internal-install fault, lost `track` and `iOSNotificationCenter`, and gained 17 names.
- **Writers:** 27.0 added the context menu's `"menu"` subvariant and its `-viewWillAppear` writer
  (its `-loadView` already set the adaptive appearance on 26.6), and the suggestions-window, Campo and
  tab-drag-image writers. The 26.6 tab track glass (variant 1, `"track"`, subdued 1, lensing 1,
  adaptive 2) is gone, replaced by `NSSubduedGlassEffectView`.
- **Identity override:** the associated-object check that forces variant 13 exists only on 27.0.

## 6. Consequences for this project

- **`NSGlassEffectView_Private.h` now types all seven settings.** The enum names are ours except
  the adaptive appearance's. `_NSGlassEffectViewSubvariant` is declared `NS_TYPED_EXTENSIBLE_ENUM`,
  since any string can be passed and the accepted set changes between releases. Its 31 constants —
  one per name both releases accept — are defined by the library itself (section 2.2); AppKit has
  none.
- **Two values can crash a caller.** An out-of-range `_interactionState` or `_adaptiveAppearance`
  terminates the process inside the setter; every other setting tolerates any value.
- **The window tab bar port in `TabBar+SystemDecoration.swift`** has three findings, none acted on
  in this batch:
  - It turns lensing "on" through a `Bool` path, which stores 1 and so turns nothing on — exactly
    what AppKit does for its own tabs.
  - That path passes a C `Bool` where the method takes an `NSInteger`, and the callee stores the
    whole register, so the upper bits are not guaranteed.
  - It calls `_variant` 13 "frosted"; 13 is `identity`, the glass-less look.
- **`GlassEffectReplicaView` is unaffected.** It copies the values off a live glass and never names
  one.

## 7. Still open

1. **What DesignLibrary renders** for each variant, subvariant, subdued, scrim and lensing state.
   That is DesignLibrary's code (`GlassRecipes`, `ApplyLegacySubvariant`, `ScrimRecipe`), which an
   AppKit-only database cannot show. Closing it needs a DesignLibrary IDA database, or a runtime
   comparison of the values side by side.
2. **What `sub_185DD73C4` counts**, the associated-object value that forces `identity` on 27.0.
3. **Who uses the key-path accessor thunks** of these properties (27.0 around `0x1852302F0`–`0x185230478`).
   Key-path patterns point at them through relative offsets that IDA does not cross-reference.
4. **Senders outside AppKit.** Safari on 26.6 carries the `set_subvariant:` selector, and AVKit's
   26.6 subdued writers were not traced.

## 8. Method notes

- **Addresses** come from the RuntimeViewer dumps; from `ipsw class-dump … --re -V` for initialisers,
  which the dump strips; and from the symbol table for direct methods. Every function a conclusion
  rests on was disassembled in IDA, on private copies of the archived `AppKit.i64` databases.
- **Cross-image calls go through stubs whose GOT slots name the callee.** Reading those slots and
  matching them against `swift-section`'s DesignLibrary addresses is how the variant table and the
  subvariant converter were confirmed.
- **Selector stubs can live outside the image.** Several `objc_msgSend$…` stubs AppKit calls sit in
  the cache-wide stub region (27.0 `set_subvariant:` at `0x1880AF030`), not at the address in
  AppKit's own symbol table. `ipsw dyld xref` does not follow stub islands, so an empty result from
  it proves nothing.
- **Swift literals of up to 15 bytes are instruction immediates** (`MOV`/`MOVK` pairs, with the
  length in the top byte of the second word). A `strings` search misses every name above that is
  that short — which is most of them.
