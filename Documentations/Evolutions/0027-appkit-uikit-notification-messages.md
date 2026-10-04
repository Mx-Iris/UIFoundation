# 0027 - 把 AppKit / UIKit 预置的系统通知消息搬进 `NotificationCenter.Backport`

- **状态**: Implemented
- **创建日期**: 2026-10-04
- **最后更新**: 2026-10-04
- **所属愿景**: 无
- **配套文档**: 使用指南 [`NotificationMessages.md`](../NotificationMessages.md)；逆向报告 [`AppKit-UIKit-NotificationMessages-Internals.md`](../../Researchs/AppKit-UIKit-NotificationMessages-Internals.md)

## 摘要

苹果在 SDK 里给 AppKit / UIKit 的系统通知预置了类型化消息，例如 `NSWindow.DidBecomeKeyMessage` 配
`.didBecomeKey`。这些消息要 macOS 27 / iOS 26 才能用。FrameworkToolbox 已经把类型化通知的通用机制
`NotificationCenter.Backport` 搬到了老系统上，Foundation 的预置消息也由它自己搬（FrameworkToolbox 仓库的草案
`draft-notification-center-backport-foundation-messages.md`）。本提案把 AppKit 和 UIKit 这两批搬进
`UIFoundationToolbox`，共 208 个消息。命名、重载和可用性规则与 Foundation 那批一致；每个消息的
`name` / `makeMessage` / `makeNotification` 都照苹果二进制的行为实现。纯新增，三个已知下游不受影响。

## 方案

### 清单

以 Xcode 27.0 的 SDK 为准，与 27.2 beta 2 逐个比对过，完全一致。Xcode 26.6 的 SDK 里，AppKit 只有 `NSWorkspace`
的 20 个，其余 117 个苹果标的是 macOS 27；UIKit 有 72 个，比 27.0 少 1 个。

| 框架 | 主题类型（消息数） | 合计 |
|---|---|---|
| AppKit | `NSWindow` 29、`NSWorkspace` 20、`NSApplication` 17、`NSSpellChecker` 8、`NSOutlineView` 8、`NSMenu` 7、`NSTextView` 6、`NSScrollView` 5、`NSTableView` / `NSPopover` / `NSComboBox` 各 4、`NSControl` 3、`NSView` / `NSToolbar` / `NSSplitView` / `NSHelpManager` 各 2，另有 14 个类型各 1 个 | 137 |
| UIKit | `UIAccessibility` 19、`UIApplication` 13、`UIScene` / `UIResponder` 各 6、`UIWindow` / `UIScreen` / `UIDevice` 各 4、`UITextView` / `UITextField` 各 3、`UIPasteboard` / `UIFocusSystem` / `UIDocument` 各 2，另有 5 个类型各 1 个 | 73，搬 71 |

- AppKit 有 3 个是 `AsyncMessage`：`NSWorkspace` 的 `ScreensDidSleep`、`ScreensDidWake`、`ActiveSpaceDidChange`。其余全是 `MainActorMessage`。
- 不搬的 2 个是 `UIDocument.DidMoveToWritableLocationMessage` 和 `UIApplication.SystemPrefersReducedResourceUsageDidChangeMessage`。
  它们的底层常量本身就是 iOS 26 / 27 才有，backport 版能用的系统，苹果版也都能用。
- 几处与直觉不同的地方，照抄：
  - `NSTextView` 的三个编辑消息，`Subject` 是 `NSText`。
  - `UIResponder` 的六个键盘消息和 `UIContentSizeCategory.DidChangeMessage`，`Subject` 是 `UIScreen`。
  - `NSTextView.DidChangeSelectionMessage` 没有公开的 `init`。
  - `NSSplitView` 两个消息的 `init` 接收 `userResize: Bool?`，属性却是 `Bool`。

### 命名与重载

完全沿用 Foundation 那批的约定：

- 类型写成 `<主题类型>.Backport.<与苹果同名>Message`。
- 标识符挂在 `NotificationCenter.Backport.MessageIdentifier` 上，名字与苹果相同，并且都标 `@_disfavoredOverload`。
  不标的话，在部署目标够新的工程里、或者在 `#available` 块里，连苹果原生的简写都会报歧义。
- 迁回原生 API 时删掉 `Backport.` 即可。

**经子类找不到父类的消息。** 子类自己也声明了 `Backport` 时，会遮住父类的那个。比如 `NSComboBox.Backport.TextDidChangeMessage`
不存在，要写 `NSControl.Backport.TextDidChangeMessage`；苹果的嵌套类型却能经子类访问。
本库受影响的有四组：AppKit 的 `NSView`、`NSControl`、`NSWindow`，以及 UIKit 的 `UIResponder`。
用标识符（`.textDidChange`）的写法不受影响。只写进文档，不补 typealias，理由见决策日志。

### 行为

规则同 Foundation 那批：逐个逆向 `name`、`makeMessage`、`makeNotification`，照二进制实现。
依据是 macOS 27.0 的 AppKit（2775.10.103）和 Mac Catalyst 的 UIKitCore（9127.0.84），两者都取自与本机 UUID 一致的那份 dyld cache。

抽样确认了三种模式：

- **`name`**：直接返回对应的系统通知常量，例如 `NSWindowDidBecomeKeyNotification`。
- **空结构体**（AppKit 40 个、UIKit 36 个）：抽样的几个，`makeMessage(_:)` 都是无条件返回 `Self()`，与 Foundation 那批相同。
- **带属性的消息**：抽样的几个，`makeMessage(_:)` 都是逐项取值，**任何一项取不到或类型不对就返回 `nil`**，必须照抄。
  Foundation 那批不是这样：它带属性的 7 个里，4 个取不到就用默认值（`UndoManager` 三个的 `groupIsDiscardable` 取 `false`，
  `TimeZone` 的 `previousTimeZone` 取 `nil`），只有 `FileHandle` 的三个会返回 `nil`，条件是 userInfo 里既没有合法的错误码、也没有数据键。
  文档里拿 Foundation 做对比时，要把这三个例外写上。例子：
  - `NSWindow.DidBecomeKeyMessage`：`notification.object as? NSWindow`。
  - `NSTableView.ColumnDidMoveMessage`：在 object 之外，还取 `userInfo["NSOldColumn"]` 和 `["NSNewColumn"]`，都 `as? Int`。
  - `UIResponder.KeyboardWillShowMessage`：五个 userInfo 值，再加 `object as? UIScreen`，缺一项就是 `nil`。
    帧取 `NSValue` 的 `cgRectValue`，动画曲线取 `NSNumber` 的 `integerValue`（Swift 里写作 `intValue`），再强制解包成 `UIView.AnimationCurve`。
- **`makeNotification(_:)`**：把属性写回 object 和 userInfo。`NSWorkspace` 的消息，object 写的是 `NSWorkspace.shared`。

**AppKit 有 88 个消息的实现在 `.swiftinterface` 里看不到。** 它们的 `makeMessage` / `makeNotification` 来自 17 个内部协议的扩展
（`StandardNSWindowMessage` 管 26 个，`StandardNSApplicationMessage` 管 17 个，依此类推）。公开接口里只剩一个空的协议遵循，
只看接口会以为它们用的是协议默认实现，也就是返回 `nil`。照那样写，系统发出的通知永远到不了观察者。
这些实现的地址用 `swift-section dump --emit-pwt-addresses` 从见证表里取，见证表是协议遵循记录每个要求由哪个函数实现的那张表。

### 可用性

跟底层通知常量走；苹果标的平台不可用和废弃照抄。常量几乎都早于本库的最低系统，例外如下：

| 消息 | backport 版最低 | 苹果版 |
|---|---|---|
| `NSSpellChecker.DidChangeAutomaticInlinePredictionMessage` | macOS 14 | macOS 27 |
| `UIScene.SystemProtectionDidChangeMessage` | iOS 18 | iOS 26 |
| `UIScreen.ReferenceDisplayModeStatusDidChangeMessage` | iOS 16 | iOS 26 |
| `UIPointerLockState.DidChangeMessage` | iOS 14 | iOS 26 |
| `UIAccessibility.ButtonShapesEnabledStatusDidChangeMessage` | iOS 14，从 26.1 起标废弃（照抄苹果） | iOS 26，从 26.1 起标废弃 |

另外两点：

- `NSToolbar` 的两个消息在 Mac Catalyst 上也提供，常量从 iOS 13 起就有。
- watchOS 上苹果只有 `UIAccessibility` 的 `ElementFocused` 和 `AnnouncementDidFinish` 两个。本库在 watchOS 上一个都不提供，见决策日志。

### 放在哪

放在 `UIFoundationToolbox`。它已经依赖 `FoundationToolbox`，本身就是「框架类型的扩展」这一层，伞包也经它导出。

- 新建 `AppKit/NotificationMessages/` 和 `UIKit/NotificationMessages/` 两个目录。
- 每个主题类型一个文件，命名为 `<主题类型>+NotificationMessages.swift`。
- 不设 trait。

有两点与本库的惯例不同，会写进 `AGENTS.md`：

- `<主题类型>.Backport` 是直接加在 AppKit / UIKit 类上的嵌套类型，不走 `.box`。
  原因是迁回规则要求「删掉 `Backport.` 就是原生写法」。
- 本库不重新导出 `FoundationToolbox`。开了 `MemberImportVisibility` 的使用方，要自己 `import FoundationToolbox` 才能调 `addObserver(of:for:)`。
  不为此改导出：那会把 FoundationToolbox 的全部 API 都塞进 `import UIFoundation`。

### 测试

- **与苹果对照**：
  - AppKit 在本机（macOS 27）用 `swift test` 跑；UIKit 在 Mac Catalyst 上用 `xcodebuild test` 跑，不启动模拟器。
  - 每个消息比三样：`name`；同一组 `Notification`（齐全、缺 object、缺键、类型不对）分别交给两边 `makeMessage` 的结果；
    两边 `makeNotification` 产出的 name、object、userInfo，包括值的类型。
  - 需要 27 SDK 才能编译的部分，按 SDK 版本在编译期跳过，所以 Xcode 26 照样能编这个包。
- **端到端**：用真实对象触发一部分，例如窗口变成 key、菜单增删项、表格挪列、split view 调整、视图改 frame。
- **编译期守卫**：照 FrameworkToolbox 的写法（`FoundationToolboxClient/main.swift` 里的 `observeThroughFoundationsOwnShorthand`）。
  在 `#available` 块里，每个标识符写一次 `_ = center.addObserver(of: X.self, for: .xxx) { _ in }`。以后谁去掉 `@_disfavoredOverload`，这里会报歧义、编译失败。
  - 结果必须丢掉。收进有类型的数组或变量，参数类型会替编译器选好重载，去掉 `@_disfavoredOverload` 也照样能编译，守卫就失效了。
- **端到端测试写出消息类型名，不用简写**：否则测试目标的部署目标一旦升到 27，测的就变成了苹果的实现。
- **同名标识符、主题之间有继承关系的情况**：接受标识符的重载都要求传主题，同名标识符平时靠主题类型就能区分开。
  只有一个主题是另一个的子类时，传子类实例才会两个都匹配。逐个查过 208 个加 Foundation 的 32 个，这样的只有四对，
  都是 `NSTableView` 与 `NSOutlineView`：`.selectionDidChange`、`.selectionIsChanging`、`.columnDidMove`、`.columnDidResize`。
  Foundation 那批的主题与 AppKit / UIKit 的主题之间没有继承关系，不会撞。
  用编译探针确认苹果原生 API 在 `addObserver(of: outlineView, for: .selectionDidChange)` 上怎么解析，本库必须与之一致，并写进指南。
- **确认测试能变红**：分别改错一个 userInfo 键、删掉一个显式的 `makeMessage`、去掉 `@_disfavoredOverload`，每次都要看到失败。
- iOS / tvOS / visionOS 只编译，不运行（watchOS 见决策日志）。

### 文档

- 新指南 `Documentations/NotificationMessages.md`，写这几件事：
  - 清单；
  - `NSWorkspace` 的消息要在 `NSWorkspace.shared.notificationCenter` 上观察；
  - 经子类找不到父类的消息；
  - 要 `import FoundationToolbox`；
  - 取不到值时观察者不会被调用；
  - 迁回原生 API 的步骤。
- 逆向报告 `Researchs/AppKit-UIKit-NotificationMessages-Internals.md`：每个消息用哪个常量、`makeMessage` 读什么、`makeNotification` 写什么，附地址。
- `AGENTS.md` 加一节，两份索引同步更新。

### 依赖 FrameworkToolbox

`NotificationCenter.Backport` 在 FrameworkToolbox 的 main（`ac16df5`）上，还没进任何 tag。最新 tag 是 0.14.0；
本库要求 `from: "0.12.0"`，当前锁在 0.13.0。

- **开发期**：在单独的 worktree 里做。用 `Package.swift` 现成的 `.package(local:remote:)` 开关，把 FrameworkToolbox 临时指向本地 checkout。
  指向的是 FrameworkToolbox 的主 checkout，会连带编进它工作区里还没提交的 Foundation 那批。这是有意的：发版后使用方拿到的就是两批合在一起，
  两批同名的标识符（例如 `.didChange`、`.didBecomeActive`）之间有没有重载问题，越早编在一起越早发现。代价是那边改动期间这边可能暂时编不过。
- **发版**：等 FrameworkToolbox 的 Foundation 那批做完、本提案也能落地时，FrameworkToolbox 再发一个版本（例如 0.15.0）。
  开发中发现要改 FrameworkToolbox 的地方，由 FrameworkToolbox 的会话改，赶上同一个版本。
- **落地前**：把下限提到那个版本，关掉本地开关，更新 `Package.resolved`，然后才合入 main。
  main 上任何时候都不出现指向本地路径的依赖，否则使用方解析时拿到的是 0.13.0，找不到 `Backport`。

### 下游影响与源码兼容性

纯新增。已搜过 RuntimeViewer、MachOKitUI、PrivateSymbols：都没有名为 `Backport` 的类型，也没用到类型化通知 API，不受影响。
唯一可能的冲突，是下游自己在这些 AppKit / UIKit 类上声明了嵌套的 `Backport`。

### 未问就定下的假设

- 本提案按轻量档处理。
- 先做 AppKit，再做 UIKit，两部分同一批落地。
- FrameworkToolbox 那份 Foundation 草案若改了约定，本提案跟着改。

## 实现与验证

实现、测试和文档都已完成。FrameworkToolbox 0.15.0 已发布，依赖已切到发布版并重新验证过，随后合入 main。

- **代码**：`Sources/UIFoundationToolbox/AppKit/NotificationMessages/` 30 个文件（137 个消息），
  `UIKit/NotificationMessages/` 17 个文件（71 个），约定写在 `Shared/NotificationMessages.swift`。
  逆向确认了全部 208 个，不只是抽样：不带属性的消息 `makeMessage` 一律返回 `Self()`；UIKit 里这些消息的 `makeNotification`
  直接用的是 Foundation 的协议默认实现，AppKit 一个都没用。
- **与苹果对照**：AppKit 137 个在本机（macOS 27.0）全部一致；UIKit 71 个在 Mac Catalyst 上全部一致。
  另加一条：`UIAccessibility.ElementFocusedMessage` 在通知不带元素时，两边的 `element` 都是 `NSNull`。
- **端到端**：菜单增删改项、视图改 frame / bounds、窗口改大小 / 移动 / 关闭、表格挪列 / 改列宽、大纲展开收起、
  split view 调整、文本视图改选区、颜色表变化、工具栏增删项，全部由 AppKit 真实发出，消息内容正确。
  另有一个测试确认 `addObserver(of: NSOutlineView.self, for: .selectionDidChange)` 选中的是大纲视图的消息。
- **确认测试能变红**：每次埋错都看到了失败，然后还原：
  - AppKit：`NSWorkspace` 埋 4 处（object 写成 `nil`、URL 写成 `NSURL`、键名写错、删掉协议遵循）；
    `NSWindow` 的协议把 object 写成 `nil`（27 个消息失败）、`NSMenu` 的键名写错、`NSApplication.WillTerminate` 删掉协议遵循。
  - UIKit：键盘结束帧改读开始帧的键（6 个消息失败）、`VoiceOverStatusDidChange` 删掉协议遵循、`ElementFocused` 的取值改成得到 `nil`。
  - 守卫：去掉 `didBecomeKey`、`didWake`、`keyboardWillShow` 的 `@_disfavoredOverload`，三处都报 `ambiguous use`，编译失败。
- **构建**：`swift test` 全部通过（Swift Testing 189 个、XCTest 9 个）；开全部 trait 的构建 0 错误，
  新代码没有警告（仅有的 3 条警告在 `StatusItemController` 和两个旧测试里，main 上就有）；示例 app 编译通过；
  `UIFoundationToolbox` 在 iOS / tvOS / visionOS 上编译 0 错误 0 警告；测试目标在 iOS 模拟器 SDK 上编译通过（没有启动模拟器）。
- **全量测试偶发崩溃，main 上同样存在**：完整的 `swift test` 大约每 7 次有 1 次以 signal 11 崩溃，崩在主线程 run loop
  清空自动释放池时（某个对象被多释放了一次）。用调试器各跑 20 次对照：本分支全部测试 3 次、跳过本提案的测试 3 次、
  只跑本提案的测试 0 次、main 3 次。与本提案无关，没有在这里修。
- **测试里实测到的两个 AppKit 行为**，写进了测试注释和逆向报告：工具栏插入一项后，要等有人读一次 `items` 才发
  `WillAddItem`，删除则立刻发；从没显示过的窗口，`setFrame(_:display:)` 只发改大小、不发移动，`setFrameOrigin(_:)` 才发移动。
- **逆向报告里原本只是推断的五处，改成了实测**：键盘消息做出的通知转不回消息、`NSNumber` 形式的 `UITextField` reason 和
  `NSFontCollection` visibility 读成 `nil`、`ElementFocused` 两边都得到 `NSNull`，各补了一个测试（苹果的实现和本库的一起断言，
  都先看到变红）；`NSImageRep` 和 `NSFontCollection` 的系统通知用探针实测。后者推翻了原来的注释：AppKit 显示、隐藏字体集合时发的通知
  不带 object，所以**整条消息**都是 `nil`，不只是 visibility，苹果自己的实现也一样。注释和使用指南已按实测改正。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-10-04 | Created as Draft | 用户经 FrameworkToolbox 会话转达：「把现在 SDK 有的通知适配一下，我们这个仓库（FrameworkToolbox）只适配 Foundation，AppKit/UIKit 的让 UIFoundation 的 agent 适配」 |
| 2026-10-04 | 命名、`@_disfavoredOverload`、可用性规则沿用 FrameworkToolbox 的 Foundation 草案 | 两边的迁回规则保持一致：删掉 `Backport.` |
| 2026-10-04 | 不搬 `UIDocument.DidMoveToWritableLocationMessage` 和 `UIApplication.SystemPrefersReducedResourceUsageDidChangeMessage` | 底层常量分别是 iOS 26 / 27 才有，backport 版能用的地方苹果版都能用 |
| 2026-10-04 | 放在 `UIFoundationToolbox`，不设 trait | 与 FoundationToolbox 那批一致；只有声明，没有资源 |
| 2026-10-04 | 经子类找不到父类的消息：只写文档，不补 typealias | 沿用 Foundation 那批的约定。补齐要加约 110 个 typealias，以后真需要再加也是纯新增 |
| 2026-10-04 | UIKit 的对照测试只在 Mac Catalyst 上跑 | 本机能直接跑，不用启动模拟器；启动模拟器需要单独授权 |
| 2026-10-04 | 开发期在 worktree 里把 FrameworkToolbox 指向本地路径 | 用户选定。开发不用等 FrameworkToolbox 发版 |
| 2026-10-04 | FrameworkToolbox 等 Foundation 那批和本提案都能落地时再发版 | 用户选定。本提案开发中要改 FrameworkToolbox 的地方也能赶上同一个版本 |
| 2026-10-04 | 本地路径指向 FrameworkToolbox 的主 checkout，连同它未提交的 Foundation 那批一起编 | 发版后两批就是合在一起用的，标识符之间的重载问题越早暴露越好 |
| 2026-10-04 | 编译期守卫和端到端测试照 FrameworkToolbox 已验证过的写法 | 它那边实测：结果收进有类型的容器会让守卫失效；端到端测试用简写，部署目标一升就测成了苹果的实现 |
| 2026-10-04 | 状态改为 Accepted | 用户批准。在 worktree `.worktrees/UIFoundation-NotificationMessages`（分支 `feature/notification-messages`）里实现 |
| 2026-10-04 | watchOS 上一个都不提供，UIKit 的文件守卫写成 `canImport(UIKit) && !os(watchOS)` | 本包改动前就编译不到 watchOS（依赖的 AssociatedObject 在 watchOS 上编不过），写了也验证不了；苹果在 watchOS 上本来也只有两个 |
| 2026-10-04 | 共享实现照搬苹果的结构：苹果用内部协议共享的，本库也用同名的内部协议；苹果没有协议、只是代码相同的，本库另起名字去重（`NSWorkspace…`、`StandardUI…`） | 读代码时能和逆向报告逐个对上 |
| 2026-10-04 | `NSWindow.DidExitFullScreenMessage` 也遵循 `StandardNSWindowMessage` | 苹果单独声明了它的实现，但跑的是同一段代码，结果一样 |
| 2026-10-04 | `NSToolbar` 的两个 userInfo 键用原始值 `"item"`、`"newIndex"` 构造 | SDK 里对应的常量要 macOS 13 / 15，用原始值得到的是同一个键，最低系统不用跟着抬 |
| 2026-10-04 | 对照测试的主题对象用 `IdentityOnlyObjects`（只分配、不初始化，整个测试期间不释放） | `UIScene`、`UIScreen`、`UIFocusSystem` 的初始化要求 app 在运行；`makeMessage` 只做类型转换、存引用，分配出来的对象就够 |
| 2026-10-04 | 文档注释按 SDK 头文件写，不照抄苹果网页上写错的地方 | 苹果网页有几处与 SDK 矛盾（例如 `NSWindow.DidExitFullScreenMessage` 的说明抄的是 `didExpose` 的），清单记在逆向报告里 |
| 2026-10-04 | 状态改为 In Progress | 实现、测试、文档完成；等 FrameworkToolbox 发版，提下限、关本地开关、更新 `Package.resolved` 后落地 |
| 2026-10-04 | 依赖切到 FrameworkToolbox 0.15.0：下限从 0.12.0 提到 0.15.0，去掉本地路径开关，`Package.resolved` 只改了 FrameworkToolbox 一项（0.13.0 → 0.15.0，`c87146b`），AppKitPlus 的锁定保留 | FrameworkToolbox 发布了 0.15.0，内容是 `NotificationCenter.Backport` 加 Foundation 的 32 个消息。切换后重跑了完整测试、全 trait 构建、Mac Catalyst 对照、各平台编译和示例 app |
| 2026-10-04 | 状态改为 Implemented，编号 0027，合入 main | 用户批准提交并快进合入 main（不推送）。配套文档：使用指南 `NotificationMessages.md` 与逆向报告 `AppKit-UIKit-NotificationMessages-Internals.md`，已登记在文首。术语表不新增：用到的「消息」「主题」「标识符」都是苹果与 FrameworkToolbox 的现成 API 术语，`Backport` 命名空间的含义写在使用指南里 |
