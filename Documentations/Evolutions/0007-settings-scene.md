# 0007 - SettingsScene：让 SwiftUI 与 AppKit 共用原生设置 Scene

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-14
- **最后更新**: 2026-08-14
- **所属愿景**: 无
- **关联提案**: [0002](0002-reusable-settings-window.md)（Settings 模块初次抽取）、[0003](0003-settings-navigation-history.md)（页面历史导航）、[0006](0006-settings-window-configuration.md)（统一自定义入口）
- **实现分支 / PR**: `main`
- **配套文档**: [`SettingsWindow.md`](../SettingsWindow.md)

## 摘要

在现有 `SettingsWindowController` 与可嵌入的 `SettingsRootView` 之外，新增公开的
`SettingsScene: Scene`。它用 SwiftUI 原生 `Settings` Scene 承载同一套页面、`Configuration` 与
`SettingsNavigator`。SwiftUI App 可以直接把它放入 `App.body`；macOS 26 及以上的 AppKit App 可以用
`NSHostingSceneRepresentation` 注册它，再通过 representation 的 `environment.openSettings()` 打开。

本提案增加第三种呈现入口，不替换现有窗口控制器，也不提高 `UIFoundationSettingsUI` 的 macOS 14 最低版本。

## 动机

`SettingsWindowController` 适合 AppKit 自己管理窗口的应用，但它绕过了 SwiftUI `Settings` Scene 的生命周期：
SwiftUI App 不能把它声明在 `App.body` 中，AppKit App 也不能通过 Scene environment 取得系统提供的
`openSettings` action。`SettingsRootView` 只是一棵 `View`，调用方虽然可以自行写一层 `SwiftUI.Settings`，
却必须重复页面构建、窗口尺寸和 navigator 的所有权规则。

macOS 26 新增了 `NSHostingSceneRepresentation<Content: Scene>` 与
`NSApplication.addSceneRepresentation(_:)`。Apple 的官方用法正是把 `Settings { ... }` 注册进采用 AppKit
lifecycle 的应用，并从 representation 的 environment 调用 `openSettings()`。UIFoundation 已经拥有完整的
设置内容与导航状态，只缺一个真正的 `Scene` 入口。

用户诉求原话：「设置给多一个选择，可以暴露一个 `Settings` Scene，AppKit 可以使用
`NSHostingSceneRepresentation` 加载。」

## 提议方案

### 新增 SettingsScene

在 `UIFoundationSettingsUI` 新增：

```swift
@available(macOS 14.0, *)
public struct SettingsScene: Scene {
    public let configuration: SettingsWindowController.Configuration
    public let navigator: SettingsNavigator

    @MainActor
    public init(
        configuration: SettingsWindowController.Configuration = .init(),
        navigator: SettingsNavigator? = nil,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    )

    @MainActor
    public var body: some Scene { get }
}
```

initializer 与 `SettingsWindowController` 保持相同形状：先求值页面 builder；未传 navigator 时，以第一页的
ID 创建一个；传入的 navigator 则原样保留。调用方因此可以在打开 Scene 前写
`settingsScene.navigator.currentPageID = "updates"`，行为与 controller 完全一致。

`body` 使用 `SwiftUI.Settings` 包住 `SettingsRootView`，并应用 `Configuration.contentWidth` 与
`minimumContentHeight`。sidebar 与导航按钮配置继续由 `SettingsRootView` 消费。`Configuration.title` 只对
`SettingsWindowController` 生效：SwiftUI 原生 `Settings` Scene 的窗口标题与 Settings 菜单项由系统管理，
本库不在 Scene 内容中伪造另一层标题。

### SwiftUI App 用法

```swift
@main
struct WorkbenchApplication: App {
    var body: some Scene {
        WindowGroup { ContentView() }
        SettingsScene {
            SettingsPage("General", id: "general", symbol: "gearshape") {
                GeneralSettingsView()
            }
        }
    }
}
```

### AppKit App 用法

macOS 26 及以上由调用方直接使用 Apple 的 bridge；UIFoundation 不再包一层同义 factory：

```swift
let settingsScene = SettingsScene { /* pages */ }
let settingsSceneRepresentation = NSHostingSceneRepresentation {
    settingsScene
}

NSApplication.shared.addSceneRepresentation(settingsSceneRepresentation)
settingsSceneRepresentation.environment.openSettings()
```

注册应发生在 `applicationWillFinishLaunching(_:)`。支持 macOS 14–25 的 AppKit App 继续使用
`SettingsWindowController`，或在 availability 分支里以 controller 作回退。

## 替代方案考量

### 只在文档里让调用方自行写 SwiftUI.Settings

否决。这样每个调用方都要重复 `SettingsRootView` 的 frame、Configuration 透传和默认 navigator 所有权；
而且库对外仍然没有一个可以直接放进 `App.body` 的完整设置组件。

### 直接公开 NSHostingSceneRepresentation factory

否决。它会把整个新入口限定在 macOS 26，SwiftUI App 反而无法直接复用；返回泛型 representation 也只是把
Apple 已经是一行的 initializer 换个名字。公开 `SettingsScene` 能同时服务两种 lifecycle，桥接仍交给系统。

### 用 SettingsScene 替换 SettingsWindowController

否决。`NSHostingSceneRepresentation` 只有 macOS 26 才能接入 AppKit，而模块最低版本是 macOS 14；既有宿主
还可能需要直接持有 `NSWindowController`、访问 `window` 或自行安排窗口生命周期。新增选择不应破坏原选择。

### 让 SettingsScene 自己注册到 NSApplication

否决。注册时机属于 App lifecycle；Scene 值不应偷偷修改 process-wide 的 `NSApplication`。显式注册也与
Apple 官方 API 的所有权模型一致。

## 兼容性与下游影响

- **ABI 兼容性**: 不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。
- **源码兼容性**: 纯新增。现有 `SettingsWindowController` 与 `SettingsRootView` 调用点不变。
- **平台与最低版本**: `SettingsScene` 自身仍是 macOS 14+；只有 AppKit bridge 的调用点需要 macOS 26+。
- **RuntimeViewer**: 当前最低版本为 macOS 15，现有 controller 路径保持不变；可以在未来用 availability 分支
  选择 Scene bridge，无需本提案强制迁移。
- **MachOKitUI / PrivateSymbols / LocalizationStudio**: 当前未使用 `UIFoundationSettingsUI`，无行为变化。
- **发布影响**: Settings trait 新增一个公开类型，指南需同时说明 SwiftUI 与 AppKit lifecycle 的接入方式。

## 测试与验收

1. `SettingsScene` 保存同一个 `Configuration`，未传 navigator 时从第一页建立导航状态。
2. 显式传入的 `SettingsNavigator` 保持引用身份，不产生第二份选择与历史。
3. macOS 26 SDK 下，公开类型能直接构造 `NSHostingSceneRepresentation<SettingsScene>`。
4. Settings trait 的完整测试以原始测试进程退出码 0 通过。
5. macOS 示例 App 使用 agent 独立 DerivedData 构建通过。
6. 不启动 Simulator，也不执行交互式 UI 验证。

## 实施结果

- 新增公开的 `SettingsScene: Scene`。它与 `SettingsWindowController` 使用同形 initializer，公开同一个
  `Configuration` 与 `SettingsNavigator`，未传 navigator 时从第一页建立默认导航状态。
- Scene body 使用 SwiftUI 原生 `Settings` 包住 `SettingsRootView`；content width、minimum height、sidebar
  与导航按钮设置沿用 Configuration。标题继续由 SwiftUI Settings Scene 管理，未伪造第二套标题逻辑。
- macOS 26 聚焦测试直接构造 `NSHostingSceneRepresentation<SettingsScene>` 并读取
  `environment.openSettings`，证明 AppKit bridge 接受公开 Scene，不需要 UIFoundation 再加 factory。
- 更新公开指南、文档索引和项目 agent 指南，分别记录 SwiftUI `App.body`、AppKit 注册时机、macOS 14–25
  fallback 与 navigator 所有权。
- `swift test --traits Settings` 以原始退出码 0 通过 125 项测试，0 warning、0 error；其中 3 项是新增的
  Settings Scene 聚焦测试。macOS 示例 App 使用 `/tmp/codex/DerivedData/UIFoundation` 独立构建通过。
- `swift package update` 未改变 `Package.resolved`，`git diff --check` 通过。未启动 Simulator、未运行示例
  App，也未做交互式 UI 验证。

## 决策日志

| 日期 | 决策 | 说明 |
|---|---|---|
| 2026-08-14 | Created as Draft | 调研 SwiftUI `Settings` 与 macOS 26 `NSHostingSceneRepresentation` 的官方契约。 |
| 2026-08-14 | Accepted → In Progress | 用户明确要求保留现有设置窗口，并增加可由 AppKit bridge 加载的 `Settings` Scene 选择。 |
| 2026-08-14 | Implemented | Scene、macOS 26 bridge 编译契约、测试、公开指南与维护规则已同步落地。 |
