# AppKit and UIKit Notification Message Internals

> Static analysis: the macOS 27.0 (26A428) dyld shared cache for arm64e
> (`/Volumes/DyldSharedCaches/macOS/27.0/dyld_shared_cache_arm64e`, cache UUID
> `ea2c265e297c39c286467d8a2dff648a`): AppKit 2775.10.103.1 and the Mac Catalyst build of UIKitCore
> 9127.0.84, IDA Pro decompilation and disassembly. Every address below is a slid address in that
> cache, as the IDA databases show it, and is valid for this build only.
>
> Behaviour stated as measured — section 6 and the findings that cite it — was run on macOS 27.0
> (26A428): AppKit in this library's `swift test` process, which has no `NSApplication` instance, or
> in a standalone probe; UIKit in the Mac Catalyst test run.
>
> **Why this report exists.** AppKit (macOS 27 SDK) and UIKit (iOS 26 SDK onwards) declare typed
> notification messages: `NotificationCenter.MainActorMessage` and `AsyncMessage` conformers such as
> `NSWindow.DidBecomeKeyMessage`, observed through identifiers such as `.didBecomeKey`. Three
> requirements decide what a message does. `static var name` is the notification's name.
> `static func makeMessage(_ notification: Notification) -> Self?` decodes a posted notification; a
> `nil` result means the observer is not called. `static func makeNotification(_ message: Self) ->
> Notification` encodes a message for posting. The public `.swiftinterface` does not say which
> implementation 88 of AppKit's messages use, and for none of them does it say what is read, cast or
> written. This library backports all 137 AppKit messages and 71 of UIKit's 73 onto older systems as
> `<Subject>.Backport.<Name>Message`, on top of FrameworkToolbox's `NotificationCenter.Backport`, and
> reproduces Apple's behaviour exactly. This report records what Apple's binaries do. The code is in
> `Sources/UIFoundationToolbox/AppKit/NotificationMessages/`,
> `Sources/UIFoundationToolbox/UIKit/NotificationMessages/` and
> `Sources/UIFoundationToolbox/Shared/NotificationMessages.swift`. The two UIKit messages left out,
> `UIDocument.DidMoveToWritableLocationMessage` (an `AsyncMessage`) and
> `UIApplication.SystemPrefersReducedResourceUsageDidChangeMessage`, were not analysed: their
> notifications exist only from iOS 26 and iOS 27 respectively, where UIKit's own messages are
> available too.

---

## 1. Builds and method

| Binary | Version | Database | Identity checks |
|---|---|---|---|
| AppKit | 2775.10.103.1 | `/Volumes/DyldSharedCaches/macOS/27.0/AppKit-20261002.i64` (IDA session `appkit-messages`) | Mach-O UUID `2688AFBC-5C39-3132-BCF5-8D00D32D7615`, from the RuntimeViewer export of the same cache. Every public symbol address in that export is a function start in the database with the same Swift symbol (for example `NSTableView.ColumnDidMoveMessage.makeMessage` at `0x186069BEC` in both). |
| UIKitCore, Mac Catalyst | 9127.0.84 | IDA session `uikit-messages`: UIKitCore together with Foundation, CoreFoundation, CoreUI, FocusEngine and BaseBoard from the same cache | Image base `0x1BC90D000`. Every SDK constant was matched against UIKitCore's export trie (`dyld_info -exports`), and the CFString it points at was read out of the database. |

**Finding the witnesses.** `swift-section dump --emit-pwt-addresses --sections protocolConformances`
lists every protocol conformance in an image with the addresses in its witness table. Each message has
a block for its `NotificationCenter.MainActorMessage` or `AsyncMessage` conformance, with four
entries in this order:

| Entry | Requirement |
|---|---|
| 0 | associated type `Subject` (a mangled-name reference, not followed) |
| 1 | the `name` getter |
| 2 | `makeMessage(_:)` |
| 3 | `makeNotification(_:)` |

Each entry's `// Address:` line is the witness. The `sub_…` line printed under it names something
else and was ignored. A message that also conforms to an internal protocol has a second block, such
as `…DidBecomeKeyMessage: AppKit.StandardNSWindowMessage {`.

**Following them.** Every analysis started at a witness address and followed branches and calls from
there. IDA's search and listing tools were never used to locate an implementation. Witnesses are often
one-instruction thunks (`B sub_…`), and folded code serves several messages at once. Each message's own
chain was still followed, and each `name` getter was read on its own, because the constant differs per
message.

**Decompilation was always paired with disassembly, and the assembly won where they disagreed.** Two
places where it mattered:

- `NSWorkspace.DidRenameVolumeMessage.makeMessage` (`0x185E11688`). Hex-Rays folds the two URL
  temporaries into one variable, so `oldVolumeURL` seems to come from `volumeURL`'s buffer. The
  assembly keeps two buffers: X24 receives `volumeURL` (`initializeWithTake` at `0x185E11ADC`), X25
  receives `oldVolumeURL` (`0x185E11E3C`). Each field comes from its own key.
- `UIAccessibility.ElementFocusedMessage.makeMessage` (`0x1BE1A58F4`). The decompiler types the result
  as the `Bool` that `swift_dynamicCast` returns. The real result is the word stored at `0x1BE1A5A00`
  (`CSEL X8, castResult, XZR, NE; STR X8,[X19]`).

**Reading results, casts and literals.**

- `Optional<Self>` comes back through X8. For a message without properties it is one byte: `0` is
  `.some(Self())`, `1` is `nil`. For a struct whose first field is an object reference, a zero first
  word is `nil`.
- `swift_dynamicCast(dest, src, srcType: Any, targetType: T, flags: 6)` is a plain `as?` (flags 6:
  take on success, destroy on failure). `T` was read off its metadata: `$sSiN` is `Int`, `$sSbN`
  `Bool`, `$sSdN` `Double`, `$sSSN` `String`, a class accessor a class, and so on.
- A Swift string literal of up to 15 bytes is two 64-bit immediates, little-endian, with `0xE0 | count`
  in the top byte. `0x6C6F43646C4F534E` + `0xEB000000006E6D75` is `"NSOldColumn"`. Longer literals are
  references to string data; SDK constants are loads of their globals.
- Data addresses were named with `ipsw dyld a2s` against the cache file. Checked: `0x1E451D358`
  resolves to `_NSApplicationDidBecomeActiveNotification`, the symbol IDA shows there.
- The Swift spellings of AppKit's constants come from the macOS 27.0 SDK's `AppKit.apinotes`. The
  three unusual ones (section 5.11) were confirmed with a `swiftc -typecheck` probe against that SDK.

**Limits.** The witness-table slots of AppKit's internal protocols for the `name` getter and `init`
(for example `0x1E844A2B8` and `0x1E844A2C0`) both read `0x194EB8DC8`, an address the database does not
map, probably an unresolved fixup. Nothing here depends on them: the internal protocols were read
through the public conformance's witnesses and the bodies those reach, and field order was checked
against the `.swiftinterface`. Statements marked *inferred* follow from Swift's cast rules, the Swift
compiler and runtime sources, or a header comment, and were not executed.

## 2. Why the interface misleads

For 88 of AppKit's 137 messages, the macOS 27.0 SDK's `AppKit.swiftinterface` declares the struct and
an empty conformance, and nothing more (abridged):

```swift
extension NSWindow {
  public struct DidBecomeKeyMessage {
    public typealias Subject = NSWindow
    public static var name: Notification.Name { get }
    public var window: NSWindow
    public init(window: NSWindow)
  }
}
extension NSWindow.DidBecomeKeyMessage : NotificationCenter.MainActorMessage {}
```

Read on its own, that says Foundation's protocol defaults apply: `makeMessage` returns `nil` and
`makeNotification` returns `Notification(name: Self.name)`. A backport written that way compiles,
and its observers never run. In the binary, all 176 `makeMessage` and `makeNotification` witnesses of
those 88 messages land in AppKit's own code. Extensions of 17 internal protocols supply them, and the
interface never names those protocols:

| Internal protocol | Messages |
|---|---|
| `StandardNSWindowMessage` | 26 `NSWindow` |
| `StandardNSApplicationMessage` | 17 `NSApplication` |
| `StandardNSSpellCheckerMessage` | 8 `NSSpellChecker` |
| `StandardNSScrollViewMessage` | 5 `NSScrollView` |
| `SimpleNSComboBoxMessage` | 4 `NSComboBox` |
| `StandardNSMenuMessage` | 4 `NSMenu`: `DidBeginTracking`, `DidEndTracking`, `DidSendAction`, `WillSendAction` |
| `NSOutlineViewItemMessage` | 4 `NSOutlineView`: `ItemWillExpand`, `ItemDidExpand`, `ItemWillCollapse`, `ItemDidCollapse` |
| `NSControlFieldEditorMessage` | 3 `NSControl` |
| `NSMenuItemIndexMessage` | 3 `NSMenu`: `DidAddItem`, `DidChangeItem`, `DidRemoveItem` |
| `StandardNSOutlineViewMessage` | 2 `NSOutlineView`: `SelectionDidChange`, `SelectionIsChanging` |
| `StandardNSPopoverMessage` | 2 `NSPopover`: `WillShow`, `DidShow` |
| `NSPopoverCloseReasonMessage` | 2 `NSPopover`: `WillClose`, `DidClose` |
| `StandardNSTableViewMessage` | 2 `NSTableView`: `SelectionDidChange`, `SelectionIsChanging` |
| `StandardNSTextMessage` | 2 `NSTextView`: `DidBeginEditing`, `DidChange` |
| `StandardNSViewMessage` | 2 `NSView` |
| `StandardNSRuleEditorMessage` | 1 `NSRuleEditor` |
| `SimpleNSFontMessage` | 1 `NSFont` |

The other 49 AppKit messages declare `makeMessage` and `makeNotification` as public static functions,
and those are AppKit's own bodies too. **No AppKit witness is a Foundation default.** Foundation's
defaults are not `@inlinable` in the SDK's Foundation `.swiftinterface`, so a witness that used one
would be a thunk into Foundation's generic implementation, and none is. Four AppKit messages without
properties (`NSFont.FontSetChangedMessage`, `NSColor.SystemColorsDidChangeMessage`,
`NSScroller.PreferredScrollerStyleDidChangeMessage`,
`NSTextInputContext.KeyboardSelectionDidChangeMessage`) make a notification with no object and no user
info. That equals the default's result, but each comes from a self-contained AppKit body.

**Foundation's default is used in exactly one place: the `makeNotification` of UIKit's 35 messages
without properties.** Their witnesses are chains of one-instruction branches that end in Foundation's
generic `MainActorMessage.makeNotification(_:)` (section 3.4, S2). There the interface tells the
truth: UIKit declares `makeMessage` for these messages and no `makeNotification` (abridged):

```swift
public struct DidBecomeActiveMessage : NotificationCenter.MainActorMessage {
  public static var name: Notification.Name { get }
  public typealias Subject = UIApplication
  public init()
  @MainActor public static func makeMessage(_ notification: Notification) -> UIApplication.DidBecomeActiveMessage?
}
```

Every other UIKit witness is UIKit's own code.

So a message without properties still needs a `makeMessage` from somewhere. There are 75 of them
(40 in AppKit, `NSWorkspace`'s nine included, and 35 in UIKit), and on every one the protocol's default
would return `nil` and drop every notification the system posts.

## 3. Shared bodies

Section 4 refers to these by label: B1–B8 for AppKit's internal protocols, A-MM to E-MN for
`NSWorkspace`, HM-MN, SV-MM and SV-MN for AppKit's other explicit messages, and S1–S5, O1, N1, K1 and
K2 for UIKit.

### 3.1 AppKit: the 88 internal-protocol messages

What all 88 have in common:

- **`name` getter:** `ADRL X8, _<Constant>; LDR X0, [X8]; B objc_retain`, which returns the SDK
  global. `NSFont`'s goes through a GOT slot (section 5.10).
- **`makeMessage` witness:** `B <thunk>`, and the thunk is `PACIBSP; BL <body>; RETAB`. The body
  writes `Optional<Self>` through X8.
- **`makeNotification` witness:** `ADRL X3, _<Constant>; B <body>` for the messages without properties
  and with one subject. For the two-field messages it is a ten-instruction frame that loads both stored
  fields and calls `<body>(field0, field1, &_<Constant>)`; the `NSOutlineView` item witness passes the
  message's address in X0 and the constant's in X1. Either way the body dereferences the pointer for
  the name.
- **Casts:** `as?` throughout. Class metadata comes from a cached
  `swift_getObjCClassMetadata(objc_opt_self(classref))` (the generic helper `0x185CFAA80` or a
  per-class accessor). A `nil` `notification.object` is destroyed (`0x185CF115C`, `0x185D028D4`) and
  the body returns `nil` before any cast.
- **`object:`** in every `makeNotification` is the stored field, boxed with the field's static class:
  `object: message.<field>`.

**B1 — `makeMessage` without properties, `0x18522E5FC`.** `STRB WZR, [X8]; RET` writes tag byte 0,
`.some(Self())`. Nothing in the notification is read: not its name, object or user info.

```swift
static func makeMessage(_ notification: Notification) -> Self? { Self() }
```

The 17 `NSApplication` and 8 `NSSpellChecker` messages reach it through the thunk `0x185CF9B04`
(`B 0x18522E5FC`); `NSFont.FontSetChangedMessage`'s witness is `0x18522E5FC` itself. Outside the
internal protocols the same two instructions serve 14 more AppKit messages (sections 3.2 and 3.3), 40
in all.

**B2 — `NSApplication` `makeNotification`, `0x185E517D8`.**

```swift
Notification(name: name, object: NSApplication.shared, userInfo: nil)
```

`+[NSApplication sharedApplication]` is sent on every call (selector stub `0x1880305C0`), so it creates
the application object if none exists yet. The object is boxed as `NSApplication` (metadata accessor
`0x185E51970`).

**B3 — `NSSpellChecker` `makeNotification`, `0x185DA1194`.** The same with
`+[NSSpellChecker sharedSpellChecker]` (stub `0x1880AF810`, accessor `0x185DA129C`):
`object: NSSpellChecker.shared`, `userInfo: nil`.

**B4 — `NSFont` `makeNotification`, `0x185FC5EC4`** (the witness is the body). The name is loaded
through the GOT slot `0x1E0751550`. `object` is 32 zero bytes (`MOVI V0.2D,#0; STP Q0,Q0`) and the user
info is `nil`. The result equals `Notification(name: Self.name)`, but the code is AppKit's.

**B5 / B6 — one subject, which is the notification's object.**

```swift
static func makeMessage(_ notification: Notification) -> Self? {        // B5
    guard let window = notification.object as? NSWindow else { return nil }
    return Self(window: window)
}
static func makeNotification(_ message: Self) -> Notification {         // B6
    Notification(name: Self.name, object: message.window, userInfo: nil)
}
```

| Class | Messages | `makeMessage` witness → thunk → B5 body | B6 body |
|---|---|---|---|
| `NSWindow` | 26 | `0x1860B3454` → `0x18523BD04` → `0x1860B11C4` | `0x1860B12FC` |
| `NSScrollView` | 5 | `0x185D5ACC0` → `0x18522FAE4` → `0x185D5A6F8` | `0x185D5AB9C` |
| `NSComboBox` | 4 | `0x185F72CCC` → `0x185238C48` → `0x185F727E4` | `0x185F72BC0` |
| `NSMenu` | 4 | `0x1860E43A4` → `0x18523C7B4` → `0x1860E389C` | `0x1860E42A4` |
| `NSOutlineView` | 2 | `0x185DD6410` → `0x1852301E4` → `0x185DD4F08` | `0x185DD5D68` |
| `NSPopover` | 2 | `0x18605DEE8` → `0x18523AD64` → `0x18605D638` | `0x18605DA70` |
| `NSTableView` | 2 | `0x18606A71C` → `0x18523AF80` → `0x186069A04` | `0x18606A55C` |
| `NSText` | 2 | `0x185D5A6EC` → `0x18522FAC4` → `0x185D52B34` | `0x185D53900` |
| `NSView` | 2 | `0x18610F95C` → `0x18523CC0C` → `0x18610F680` | `0x18610F8CC` |
| `NSRuleEditor` | 1 | `0x186015A64` → `0x1860158EC` (a direct `B`, no thunk) | `0x186015A68` (the witness itself) |

`NSRuleEditor.RowsDidChangeMessage` is its protocol's only conformer, so its `makeNotification` witness
loads the constant itself instead of receiving it in X3. Its behaviour is the same as the others'.

**B7 / B8 — the subject plus one user-info entry.** All four `makeMessage` bodies work in this order:

1. `object as? <Class>`. On failure the result is `nil` and the user info is never read.
2. `notification.userInfo`. `nil` gives `nil`.
3. Look up the key. An empty dictionary or a missing key gives `nil` (the lookup is
   `_NativeDictionary<AnyHashable, Any>.find` at `0x185D1B540`; a hit is copied out with `0x185CFB7B8`).
4. The value step. A failed cast gives `nil`.
5. Store both fields.

The `makeNotification` bodies build a one-element `[(AnyHashable, Any)]` on the stack, turn it into
`[AnyHashable: Any]` with the dictionary-literal builder `0x185D581B8` (which traps on a duplicate key),
and pass the subject as `object`. The key is always written.

```swift
static func makeMessage(_ notification: Notification) -> Self? {        // B7
    guard let control = notification.object as? NSControl,
          let userInfo = notification.userInfo,
          let fieldEditor = userInfo["NSFieldEditor"] as? NSText
    else { return nil }
    return Self(control: control, fieldEditor: fieldEditor)
}
static func makeNotification(_ message: Self) -> Notification {         // B8
    Notification(name: Self.name, object: message.control, userInfo: ["NSFieldEditor": message.fieldEditor])
}
```

| Internal protocol | `makeMessage` witness → thunk → B7 body | Key | Value read | B8 body | Value written |
|---|---|---|---|---|---|
| `NSControlFieldEditorMessage` | `0x185F3BEBC` → `0x185236DE8` → `0x185F3B7E4` | `"NSFieldEditor"`, literal `0x45646C656946534E` / `0xED0000726F746964` | `as? NSText` | `0x185F3B9A8` | the `NSText` object |
| `NSMenuItemIndexMessage` | `0x1860E43A8` → `0x18523C7CC` → `0x1860E392C` | `"NSMenuItemIndex"`, literal `0x7449756E654D534E` / `0xEF7865646E496D65` | `as? Int` | `0x1860E3ACC` | Swift `Int`, not `NSNumber` |
| `NSOutlineViewItemMessage` | `0x185DD6414` → `0x1852301FC` → `0x185DD4FA8` | `"NSObject"`, literal `0x7463656A624F534E` / `0xE800000000000000` | none: the `Any` is moved into `item` | `0x185DD513C` | the stored `Any`, its dynamic type unchanged |
| `NSPopoverCloseReasonMessage` | `0x18605DEEC` → `0x18523AD7C` → `0x18605D6C8` | `NSPopover.closeReasonUserInfoKey` (the SDK global at `0x1E06E51C8`, bridged to `String`) | `as? NSPopover.CloseReason` | `0x18605D880` | `NSPopover.CloseReason`, the newtype struct: not `String`, not `NSString` |

### 3.2 AppKit: `NSWorkspace`

The 20 `NSWorkspace` messages involve no internal protocol (the conformance dump has only the
Foundation block for each type) and no Foundation default. What they share:

- Every name and every user-info key is an AppKit SDK constant, loaded from its global
  (`ADRL Xn, _Constant; LDR X0, [Xn]`), never a literal. Each CFString value equals the symbol name
  without the leading underscore. Keys are bridged with `String._unconditionallyBridgeFromObjectiveC`
  and wrapped as `AnyHashable(String)`, which is `[NSWorkspace.applicationUserInfoKey: …]` in Swift.
- **No `makeMessage` reads `notification.object` or `notification.name`.** The only call on the
  notification is the `userInfo` getter, made again for each key.
- **Every `makeNotification` passes `object: NSWorkspace.shared`** (`[NSWorkspace sharedWorkspace]`,
  boxed as `NSWorkspace`).
- Each message has two `name` getters with the same three instructions: the public `static var name`
  and a separate copy in the witness table.

**A-MM — application `makeMessage`, `0x185E101A4`.** All seven witness entries hold `0x185E12824`,
which is `B 0x18523219C`, then `B 0x185E10150` (`DidHideApplicationMessage`'s public `makeMessage`),
then the body.

```swift
guard let userInfo = notification.userInfo,
      let value = userInfo[AnyHashable(NSWorkspace.applicationUserInfoKey)],
      let application = value as? NSRunningApplication
else { return nil }
return Self(application: application)
```

**A-MN — application `makeNotification`, `0x185E102F8`.** X0 holds the message's address and X1 the
name global's address. Each public `makeNotification` is `ADRL X1, _<Name>; B 0x185E102F8`, and each
witness branches to its type's public function.

```swift
Notification(name: name, object: NSWorkspace.shared,
             userInfo: [NSWorkspace.applicationUserInfoKey: message.application])   // the NSRunningApplication object
```

**V-MM — volume `makeMessage`, `0x185E10AC8`.** A merged function. The public `makeMessage` of
`DidMountVolumeMessage` (`0x185E1082C`), `WillUnmountVolumeMessage` (`0x185E10AB0`) and
`DidUnmountVolumeMessage` (`0x185E1120C`) each pass their own type-metadata accessor in X1, PAC-signed
with discriminator `0x143C`. The body uses it only for `volumeURL`'s field offset and the optional's
tag, so the three behave identically.

```swift
guard let userInfo1 = notification.userInfo,
      let nameValue = userInfo1[AnyHashable(NSWorkspace.localizedVolumeNameUserInfoKey)],
      let localizedVolumeName = nameValue as? String,           // an NSString bridges
      let userInfo2 = notification.userInfo,                    // read again
      let urlValue = userInfo2[AnyHashable(NSWorkspace.volumeURLUserInfoKey)],
      let volumeURL = urlValue as? URL                          // an NSURL bridges
else { return nil }
return Self(localizedVolumeName: localizedVolumeName, volumeURL: volumeURL)
```

**V-MN — volume `makeNotification`, `0x185E10F40`.** Two entries: the name as a Swift `String`
(metadata `$sSSN`) and the URL as a Swift `URL` value (`$s10Foundation3URLVMa`, copied with
`initializeWithCopy`). Never `NSString` or `NSURL`.

```swift
Notification(name: name, object: NSWorkspace.shared,
             userInfo: [NSWorkspace.localizedVolumeNameUserInfoKey: message.localizedVolumeName,
                        NSWorkspace.volumeURLUserInfoKey: message.volumeURL])
```

**`DidRenameVolumeMessage` has bodies of its own, `0x185E11688` (`makeMessage`) and `0x185E11EB8`
(`makeNotification`).** They follow the volume pattern with four keys, all required by `makeMessage`
and all written by `makeNotification`, and are not merged with V-MM and V-MN.

**E-MM — `makeMessage` without properties.** All nine witnesses are `0x185CF9B04`, the thunk to B1
(`0x18522E5FC`). The public `DidWakeMessage.makeMessage` (`0x185E10554`) is the same two instructions,
and the other eight public functions branch to it.

**E-MN — `makeNotification` without properties, `0x185E1061C` (witness path) and `0x185E10568`
(public path).** The witness is `ADRL X3, _<Name>; B 0x185E1061C`, the public function
`ADRL X1, _<Name>; B 0x185E10568`. The two merged copies differ only in that register.

```swift
Notification(name: name, object: NSWorkspace.shared, userInfo: nil)   // MOV X2, #0: nil, not [:]
```

This is not Foundation's default, which has no object.

### 3.3 AppKit: the other 29 explicit messages

None of these conforms to an internal protocol, and none uses a Foundation default. Most are separate
per-message copies of three recurring shapes. The bodies they share are:

- **B1** again: it is the `makeMessage` witness itself for `NSColor.SystemColorsDidChangeMessage`,
  `NSScroller.PreferredScrollerStyleDidChangeMessage` and
  `NSTextInputContext.KeyboardSelectionDidChangeMessage`, and both `NSHelpManager` messages reach it
  through the thunk `0x185CF9B04`.
- **HM-MN — `NSHelpManager` `makeNotification`, `0x186069958`.** The witness stubs (`0x186069888`,
  `0x18606994C`) put the name constant's address in X3. The body is
  `Notification(name: <*X3>, object: NSHelpManager.shared, userInfo: nil)`, with
  `+[NSHelpManager sharedHelpManager]` sent on every call and the object boxed as `NSHelpManager`
  (accessor `0x18606982C`). The public functions (`0x186069820`, `0x1860698A8`) pass the name in X1 to
  a byte-for-byte equivalent twin, `0x1860698B4`.
- **B6's `NSWindow` body, `0x1860B12FC`**, which `NSWindow.DidExitFullScreenMessage`'s stub
  `0x1860B2480` enters exactly as the internal-protocol messages' stubs do.
- **SV-MM — `NSSplitView` `makeMessage`, `0x185FC60E4`, and SV-MN — `NSSplitView` `makeNotification`,
  `0x185FC6380`**, shared by `WillResizeSubviewsMessage` and `DidResizeSubviewsMessage` together with
  their `init` (section 5.7).

The three recurring shapes:

- **One object.** `makeMessage` is `object as? T`, stored in the one field; the user info is never
  read. `makeNotification` is `Notification(name: <name>, object: message.<field>, userInfo: nil)`.
- **Every user-info value required.** Anything missing — a `nil` user info, an absent key, a value of
  the wrong type — gives `nil`. `makeNotification` builds a dictionary literal with every key
  (`0x185D581B8`, `Dictionary<AnyHashable, Any>(dictionaryLiteral:)`, which traps on a duplicate key),
  so its user info is never `nil`.
- **Optional user-info values.** Only the object is required; a missing value leaves its field `nil`.
  `makeNotification` starts from an empty `[String: Any]` (`0x185D57594`), sets a key only when its
  field is not `nil` (`0x185D54214`), and passes `dict.isEmpty ? nil : dict as [AnyHashable: Any]`
  (the upcast is `0x185D52F88`). **The user info is `nil` when every optional field is `nil`.**
  `NSFontCollection` uses the `[NSFontCollection.UserInfoKey: Any]` equivalents (`0x185D5A4FC`,
  `0x185D56D70`, `0x185D53588` → `0x185D535A0`).

Other helpers that appear throughout: `0x185CFAA80` (the lazy
`swift_getObjCClassMetadata(objc_opt_self(classref))` with a cache word), `0x185D1B540` (`AnyHashable`
lookup in `[AnyHashable: Any]`), `0x185CFB7B8` (copy an `Any`), `0x185D028D4` and `0x185CF115C`
(destroy an `Any?`).

### 3.4 UIKit

**S1 — `makeMessage` without properties, `0x1BCB471B0`.** `STRB WZR, [X8]; RET`, the same as B1:
`Self()` for any notification. The witness-table entry `0x1BDD8EC44` is `B 0x1BCB471B0` for the 17
`UIAccessibility`, 12 `UIApplication` and 4 `UIDevice` messages. For `UIPasteboard.RemovedMessage` and
`UITextInputMode.CurrentInputModeDidChangeMessage` the table points at `0x1BCB471B0` directly. The
public `makeMessage` functions are separate folded copies of the same two instructions: `0x1BE1A61D0`
for `UIAccessibility`, `0x1BE1BCB38` for `UIApplication`, `0x1BDD8EBB4` for `UIDevice`, and
`0x1BDEDBAF4` and `0x1BE223120` for the last two.

**S2 — `makeNotification` without properties: Foundation's default.** No UIKit code runs. Each
witness is a chain of one-instruction branches ending at the cache stub `0x1C022B190`
(`ADRL X17, 0x1E7F6AED8; LDR X16,[X17]; BRAA X16,X17`). The GOT slot `0x1E7F6AED8` holds `0x182682E24`,
Foundation's `static NSNotificationCenter.MainActorMessage.makeNotification(_:)`
(`$sSo20NSNotificationCenterC10FoundationE16MainActorMessagePACE16makeNotificationyAC0H0VxFZ`), the
protocol extension's default. That body calls `Self.name` through witness-table slot `+0x10` and
builds a notification whose object is a `nil` `Any?` (32 zero bytes) and whose user info is `nil`:
`Notification(name: Self.name)`. The message itself is ignored.

| Messages | `makeNotification` chain |
|---|---|
| 17 `UIAccessibility` | `0x1BE1A64D4` → `0x1BCB40508` → `0x1C022B190` |
| 12 `UIApplication` | `0x1BE1BCD4C` → `0x1BCB408E4` → `0x1C022B190` |
| 4 `UIDevice` | `0x1BDD8EC40` → `0x1BCB33A00` → `0x1C022B190` |
| `UIPasteboard.RemovedMessage` | `0x1BDEDBB0C` → `0x1C022B190` |
| `UITextInputMode.CurrentInputModeDidChangeMessage` | `0x1BCB408E4` → `0x1C022B190` |

**S3 — `name` getters.** One per message, not shared:
`ADRL X8, <exported constant>; LDR X0,[X8]; B 0x1C01F48C0`, where `0x1C01F48C0` is `objc_retain_x0`
(IDA mislabels it `-[UITraitCollection copyWithZone:]_0`). Each message also has a separate public
getter with identical code.

**S4 — user-info lookup** in the bodies of `UIAccessibility.AnnouncementDidFinishMessage`,
`UIAccessibility.ElementFocusedMessage` and `UIPasteboard.ChangedMessage`. For each key, in source
order: call the `userInfo` getter again (`nil` means not found); build the key from the SDK `NSString`
constant, bridged to `String` and wrapped as `AnyHashable`; look it up (`__RawDictionaryStorage.find`
at `0x1BDD94460`, a hit copied out by `0x1BDD002B4`). Neither `notification.name` nor
`notification.object` is read.

**S5 — user-info construction** in the same three bodies: a stack
`_ContiguousArrayStorage<(AnyHashable, Any)>` with header (1, 2) for one entry or (2, 4) for two; keys
`AnyHashable(String(<SDK constant>))`; each value stored inline in an `Any` with explicit metadata; then
`Dictionary<AnyHashable, Any>(dictionaryLiteral:)` (`0x1BDD991A8`) and `Notification(name:object:userInfo:)`
with a zeroed `Any?`, so `object` is `nil`. Every key is written.

**O1 / N1 — one subject, which is the notification's object.** The same Swift as B5 and B6, with
`userInfo: nil`, not `[:]`. Each `makeNotification` witness is `ADRL X3, _<SDK name global>; B <N1
body>`: Swift function merging turned the name into a parameter.

| Class | Messages | `makeMessage` chain → O1 body | N1 body |
|---|---|---|---|
| `UIScene` | 6 | `0x1BE0A8578` → `0x1BCB3D538` → `0x1BE0A83EC` → `0x1BE0A8190` | `0x1BE0A82B8` |
| `UIWindow` | 4 | `0x1BE1FCB44` → `0x1BCB41F68` → `0x1BE1FC910` → `0x1BE1FC96C` | `0x1BE1FCA74` |
| `UIScreen` | 4 | `0x1BDF19E1C` → `0x1BCB38670` → `0x1BDF19B90` → `0x1BDF19C44` | `0x1BDF19D4C` |
| `UITextView` | 3 | `0x1BE28E334` → `0x1BCB439D0` → `0x1BE28E0F0` → `0x1BE28E0F4` | `0x1BE28E21C` |
| `UITextField` | 2 | `0x1BDD9E9F8` → `0x1BCB33A68` → `0x1BDD933A8` → `0x1BDD933AC` | `0x1BDD934E4` |
| `UIDocument` | 1 | `0x1BDE10FD4` → `0x1BDE10E80` (same shape, not shared) | `0x1BDE10FD8` (the witness) |
| `UIViewController` | 1 | `0x1BE022628` → `0x1BE0224E4` (same shape, not shared) | `0x1BE02262C` (the witness) |
| `UITableView` | 1 | `0x1BE1A8A1C` → `0x1BE1A8924` (same shape, not shared) | `0x1BE1A8A20` (the witness) |

The two `UITextField` messages here are `TextDidBeginEditingMessage` and `TextDidChangeMessage`;
`TextDidEndEditingMessage` has bodies of its own.

**K1 — keyboard `makeMessage`, `0x1BDF139CC`.** All six keyboard messages conform to the internal
protocol `KeyboardNotificationMessageProviding`, and all six `makeMessage` witnesses are `0x1BDF150E4`
→ `0x1BCB38600` → `0x1BDF14C34`, which copies the notification and calls the body. Every step is
required; the first failure zeroes the 96-byte result:

```swift
guard let userInfo = notification.userInfo,                         // the binary reads it again before each key
      let begin = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue,
      let end = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue,
      let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double,
      let curve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber,
      let isLocal = userInfo[UIResponder.keyboardIsLocalUserInfoKey] as? Bool,
      let screen = notification.object as? UIScreen                                         // checked last
else { return nil }
return Self(beginFrame: begin.cgRectValue, endFrame: end.cgRectValue, animationDuration: duration,
            animationCurve: UIView.AnimationCurve(rawValue: curve.intValue)!, isLocal: isLocal, screen: screen)
```

`CGRectValue` is sent only after every check has passed. The curve is the raw `integerValue`, stored
unvalidated — there is no switch over the raw values. The store offsets confirm declaration order:
`beginFrame` `0x0`, `endFrame` `0x20`, `animationDuration` `0x40`, `animationCurve` `0x48`, `isLocal`
`0x50`, `screen` `0x58`.

**K2 — keyboard `makeNotification`, `0x1BDF13710`.** Each witness copies the message to the stack and
calls the body with its own name global in X0 and a per-type copy helper in X1 (checked for
`KeyboardWillShowMessage`: `0x1BDF1501C`, which only does retain bookkeeping). Five entries, every one
unconditional, then `object: message.screen`, typed `UIScreen`:

| Key | Value | Type stored in the `Any` |
|---|---|---|
| `UIResponder.keyboardFrameBeginUserInfoKey` | `beginFrame` | Swift `CGRect`, not `NSValue` |
| `UIResponder.keyboardFrameEndUserInfoKey` | `endFrame` | Swift `CGRect`, not `NSValue` |
| `UIResponder.keyboardAnimationDurationUserInfoKey` | `animationDuration` | Swift `Double` |
| `UIResponder.keyboardAnimationCurveUserInfoKey` | `animationCurve` | `UIView.AnimationCurve`, the imported enum: not `Int`, not `NSNumber` |
| `UIResponder.keyboardIsLocalUserInfoKey` | `isLocal` | Swift `Bool` |

## 4. Per-message reference

How to read the tables:

- **Message** drops the `Message` suffix: `NSWindow.DidBecomeKey` is `NSWindow.DidBecomeKeyMessage`.
- **Notification** is the constant's Swift spelling. Section 5.11 lists the ones that do not follow
  `<Type>.<name>Notification`.
- **`name`**, **`makeMessage`** and **`makeNotification`** are witness addresses, followed through
  thunks (`→`) to the body, or to a label from section 3. In the "Addresses" columns, **mM** is the
  `makeMessage` witness and **mN** the `makeNotification` witness.
- **req**: the message is `nil` when the value is missing, when the user info is `nil`, or when the
  value has another type. **opt**: the field takes the stated value instead, and the message is still
  made.
- **Swift `Int`** (or `Bool`, `CGFloat`, `String`, `URL`, …): a Swift value boxed in `Any`, not an
  `NSNumber`, `NSString`, `NSValue` or `NSURL`. **the object**: the object reference itself.
- Every message is a `MainActorMessage` except the three marked **Async** in section 4.4.

### 4.1 AppKit messages without properties (31)

`makeMessage` returns `Self()` whatever the notification holds (B1). `makeNotification` passes
`userInfo: nil` and the object in the `object:` column. "Thunk" is `0x185CF9B04`, `B 0x18522E5FC`.

| Message | Notification | `object:` | `name` | `makeMessage` | `makeNotification` |
|---|---|---|---|---|---|
| `NSApplication.DidBecomeActive` | `NSApplication.didBecomeActiveNotification` | `NSApplication.shared` | `0x185E50CD4` | thunk → B1 | `0x185E50CE4` → B2 |
| `NSApplication.DidChangeOcclusionState` | `NSApplication.didChangeOcclusionStateNotification` | `NSApplication.shared` | `0x185E50D04` | thunk → B1 | `0x185E50D14` → B2 |
| `NSApplication.DidChangeScreenParameters` | `NSApplication.didChangeScreenParametersNotification` | `NSApplication.shared` | `0x185E50D34` | thunk → B1 | `0x185E50D44` → B2 |
| `NSApplication.DidFinishRestoringWindows` | `NSApplication.didFinishRestoringWindowsNotification` | `NSApplication.shared` | `0x185E50D64` | thunk → B1 | `0x185E50D74` → B2 |
| `NSApplication.DidHide` | `NSApplication.didHideNotification` | `NSApplication.shared` | `0x185E50D94` | thunk → B1 | `0x185E50DA4` → B2 |
| `NSApplication.DidResignActive` | `NSApplication.didResignActiveNotification` | `NSApplication.shared` | `0x185E50DC4` | thunk → B1 | `0x185E50DD4` → B2 |
| `NSApplication.DidUnhide` | `NSApplication.didUnhideNotification` | `NSApplication.shared` | `0x185E50DF4` | thunk → B1 | `0x185E50E04` → B2 |
| `NSApplication.DidUpdateWindows` | `NSApplication.didUpdateNotification` | `NSApplication.shared` | `0x185E50E24` | thunk → B1 | `0x185E50E34` → B2 |
| `NSApplication.ProtectedDataDidBecomeAvailable` | `NSNotification.Name.NSApplicationProtectedDataDidBecomeAvailable` | `NSApplication.shared` | `0x185E50FA4` | thunk → B1 | `0x185E50FB4` → B2 |
| `NSApplication.ProtectedDataWillBecomeUnavailable` | `NSNotification.Name.NSApplicationProtectedDataWillBecomeUnavailable` | `NSApplication.shared` | `0x185E517BC` | thunk → B1 | `0x185E517CC` → B2 |
| `NSApplication.WillBecomeActive` | `NSApplication.willBecomeActiveNotification` | `NSApplication.shared` | `0x185E50E54` | thunk → B1 | `0x185E50E64` → B2 |
| `NSApplication.WillFinishLaunching` | `NSApplication.willFinishLaunchingNotification` | `NSApplication.shared` | `0x185E50E84` | thunk → B1 | `0x185E50E94` → B2 |
| `NSApplication.WillHide` | `NSApplication.willHideNotification` | `NSApplication.shared` | `0x185E50EB4` | thunk → B1 | `0x185E50EC4` → B2 |
| `NSApplication.WillResignActive` | `NSApplication.willResignActiveNotification` | `NSApplication.shared` | `0x185E50EE4` | thunk → B1 | `0x185E50EF4` → B2 |
| `NSApplication.WillTerminate` | `NSApplication.willTerminateNotification` | `NSApplication.shared` | `0x185E50F14` | thunk → B1 | `0x185E50F24` → B2 |
| `NSApplication.WillUnhide` | `NSApplication.willUnhideNotification` | `NSApplication.shared` | `0x185E50F44` | thunk → B1 | `0x185E50F54` → B2 |
| `NSApplication.WillUpdateWindows` | `NSApplication.willUpdateNotification` | `NSApplication.shared` | `0x185E50F74` | thunk → B1 | `0x185E50F84` → B2 |
| `NSSpellChecker.DidChangeAutomaticCapitalization` | `NSSpellChecker.didChangeAutomaticCapitalizationNotification` | `NSSpellChecker.shared` | `0x185DA0D08` | thunk → B1 | `0x185DA0D18` → B3 |
| `NSSpellChecker.DidChangeAutomaticDashSubstitution` | `NSSpellChecker.didChangeAutomaticDashSubstitutionNotification` | `NSSpellChecker.shared` | `0x185DA0CD8` | thunk → B1 | `0x185DA0CE8` → B3 |
| `NSSpellChecker.DidChangeAutomaticInlinePrediction` | `NSNotification.Name.NSSpellCheckerDidChangeAutomaticInlinePrediction` | `NSSpellChecker.shared` | `0x185DA1178` | thunk → B1 | `0x185DA1188` → B3 |
| `NSSpellChecker.DidChangeAutomaticPeriodSubstitution` | `NSSpellChecker.didChangeAutomaticPeriodSubstitutionNotification` | `NSSpellChecker.shared` | `0x185DA0D38` | thunk → B1 | `0x185DA0D48` → B3 |
| `NSSpellChecker.DidChangeAutomaticQuoteSubstitution` | `NSSpellChecker.didChangeAutomaticQuoteSubstitutionNotification` | `NSSpellChecker.shared` | `0x185DA0CA8` | thunk → B1 | `0x185DA0CB8` → B3 |
| `NSSpellChecker.DidChangeAutomaticSpellingCorrection` | `NSSpellChecker.didChangeAutomaticSpellingCorrectionNotification` | `NSSpellChecker.shared` | `0x185DA0C48` | thunk → B1 | `0x185DA0C58` → B3 |
| `NSSpellChecker.DidChangeAutomaticTextCompletion` | `NSSpellChecker.didChangeAutomaticTextCompletionNotification` | `NSSpellChecker.shared` | `0x185DA0D68` | thunk → B1 | `0x185DA0D78` → B3 |
| `NSSpellChecker.DidChangeAutomaticTextReplacement` | `NSSpellChecker.didChangeAutomaticTextReplacementNotification` | `NSSpellChecker.shared` | `0x185DA0C78` | thunk → B1 | `0x185DA0C88` → B3 |
| `NSHelpManager.ContextHelpModeDidActivate` | `NSHelpManager.contextHelpModeDidActivateNotification` | `NSHelpManager.shared` | `0x186069878` | thunk → B1 | `0x186069888` → HM-MN |
| `NSHelpManager.ContextHelpModeDidDeactivate` | `NSHelpManager.contextHelpModeDidDeactivateNotification` | `NSHelpManager.shared` | `0x18606993C` | thunk → B1 | `0x18606994C` → HM-MN |
| `NSFont.FontSetChanged` | `NSFont.fontSetChangedNotification` | `nil` | `0x185FC5EB4` | `0x18522E5FC` (B1 itself) | `0x185FC5EC4` (B4, the witness) |
| `NSColor.SystemColorsDidChange` | `NSColor.systemColorsDidChangeNotification` | `nil` | `0x185FC5DA0` | `0x18522E5FC` (B1 itself) | `0x185FC5DB0` (the witness) |
| `NSScroller.PreferredScrollerStyleDidChange` | `NSScroller.preferredScrollerStyleDidChangeNotification` | `nil` | `0x18600E7CC` | `0x18522E5FC` (B1 itself) | `0x18600E7DC` (the witness) |
| `NSTextInputContext.KeyboardSelectionDidChange` | `NSTextInputContext.keyboardSelectionDidChangeNotification` | `nil` | `0x18609F178` | `0x18522E5FC` (B1 itself) | `0x18609F188` (the witness) |

The last three, like `NSFont`'s, behave exactly like Foundation's default `makeNotification` but are
AppKit bodies. `NSTextInputContext`'s matches how AppKit posts that notification:
`__NSSelectedKeyboardInputSourcesChangedNotification` (`0x1851D2798`) calls
`postNotificationName:object:userInfo:` with a `nil` object and a `nil` user info.

### 4.2 AppKit messages whose only property is the object (59)

`makeMessage`: `object as? <Class>` (req), stored in the one field; the user info is never read.
`makeNotification`: `object: message.<field>`, `userInfo: nil`. A subclass passes the cast
(section 5.12).

The 50 that go through internal protocols share their class's `makeMessage` chain and B5 body, and end
their `makeNotification` in the class's B6 body (both in the B5 / B6 table of section 3.1):

| Message | Notification | Cast → field | `name` | `makeNotification` |
|---|---|---|---|---|
| `NSWindow.DidBecomeKey` | `NSWindow.didBecomeKeyNotification` | `NSWindow` → `window` | `0x1860B1294` | `0x1860B12A4` → B6 |
| `NSWindow.DidBecomeMain` | `NSWindow.didBecomeMainNotification` | `NSWindow` → `window` | `0x1860B12E0` | `0x1860B12F0` → B6 |
| `NSWindow.DidChangeOcclusionState` | `NSWindow.didChangeOcclusionStateNotification` | `NSWindow` → `window` | `0x1860B25EC` | `0x1860B25FC` → B6 |
| `NSWindow.DidChangeScreen` | `NSWindow.didChangeScreenNotification` | `NSWindow` → `window` | `0x1860B13A4` | `0x1860B13B4` → B6 |
| `NSWindow.DidChangeScreenProfile` | `NSWindow.didChangeScreenProfileNotification` | `NSWindow` → `window` | `0x1860B2184` | `0x1860B2194` → B6 |
| `NSWindow.DidDeminiaturize` | `NSWindow.didDeminiaturizeNotification` | `NSWindow` → `window` | `0x1860B13F0` | `0x1860B1400` → B6 |
| `NSWindow.DidEndLiveResize` | `NSWindow.didEndLiveResizeNotification` | `NSWindow` → `window` | `0x1860B221C` | `0x1860B222C` → B6 |
| `NSWindow.DidEndSheet` | `NSWindow.didEndSheetNotification` | `NSWindow` → `window` | `0x1860B1B54` | `0x1860B1B64` → B6 |
| `NSWindow.DidEnterFullScreen` | `NSWindow.didEnterFullScreenNotification` | `NSWindow` → `window` | `0x1860B22B4` | `0x1860B22C4` → B6 |
| `NSWindow.DidEnterVersionBrowser` | `NSWindow.didEnterVersionBrowserNotification` | `NSWindow` → `window` | `0x1860B2508` | `0x1860B2518` → B6 |
| `NSWindow.DidExitVersionBrowser` | `NSWindow.didExitVersionBrowserNotification` | `NSWindow` → `window` | `0x1860B25A0` | `0x1860B25B0` → B6 |
| `NSWindow.DidMiniaturize` | `NSWindow.didMiniaturizeNotification` | `NSWindow` → `window` | `0x1860B1820` | `0x1860B1830` → B6 |
| `NSWindow.DidMove` | `NSWindow.didMoveNotification` | `NSWindow` → `window` | `0x1860B18A8` | `0x1860B18B8` → B6 |
| `NSWindow.DidResignKey` | `NSWindow.didResignKeyNotification` | `NSWindow` → `window` | `0x1860B18F4` | `0x1860B1904` → B6 |
| `NSWindow.DidResignMain` | `NSWindow.didResignMainNotification` | `NSWindow` → `window` | `0x1860B1940` | `0x1860B1950` → B6 |
| `NSWindow.DidResize` | `NSWindow.didResizeNotification` | `NSWindow` → `window` | `0x1860B198C` | `0x1860B199C` → B6 |
| `NSWindow.DidUpdate` | `NSWindow.didUpdateNotification` | `NSWindow` → `window` | `0x1860B19D8` | `0x1860B19E8` → B6 |
| `NSWindow.WillBeginSheet` | `NSWindow.willBeginSheetNotification` | `NSWindow` → `window` | `0x1860B1B08` | `0x1860B1B18` → B6 |
| `NSWindow.WillClose` | `NSWindow.willCloseNotification` | `NSWindow` → `window` | `0x1860B1A24` | `0x1860B1A34` → B6 |
| `NSWindow.WillEnterFullScreen` | `NSWindow.willEnterFullScreenNotification` | `NSWindow` → `window` | `0x1860B2268` | `0x1860B2278` → B6 |
| `NSWindow.WillEnterVersionBrowser` | `NSWindow.willEnterVersionBrowserNotification` | `NSWindow` → `window` | `0x1860B24BC` | `0x1860B24CC` → B6 |
| `NSWindow.WillExitFullScreen` | `NSWindow.willExitFullScreenNotification` | `NSWindow` → `window` | `0x1860B2300` | `0x1860B2310` → B6 |
| `NSWindow.WillExitVersionBrowser` | `NSWindow.willExitVersionBrowserNotification` | `NSWindow` → `window` | `0x1860B2554` | `0x1860B2564` → B6 |
| `NSWindow.WillMiniaturize` | `NSWindow.willMiniaturizeNotification` | `NSWindow` → `window` | `0x1860B1A70` | `0x1860B1A80` → B6 |
| `NSWindow.WillMove` | `NSWindow.willMoveNotification` | `NSWindow` → `window` | `0x1860B1ABC` | `0x1860B1ACC` → B6 |
| `NSWindow.WillStartLiveResize` | `NSWindow.willStartLiveResizeNotification` | `NSWindow` → `window` | `0x1860B21D0` | `0x1860B21E0` → B6 |
| `NSScrollView.DidEndLiveMagnify` | `NSScrollView.didEndLiveMagnifyNotification` | `NSScrollView` → `scrollView` | `0x185D5A7F4` | `0x185D5A804` → B6 |
| `NSScrollView.DidEndLiveScroll` | `NSScrollView.didEndLiveScrollNotification` | `NSScrollView` → `scrollView` | `0x185D5AB80` | `0x185D5AB90` → B6 |
| `NSScrollView.DidLiveScroll` | `NSScrollView.didLiveScrollNotification` | `NSScrollView` → `scrollView` | `0x185D5A8C8` | `0x185D5A8D8` → B6 |
| `NSScrollView.WillStartLiveMagnify` | `NSScrollView.willStartLiveMagnifyNotification` | `NSScrollView` → `scrollView` | `0x185D5A7A8` | `0x185D5A7B8` → B6 |
| `NSScrollView.WillStartLiveScroll` | `NSScrollView.willStartLiveScrollNotification` | `NSScrollView` → `scrollView` | `0x185D5A840` | `0x185D5A850` → B6 |
| `NSComboBox.SelectionDidChange` | `NSComboBox.selectionDidChangeNotification` | `NSComboBox` → `comboBox` | `0x185F72894` | `0x185F728A4` → B6 |
| `NSComboBox.SelectionIsChanging` | `NSComboBox.selectionIsChangingNotification` | `NSComboBox` → `comboBox` | `0x185F728E0` | `0x185F728F0` → B6 |
| `NSComboBox.WillDismiss` | `NSComboBox.willDismissNotification` | `NSComboBox` → `comboBox` | `0x185F7292C` | `0x185F7293C` → B6 |
| `NSComboBox.WillPopUp` | `NSComboBox.willPopUpNotification` | `NSComboBox` → `comboBox` | `0x185F72BA4` | `0x185F72BB4` → B6 |
| `NSMenu.DidBeginTracking` | `NSMenu.didBeginTrackingNotification` | `NSMenu` → `menu` | `0x1860E3ED8` | `0x1860E3EE8` → B6 |
| `NSMenu.DidEndTracking` | `NSMenu.didEndTrackingNotification` | `NSMenu` → `menu` | `0x1860E4288` | `0x1860E4298` → B6 |
| `NSMenu.DidSendAction` | `NSMenu.didSendActionNotification` | `NSMenu` → `menu` | `0x1860E3CA8` | `0x1860E3CB8` → B6 |
| `NSMenu.WillSendAction` | `NSMenu.willSendActionNotification` | `NSMenu` → `menu` | `0x1860E3C20` | `0x1860E3C30` → B6 |
| `NSOutlineView.SelectionDidChange` | `NSOutlineView.selectionDidChangeNotification` | `NSOutlineView` → `outlineView` | `0x185DD52CC` | `0x185DD52DC` → B6 |
| `NSOutlineView.SelectionIsChanging` | `NSOutlineView.selectionIsChangingNotification` | `NSOutlineView` → `outlineView` | `0x185DD5D4C` | `0x185DD5D5C` → B6 |
| `NSPopover.DidShow` | `NSPopover.didShowNotification` | `NSPopover` → `popover` | `0x18605DA54` | `0x18605DA64` → B6 |
| `NSPopover.WillShow` | `NSPopover.willShowNotification` | `NSPopover` → `popover` | `0x18605D9CC` | `0x18605D9DC` → B6 |
| `NSTableView.SelectionDidChange` | `NSTableView.selectionDidChangeNotification` | `NSTableView` → `tableView` | `0x186069B00` | `0x186069B10` → B6 |
| `NSTableView.SelectionIsChanging` | `NSTableView.selectionIsChangingNotification` | `NSTableView` → `tableView` | `0x18606A540` | `0x18606A550` → B6 |
| `NSTextView.DidBeginEditing` | `NSText.didBeginEditingNotification` | `NSText` → `text` | `0x185D52BF4` | `0x185D52C04` → B6 |
| `NSTextView.DidChange` | `NSText.didChangeNotification` | `NSText` → `text` | `0x185D538E4` | `0x185D538F4` → B6 |
| `NSView.BoundsDidChange` | `NSView.boundsDidChangeNotification` | `NSView` → `view` | `0x18610F8B0` | `0x18610F8C0` → B6 |
| `NSView.FrameDidChange` | `NSView.frameDidChangeNotification` | `NSView` → `view` | `0x18610F76C` | `0x18610F77C` → B6 |
| `NSRuleEditor.RowsDidChange` | `NSRuleEditor.rowsDidChangeNotification` | `NSRuleEditor` → `ruleEditor` | `0x186015A54` | `0x186015A68` (the witness is the B6 body) |

The other nine are explicit, each with its own copy of the same code:

| Message | Notification | Cast → field | `name` | `makeMessage` | `makeNotification` |
|---|---|---|---|---|---|
| `NSBrowser.ColumnConfigurationDidChange` | `NSBrowser.columnConfigurationDidChangeNotification` | `NSBrowser` → `browser` | `0x1860E3808` | `0x1860E3818` → `0x1860E36CC` | `0x1860E381C` (the witness) |
| `NSColorList.DidChange` | `NSColorList.didChangeNotification` | `NSColorList` → `colorList` | `0x185DADCB4` | `0x185DADCC4` → `0x185DADB78` | `0x185DADCC8` (the witness) |
| `NSColorPanel.ColorDidChange` | `NSColorPanel.colorDidChangeNotification` | `NSColorPanel` → `colorPanel` | `0x185EC169C` | `0x185EC16AC` → `0x185EC1560` | `0x185EC16B0` (the witness) |
| `NSImageRep.RegistryDidChange` | `NSImageRep.registryDidChangeNotification` | `NSImageRep` → `imageRep` | `0x186015CDC` | `0x186015CEC` → `0x186015BA0` | `0x186015CF0` (the witness) |
| `NSPopUpButton.WillPopUp` | `NSPopUpButton.willPopUpNotification` | `NSPopUpButton` → `popUpButton` | `0x185F52988` | `0x185F52998` → `0x185F5284C` | `0x185F5299C` (the witness) |
| `NSPopUpButtonCell.WillPopUp` | `NSPopUpButtonCell.willPopUpNotification` | `NSPopUpButtonCell` → `popUpButtonCell` | `0x185F5274C` | `0x185F5275C` → `0x185F52610` | `0x185F52760` (the witness) |
| `NSScreen.ColorSpaceDidChange` | `NSScreen.colorSpaceDidChangeNotification` | `NSScreen` → `screen` | `0x185DB269C` | `0x185DB26AC` → `0x185DB25AC` | `0x185DB26B0` (the witness) |
| `NSTextView.DidChangeTypingAttributes` | `NSTextView.didChangeTypingAttributesNotification` | `NSTextView` → `textView` | `0x185D8C2A8` | `0x185D8C2B8` → `0x185D8C198` | `0x185D8C2BC` (the witness) |
| `NSWindow.DidExitFullScreen` | `NSWindow.didExitFullScreenNotification` | `NSWindow` → `window` | `0x1860B246C` | `0x1860B247C` → `0x1860B234C` | `0x1860B2480` → B6 (`0x1860B12FC`) |

`NSWindow.DidExitFullScreenMessage` behaves exactly like the 26 `StandardNSWindowMessage` messages. Its
`makeMessage` body `0x1860B234C` is the same code as B5's `NSWindow` body (the same `as? NSWindow`,
the same metadata cache `qword_1E6412F00`), and its `makeNotification` stub enters the very same B6
body. Only the declaration differs: it declares public `makeMessage` and `makeNotification` on the
struct (public `makeNotification` at `0x1860B23EC`) and has no `StandardNSWindowMessage` conformance.
For `NSImageRep.RegistryDidChangeMessage`, see section 5.8 for what AppKit posts as the object.

### 4.3 AppKit messages with user info (27)

The object is always read first; when it fails, the user info is never read. Keys in quotes are Swift
string literals in the binary; the others are SDK constants. "Never `nil`" in the last column means the
notification always carries a user info dictionary.

| Message | Notification | `makeMessage` reads | `makeNotification` writes | Addresses |
|---|---|---|---|---|
| `NSControl.TextDidBeginEditing` | `NSControl.textDidBeginEditingNotification` | object `as? NSControl` → `control` (req); `"NSFieldEditor"` `as? NSText` → `fieldEditor` (req) | `object: control`; `"NSFieldEditor"`: the `NSText` object | `name` `0x185F3BB44`; mM → B7; mN `0x185F3BB54` → B8 |
| `NSControl.TextDidChange` | `NSControl.textDidChangeNotification` | as above | as above | `name` `0x185F3BC3C`; mM → B7; mN `0x185F3BC4C` → B8 |
| `NSControl.TextDidEndEditing` | `NSControl.textDidEndEditingNotification` | as above | as above | `name` `0x185F3BE38`; mM → B7; mN `0x185F3BE48` → B8 |
| `NSMenu.DidAddItem` | `NSMenu.didAddItemNotification` | object `as? NSMenu` → `menu` (req); `"NSMenuItemIndex"` `as? Int` → `itemIndex` (req) | `object: menu`; `"NSMenuItemIndex"`: Swift `Int` | `name` `0x1860E3D60`; mM → B7; mN `0x1860E3D70` → B8 |
| `NSMenu.DidChangeItem` | `NSMenu.didChangeItemNotification` | as above | as above | `name` `0x1860E3E70`; mM → B7; mN `0x1860E3E80` → B8 |
| `NSMenu.DidRemoveItem` | `NSMenu.didRemoveItemNotification` | as above | as above | `name` `0x1860E3DE8`; mM → B7; mN `0x1860E3DF8` → B8 |
| `NSOutlineView.ItemDidCollapse` | `NSOutlineView.itemDidCollapseNotification` | object `as? NSOutlineView` → `outlineView` (req); `"NSObject"`, any value, no cast → `item` (req: only its absence fails) | `object: outlineView`; `"NSObject"`: `item`, its dynamic type unchanged | `name` `0x185DD6040`; mM → B7; mN `0x185DD6050` → B8 |
| `NSOutlineView.ItemDidExpand` | `NSOutlineView.itemDidExpandNotification` | as above | as above | `name` `0x185DD5F40`; mM → B7; mN `0x185DD5F50` → B8 |
| `NSOutlineView.ItemWillCollapse` | `NSOutlineView.itemWillCollapseNotification` | as above | as above | `name` `0x185DD5FC0`; mM → B7; mN `0x185DD5FD0` → B8 |
| `NSOutlineView.ItemWillExpand` | `NSOutlineView.itemWillExpandNotification` | as above | as above | `name` `0x185DD5E30`; mM → B7; mN `0x185DD5E40` → B8 |
| `NSPopover.DidClose` | `NSPopover.didCloseNotification` | object `as? NSPopover` → `popover` (req); `NSPopover.closeReasonUserInfoKey` `as? NSPopover.CloseReason` → `closeReason` (req) | `object: popover`; `closeReasonUserInfoKey`: the `NSPopover.CloseReason` struct | `name` `0x18605DE10`; mM → B7; mN `0x18605DE20` → B8 |
| `NSPopover.WillClose` | `NSPopover.willCloseNotification` | as above | as above | `name` `0x18605DB28`; mM → B7; mN `0x18605DB38` → B8 |
| `NSTableView.ColumnDidMove` | `NSTableView.columnDidMoveNotification` | object `as? NSTableView` → `tableView` (req); `"NSOldColumn"` `as? Int` → `oldColumn` (req); `"NSNewColumn"` `as? Int` → `newColumn` (req) | `object: tableView`; `"NSOldColumn"`, `"NSNewColumn"`: Swift `Int`; never `nil` | `name` `0x186069FC8`; mM `0x186069FD8` → `0x186069BEC`; mN `0x186069FDC` → `0x186069E3C` |
| `NSOutlineView.ColumnDidMove` | `NSOutlineView.columnDidMoveNotification` | the same with `as? NSOutlineView` → `outlineView` | the same with `object: outlineView` | `name` `0x185DD57B4`; mM `0x185DD57C4` → `0x185DD53B8`; mN `0x185DD57C8` → `0x185DD5628` |
| `NSTableView.ColumnDidResize` | `NSTableView.columnDidResizeNotification` | object `as? NSTableView` → `tableView` (req); `"NSTableColumn"` `as? NSTableColumn` → `tableColumn` (req); `"NSOldWidth"` `as? CGFloat` → `oldWidth` (req; a direct cast, which an `NSNumber` passes) | `object: tableView`; `"NSTableColumn"`: the object; `"NSOldWidth"`: Swift `CGFloat`; never `nil` | `name` `0x18606A4F8`; mM `0x18606A508` → `0x18606A0A0`; mN `0x18606A50C` → `0x18606A33C` |
| `NSOutlineView.ColumnDidResize` | `NSOutlineView.columnDidResizeNotification` | the same with `as? NSOutlineView` → `outlineView` | the same with `object: outlineView` | `name` `0x185DD5D04`; mM `0x185DD5D14` → `0x185DD588C`; mN `0x185DD5D18` → `0x185DD5B48` |
| `NSTextAlternatives.SelectedAlternativeString` | `NSTextAlternatives.selectedAlternativeStringNotification` | object `as? NSTextAlternatives` → `textAlternatives` (req); `"NSAlternativeString"` `as? String` → `alternativeString` (req) | `object: textAlternatives`; `"NSAlternativeString"`: Swift `String`; never `nil` | `name` `0x18611A420`; mM `0x18611A430` → `0x18611A10C`; mN `0x18611A434` → `0x18611A2F8` |
| `NSToolbar.WillAddItem` | `NSToolbar.willAddItemNotification` | object `as? NSToolbar` → `toolbar` (req); `NSToolbarItemKey` (`"item"`) `as? NSToolbarItem` → `item` (req); `NSToolbarNewIndexKey` (`"newIndex"`) `as? Int` → `newIndex` (req) | `object: toolbar`; `NSToolbarItemKey`: the object; `NSToolbarNewIndexKey`: Swift `Int`; keys are `AnyHashable(NSToolbarUserInfoKey)`; never `nil` | `name` `0x186118FC8`; mM `0x186118FD8` → `0x186118B10`; mN `0x186118FDC` → `0x186118E1C` |
| `NSToolbar.DidRemoveItem` | `NSToolbar.didRemoveItemNotification` | object `as? NSToolbar` → `toolbar` (req); `NSToolbarItemKey` `as? NSToolbarItem` → `item` (req) | `object: toolbar`; `NSToolbarItemKey`: the object; never `nil` | `name` `0x1861193D0`; mM `0x1861193E0` → `0x1861190A0`; mN `0x1861193E4` → `0x186119274` |
| `NSWindow.DidExpose` | `NSWindow.didExposeNotification` | object `as? NSWindow` → `window` (req); `"NSExposedRect"` `as? CGRect` → `exposedRect` (req; a direct cast, which an `NSValue` holding a rect passes) | `object: window`; `"NSExposedRect"`: Swift `CGRect` (heap-boxed, 32 bytes), not `NSValue`; never `nil` | `name` `0x1860B17D8`; mM `0x1860B17E8` → `0x1860B14B8`; mN `0x1860B17EC` → `0x1860B167C` |
| `NSTextView.DidChangeSelection` | `NSTextView.didChangeSelectionNotification` | object `as? NSTextView` → `textView` (req); `"NSOldSelectedCharacterRange"` `as? NSValue`, then `.rangeValue` → `oldSelectedCharacterRange` (opt → `nil`) | `object: textView`; the key only when the range is not `nil`, holding `NSValue(range:)`; otherwise `userInfo: nil` | `name` `0x185D8C114`; mM `0x185D8C124` → `0x185D8BDF4`; mN `0x185D8C128` → `0x185D8BFAC` |
| `NSTextView.DidEndEditing` | `NSText.didEndEditingNotification` | object `as? NSText` → `text` (req); `NSText.movementUserInfoKey` (`"NSTextMovement"`) `as? Int` → `textMovement` (opt → `nil`) | `object: text`; the key only when `textMovement` is not `nil`, a Swift `Int`; otherwise `userInfo: nil` | `name` `0x185D53860`; mM `0x185D53870` → `0x185D52CB8`; mN `0x185D53874` → `0x185D52E50` |
| `NSTextView.WillChangeNotifyingTextView` | `NSTextView.willChangeNotifyingTextViewNotification` | object `as? NSTextView` → `textView` (req); `"NSOldNotifyingTextView"` `as? NSTextView` → `oldNotifyingTextView` (opt → `nil`); `"NSNewNotifyingTextView"` `as? NSTextView` → `newNotifyingTextView` (opt → `nil`) | `object: textView`; each key only when its field is not `nil`, holding the object; `userInfo: nil` when both are `nil` | `name` `0x185D8BD40`; mM `0x185D8BD50` → `0x185D8B934`; mN `0x185D8BD54` → `0x185D8BB8C` |
| `NSWindow.DidChangeBackingProperties` | `NSWindow.didChangeBackingPropertiesNotification` | object `as? NSWindow` → `window` (req); `NSWindow.oldScaleFactorUserInfoKey` `as? CGFloat` → `oldScaleFactor` (opt → `nil`); `NSWindow.oldColorSpaceUserInfoKey` `as? NSColorSpace` → `oldColorSpace` (opt → `nil`) | `object: window`; each key only when its field is not `nil` (Swift `CGFloat`; the `NSColorSpace` object); `userInfo: nil` when both are `nil` | `name` `0x1860B213C`; mM `0x1860B214C` → `0x1860B1C94`; mN `0x1860B2150` → `0x1860B1F6C` |
| `NSSplitView.DidResizeSubviews` | `NSSplitView.didResizeSubviewsNotification` | object `as? NSSplitView` → `splitView` (req); `"NSSplitViewDividerIndex"` `as? Int` → `dividerIndex` (opt → `nil`); `"NSSplitViewUserResizeKey"` `as? Bool` → `userResize` (opt → `false`) | `object: splitView`; the divider index only when not `nil` (Swift `Int`); the user-resize flag always (Swift `Bool`), so never `nil` | `name` `0x185FC651C`; mM `0x185FC6614` → `0x185239964` → `0x185FC60E0` → SV-MM; mN `0x185FC652C` → `0x185FC6374` → SV-MN |
| `NSSplitView.WillResizeSubviews` | `NSSplitView.willResizeSubviewsNotification` | as above | as above | `name` `0x185FC5FEC`; mM `0x185FC6614` (the same witness) → SV-MM; mN `0x185FC5FFC` → `0x185FC5FE0` → SV-MN |
| `NSFontCollection.DidChange` | `NSFontCollection.didChangeNotification` | object `as? NSFontCollection` → `fontCollection` (req); user info `nil` → `nil`; `NSFontCollection.actionUserInfoKey` `as? NSFontCollection.ActionTypeKey` → `action` (req); `.nameUserInfoKey` `as? String` → `collectionName` (opt → `nil`); `.oldNameUserInfoKey` `as? String` → `oldName` (opt → `nil`); `.visibilityUserInfoKey` `as? NSFontCollection.Visibility` → `visibility` (opt → `nil`) | `object: fontCollection`; a `[NSFontCollection.UserInfoKey: Any]` with the action always (the `ActionTypeKey` newtype), and the name, old name (Swift `String`) and visibility (the `Visibility` struct) only when not `nil`; never `nil` | `name` `0x186082594`; mM `0x1860825A4` → `0x186081E6C`; mN `0x1860825A8` → `0x186082350` |

Notes on single rows:

- **`NSFontCollection.DidChange`.** The name is loaded through the GOT slot `0x1E01B9C28`; the
  constant lives in CoreText (`0x1E0656680`), not AppKit. Each key in the result is
  `AnyHashable(NSFontCollection.UserInfoKey)`: its `.base` is the newtype, and hashing and equality go
  through the `String` raw value, so it still matches a `String` or `NSString` key. Section 5.9 covers
  `visibility`.
- **`NSTextAlternatives.SelectedAlternativeString`, `NSTextView.DidChangeSelection`,
  `NSTextView.WillChangeNotifyingTextView`** and `NSTextView.DidChangeTypingAttributes` (section 4.2)
  load their names through GOT slots `0x1E0751728`, `0x1E07517E0`, `0x1E07517F0` and `0x1E07517E8`,
  because the constants are defined in UIFoundation, Apple's private text-system framework, which is
  unrelated to this repository (section 5.10). The class `NSTextAlternatives` is defined there too
  (accessor `0x18611A2AC`).
- **`NSTextView.DidChangeSelection`** has no public initializer, in the public `.swiftinterface` or in
  the RuntimeViewer export of this build. `.rangeValue` is sent to whatever `NSValue` was found, without
  checking its `objCType`.
- **`NSToolbar`**: `NSToolbarItemKey` is available from macOS 13 and `NSToolbarNewIndexKey` from
  macOS 15; their CFString values are `"item"` and `"newIndex"`. Below those versions
  `NSToolbarUserInfoKey(rawValue: "item")` and `(rawValue: "newIndex")` give the same keys.
- **`NSTextView.DidEndEditing`**: `textMovement` is a plain `Int`, not `NSTextMovement`; the key
  `NSTextMovementUserInfoKey` exists from macOS 10.13.
- **`NSSplitView`**: section 5.7.

### 4.4 `NSWorkspace` (20)

No message reads the notification's object or name. Every one writes `object: NSWorkspace.shared`. The
keys are SDK constants used as `String` keys: `NSWorkspace.applicationUserInfoKey`
(`NSWorkspaceApplicationKey`), `.localizedVolumeNameUserInfoKey` (`NSWorkspaceVolumeLocalizedNameKey`),
`.volumeURLUserInfoKey` (`NSWorkspaceVolumeURLKey`), `.oldLocalizedVolumeNameUserInfoKey`
(`NSWorkspaceVolumeOldLocalizedNameKey`) and `.oldVolumeURLUserInfoKey` (`NSWorkspaceVolumeOldURLKey`).

| Shape | `makeMessage` reads | `makeNotification` writes |
|---|---|---|
| Application (A-MM, A-MN) | `applicationUserInfoKey` `as? NSRunningApplication` → `application` (req) | `applicationUserInfoKey`: the `NSRunningApplication` object |
| Volume (V-MM, V-MN) | `localizedVolumeNameUserInfoKey` `as? String` → `localizedVolumeName` (req); `volumeURLUserInfoKey` `as? URL` → `volumeURL` (req) | the name as a Swift `String`, the URL as a Swift `URL` |
| Rename (own bodies) | the two volume keys, then `oldLocalizedVolumeNameUserInfoKey` `as? String` → `oldLocalizedVolumeName` and `oldVolumeURLUserInfoKey` `as? URL` → `oldVolumeURL`, all four req, in that order | all four, Swift `String` and `URL` values |
| None (E-MM, E-MN) | nothing: returns `Self()` | `userInfo: nil` |

In the table below, the `name` column gives the witness and, in brackets, the public getter. All seven
application `makeMessage` witnesses are `0x185E12824` → `0x18523219C` → `0x185E10150` → A-MM, and all
nine without properties are `0x185CF9B04` → B1 (E-MM).

| Message | Kind | Notification | Shape | `name` | `makeMessage` | `makeNotification` |
|---|---|---|---|---|---|---|
| `NSWorkspace.DidActivateApplication` | MainActor | `NSWorkspace.didActivateApplicationNotification` | Application | `0x185E11298` (`0x185E1125C`) | → A-MM | `0x185E112A8` → `0x185E1128C` → A-MN |
| `NSWorkspace.DidDeactivateApplication` | MainActor | `NSWorkspace.didDeactivateApplicationNotification` | Application | `0x185E112E8` (`0x185E112AC`) | → A-MM | `0x185E112F8` → `0x185E112DC` → A-MN |
| `NSWorkspace.DidHideApplication` | MainActor | `NSWorkspace.didHideApplicationNotification` | Application | `0x185E10160` (`0x185E100E4`) | → A-MM | `0x185E10170` → `0x185E10154` → A-MN |
| `NSWorkspace.DidLaunchApplication` | MainActor | `NSWorkspace.didLaunchApplicationNotification` | Application | `0x185E104F0` (`0x185E104B4`) | → A-MM | `0x185E10500` → `0x185E104E4` → A-MN |
| `NSWorkspace.DidTerminateApplication` | MainActor | `NSWorkspace.didTerminateApplicationNotification` | Application | `0x185E106F0` (`0x185E106B4`) | → A-MM | `0x185E10700` → `0x185E106E4` → A-MN |
| `NSWorkspace.DidUnhideApplication` | MainActor | `NSWorkspace.didUnhideApplicationNotification` | Application | `0x185E10450` (`0x185E10174`) | → A-MM | `0x185E10460` → `0x185E102EC` → A-MN |
| `NSWorkspace.WillLaunchApplication` | MainActor | `NSWorkspace.willLaunchApplicationNotification` | Application | `0x185E104A0` (`0x185E10464`) | → A-MM | `0x185E104B0` → `0x185E10494` → A-MN |
| `NSWorkspace.DidMountVolume` | MainActor | `NSWorkspace.didMountNotification` | Volume | `0x185E10864` (`0x185E10704`) | `0x185E10874` → `0x185E1082C` → V-MM | `0x185E10878` → `0x185E10844` → V-MN |
| `NSWorkspace.DidUnmountVolume` | MainActor | `NSWorkspace.didUnmountNotification` | Volume | `0x185E11244` (`0x185E1114C`) | `0x185E11254` → `0x185E1120C` → V-MM | `0x185E11258` → `0x185E11224` → V-MN |
| `NSWorkspace.WillUnmountVolume` | MainActor | `NSWorkspace.willUnmountNotification` | Volume | `0x185E11134` (`0x185E1087C`) | `0x185E11144` → `0x185E10AB0` → V-MM | `0x185E11148` → `0x185E10F20` → V-MN |
| `NSWorkspace.DidRenameVolume` | MainActor | `NSWorkspace.didRenameVolumeNotification` | Rename | `0x185E1216C` (`0x185E112FC`) | `0x185E1217C` → `0x185E11688` | `0x185E12180` → `0x185E11EB8` |
| `NSWorkspace.AccessibilityDisplayOptionsDidChange` | MainActor | `NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` | None | `0x185E1230C` (`0x185E122EC`) | → E-MM | `0x185E1231C` → E-MN |
| `NSWorkspace.ActiveSpaceDidChange` | Async | `NSWorkspace.activeSpaceDidChangeNotification` | None | `0x185E122D0` (`0x185E122B0`) | → E-MM | `0x185E122E0` → E-MN |
| `NSWorkspace.DidChangeFileLabels` | MainActor | `NSWorkspace.didChangeFileLabelsNotification` | None | `0x185E1221C` (`0x185E121FC`) | → E-MM | `0x185E1222C` → E-MN |
| `NSWorkspace.DidWake` | MainActor | `NSWorkspace.didWakeNotification` | None | `0x185E10600` (`0x185E10540`) | → E-MM | `0x185E10610` → E-MN |
| `NSWorkspace.ScreensDidSleep` | Async | `NSWorkspace.screensDidSleepNotification` | None | `0x185E12258` (`0x185E12238`) | → E-MM | `0x185E12268` → E-MN |
| `NSWorkspace.ScreensDidWake` | Async | `NSWorkspace.screensDidWakeNotification` | None | `0x185E12294` (`0x185E12274`) | → E-MM | `0x185E122A4` → E-MN |
| `NSWorkspace.SessionDidBecomeActive` | MainActor | `NSWorkspace.sessionDidBecomeActiveNotification` | None | `0x185E121A4` (`0x185E12184`) | → E-MM | `0x185E121B4` → E-MN |
| `NSWorkspace.SessionDidResignActive` | MainActor | `NSWorkspace.sessionDidResignActiveNotification` | None | `0x185E121E0` (`0x185E121C0`) | → E-MM | `0x185E121F0` → E-MN |
| `NSWorkspace.WillSleep` | MainActor | `NSWorkspace.willSleepNotification` | None | `0x185E10524` (`0x185E10504`) | → E-MM | `0x185E10534` → E-MN |

The three `Async` messages run exactly the code of the main-actor ones: the same `makeMessage` witness,
the same `makeNotification` body, and no executor or isolation check anywhere on the path. Only their
declarations differ, in that the public static functions are not `@MainActor`.

Ten of the name globals are declared without `const` in the SDK (`WillLaunch`, `DidLaunch`,
`DidTerminate`, `DidMount`, `DidUnmount`, `WillUnmount`, `WillSleep`, `DidWake`,
`SessionDidBecomeActive`, `SessionDidResignActive`) and sit in AppKit's `__DATA.__data`
(`0x1E45258B8`–`0x1E4525908`). The getters load them on every call, as `NSWorkspace.<name>` does, so
this has no effect on behaviour.

### 4.5 UIKit messages without properties (35)

`makeMessage` returns `Self()` for any notification (S1). `makeNotification` is Foundation's default,
`Notification(name: Self.name)`: no object and no user info (S2). Every `makeMessage` witness below is
`0x1BDD8EC44` → S1, except those of `UIPasteboard.Removed` and `UITextInputMode.CurrentInputModeDidChange`,
which are S1's body `0x1BCB471B0` itself. The `makeNotification` chains are in the S2 table of
section 3.4. The last column is the exported constant the getter loads.

| Message | Notification | `name` | Constant |
|---|---|---|---|
| `UIAccessibility.AssistiveTouchStatusDidChange` | `UIAccessibility.assistiveTouchStatusDidChangeNotification` | `0x1BE1A60D4` | `0x1E1AD2CC8` |
| `UIAccessibility.BoldTextStatusDidChange` | `UIAccessibility.boldTextStatusDidChangeNotification` | `0x1BE1A6020` | `0x1E1AD2C70` |
| `UIAccessibility.ButtonShapesEnabledStatusDidChange` | `UIAccessibility.buttonShapesEnabledStatusDidChangeNotification` | `0x1BE1A6220` | `0x1E1AD2B90` |
| `UIAccessibility.ClosedCaptioningStatusDidChange` | `UIAccessibility.closedCaptioningStatusDidChangeNotification` | `0x1BE1A6044` | `0x1E1AD2C58` |
| `UIAccessibility.DarkerSystemColorsStatusDidChange` | `UIAccessibility.darkerSystemColorsStatusDidChangeNotification` | `0x1BE1A6068` | `0x1E1AD2CA0` |
| `UIAccessibility.GrayscaleStatusDidChange` | `UIAccessibility.grayscaleStatusDidChangeNotification` | `0x1BE1A608C` | `0x1E1AD2C78` |
| `UIAccessibility.GuidedAccessStatusDidChange` | `UIAccessibility.guidedAccessStatusDidChangeNotification` | `0x1BE1A60F8` | `0x1E1AD2C68` |
| `UIAccessibility.HearingDevicePairedEarDidChange` | `UIAccessibility.hearingDevicePairedEarDidChangeNotification` | `0x1BE1A6188` | `0x1E1AD2CD0` |
| `UIAccessibility.InvertColorsStatusDidChange` | `UIAccessibility.invertColorsStatusDidChangeNotification` | `0x1BE1A60B0` | `0x1E1AD2C60` |
| `UIAccessibility.MonoAudioStatusDidChange` | `UIAccessibility.monoAudioStatusDidChangeNotification` | `0x1BE1A611C` | `0x1E1AD2C50` |
| `UIAccessibility.ReduceMotionStatusDidChange` | `UIAccessibility.reduceMotionStatusDidChangeNotification` | `0x1BE1A61AC` | `0x1E1AD2C88` |
| `UIAccessibility.ReduceTransparencyStatusDidChange` | `UIAccessibility.reduceTransparencyStatusDidChangeNotification` | `0x1BE1A5B54` | `0x1E1AD2C80` |
| `UIAccessibility.ShakeToUndoDidChange` | `UIAccessibility.shakeToUndoDidChangeNotification` | `0x1BE1A61D8` | `0x1E1AD2CC0` |
| `UIAccessibility.SpeakScreenStatusDidChange` | `UIAccessibility.speakScreenStatusDidChangeNotification` | `0x1BE1A6140` | `0x1E1AD2CB8` |
| `UIAccessibility.SpeakSelectionStatusDidChange` | `UIAccessibility.speakSelectionStatusDidChangeNotification` | `0x1BE1A6164` | `0x1E1AD2CB0` |
| `UIAccessibility.SwitchControlStatusDidChange` | `UIAccessibility.switchControlStatusDidChangeNotification` | `0x1BE1A5878` | `0x1E1AD2CA8` |
| `UIAccessibility.VoiceOverStatusDidChange` | `UIAccessibility.voiceOverStatusDidChangeNotification` | `0x1BE1A61FC` | `0x1E1AD2C40` |
| `UIApplication.BackgroundRefreshStatusDidChange` | `UIApplication.backgroundRefreshStatusDidChangeNotification` | `0x1BE1BCBAC` | `0x1E1AF5970` |
| `UIApplication.DidBecomeActive` | `UIApplication.didBecomeActiveNotification` | `0x1BE1BCAA8` | `0x1E1AF4CC0` |
| `UIApplication.DidEnterBackground` | `UIApplication.didEnterBackgroundNotification` | `0x1BE1BCACC` | `0x1E1AF4CB0` |
| `UIApplication.DidFinishLaunching` | `UIApplication.didFinishLaunchingNotification` | `0x1BE1BCA84` | `0x1E1AF4CD0` |
| `UIApplication.DidReceiveMemoryWarning` | `UIApplication.didReceiveMemoryWarningNotification` | `0x1BE1BCB64` | `0x1E1AF4CD8` |
| `UIApplication.ProtectedDataDidBecomeAvailable` | `UIApplication.protectedDataDidBecomeAvailableNotification` | `0x1BE1BCBF4` | `0x1E1AF4E18` |
| `UIApplication.ProtectedDataWillBecomeUnavailable` | `UIApplication.protectedDataWillBecomeUnavailableNotification` | `0x1BE1BCC18` | `0x1E1AF4E10` |
| `UIApplication.SignificantTimeChange` | `UIApplication.significantTimeChangeNotification` | `0x1BE1BCB88` | `0x1E1AF4CF8` |
| `UIApplication.UserDidTakeScreenshot` | `UIApplication.userDidTakeScreenshotNotification` | `0x1BE1BCBD0` | `0x1E1AF4E20` |
| `UIApplication.WillEnterForeground` | `UIApplication.willEnterForegroundNotification` | `0x1BE1BCAF0` | `0x1E1AF4CB8` |
| `UIApplication.WillResignActive` | `UIApplication.willResignActiveNotification` | `0x1BE1BCB14` | `0x1E1AF4CC8` |
| `UIApplication.WillTerminate` | `UIApplication.willTerminateNotification` | `0x1BE1BCB40` | `0x1E1AF4CE0` |
| `UIDevice.BatteryLevelDidChange` | `UIDevice.batteryLevelDidChangeNotification` | `0x1BDD8EB6C` | `0x1E1AE6A78` |
| `UIDevice.BatteryStateDidChange` | `UIDevice.batteryStateDidChangeNotification` | `0x1BDD8EB90` | `0x1E1AE6A70` |
| `UIDevice.OrientationDidChange` | `UIDevice.orientationDidChangeNotification` | `0x1BDD8EBBC` | `0x1E1AE6A60` |
| `UIDevice.ProximityStateDidChange` | `UIDevice.proximityStateDidChangeNotification` | `0x1BDD8EBE0` | `0x1E1AE6A80` |
| `UIPasteboard.Removed` | `UIPasteboard.removedNotification` | `0x1BDEDBAFC` | `0x1E1AF2F68` |
| `UITextInputMode.CurrentInputModeDidChange` | `UITextInputMode.currentInputModeDidChangeNotification` | `0x1BE223128` | `0x1E1AF1D50` |

`UIAccessibility.ButtonShapesEnabledStatusDidChangeMessage` is deprecated in 26.1 according to the
`.swiftinterface`, and is implemented exactly like the others. `UIApplication.DidFinishLaunchingMessage`
neither reads nor writes the launch options.

### 4.6 UIKit messages whose only property is the object (22)

`makeMessage`: `object as? <Class>` (req), stored in the one field; the user info is never read.
`makeNotification`: `object: message.<field>`, `userInfo: nil`. The `makeMessage` chains are in the
O1 / N1 table of section 3.4; every `makeNotification` witness below ends in its class's N1 body.

| Message | Notification | Cast → field | `name` | `makeNotification` |
|---|---|---|---|---|
| `UIScene.DidActivate` | `UIScene.didActivateNotification` | `UIScene` → `scene` | `0x1BE0A83FC` | `0x1BE0A840C` → N1 |
| `UIScene.DidEnterBackground` | `UIScene.didEnterBackgroundNotification` | `UIScene` → `scene` | `0x1BE0A84AC` | `0x1BE0A84BC` → N1 |
| `UIScene.SystemProtectionDidChange` | `UIScene.systemProtectionDidChangeNotification` | `UIScene` → `scene` | `0x1BE0A8144` | `0x1BE0A8154` → N1 |
| `UIScene.WillConnect` | `UIScene.willConnectNotification` | `UIScene` → `scene` | `0x1BE0A829C` | `0x1BE0A82AC` → N1 |
| `UIScene.WillDeactivate` | `UIScene.willDeactivateNotification` | `UIScene` → `scene` | `0x1BE0A8454` | `0x1BE0A8464` → N1 |
| `UIScene.WillEnterForeground` | `UIScene.willEnterForegroundNotification` | `UIScene` → `scene` | `0x1BE0A8364` | `0x1BE0A8374` → N1 |
| `UIWindow.DidBecomeHidden` | `UIWindow.didBecomeHiddenNotification` | `UIWindow` → `window` | `0x1BE1FC888` | `0x1BE1FC898` → N1 |
| `UIWindow.DidBecomeKey` | `UIWindow.didBecomeKeyNotification` | `UIWindow` → `window` | `0x1BE1FC920` | `0x1BE1FC930` → N1 |
| `UIWindow.DidBecomeVisible` | `UIWindow.didBecomeVisibleNotification` | `UIWindow` → `window` | `0x1BE1FC830` | `0x1BE1FC840` → N1 |
| `UIWindow.DidResignKey` | `UIWindow.didResignKeyNotification` | `UIWindow` → `window` | `0x1BE1FCA58` | `0x1BE1FCA68` → N1 |
| `UIScreen.BrightnessDidChange` | `UIScreen.brightnessDidChangeNotification` | `UIScreen` → `screen` | `0x1BDF19B08` | `0x1BDF19B18` → N1 |
| `UIScreen.CapturedDidChange` | `UIScreen.capturedDidChangeNotification` | `UIScreen` → `screen` | `0x1BDF19BF8` | `0x1BDF19C08` → N1 |
| `UIScreen.ModeDidChange` | `UIScreen.modeDidChangeNotification` | `UIScreen` → `screen` | `0x1BDF19BA0` | `0x1BDF19BB0` → N1 |
| `UIScreen.ReferenceDisplayModeStatusDidChange` | `UIScreen.referenceDisplayModeStatusDidChangeNotification` | `UIScreen` → `screen` | `0x1BDF19D30` | `0x1BDF19D40` → N1 |
| `UITextView.TextDidBeginEditing` | `UITextView.textDidBeginEditingNotification` | `UITextView` → `textView` | `0x1BE28E068` | `0x1BE28E078` → N1 |
| `UITextView.TextDidChange` | `UITextView.textDidChangeNotification` | `UITextView` → `textView` | `0x1BE28E200` | `0x1BE28E210` → N1 |
| `UITextView.TextDidEndEditing` | `UITextView.textDidEndEditingNotification` | `UITextView` → `textView` | `0x1BE28E2C8` | `0x1BE28E2D8` → N1 |
| `UITextField.TextDidBeginEditing` | `UITextField.textDidBeginEditingNotification` | `UITextField` → `textField` | `0x1BDD93320` | `0x1BDD93330` → N1 |
| `UITextField.TextDidChange` | `UITextField.textDidChangeNotification` | `UITextField` → `textField` | `0x1BDD934C8` | `0x1BDD934D8` → N1 |
| `UIDocument.StateChanged` | `UIDocument.stateChangedNotification` | `UIDocument` → `document` | `0x1BDE10FC4` | `0x1BDE10FD8` (the witness) |
| `UIViewController.ShowDetailTargetDidChange` | `UIViewController.showDetailTargetDidChangeNotification` | `UIViewController` → `viewController` | `0x1BE022618` | `0x1BE02262C` (the witness) |
| `UITableView.SelectionDidChange` | `UITableView.selectionDidChangeNotification` | `UITableView` → `tableView` | `0x1BE1A8A0C` | `0x1BE1A8A20` (the witness) |

`UITextView.TextDidEndEditingMessage` carries no reason, unlike `UITextField`'s.

### 4.7 UIKit messages with user info (14)

Every key is an SDK constant, used as a `String` key. The six keyboard messages have `UIScreen` as their
subject, and so does `UIContentSizeCategory.DidChangeMessage`.

| Message | Notification | `makeMessage` reads | `makeNotification` writes | Addresses |
|---|---|---|---|---|
| `UIAccessibility.AnnouncementDidFinish` | `UIAccessibility.announcementDidFinishNotification` | user info `nil` → `nil`; `UIAccessibility.announcementStringValueUserInfoKey` `as? String` → `announcement` (req); `.announcementWasSuccessfulUserInfoKey` `as? Bool` → `wasSuccessful` (req); the object is ignored | `object: nil`; the two keys, a Swift `String` and a Swift `Bool` | `name` `0x1BE1A5FF4`; mM `0x1BE1A6004` → `0x1BE1A5C38`; mN `0x1BE1A6008` → `0x1BE1A5E7C` |
| `UIAccessibility.ElementFocused` | `UIAccessibility.elementFocusedNotification` | `userInfo?[UIAccessibility.focusedElementUserInfoKey] as? AnyObject`, applied to the optional result without unwrapping it → `element`; never `nil`: a missing element gives `NSNull` (section 5.14) | `object: nil`; `focusedElementUserInfoKey`: `element` as an `Optional<AnyObject>`, written even when `nil` | `name` `0x1BE1A5B28`; mM `0x1BE1A5B38` → `0x1BE1A58F4`; mN `0x1BE1A5B3C` → `0x1BE1A5A18` |
| `UIPasteboard.Changed` | `UIPasteboard.changedNotification` | user info `nil` → `nil`; `UIPasteboard.changedTypesAddedUserInfoKey` `as? [String]` → `typesAdded` (req); `.changedTypesRemovedUserInfoKey` `as? [String]` → `typesRemoved` (req); the object is ignored | `object: nil`, not the pasteboard; both keys always, Swift `[String]`, empty arrays included | `name` `0x1BDEDBAC8`; mM `0x1BDEDBAD8` → `0x1BDEDB6F0`; mN `0x1BDEDBADC` → `0x1BDEDB93C` |
| `UIContentSizeCategory.DidChange` | `UIContentSizeCategory.didChangeNotification` | user info `nil` → `nil`; `UIContentSizeCategory.newValueUserInfoKey` `as? String` → `contentSize` (req); then object `as? UIScreen` → `screen` (req) | `object: screen`; `newValueUserInfoKey`: Swift `String` | `name` `0x1BE023428`; mM `0x1BE023438` → `0x1BE023160`; mN `0x1BE02343C` → `0x1BE023310` |
| `UIFocusSystem.DidUpdate` | `UIFocusSystem.didUpdateNotification` | object `as? UIFocusSystem` → `focusSystem` (req, checked first); `UIFocusSystem.focusUpdateContextUserInfoKey` `as? UIFocusUpdateContext` → `updateContext` (opt → `nil`); `.animationCoordinatorUserInfoKey` `as? UIFocusAnimationCoordinator` → `animationCoordinator` (opt → `nil`) | `object: focusSystem`; both keys always, each holding the `Optional` itself (`value as Any`) | `name` `0x1BE1A278C`; mM `0x1BE1A279C` → `0x1BE1A22FC`; mN `0x1BE1A27A0` → `0x1BE1A25D8` |
| `UIFocusSystem.MovementDidFail` | `UIFocusSystem.movementDidFailNotification` | object `as? UIFocusSystem` → `focusSystem` (req, checked first); `focusUpdateContextUserInfoKey` `as? UIFocusUpdateContext` → `updateContext` (opt → `nil`) | `object: focusSystem`; the key always, holding the `Optional` | `name` `0x1BE1A2B70`; mM `0x1BE1A2B80` → `0x1BE1A2884`; mN `0x1BE1A2B84` → `0x1BE1A2A40` |
| `UIPointerLockState.DidChange` | `UIPointerLockState.didChangeNotification` | user info `nil` → `nil`; `UIPointerLockState.sceneUserInfoKey` (value `"scene"`) `as? UIScene` → `scene` (req); then object `as? UIPointerLockState` → `pointerLockState` (req) | `object: pointerLockState`; `sceneUserInfoKey`: the `UIScene` object | `name` `0x1BE13FB88`; mM `0x1BE13FB98` → `0x1BE13F88C`; mN `0x1BE13FB9C` → `0x1BE13FA50` |
| `UITextField.TextDidEndEditing` | `UITextField.textDidEndEditingNotification` | object `as? UITextField` → `textField` (req, checked first); `UITextField.didEndEditingReasonUserInfoKey` `as? UITextField.DidEndEditingReason` → `reason` (opt → `nil`) | `object: textField`; the key always, holding `Optional<UITextField.DidEndEditingReason>` | `name` `0x1BDD938F4`; mM `0x1BDD93904` → `0x1BDD93600`; mN `0x1BDD93908` → `0x1BDD937BC` |
| `UIResponder.KeyboardWillShow` | `UIResponder.keyboardWillShowNotification` | K1: five keys and the object, all req | K2 | `name` `0x1BDF1438C`; mM `0x1BDF150E4` → K1; mN `0x1BDF1439C` → K2 |
| `UIResponder.KeyboardDidShow` | `UIResponder.keyboardDidShowNotification` | K1 | K2 | `name` `0x1BDF14534`; mM `0x1BDF150E4` → K1; mN `0x1BDF14544` → K2 |
| `UIResponder.KeyboardWillHide` | `UIResponder.keyboardWillHideNotification` | K1 | K2 | `name` `0x1BDF146DC`; mM `0x1BDF150E4` → K1; mN `0x1BDF146EC` → K2 |
| `UIResponder.KeyboardDidHide` | `UIResponder.keyboardDidHideNotification` | K1 | K2 | `name` `0x1BDF14920`; mM `0x1BDF150E4` → K1; mN `0x1BDF14930` → K2 |
| `UIResponder.KeyboardWillChangeFrame` | `UIResponder.keyboardWillChangeFrameNotification` | K1 | K2 | `name` `0x1BDF14AC8`; mM `0x1BDF150E4` → K1; mN `0x1BDF14AD8` → K2 |
| `UIResponder.KeyboardDidChangeFrame` | `UIResponder.keyboardDidChangeFrameNotification` | K1 | K2 | `name` `0x1BDF14D64`; mM `0x1BDF150E4` → K1; mN `0x1BDF14D74` → K2 |

The folded keyboard `makeMessage` (`0x1BDF14C34`) carries `KeyboardDidHideMessage`'s symbol name, but
it is the same code for all six.

## 5. Findings that a re-implementation gets wrong

### 5.1 Required values, and the few that are optional

Most messages with properties are all or nothing. A missing value, a `nil` user info or a value of
another type gives `nil` — for the object as much as for a user-info entry — and the observer never
runs. These are the exceptions, where a missing value only empties one field:

| Message | Field when missing or of another type | `makeNotification` when the field is `nil` |
|---|---|---|
| `NSSplitView.WillResizeSubviews`, `DidResizeSubviews` | `dividerIndex` → `nil`; `userResize` → `false` | divider key left out; user-resize key always written |
| `NSTextView.DidChangeSelection` | `oldSelectedCharacterRange` → `nil` | key left out, `userInfo: nil` |
| `NSTextView.DidEndEditing` | `textMovement` → `nil` | key left out, `userInfo: nil` |
| `NSTextView.WillChangeNotifyingTextView` | `oldNotifyingTextView`, `newNotifyingTextView` → `nil` | keys left out; `userInfo: nil` when both are `nil` |
| `NSWindow.DidChangeBackingProperties` | `oldScaleFactor`, `oldColorSpace` → `nil` | keys left out; `userInfo: nil` when both are `nil` |
| `NSFontCollection.DidChange` | `collectionName`, `oldName`, `visibility` → `nil`; the object and `action` stay required | keys left out; never `nil`, since `action` is always written |
| `UIFocusSystem.DidUpdate`, `MovementDidFail` | `updateContext` → `nil`; `animationCoordinator` (`DidUpdate` only) → `nil` | key written, holding `Optional.none` |
| `UITextField.TextDidEndEditing` | `reason` → `nil` | key written, holding `Optional.none` |
| `UIAccessibility.ElementFocused` | `element` → `NSNull` (section 5.14) | key written, holding `Optional.none` |

The two frameworks treat a `nil` field differently. AppKit leaves its key out and passes
`userInfo: nil` when nothing is left. UIKit writes the key anyway, holding the `Optional` boxed as
`Any`; that becomes `NSNull` once the notification is bridged to Objective-C, and `as?` reads it back
as `nil`.

The order of the checks differs too: AppKit reads the object first and skips the user info when it
fails, while `UIContentSizeCategory.DidChange`, `UIPointerLockState.DidChange` and the keyboard
messages read the object last. Every failure gives the same `nil`.

### 5.2 Messages without properties accept any notification

B1, E-MM and S1 never look at the notification: not its name, not its object, not its user info.
`makeMessage` returns `Self()` even for a notification posted under another name with an unrelated
object. A re-implementation that checks the name or the object rejects notifications Apple's
implementation accepts.

### 5.3 Which object `makeNotification` writes

| Messages | `object:` |
|---|---|
| 17 `NSApplication` | `NSApplication.shared`; `+sharedApplication` is sent on every call and creates the application object if there is none yet |
| 8 `NSSpellChecker` | `NSSpellChecker.shared`, also fetched on every call |
| 2 `NSHelpManager` | `NSHelpManager.shared`, also fetched on every call |
| 20 `NSWorkspace` | `NSWorkspace.shared` |
| `NSFont`, `NSColor`, `NSScroller`, `NSTextInputContext` | `nil` |
| 35 UIKit messages without properties | `nil` — not `UIApplication.shared`, `UIDevice.current` or the pasteboard |
| `UIAccessibility.AnnouncementDidFinish`, `UIAccessibility.ElementFocused`, `UIPasteboard.Changed` | `nil` |
| every other message | the subject, `message.<field>`, boxed with the field's static class |

### 5.4 `NSWorkspace` writes its object and never reads it

No `NSWorkspace` `makeMessage` reads `notification.object` or `notification.name`; the only thing read
is the user info. A notification with any object, or none, converts as long as its user info is right.
Every `makeNotification` writes `object: NSWorkspace.shared`, the nine without properties included, and
those nine pass `userInfo: nil`, not `[:]`. They are not `Notification(name: Self.name)`. All four of
`DidRenameVolumeMessage`'s values are required.

### 5.5 Stored value types

`makeNotification` stores Swift values boxed in `Any`, not their Objective-C counterparts. Tests that
compare value types, not just values, must expect these:

| Value | Stored as | Messages |
|---|---|---|
| integers | Swift `Int` | `NSMenu` item index; `NSTableView` and `NSOutlineView` column indexes; `NSToolbar` new index; `NSTextView.DidEndEditing` movement; `NSSplitView` divider index |
| Booleans | Swift `Bool` | `NSSplitView` user resize; `UIAccessibility.AnnouncementDidFinish`; keyboard `isLocal` |
| widths and scale factors | Swift `CGFloat` | column `oldWidth`; `oldScaleFactor` |
| a duration | Swift `Double` | keyboard `animationDuration` |
| strings | Swift `String` | `NSTextAlternatives`; `NSFontCollection` names; `NSWorkspace` volume names; `UIContentSizeCategory`; `UIAccessibility` announcement |
| URLs | Swift `URL` | `NSWorkspace` volume URLs |
| string arrays | Swift `[String]` | `UIPasteboard.Changed` |
| rectangles | Swift `CGRect` | `NSWindow.DidExpose`; keyboard frames |
| a range | `NSValue(range:)`, the one `NSValue` | `NSTextView.DidChangeSelection` |
| enumerations, option sets and newtypes | the imported type itself | `NSPopover.CloseReason`; `NSFontCollection.ActionTypeKey`; `NSFontCollection.Visibility`; `UIView.AnimationCurve`; `UITextField.DidEndEditingReason` (as an `Optional`) |
| objects | the object | field editor, table column, toolbar item, color space, notifying text views, running application, scene; the focus context and coordinator (as `Optional`s); the accessibility element (as `Optional<AnyObject>`) |
| the outline view's item | the stored `Any`, its dynamic type unchanged | the four `NSOutlineView` item messages |

On the reading side, `as? Int`, `as? CGFloat` and `as? CGRect` accept the `NSNumber` and `NSValue` that
AppKit posts, and `as? String` and `as? URL` accept `NSString` and `NSURL`. Two reads demand an
Objective-C class instead: `NSTextView.DidChangeSelection` (`as? NSValue`) and the keyboard frames and
curve (`as? NSValue`, `as? NSNumber`). Section 5.13 shows what that does to the keyboard messages.

### 5.6 Keys

- **Swift string literals in the binary**, where no SDK constant exists or none is used:
  `"NSFieldEditor"`, `"NSMenuItemIndex"`, `"NSObject"`, `"NSOldColumn"`, `"NSNewColumn"`,
  `"NSTableColumn"`, `"NSOldWidth"`, `"NSAlternativeString"`, `"NSOldSelectedCharacterRange"`,
  `"NSOldNotifyingTextView"`, `"NSNewNotifyingTextView"`, `"NSExposedRect"`.
- **Exported AppKit globals that no SDK header declares**: the two `NSSplitView` keys (section 5.7).
- **Typed keys.** `NSToolbar` and `NSFontCollection` use SDK constants of an `NS_TYPED_ENUM` newtype
  (`NSToolbarUserInfoKey`, `NSFontCollection.UserInfoKey`) and look them up and write them as
  `AnyHashable` of that newtype, not of `String`. They hash and compare equal to the `String` key, but
  `key.base` is the newtype, so a test that compares key types must expect it. Every other key is
  `AnyHashable(String)`.
- **Everything else is an SDK constant bridged to `String`**: `NSPopover.closeReasonUserInfoKey`,
  `NSText.movementUserInfoKey`, the two backing-property keys, every `NSWorkspace` key and every UIKit
  key. Two UIKit values are surprising:
  `UITextField.didEndEditingReasonUserInfoKey` is `"UITextFieldEndEditingReasonKey"`, without "Did",
  and `UIPointerLockState.sceneUserInfoKey` is `"scene"`.

### 5.7 `NSSplitView`

- Both keys are AppKit globals, `_NSSplitViewDividerIndexKey` and `_NSSplitViewUserResizeKey`. AppKit
  exports them (they are listed in `AppKit.tbd`), but no SDK header declares them; the header only
  mentions `@"NSSplitViewDividerIndex"` in a comment. A re-implementation has to spell out the values:
  `"NSSplitViewDividerIndex"` (23 characters, with no `Key` suffix) and `"NSSplitViewUserResizeKey"`
  (24 characters, with one).
- **`userResize` is `false` when its key is missing or holds something other than a `Bool`.** The public
  `init(splitView:dividerIndex:userResize: Bool? = nil)` stores `userResize ?? false` as well
  (`AND W9, W3, #1`: a `nil` `Bool?` is encoded as 2, which the mask turns into `false`).
- `makeNotification` writes the divider index only when it is set and the flag always, so its user
  info is never `nil`.
- The two messages share `makeMessage`, `makeNotification` and `init` (`0x185FC60CC`;
  `WillResizeSubviewsMessage`'s `init` at `0x185FC6600` is `B 0x185FC60CC`).

### 5.8 `NSImageRep.RegistryDidChangeMessage`

`makeMessage` requires `object as? NSImageRep`. AppKit's own posters,
`+[NSImageRep registerImageRepClass:]` (`0x1854AE2D4`) and `+[NSImageRep unregisterImageRepClass:]`
(`0x1854AE3B0`), call `postNotificationName:object:` with the class they were given as the object
(X3 = `imageRepClass`). A class object is not an `NSImageRep` instance, so the cast fails and every
notification AppKit itself posts converts to `nil`. Measured (section 6.4): both notifications carry the
class, and AppKit's own `makeMessage` returns `nil` for each. Reproduce the cast as it is.

### 5.9 Ranges, rectangles and `NSFontCollection`'s visibility

- `NSTextView.DidChangeSelectionMessage` reads `"NSOldSelectedCharacterRange"` with `as? NSValue`,
  then `.rangeValue`, and writes it back as `NSValue(range:)` (`+[NSValue valueWithRange:]`). With no
  range, its user info is `nil`.
- `NSWindow.DidExposeMessage` does the opposite: a direct `as? CGRect`, not `as? NSValue` plus
  `.rectValue`. An `NSValue` holding a rect passes; an `NSValue` holding anything else fails, and the
  message is `nil`. It writes a Swift `CGRect`, not an `NSValue`.
- `NSFontCollection.DidChangeMessage` casts the visibility straight to `NSFontCollection.Visibility`,
  with no `NSNumber` or `rawValue` step. AppKit posts that value as an `NSNumber`, and an imported
  `NS_OPTIONS` type gets no `_ObjectiveCBridgeable` conformance (the Clang importer synthesizes one only
  for `swift_newtype` types), so an `NSNumber` visibility reads `nil`. Measured: the test "A visibility
  posted as an NSNumber reads as nil" gets `nil` from AppKit's `makeMessage` and this library's alike.
  `action`, a `String`-backed newtype, does bridge. In the other direction, the stored `Visibility`
  struct would not become an `NSNumber` when bridged to Objective-C (*inferred*).
- **For the notifications AppKit itself posts, the whole message is `nil`, not just the visibility.**
  Measured (section 6.4): showing and hiding a collection posts `NSFontCollectionDidChangeNotification`
  with no object at all, and the object is required, so AppKit's own `makeMessage` returns `nil`.

### 5.10 Constants defined outside AppKit

`NSFont.FontSetChangedMessage`'s name is not AppKit's own. Its getter and its `makeNotification` both
load the constant through AppKit's GOT slot `0x1E0751550`, which points at `0x1E45779A8`:
`_NSFontSetChangedNotification` in the `__DATA.__data` of **UIFoundation, Apple's private text-system
framework — unrelated to this repository despite the shared name**. Apple's UIFoundation also defines
`NSTextView.didChangeSelectionNotification`, `didChangeTypingAttributesNotification`,
`willChangeNotifyingTextViewNotification`, `NSTextAlternatives.selectedAlternativeStringNotification`
and the class `NSTextAlternatives` itself, all loaded through AppKit's GOT (section 4.3).
`NSFontCollection.didChangeNotification` comes from CoreText. All of them are reachable through their
AppKit Swift names.

### 5.11 Constant names that do not follow `<Type>.<name>Notification`

| Message | Constant, in Swift |
|---|---|
| `NSApplication.DidUpdateWindowsMessage` | `NSApplication.didUpdateNotification` (`NSApplicationDidUpdateNotification`: no "Windows") |
| `NSApplication.WillUpdateWindowsMessage` | `NSApplication.willUpdateNotification` (no "Windows") |
| `NSApplication.ProtectedDataDidBecomeAvailableMessage` | `NSNotification.Name.NSApplicationProtectedDataDidBecomeAvailable` |
| `NSApplication.ProtectedDataWillBecomeUnavailableMessage` | `NSNotification.Name.NSApplicationProtectedDataWillBecomeUnavailable` |
| `NSSpellChecker.DidChangeAutomaticInlinePredictionMessage` | `NSNotification.Name.NSSpellCheckerDidChangeAutomaticInlinePrediction` |
| `NSWorkspace.DidMountVolumeMessage` | `NSWorkspace.didMountNotification` (no "Volume") |
| `NSWorkspace.WillUnmountVolumeMessage` | `NSWorkspace.willUnmountNotification` |
| `NSWorkspace.DidUnmountVolumeMessage` | `NSWorkspace.didUnmountNotification` |
| `NSTextView.DidBeginEditingMessage`, `DidChangeMessage`, `DidEndEditingMessage` | `NSText.didBeginEditingNotification`, `NSText.didChangeNotification`, `NSText.didEndEditingNotification`: `NSText`'s constants, with `NSText` as the subject |

The three `NSNotification.Name` globals are not members of any type. `AppKit.apinotes` renames the two
`NSApplication` ones to bare names, and the inline-prediction one has no apinote at all; a
`swiftc -typecheck` probe against the macOS 27.0 SDK confirmed that `NSApplication.…Notification` and
`NSSpellChecker.didChangeAutomaticInlinePredictionNotification` do not exist.

UIKit has two kinds of surprise:

- `UIApplication.ProtectedDataDidBecomeAvailableMessage` and `…WillBecomeUnavailableMessage` load the
  exports `UIApplicationProtectedDataDidBecomeAvailable` and
  `UIApplicationProtectedDataWillBecomeUnavailable`, with no `Notification` suffix. Their Swift names
  carry it: `UIApplication.protectedDataDidBecomeAvailableNotification`.
- Five `UIAccessibility` constants hold the text of an older notification. Use the constant, never a
  string spelled after the symbol:

| Constant | String value |
|---|---|
| `UIAccessibility.voiceOverStatusDidChangeNotification` | `"UIAccessibilityVoiceOverTouchStatusChanged"` — the same CFString object (`0x1ECE29BB8`) as the deprecated `UIAccessibilityVoiceOverStatusChanged` (export `0x1E1AD2C48`), so both spellings give an identical name |
| `UIAccessibility.closedCaptioningStatusDidChangeNotification` | `"UIAccessibilityClosedCaptioningChanged"` |
| `UIAccessibility.guidedAccessStatusDidChangeNotification` | `"UIAccessibilityGuidedAccessStateChanged"` |
| `UIAccessibility.invertColorsStatusDidChangeNotification` | `"UIAccessibilityInvertColorsChanged"` |
| `UIAccessibility.monoAudioStatusDidChangeNotification` | `"UIAccessibilityMonoAudioStatusChanged"` |

Three private look-alikes are different strings, and no getter uses them:
`_UIAccessibilityButtonShapesChangedNotification` (`0x1E1AD2B98`),
`_UIAccessibilityDarkenSystemColorsChangedNotification` (`0x1E1AD2BC0`) and
`_UIAccessibilityReduceMotionChangedNotification` (`0x1E1AD2B78`).

### 5.12 Casts accept subclasses

Every object cast is a class `as?`, so a subclass passes: an `NSPanel` for `NSWindow`, an `NSTextView`
or a field editor for `NSText`, an `NSOutlineView` for `NSTableView`. An outline view's notification
posted under an `NSTableView` name therefore decodes as an `NSTableView` message. A `nil` object and an
object of another class give the same `nil`.

### 5.13 The keyboard messages

- **All six values are required**: the five user-info entries and `object as? UIScreen`, which is
  checked last. The subject is `UIScreen`, not `UIResponder`.
- **The frames are read as `NSValue`** and converted with `.cgRectValue`, which is sent only after
  every check has passed.
- The duration is read `as? Double`, and `isLocal` `as? Bool`.
- **The curve is read as `NSNumber`**, and its raw integer goes through
  `UIView.AnimationCurve(rawValue:)!`. The force-unwrap never fails: `UIViewAnimationCurve` is a
  non-frozen `NS_ENUM`, and for those the Clang importer synthesizes a raw-value initializer that only
  reinterprets the value (Swift's `SwiftDeclSynthesizer.cpp`, `synthesizeEnumRawValueConstructorBody`).
  So the raw store is reproduced, the undocumented curve 7 included.
- **`makeNotification` writes Swift values**: two `CGRect`s, a `Double`, a `UIView.AnimationCurve` and
  a `Bool`, with `object: message.screen`.
- **So a notification made from a message does not convert back.** An imported enum never casts to
  `NSNumber` — `UIViewAnimationCurve` has no `_ObjectiveCBridgeable` conformance in UIKitCore, only
  `Equatable` and `RawRepresentable` (Swift runtime source, `DynamicCast.cpp`) — so
  `makeMessage(makeNotification(message))` is `nil`. Measured on Mac Catalyst 27.0 for
  `KeyboardWillShowMessage`: UIKit's own pair gives `nil`, and so does this library's (the test "A
  keyboard notification made from a message does not convert back"); the six share one body. Whether a
  Swift `CGRect` would pass `as? NSValue` was not checked and does not change that. Reproduce both sides
  as they are; do not "fix" either.

### 5.14 `UIAccessibility.ElementFocusedMessage`

`makeMessage` never returns `nil`. It looks the element up with
`notification.userInfo?[UIAccessibility.focusedElementUserInfoKey]` and passes the resulting `Any?`
straight to `swift_dynamicCast`, with source type `Any?` (mangled `ypSg`), target `AnyObject` and
flags 6: `as? AnyObject` applied to the optional itself. On success the result becomes `element`; on
failure `element` is `nil`. In this layout `Optional<ElementFocusedMessage>.none` would be the
extra-inhabitant value 1, which is never written.

What the cast gives was derived from the Swift compiler and runtime sources, and the first row below
was then measured on Mac Catalyst 27.0: for a notification with no user info, UIKit's own
`makeMessage` and this library's both produce an `element` that is `NSNull` (the test
"ElementFocusedMessage holds NSNull when the notification carries no element", and the parity
fixtures' "no user info" variant). The type checker classifies any `x as? AnyObject` as a bridging
conversion before it unwraps optionals, so the runtime receives the whole `Any?`. For a `nil` optional,
the runtime's `tryCast` fails its first four steps and then bridges the `Optional` itself, whose
`_bridgeToObjectiveC()` returns `NSNull`:

| The user info holds | `element` |
|---|---|
| no such key, or there is no user info | `NSNull` |
| a class instance | that instance |
| `NSNull` | `NSNull` |
| a Swift value | its bridged object (`String` → `NSString`, …) or a `__SwiftValue` box |
| `Optional<AnyObject>.none`, as `makeNotification` writes it | `NSNull` |

So in practice `element` is never `nil`. Write the conversion literally:
`ElementFocusedMessage(element: notification.userInfo?[UIAccessibility.focusedElementUserInfoKey] as? AnyObject)`.
Unwrapping with `if let` first gives `nil` where UIKit gives `NSNull`.
`AnnouncementDidFinishMessage` and `UIPasteboard.ChangedMessage`, which cast to `String`, `Bool` and
`[String]`, do unwrap before the cast.

`makeNotification` writes the key even when `element` is `nil`, holding `Optional<AnyObject>.none`
(type metadata `yXlSg`), which bridges to `NSNull` when the notification becomes an `NSNotification`.

### 5.15 Other UIKit details

- **`UIPasteboard.ChangedMessage`** needs both type lists. A notification that carries only one of them
  gives `nil`, not a message with an empty list. `makeNotification` writes both keys, empty arrays
  included, and `object: nil` — not the pasteboard. An `NSArray` posted from Objective-C goes through
  Swift's conditional array bridging, so every element must be a string.
- **`UIContentSizeCategory.DidChangeMessage`** reads the new category as a `String`, not as a
  `UIContentSizeCategory`. That accepts the `NSString` UIKit posts, but a Swift `UIContentSizeCategory`
  value put into a Swift user info would not cast to `String`, since a struct-to-struct cast never
  takes a bridging hop (*inferred*). UIKit's poster,
  `-[_UIContentSizeCategoryPreferenceSystem _postContentSizeCategoryDidChangeNotificationForCarPlay:]`
  (`0x1BD953154`), uses `+[UIScreen _mainScreen]` as the object (`nil` when there is no screen) for
  apps linked on or after the iOS 10 SDK and `UIApp` otherwise, for which `makeMessage` returns `nil`.
  It also adds `UIContentSizeCategoryTextLegibilityEnabledKey`, which is ignored.
- **`UITextField.TextDidEndEditingMessage`** casts the reason straight to
  `UITextField.DidEndEditingReason`, not to `Int` or `NSNumber`. UIKit's own poster,
  `-[UITextField _notifyDidEndEditing]` (`0x1BDA32A94`), stores `@(0)`
  (`+[NSNumber numberWithInteger:0]`) under that key, and an `NSNumber` never casts to an imported
  `NS_ENUM`, which has no `_ObjectiveCBridgeable` conformance. So for the notifications UIKit posts,
  `reason` is always `nil`. The cast was measured on Mac Catalyst 27.0: a reason posted as
  `NSNumber(value: 0)` reads `nil` in UIKit's `makeMessage` and this library's alike (the test "A text
  field's end-editing reason posted as an NSNumber reads as nil"); the poster storing an `NSNumber` is
  static analysis.
- **`UIPointerLockState.DidChangeMessage`** takes the lock state from the object and the scene from
  the user info; both are required.
- **`UIFocusSystem.DidUpdateMessage` and `MovementDidFailMessage`** require only the object. The
  context and the coordinator degrade to `nil` one at a time.

### 5.16 Round trips are lossy

`makeNotification` writes only the keys listed in section 4, and `makeMessage` reads only those. Any
other entry a poster adds is dropped: for example the `@"MenuItem"` that Apple documents for the
`NSMenu` send-action notifications, the launch options of `UIApplication.DidFinishLaunching`, the
`@"NSDevicePath"` documented for the `NSWorkspace` unmount notifications, and
`UIContentSizeCategoryTextLegibilityEnabledKey`. Whether AppKit itself posts extra keys on the other
notifications was not examined. The object does not survive either where `makeNotification` writes a
fixed one: a singleton, or `nil`.

## 6. Measurements from the test suite

These come from running code, not from reading the binaries. Sections 6.1 to 6.3 were measured on
macOS 27.0 in a `swift test` process with no `NSApplication` instance, section 6.4 in a standalone
probe executable on the same system.

### 6.1 `NSToolbar` posts the add notification late

After `insertItem(withItemIdentifier:at:)`, `NSToolbarWillAddItemNotification` was posted only once
something read `toolbar.items` afterwards: 0 posts without that read, 1 with it. Reading `items`
before the insertion did not help. `removeItem(at:)` posted `NSToolbarDidRemoveItemNotification` at
once.

A standalone probe executable doing the same posted as expected. Re-stamping that probe's
`LC_BUILD_VERSION` SDK to 14.0, 15.0, 26.0 and 27.0 changed nothing, so the SDK a binary is linked
against is not the cause. A test that waits for the add notification has to read `items` after
inserting.

### 6.2 A window that was never ordered in

On an `NSWindow` that was never ordered in, `setFrame(_:display:)` with a new origin and a new size
posted `NSWindowDidResizeNotification` but not `NSWindowDidMoveNotification`. `setFrameOrigin(_:)`
posted the move.

### 6.3 Which message a shorthand picks

`.selectionDidChange`, `.selectionIsChanging`, `.columnDidMove` and `.columnDidResize` each name both
an `NSTableView` message and an `NSOutlineView` message. Checked with a compile probe against the
macOS 27 SDK, Apple's API and the backport behave alike:

| Call | Resolves to |
|---|---|
| `addObserver(of: outlineView, for: .selectionDidChange)`, with an outline view instance | nothing: the call is ambiguous |
| `addObserver(of: NSOutlineView.self, for: .selectionDidChange)` | `NSOutlineView`'s message |
| `addObserver(of: tableView, for: .selectionDidChange)`, with a plain `NSTableView` instance | `NSTableView`'s message |

So on an outline view, name the message type, or pass the metatype.

### 6.4 What AppKit posts for two messages that never arrive

A probe observed the raw notifications and handed each to AppKit's own `makeMessage`:

| Action | Notification as posted | AppKit's `makeMessage` |
|---|---|---|
| `NSImageRep.registerClass(_:)`, then `unregisterClass(_:)`, with an `NSImageRep` subclass | object: the subclass itself, a class object, not an instance; no user info | `nil`, both times |
| `NSFontCollection.show(_:withName:visibility:)`, then `hide(withName:visibility:)`, with `.process` visibility | no object; `NSFontCollectionName` (a string), `NSFontCollectionAction` (`NSFontCollectionWasShown`, then `…WasHidden`), `NSFontCollectionVisibility` (`NSNumber` 1) | `nil`, both times: the object is required |

So `NSImageRep.RegistryDidChangeMessage` and `NSFontCollection.DidChangeMessage` never reach an observer
for these AppKit-posted notifications, in AppKit's API as in this library's. Renaming a collection, and
the other visibilities, were not tried.

## 7. Apple documentation that disagrees with the binary or the SDK

Apple's documentation pages for these messages have no message-level summaries. Where a page is wrong
or contradicts the SDK, this library's doc comments follow the SDK headers instead.

- `NSWindow.DidExitFullScreenMessage`: the Discussion is a copy of `didExposeNotification`'s.
- `UIWindow.DidResignKeyMessage`: says "main window" where it means the key window.
- `NSOutlineView.ItemWillExpandMessage`: says "but before the item is collapsed".
- `NSSpellChecker.DidChangeAutomaticSpellingCorrectionMessage` and `…TextReplacementMessage`: the pages
  say "changed text"; `NSSpellChecker.h` says all eight are posted when the user's settings change. Six
  other `NSSpellChecker` pages have neither a summary nor a Discussion, only the Swift concurrency
  pointer.
- `NSApplication.WillTerminateMessage`: the summary reads "Sends a notification to terminate the app."
- `NSWorkspace` `WillLaunchApplication`, `DidActivateApplication`, `DidDeactivateApplication`,
  `DidHideApplication`, `DidUnhideApplication`, `DidUnmountVolume` and `WillUnmountVolume`: the pages
  name "the Finder" as the actor, and `DidActivateApplication` even says "about to activate".
- `UIAccessibility.AssistiveTouchStatusDidChangeMessage`: the Discussion has a sentence about Guided
  Access.
- `UIAccessibility.MonoAudioStatusDidChangeMessage`: mentions only a change "from stereo to mono".
- `UITextField.TextDidEndEditingMessage`: says "The `userInfo` dictionary is not used", yet
  `didEndEditingReasonUserInfoKey` exists, the message carries `reason`, and UIKit's `makeNotification`
  writes the key (section 4.7).
- `NSFont.FontSetChangedMessage`: the summary's "currently-set font" means the set of available fonts
  (`NSFont.h`).
- Objects described unlike the field's type: `NSImageRep.RegistryDidChangeMessage.imageRep` (Apple: the
  registered class, which is indeed what AppKit posts; section 5.8),
  `NSPopUpButtonCell.WillPopUpMessage.popUpButtonCell` (Apple: the button or its cell) and
  `NSTextView.WillChangeNotifyingTextViewMessage.textView` (Apple: may be `nil`).
- User-info entries documented with no field to hold them: `NSMenu.WillSendActionMessage` and
  `DidSendActionMessage` (`@"MenuItem"`), `UIApplication.DidFinishLaunchingMessage` (the launch
  options) and the `NSWorkspace` unmount messages (`@"NSDevicePath"`). The messages drop them
  (section 5.16).
