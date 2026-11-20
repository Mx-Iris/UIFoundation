# 0043 - 设置页面在 iOS 与 visionOS 上可用

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-11-20
- **最后更新**: 2026-11-20
- **所属愿景**: 无（下游 RuntimeViewer 的愿景《iOS 版功能对齐》要用它做 iOS 设置页）
- **关联提案**: [0042-settings-store-on-all-platforms](0042-settings-store-on-all-platforms.md)（设置存储已在各平台可用）、[0002-reusable-settings-window](0002-reusable-settings-window.md)（设置窗口的来历）；下游 RuntimeViewer 的 `draft-settings-screen-on-ios`
- **实现分支 / PR**: `feature/settings-ui-on-ios`，从 `main` 切出，2026-11-20 本地 `--no-ff` 合进 `main`，随 0.49.0 发布
- **配套文档**: 无单独文档——改现有指南 [`SettingsWindow.md`](../SettingsWindow.md)
- **网页版**: 同目录同名的 `.html`

## 摘要

`UIFoundationSettingsUI` 里写页面要用的四样东西——`AppSettings`（把一项设置绑到 SwiftUI 控件的属性包装）、`SettingsForm`、
`SettingsPage` 与它的 result builder、`SettingsPageIcon`——放开到 iOS、Mac Catalyst 与 visionOS，同一份 SwiftUI 页面两边都能编；
另加一个 iOS 用的宿主：SwiftUI 的 `SettingsNavigationStack`（页面列表，点进去是页面内容，像系统「设置」App）和包着它、
给 UIKit App 弹出用的 `SettingsViewController`，与 macOS 的 `SettingsWindowController` 对称。macOS 的设置窗口一行不改。

## 动机

- **下游要在 iOS 上复用设置页**：RuntimeViewer 的设置页都是 SwiftUI，但写在 `@AppSettings` 与 `SettingsForm` 上，这两样
  连同 `SettingsPage` 都包在 `#if Settings && os(macOS)` 里（`Sources/UIFoundationSettingsUI/AppSettings.swift:1`、
  `SettingsForm.swift:1`、`SettingsPage.swift:1`）。它的愿景《iOS 版功能对齐》定了「设置页复用 SwiftUI 页面、宿主换成 UIKit」，
  不在下游另写一套。
- **这几样本来就不碰 AppKit**：`AppSettings`、`SettingsForm`、`SettingsPage` 只用 SwiftUI 与 `UIFoundationSettings`；
  `SettingsPageIcon` 只有一处用 `NSImage(systemSymbolName:)` 判断符号是否存在（`SettingsPageIcon.swift:80-86`）。
- **iOS 没有设置窗口这种东西**：macOS 的宿主是带侧栏的窗口（`SettingsWindowController`、`SettingsRootView`、`SettingsScene`），
  iOS 的习惯是一张列表、点进去一页；需要一个对应的宿主，下游才不必各自拼。

## 前期调研

- **可直接放开的**：`AppSettings`（`AppSettings.swift`，64 行）用 `Root.store.value` 与 `@Bindable`，`@Bindable` 需要 iOS 17；
  `SettingsForm`（32 行）是 `Form { }.formStyle(.grouped)`，iOS 16 起有；`SettingsPage` 与 `SettingsPageBuilder`（117 行）
  只有 SwiftUI 类型。依赖的 `UIFoundationSettings` 自 0042 起各平台可用（iOS 17、Catalyst 17、visionOS 1）。
- **要改一处的**：`SettingsPageIcon.image(named:)` 判断 SF Symbol 是否存在用的是 `NSImage(systemSymbolName:accessibilityDescription:)`；
  UIKit 上的对应是 `UIImage(systemName:)`。
- **留在 macOS 的**：`SettingsWindowController`、`SettingsWindowSupport`、`SettingsRootView`、`SettingsScene`、`SettingsConfiguration`
  （窗口尺寸与侧栏）、`SettingsNavigator`（侧栏的选择与前进后退历史；iOS 上由 `NavigationStack` 自己管）。
- **target 结构**：`UIFoundationSettingsUI` 依赖 `UIFoundationSettings`，另在 macOS 上依赖 `UIFoundationAppKit`
  （`Package.swift` 的 `UIFoundationSettingsUI` target），带一个本地化资源包（返回、前进按钮的文字）。其他平台上它现在是空模块。
- **平台范围**：Observation 与 `@Bindable` 要 iOS 17 / Catalyst 17 / visionOS 1；tvOS 与 watchOS 没有这类设置界面的用法，
  且 Xcode 27 已编不了本包声明的 tvOS 13 / watchOS 6 下限（0042 的决策日志），不纳入。
- **使用方**：RuntimeViewer 的 macOS 设置窗口；ReverseEngineeringToolbox、MacKedUpdater、XCOrganizer 都是 macOS App，不受影响。

## 提议方案

1. **四样共用的组件放开**：`AppSettings.swift`、`SettingsForm.swift`、`SettingsPage.swift`、`SettingsPageIcon.swift` 的条件改为
   `#if Settings && (os(macOS) || os(iOS) || os(visionOS))`（Mac Catalyst 上 `os(iOS)` 为真），`@available` 补
   `iOS 17.0, macCatalyst 17.0, visionOS 1.0`；`SettingsPageIcon` 判断符号是否存在时按平台用 `NSImage` 或 `UIImage`。
2. **iOS 的宿主**（新文件，`#if Settings && (os(iOS) || os(visionOS))`）：
   - `SettingsNavigationStack`：SwiftUI 视图，`NavigationStack` 里一张 `List`，每行是页面图标加标题，点进去显示页面内容，
     标题栏是页面标题；根页右上角一个「完成」按钮，按下调用传入的 `onDone`（不传就用环境里的 `dismiss`）。
   - `SettingsViewController`：`open class`，把 `SettingsNavigationStack` 装进一个 `UIHostingController` 子视图控制器，
     「完成」时 `dismiss(animated:)`；初始化器与 macOS 的 `SettingsWindowController` 同形：`init(title:pages:)`，页面用
     `@SettingsPageBuilder` 给。
3. **文档**：`SettingsWindow.md` 的平台说明改为「写页面的组件各平台可用，宿主分平台」，加一节「在 iOS 上」；
   `AGENTS.md` 项目地图里 `UIFoundationSettingsUI` 一行写清两边各有什么。

### 非目标

- **macOS 设置窗口的任何变化**。
- **iPad 上的双栏设置**（左列表右内容）：先一律用单栏的导航栈，iPad 上以 sheet 弹出时同样适用。
- **tvOS 与 watchOS**。
- **`SettingsNavigator` 与 `SettingsConfiguration` 跨平台**：它们描述的是侧栏窗口，iOS 宿主用不到。
- **把设置模块并进伞模块**。

## 改动地图

| 文件 / 类型 | 动作 | 改什么 | 为什么 | 步骤 |
|---|---|---|---|---|
| `Sources/UIFoundationSettingsUI/AppSettings.swift` · `AppSettings` | 修改 | 条件与 `@available` 放开到 iOS、Catalyst、visionOS | 页面绑定设置用它 | 1 |
| `Sources/UIFoundationSettingsUI/SettingsForm.swift` · `SettingsForm` | 修改 | 同上 | 页面外框用它 | 1 |
| `Sources/UIFoundationSettingsUI/SettingsPage.swift` · `SettingsPage`、`SettingsPageBuilder` | 修改 | 同上 | 两边的宿主都收页面 | 1 |
| `Sources/UIFoundationSettingsUI/SettingsPageIcon.swift` · `SettingsPageIcon` | 修改 | 同上；`image(named:)` 按平台判断符号是否存在 | iOS 列表行也画页面图标 | 1 |
| `Sources/UIFoundationSettingsUI/SettingsNavigationStack.swift` | 新增 | iOS 的页面列表与导航 | iOS 习惯的设置界面 | 2 |
| `Sources/UIFoundationSettingsUI/SettingsViewController.swift` | 新增 | 给 UIKit App 弹出的宿主 | 与 macOS 的 `SettingsWindowController` 对称 | 2 |
| `Documentations/SettingsWindow.md` | 修改 | 平台说明；新增「在 iOS 上」一节 | 指南是对外契约 | 3 |
| `AGENTS.md` · 项目地图 | 修改 | `UIFoundationSettingsUI` 一行写两边各有什么 | 让 agent 知道 | 3 |
| `Documentations/Evolutions/README.md` | 修改 | 登记本提案 | 索引 | 3 |

## 架构图

```text
UIFoundationSettingsUI (trait Settings)
  shared, macOS + iOS + Mac Catalyst + visionOS        - was macOS only
    AppSettings<Root, Value>       property wrapper
    SettingsForm                   Form { }.formStyle(.grouped)
    SettingsPage / SettingsPageBuilder
    SettingsPageIcon               + UIImage(systemName:) on UIKit
  macOS only (unchanged)
    SettingsWindowController ── SettingsRootView (sidebar + back/forward) ── SettingsNavigator
    SettingsScene, SettingsConfiguration, SettingsWindowSupport
+ iOS + Mac Catalyst + visionOS
+   SettingsViewController (open, UIKit)
+     └─ UIHostingController ── SettingsNavigationStack
+                                  NavigationStack
+                                    List: SettingsPageIcon + title  ──push──▶ page.content
+                                    toolbar: Done ─▶ onDone / dismiss
```

```text
A UIKit app opening its settings
  host view controller
    present(MySettingsViewController())          // subclass of SettingsViewController, pages given in init
      SettingsNavigationStack(title:pages:onDone:)
        row tap ─▶ page.content (SettingsForm { … @AppSettings bindings … })
        Done    ─▶ SettingsViewController.dismiss(animated: true)
```

## 详细设计

```swift
#if Settings && (os(iOS) || os(visionOS))
import SwiftUI

/// The settings pages as iOS presents them: a list of pages, each pushing
/// its content, with a Done button on the list.
@available(iOS 17.0, macCatalyst 17.0, visionOS 1.0, *)
public struct SettingsNavigationStack: View {
    public init(
        title: String = "Settings",
        onDone: (() -> Void)? = nil,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    )

    public var body: some View   // NavigationStack { List(pages) { NavigationLink … } .navigationTitle(title) .toolbar { Done } }
}

/// Presents the settings pages from a UIKit app — the counterpart of the
/// macOS `SettingsWindowController`. Subclass it to give the pages once.
@available(iOS 17.0, macCatalyst 17.0, visionOS 1.0, *)
@MainActor
open class SettingsViewController: UIViewController {
    public let pages: [SettingsPage]

    public init(title: String = "Settings", @SettingsPageBuilder pages: () -> [SettingsPage])

    override open func viewDidLoad()   // embeds UIHostingController(rootView: SettingsNavigationStack(…, onDone: dismiss))
}
#endif
```

- 列表行：`SettingsPageIcon(page.icon, size: 29)` 加 `Text(page.title)`；`plainSymbol` 图标在 iOS 上画成单色符号，与系统
  「设置」的彩色方块不同，页面要彩色方块就用 `.symbol(_, tint:)`。
- `SettingsPage.content` 已是 `@MainActor` 的 `AnyView`，`NavigationLink(value: page.id)` 配 `navigationDestination` 取页面。
- 「完成」按钮的文字用模块的本地化资源（已有 `Localizable.xcstrings`），新增一条 `Done`。

## 替代方案考量

- **只放开组件，不提供 iOS 宿主**：每个下游各写一份列表加导航，形状会各不相同。宿主不到百行，放在库里。
- **iOS 上也做侧栏窗口的样子**（`UISplitViewController`）：iPhone 上会折叠成导航栈，iPad 上的双栏留作后续。
- **`SettingsViewController` 直接继承 `UIHostingController`**：泛型根视图让子类化很别扭，下游子类还得写出根视图类型；
  包一层子视图控制器更像 macOS 的 `SettingsWindowController`。

## 影响

### 源码兼容性（source compatibility）

**纯新增**。macOS 上的类型、行为都不变；放开的四样在其他平台上原来不存在。

### ABI 兼容性（条件项）

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- 本仓库：`UIFoundationSettingsUI` 在 iOS、Catalyst、visionOS 上从空模块变成有内容。
- **RuntimeViewer**：iOS 设置页用它（`draft-settings-screen-on-ios`），下限抬到本次发版。
- **ReverseEngineeringToolbox、MacKedUpdater、XCOrganizer**：只在 macOS 上用，不受影响。

### 文档与示例

`SettingsWindow.md`（平台说明、「在 iOS 上」一节）、`AGENTS.md` 项目地图。iOS 示例 App 不加设置演示。

## API 演进与废弃策略

- 不废弃任何东西；按惯例发次版本 0.49.0。

## 落地步骤

1. **共用组件放开**（已完成）—— 改动地图前四行
   - 行为：`sharedSettingsComponentsBuildForIOSCatalystAndVisionOS`（交叉编译 `UIFoundationSettingsUI`）
   - 行为：`existingSettingsTestsPassOnMac`
   - 行为：`pageIconFallsBackToAnAssetImageWhenTheSymbolIsUnknown`（判断逻辑抽成可测的纯函数，在 macOS 上测）
2. **iOS 宿主**（已完成）—— `SettingsNavigationStack.swift`、`SettingsViewController.swift`、`Localizable.xcstrings`
   - 行为：`settingsViewControllerBuildsForIOSCatalystAndVisionOS`
   - 行为：`navigationStackListsThePagesInOrder`（页面顺序与 id 的映射抽成可测的部分）
3. **文档与发版**（已完成）—— 指南、`AGENTS.md`、索引；合进 `main` 后打 `0.49.0`

**收尾时必须判断两件事**（判断结果写进决策日志，不允许沉默跳过）：

- **要不要配套专题文章** —— 预计不需要：写进现有的 `SettingsWindow.md`。
- **有没有引入新术语** —— 预计没有。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-11-20 | Created as Draft | RuntimeViewer 要在 iOS 上复用现有的 SwiftUI 设置页，用户选了上游一起放开、不在下游另写 |
| 2026-11-20 | 自定：宿主用单栏导航栈，iPad 双栏不做 | iOS 的习惯；双栏留作后续 |
| 2026-11-20 | 自定：`SettingsViewController` 包一层子视图控制器，不继承 `UIHostingController` | 子类化顺手，形状与 macOS 的 `SettingsWindowController` 对称 |
| 2026-11-20 | 自定：不含 tvOS 与 watchOS | 没有用法；本包在这两个平台上的部署下限已低于 Xcode 27 的支持范围 |
| 2026-11-20 | 用户批准，开始实现 | 与 RuntimeViewer 的 `draft-settings-screen-on-ios` 一起批准；本篇先落地并发 0.49.0 |
| 2026-11-20 | 实现中的调整 | 一、`SettingsPageIcon` 的符号判断抽成内部的 `isSystemSymbol(named:)`，macOS 上测两个分支（`SettingsPageIconTests`）。二、`navigationStackListsThePagesInOrder` 没写：`SettingsNavigationStack` 与 `SettingsViewController` 只在 iOS、visionOS 上编，包的测试只在 macOS 上跑，测不到；它们的验证是四个平台的交叉编译与下游在设备上看。三、`SettingsViewController` 同时把 `title` 设成传入的标题，嵌进别的导航控制器时也有标题。 |
| 2026-11-20 | Implemented，取号 0043，发 0.49.0 | 验证：macOS 上设置相关四个套件 28 个用例全过；打开全部 trait 的整包构建通过；`UIFoundationSettingsUI` 以 iOS 模拟器、iOS 真机、Mac Catalyst、visionOS 模拟器为目标交叉编译通过，产物里有 `SettingsViewController`。文档判断：写进现有的 `SettingsWindow.md`（开头的平台说明、第 4 节新增「On iOS, Mac Catalyst and visionOS」），`AGENTS.md` 项目地图更新；不另写文章，没有新术语。 |
