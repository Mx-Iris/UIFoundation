# NotificationMessages —— 在老系统上用 AppKit / UIKit 预置的类型化通知消息

苹果从 macOS 27 / iOS 26 起，给 AppKit 和 UIKit 的系统通知预置了类型化消息。观察窗口变成 key 窗口，不必再拿
`NSWindow.didBecomeKeyNotification` 注册、再从 `notification.object` 里强转：写 `.didBecomeKey`，回调直接收到
`NSWindow.DidBecomeKeyMessage`，窗口就在 `message.window` 上。`UIFoundationToolbox` 把这批消息搬到了本库支持的全部系统上：
AppKit 137 个、UIKit 71 个，放在各自类型的 `Backport` 里，例如 `NSWindow.Backport.DidBecomeKeyMessage`。
每个消息怎么从通知取值、怎么写回通知，都照苹果二进制的实现逐个复刻，并与苹果的实现逐个对照测试过。
它不挂在任何 trait 后面，随 `UIFoundationToolbox` 一起编译。

收发消息的通用机制（`addObserver(of:for:)`、`post`、观察 token、异步序列）来自 FrameworkToolbox 的
`NotificationCenter.Backport`，它的契约见 FrameworkToolbox 的指南
[`NotificationCenterBackport.md`](https://github.com/Mx-Iris/FrameworkToolbox/blob/main/Documentations/NotificationCenterBackport.md)，
这里不重复；Foundation 自己的 32 个预置消息也在那边。决策记录见提案
[把 AppKit / UIKit 预置的系统通知消息搬进 `NotificationCenter.Backport`](Evolutions/0027-appkit-uikit-notification-messages.md)，
每个消息在苹果二进制里怎么实现，见逆向报告
[`Researchs/AppKit-UIKit-NotificationMessages-Internals.md`](../Researchs/AppKit-UIKit-NotificationMessages-Internals.md)。

## 先判断该用哪一个

- **部署目标已经是 macOS 27 / iOS 26**（只用 `NSWorkspace` 的消息时，macOS 26 就够）：直接用苹果原生的，不要用这个。
- **低于这个**：用这个。等部署目标升上去，按文末的步骤换回原生，基本就是删掉 `Backport.`。

## 用法

```swift
import UIFoundation        // 或者只 import UIFoundationToolbox
import FoundationToolbox   // addObserver(of:for:) 声明在这里，见契约 4

final class WindowObserver {
    private var tokens: [NotificationCenter.Backport.ObservationToken] = []

    func observe(_ window: NSWindow) {
        tokens.append(NotificationCenter.default.addObserver(of: window, for: .didBecomeKey) { message in
            print(message.window.title)
        })
    }
}
```

`NSWorkspace` 的消息在工作区自己的通知中心上观察（契约 1），其中三个是 `AsyncMessage`，用异步序列收：

```swift
let workspace = NSWorkspace.shared
let token = workspace.notificationCenter.addObserver(of: workspace, for: .didLaunchApplication) { message in
    print(message.application.bundleIdentifier ?? "-")
}

for await _ in workspace.notificationCenter.messages(of: workspace, for: .screensDidSleep) {
    pauseRendering()
}
```

UIKit 的键盘消息，主题（`Subject`，即 `addObserver(of:)` 传的那个对象的类型）是 `UIScreen`，不是 `UIResponder`：

```swift
let token = NotificationCenter.default.addObserver(of: UIScreen.self, for: .keyboardWillShow) { message in
    print(message.endFrame, message.animationDuration)
}
```

token 一释放观察就结束，所以要存起来，这一点与原生 API 相同。

## 清单

| 类型 | 个数 | 消息（省略 `Message` 后缀） |
|---|---|---|
| `NSApplication` | 17 | `WillFinishLaunching`、`DidBecomeActive`、`WillBecomeActive`、`DidResignActive`、`WillResignActive`、`DidHide`、`WillHide`、`DidUnhide`、`WillUnhide`、`DidUpdateWindows`、`WillUpdateWindows`、`WillTerminate`、`DidChangeScreenParameters`、`DidChangeOcclusionState`、`DidFinishRestoringWindows`、`ProtectedDataDidBecomeAvailable`、`ProtectedDataWillBecomeUnavailable` |
| `NSBrowser` | 1 | `ColumnConfigurationDidChange` |
| `NSColor` | 1 | `SystemColorsDidChange` |
| `NSColorList` | 1 | `DidChange` |
| `NSColorPanel` | 1 | `ColorDidChange` |
| `NSComboBox` | 4 | `SelectionDidChange`、`SelectionIsChanging`、`WillDismiss`、`WillPopUp` |
| `NSControl` | 3 | `TextDidBeginEditing`、`TextDidChange`、`TextDidEndEditing` |
| `NSFont` | 1 | `FontSetChanged` |
| `NSFontCollection` | 1 | `DidChange` |
| `NSHelpManager` | 2 | `ContextHelpModeDidActivate`、`ContextHelpModeDidDeactivate` |
| `NSImageRep` | 1 | `RegistryDidChange` |
| `NSMenu` | 7 | `WillSendAction`、`DidSendAction`、`DidAddItem`、`DidRemoveItem`、`DidChangeItem`、`DidBeginTracking`、`DidEndTracking` |
| `NSOutlineView` | 8 | `SelectionDidChange`、`SelectionIsChanging`、`ColumnDidMove`、`ColumnDidResize`、`ItemWillExpand`、`ItemDidExpand`、`ItemWillCollapse`、`ItemDidCollapse` |
| `NSPopUpButton` | 1 | `WillPopUp` |
| `NSPopUpButtonCell` | 1 | `WillPopUp` |
| `NSPopover` | 4 | `WillShow`、`DidShow`、`WillClose`、`DidClose` |
| `NSRuleEditor` | 1 | `RowsDidChange` |
| `NSScreen` | 1 | `ColorSpaceDidChange` |
| `NSScrollView` | 5 | `WillStartLiveMagnify`、`DidEndLiveMagnify`、`WillStartLiveScroll`、`DidLiveScroll`、`DidEndLiveScroll` |
| `NSScroller` | 1 | `PreferredScrollerStyleDidChange` |
| `NSSpellChecker` | 8 | `DidChangeAutomaticSpellingCorrection`、`DidChangeAutomaticTextReplacement`、`DidChangeAutomaticQuoteSubstitution`、`DidChangeAutomaticDashSubstitution`、`DidChangeAutomaticCapitalization`、`DidChangeAutomaticPeriodSubstitution`、`DidChangeAutomaticTextCompletion`、`DidChangeAutomaticInlinePrediction` |
| `NSSplitView` | 2 | `WillResizeSubviews`、`DidResizeSubviews` |
| `NSTableView` | 4 | `SelectionDidChange`、`SelectionIsChanging`、`ColumnDidMove`、`ColumnDidResize` |
| `NSTextAlternatives` | 1 | `SelectedAlternativeString` |
| `NSTextInputContext` | 1 | `KeyboardSelectionDidChange` |
| `NSTextView` | 6 | `DidBeginEditing`、`DidChange`、`DidEndEditing`、`WillChangeNotifyingTextView`、`DidChangeSelection`、`DidChangeTypingAttributes` |
| `NSToolbar` | 2 | `WillAddItem`、`DidRemoveItem` |
| `NSView` | 2 | `FrameDidChange`、`BoundsDidChange` |
| `NSWindow` | 29 | `DidBecomeKey`、`DidBecomeMain`、`DidChangeScreen`、`DidDeminiaturize`、`DidMiniaturize`、`DidMove`、`DidResignKey`、`DidResignMain`、`DidResize`、`DidUpdate`、`WillClose`、`WillMiniaturize`、`WillMove`、`WillBeginSheet`、`DidEndSheet`、`DidChangeScreenProfile`、`WillStartLiveResize`、`DidEndLiveResize`、`WillEnterFullScreen`、`DidEnterFullScreen`、`WillExitFullScreen`、`DidExitFullScreen`、`WillEnterVersionBrowser`、`DidEnterVersionBrowser`、`WillExitVersionBrowser`、`DidExitVersionBrowser`、`DidChangeOcclusionState`、`DidExpose`、`DidChangeBackingProperties` |
| `NSWorkspace` | 20 | `WillLaunchApplication`、`DidLaunchApplication`、`DidTerminateApplication`、`DidHideApplication`、`DidUnhideApplication`、`DidActivateApplication`、`DidDeactivateApplication`、`DidMountVolume`、`WillUnmountVolume`、`DidUnmountVolume`、`DidRenameVolume`、`WillSleep`、`DidWake`、`ScreensDidSleep`（Async）、`ScreensDidWake`（Async）、`SessionDidBecomeActive`、`SessionDidResignActive`、`DidChangeFileLabels`、`ActiveSpaceDidChange`（Async）、`AccessibilityDisplayOptionsDidChange` |
| `UIAccessibility` | 19 | `VoiceOverStatusDidChange`、`MonoAudioStatusDidChange`、`ClosedCaptioningStatusDidChange`、`InvertColorsStatusDidChange`、`GuidedAccessStatusDidChange`、`BoldTextStatusDidChange`、`ButtonShapesEnabledStatusDidChange`、`GrayscaleStatusDidChange`、`ReduceTransparencyStatusDidChange`、`ReduceMotionStatusDidChange`、`DarkerSystemColorsStatusDidChange`、`SwitchControlStatusDidChange`、`SpeakSelectionStatusDidChange`、`SpeakScreenStatusDidChange`、`ShakeToUndoDidChange`、`AssistiveTouchStatusDidChange`、`HearingDevicePairedEarDidChange`、`ElementFocused`、`AnnouncementDidFinish` |
| `UIApplication` | 12 | `DidFinishLaunching`、`DidBecomeActive`、`DidEnterBackground`、`WillEnterForeground`、`WillResignActive`、`WillTerminate`、`DidReceiveMemoryWarning`、`SignificantTimeChange`、`BackgroundRefreshStatusDidChange`、`UserDidTakeScreenshot`、`ProtectedDataDidBecomeAvailable`、`ProtectedDataWillBecomeUnavailable` |
| `UIContentSizeCategory` | 1 | `DidChange` |
| `UIDevice` | 4 | `BatteryLevelDidChange`、`BatteryStateDidChange`、`OrientationDidChange`、`ProximityStateDidChange` |
| `UIDocument` | 1 | `StateChanged` |
| `UIFocusSystem` | 2 | `DidUpdate`、`MovementDidFail` |
| `UIPasteboard` | 2 | `Changed`、`Removed` |
| `UIPointerLockState` | 1 | `DidChange` |
| `UIResponder` | 6 | `KeyboardWillShow`、`KeyboardDidShow`、`KeyboardWillHide`、`KeyboardDidHide`、`KeyboardWillChangeFrame`、`KeyboardDidChangeFrame` |
| `UIScene` | 6 | `WillConnect`、`WillEnterForeground`、`DidActivate`、`WillDeactivate`、`DidEnterBackground`、`SystemProtectionDidChange` |
| `UIScreen` | 4 | `BrightnessDidChange`、`ModeDidChange`、`CapturedDidChange`、`ReferenceDisplayModeStatusDidChange` |
| `UITableView` | 1 | `SelectionDidChange` |
| `UITextField` | 3 | `TextDidBeginEditing`、`TextDidChange`、`TextDidEndEditing` |
| `UITextInputMode` | 1 | `CurrentInputModeDidChange` |
| `UITextView` | 3 | `TextDidBeginEditing`、`TextDidChange`、`TextDidEndEditing` |
| `UIViewController` | 1 | `ShowDetailTargetDidChange` |
| `UIWindow` | 4 | `DidBecomeVisible`、`DidBecomeHidden`、`DidBecomeKey`、`DidResignKey` |

标识符与苹果同名，是类型名去掉 `Message`、首字母小写（`.didBecomeKey`、`.keyboardWillShow`），只有一个例外：
`UIContentSizeCategory.DidChangeMessage` 的标识符是 `.contentSizeCategoryDidChange`。表里没注 Async 的都是
`MainActorMessage`。几处与直觉不同、照抄苹果的地方：

- **主题不是声明它的那个类型。** `NSTextView` 的 `DidBeginEditing` / `DidChange` / `DidEndEditing` 主题是 `NSText`；
  `UIResponder` 的六个键盘消息和 `UIContentSizeCategory.DidChange` 主题是 `UIScreen`。`addObserver(of:)` 要传这个类型的对象或元类型。
- `NSTextView.Backport.DidChangeSelectionMessage` 没有公开的 `init`，只能从通知转出来，不能自己构造了去 `post`。
- `NSSplitView` 两个消息的 `init` 接收 `userResize: Bool?`，属性却是 `Bool`：传 `nil` 存成 `false`。

**平台。** AppKit 的消息只在 macOS 上有；`NSToolbar` 的两个在 Mac Catalyst 上也有。UIKit 的在 iOS、Mac Catalyst、tvOS、visionOS
上有，苹果标了某平台不可用的（例如键盘消息在 tvOS 和 visionOS 上），本库同样不可用。**watchOS 一个都没有**：本包目前编译不到
watchOS（依赖的 AssociatedObject 在 watchOS 上编不过，与这批消息无关）。

**最低系统。** 跟着底层通知常量走，几乎都在本库的最低系统上就能用。例外：

| 消息 | 本库最低 | 苹果版 |
|---|---|---|
| `NSSpellChecker.DidChangeAutomaticInlinePredictionMessage` | macOS 14 | macOS 27 |
| `UIScene.SystemProtectionDidChangeMessage` | iOS 18 | iOS 26 |
| `UIScreen.ReferenceDisplayModeStatusDidChangeMessage` | iOS 16 | iOS 26 |
| `UIPointerLockState.DidChangeMessage` | iOS 14 | iOS 26 |
| `UIAccessibility.ButtonShapesEnabledStatusDidChangeMessage` | iOS 14，26.1 起标废弃 | iOS 26，26.1 起标废弃 |

**没有搬的两个**：`UIDocument.DidMoveToWritableLocationMessage` 和 `UIApplication.SystemPrefersReducedResourceUsageDidChangeMessage`。
它们的底层常量本身就要 iOS 26 / 27，能用 backport 版的系统，苹果版也都能用。

## 契约 —— 签名上看不出来，违反了就出事

1. **`NSWorkspace` 的消息只在 `NSWorkspace.shared.notificationCenter` 上收得到。** AppKit 把这 20 个通知发在工作区自己的通知中心上，
   在 `NotificationCenter.default` 上观察，什么都收不到，也不报错。原生 API 也是这样。

2. **取不到值时，观察者不会被调用。** 带属性的消息，只要主体对象（`notification.object`）或必需的 `userInfo` 值缺一个、类型不对一个，
   转换就失败，观察者不被调用，只记一条 fault 日志（见 FrameworkToolbox 指南的契约 3）。这是照抄苹果的二进制，与 Foundation 那批不同：
   那边带属性的消息大多取不到就用默认值。
   - 系统自己发的通知一般是齐全的（例外见本条最后一项）。最常踩到的是**手动 `post(name:object:userInfo:)` 的通知**，
     例如测试里不带 object 发一条 `NSWindow.didBecomeKeyNotification`。
   - 声明成可选的属性，取不到时就是 `nil`，不会让转换失败。两处例外：`NSSplitView` 两个消息的 `userResize` 取不到是 `false`；
     `UIAccessibility.ElementFocusedMessage` 的 `element` 取不到是 `NSNull`，不是 `nil`（苹果也是这样）。
   - 不带属性的消息（`NSApplication` 的 17 个、`UIApplication` 的 12 个之类）不看通知内容，有通知就有消息。
   - **有几处照抄下来的苹果缺陷，系统自己发的通知也会踩到**，苹果原生 API 完全一样（macOS 27.0 / Mac Catalyst 上实测）：
     - `NSImageRep.RegistryDidChange` 和 `NSFontCollection.DidChange` 对 AppKit 自己发的通知**永远收不到**：
       前者 AppKit 把注册的类本身当作 object 发出，不是实例；后者显示、隐藏字体集合时发出的通知不带 object。
       要观察这两件事，直接观察底层的 `Notification`。
     - `UITextField.TextDidEndEditing` 的 `reason` 和 `NSFontCollection.DidChange` 的 `visibility` 永远是 `nil`：
       系统把这两个值作为 `NSNumber` 发出，转换时直接转成枚举 / 选项集，转不过去。
     - 键盘消息用 `makeNotification` 做出来、再 `post` 出去的通知，观察者收不到：写回去的是 Swift 值
       （`CGRect`、`UIView.AnimationCurve`），读的时候却要 `NSValue` / `NSNumber`。

3. **经子类找不到父类的消息，要写声明它的那个类。** 子类自己也有 `Backport` 时，会遮住父类的（编译探针实测）：`NSComboBox.Backport.TextDidChangeMessage`
   不存在，要写 `NSControl.Backport.TextDidChangeMessage`；苹果的 `NSComboBox.TextDidChangeMessage` 却能用。受影响的有四组：
   - `NSView` 的两个：经 `NSControl`、`NSScrollView`、`NSSplitView`、`NSTextView` 以及它们的子类都找不到。
   - `NSControl` 的三个：经 `NSComboBox`、`NSTableView`、`NSOutlineView`、`NSBrowser`、`NSPopUpButton`、`NSRuleEditor`、`NSScroller` 找不到。
   - `NSWindow` 的 29 个：经 `NSColorPanel` 找不到。
   - `UIResponder` 的六个键盘消息：经 `UIApplication`、`UIScene`、`UIWindow`、`UIViewController`、`UITextView`、`UITextField`、`UITableView` 找不到。

   自己没有 `Backport` 的子类照常能找到，例如 `NSStackView.Backport.FrameDidChangeMessage`。用标识符的写法（`.textDidChange`）不受影响。
   迁回原生时，`NSControl.Backport.TextDidChangeMessage` 删掉 `Backport.` 就是合法的原生写法，不必改回子类。
   没有补 typealias 把它们接上（要补得写大约 110 个），这里选择写进文档而不是桥接，理由见提案的决策日志；
   想补任何一个之前，先在提案里重新讨论这个决定。

4. **要自己 `import FoundationToolbox`。** `addObserver(of:for:)`、`messages(of:for:)`、`post(_:subject:)` 和
   `NotificationCenter.Backport` 都声明在 FrameworkToolbox 的 `FoundationToolbox` 模块里，本库不重新导出它。
   打开了 `MemberImportVisibility`（Swift 的一个编译选项：没有直接 import 的模块，它的扩展成员不可见）的工程，不写就找不到这些方法；
   没打开的工程也建议写上。不重新导出，是因为那会把 FoundationToolbox 的全部 API 都塞进 `import UIFoundation`。

5. **四对同名标识符，传 `NSOutlineView` 实例时有歧义。** `.selectionDidChange`、`.selectionIsChanging`、`.columnDidMove`、
   `.columnDidResize` 既是 `NSTableView` 的消息，也是 `NSOutlineView` 的。大纲视图是表格视图的子类，所以
   `addObserver(of: outlineView, for: .selectionDidChange)` 两个都匹配，报 `ambiguous use`。苹果原生 API 在这里也报同样的歧义
   （用 macOS 27 SDK 的编译探针确认过）。要观察某一个大纲视图，写出消息类型：
   `addObserver(of: outlineView, for: NSOutlineView.Backport.SelectionDidChangeMessage.self)`。
   传元类型 `NSOutlineView.self`（观察所有大纲视图）、或者传 `NSTableView` 实例，都没有歧义。

6. **在苹果原生可用的地方，简写选的是苹果的。** 部署目标到了 macOS 27 / iOS 26，或者代码写在 `if #available(macOS 27, *)` 块里时，
   `.didBecomeKey` 解析到 AppKit 的 `NSWindow.DidBecomeKeyMessage`，返回的是 `NotificationCenter.ObservationToken`，
   不是 `NotificationCenter.Backport.ObservationToken`。要在那里用本库的，写出消息类型：
   `for: NSWindow.Backport.DidBecomeKeyMessage.self`。这是刻意的：本库的标识符都标了 `@_disfavoredOverload`
   （两个重载都能用时，让编译器选另一个），否则一 import 本库，苹果原生的简写就会报歧义。与 FrameworkToolbox 的 Foundation 那批一致。

7. **`MainActorMessage` 的通知必须在主线程发。** 后台线程发出一条同名的 `Notification`，观察者会在那里崩溃，原生 API 也是这样，
   见 FrameworkToolbox 指南的契约 1。哪些是 `MainActorMessage`、哪些是 `AsyncMessage` 完全照抄苹果：只有 `NSWorkspace` 的
   `ScreensDidSleep`、`ScreensDidWake`、`ActiveSpaceDidChange` 三个是 `AsyncMessage`，观察者在独立的任务里运行。

## 与苹果原生版本的差异

| | 苹果 | 本库 |
|---|---|---|
| 类型的位置 | `NSWindow.DidBecomeKeyMessage` | `NSWindow.Backport.DidBecomeKeyMessage` |
| 最低系统 | AppKit 要 macOS 27（`NSWorkspace` 的要 26），UIKit 要 26 | 跟底层通知常量走，例外见「清单」 |
| 经子类访问父类的消息 | 可以 | 子类自己有 `Backport` 时不行（契约 3） |
| watchOS | 有 `UIAccessibility` 的两个 | 没有 |
| 文档注释 | 苹果网页 | 苹果网页有几处写错（例如 `NSWindow.DidExitFullScreenMessage` 的说明抄的是 `didExpose` 的），本库按 SDK 头文件写，清单见逆向报告 |

转换行为（取哪些值、缺了怎么办、写回什么类型的值）与苹果的逐个相同，对照测试覆盖了全部 208 个。

## 迁回原生 API

1. 把部署目标升到 macOS 27（只用 `NSWorkspace` 消息的，26 即可）/ iOS、Mac Catalyst、tvOS、visionOS 26。
2. 全局删掉 `Backport.`：`NSWindow.Backport.DidBecomeKeyMessage` 变成 `NSWindow.DidBecomeKeyMessage`，
   `NotificationCenter.Backport.ObservationToken` 变成 `NotificationCenter.ObservationToken`。简写调用点（`.didBecomeKey`）不用改，
   部署目标一到，它们自己就解析到苹果的版本。
3. 为绕开契约 3 写成父类的地方（`NSControl.Backport.TextDidChangeMessage`），删掉 `Backport.` 后照样合法。
4. 其余步骤（迭代器的 `next()` 补 `try` 之类）见 FrameworkToolbox 指南的「迁回原生 API」。

## 实现说明 —— 看起来能简化、其实不能动的地方

- **文件布局。** 每个主题类型一个文件：
  `Sources/UIFoundationToolbox/{AppKit,UIKit}/NotificationMessages/<Subject>+NotificationMessages.swift`；
  所有文件共用的约定写在 `Sources/UIFoundationToolbox/Shared/NotificationMessages.swift` 里。
- **`Backport` 是直接加在 AppKit / UIKit 类上的嵌套类型，不是 `.box` 的成员。** 这是对本库「框架类型的扩展一律走 `.box`」
  规则的刻意例外：迁移契约是「删掉 `Backport.` 就是苹果的写法」，与 FrameworkToolbox 的 Foundation 那批一致，放进 `.box` 就做不到。
- **每个标识符上的 `@_disfavoredOverload` 是承重的（契约 6）。** 去掉它，客户端一 import 本库，苹果原生的简写
  （macOS 27 上下文里的 `.didBecomeKey`）就报歧义。测试目标里的 `AppKitNotificationMessageShorthandGuard.swift` 和
  `UIKitNotificationMessageShorthandGuard.swift` 在 `#available` 块里把每个标识符写一遍、丢弃结果；去掉这个属性，构建就在那里失败
  （两个文件都验证过）。**结果必须保持丢弃**：赋给有类型的变量或数组时，参数类型会替编译器选好重载，守卫就悄悄失效了。
- **行为照苹果的二进制复刻，不照 `.swiftinterface`。** AppKit 有 88 个消息的 `makeMessage` / `makeNotification` 来自 AppKit 内部协议的扩展，
  `.swiftinterface` 里看不到；只看接口会以为它们用的是协议的默认实现，而那个默认实现返回 `nil`，什么都送不到。苹果通过这类协议共享
  一份实现的地方，本库也共享一份，苹果有名字的就沿用它的名字（`StandardNSWindowMessage`、`KeyboardNotificationMessageProviding` 等）。
  `makeNotification` 写回的运行时类型也照苹果：有的地方是 Swift 的 `Int` / `Bool` / `CGRect`，有的地方是 `NSNumber` / `NSValue`。
  要改任何一处转换，先对照逆向报告。
- **FrameworkToolbox 的最低版本是 0.15.0**，它是第一个带 `NotificationCenter.Backport`（以及 Foundation 那 32 个消息）的版本。
  把下限调低，使用方就可能解析到 0.13.0 / 0.14.0，这批代码在那上面一个都编译不过。

## 测试

测试在 `Tests/UIFoundationTests/NotificationMessages/` 下。

- **与苹果原生消息逐个对照，全部 208 个**：`name`；`makeMessage` 跑过每个 fixture 的各种变体（完整的、没有 object 的、object 是无关类的、
  没有 `userInfo` 的、每个键缺失或类型不对的）；`makeNotification` 写出的内容，连值的类型一起比。`NSWorkspace` 以外的 AppKit 用例只在
  macOS 27 SDK 下编译（`#if canImport(AppKit, _version: 2700)`），所以 Xcode 26 仍然能构建这个包。初始化要求 app 在运行的主题
  （`UIScene`、`UIScreen`、`UIFocusSystem`）取自 `IdentityOnlyObjects`：不调 `init` 直接分配，整个测试运行期间一直持有。
- **UIKit 的对照测试在 Mac Catalyst 上跑，不用模拟器**：

  ```bash
  xcodebuild test -scheme UIFoundation-Package -destination 'platform=macOS,variant=Mac Catalyst' \
      -only-testing:UIFoundationTests/UIKitNotificationMessageParityTests
  ```

  跑之前和 `FilterResourcesTests` 一样，先把 `UIFoundation.xcworkspace` 暂时挪开（那个 workspace 只暴露示例 App 的 scheme）。
- **端到端测试写出消息类型**（`for: NSWindow.Backport.DidResizeMessage.self`），不用简写：测试目标的部署目标一旦到了 27，
  简写会悄悄去测苹果的实现（契约 6）。在测试进程里驱动 AppKit 对象有两处实测的坑：`NSToolbar` 插入条目后，要等有代码读一次 `items`
  才发 `WillAddItem`（移除则立即发）；对从未显示过的窗口调 `setFrame(_:display:)`，只发 resize 不发 move —— 要 move 用 `setFrameOrigin(_:)`。
