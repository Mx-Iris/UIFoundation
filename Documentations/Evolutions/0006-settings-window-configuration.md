# 0006 - SettingsWindowController.Configuration：集中管理设置窗口自定义项

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-14
- **最后更新**: 2026-08-14
- **所属愿景**: 无
- **关联提案**: [0002](0002-reusable-settings-window.md)（Settings 模块初次抽取）、[0003](0003-settings-navigation-history.md)（页面历史导航）
- **实现分支 / PR**: `main`
- **配套文档**: [`SettingsWindow.md`](../SettingsWindow.md)

## 摘要

新增 `SettingsWindowController.Configuration`，把设置窗口所有外部可调的窗口与侧栏参数收拢到一个值类型中，
由 `SettingsWindowController` 和可独立嵌入的 `SettingsRootView` 共同接收。首个迁移需求是让 RuntimeViewer
把朴素 SF Symbol 的侧栏图标从默认 20 pt 调回 15 pt；同一改动也结束现有 initializer 参数散落在两个
入口、且两边可调能力不一致的问题。

## 动机

`SettingsPageIcon` 从一开始就公开了 `size` 参数，但库自己的 `SettingsRootView` 在私有 sidebar 中始终调用
`SettingsPageIcon(page.icon)`，外部宿主没有路径把尺寸传进去。RuntimeViewer 接回 UIFoundation Settings 后
暴露了这个缺口：迁移前的图标占 20 pt frame，但 symbol 四周各有 `20 / 8` 的 padding，实际 glyph 最大为
15 pt；新的 `.plainSymbol` 没有 padding，直接把 glyph 画到 20 pt，视觉上明显变大。

只在现有 initializer 上继续追加 `sidebarIconSize` 能解决眼前问题，却会让 `title`、窗口尺寸、导航开关、
侧栏宽度和图标尺寸继续散落为一串参数。两个公开入口目前也不对称：`SettingsRootView` 有 `sidebarWidth`，
`SettingsWindowController` 没有。后续每增加一个外观参数都要重复扩展 initializer，调用点也越来越难读。

## 提议方案

### 单一 Configuration

在 `SettingsWindowController` 下新增嵌套值类型：

```swift
extension SettingsWindowController {
    public struct Configuration {
        public var title: String
        public var contentWidth: CGFloat
        public var minimumContentHeight: CGFloat
        public var sidebarWidth: CGFloat
        public var sidebarIconSize: CGFloat
        public var showsNavigationControls: Bool

        public init(
            title: String = "Settings",
            contentWidth: CGFloat = 715,
            minimumContentHeight: CGFloat = 400,
            sidebarWidth: CGFloat = 185,
            sidebarIconSize: CGFloat = 20,
            showsNavigationControls: Bool = true
        )
    }
}
```

这些字段都是宿主在构建窗口时决定、之后不会随页面导航变化的外观或几何参数。`navigator` 不进入
`Configuration`：它是可观察的运行时状态与宿主控制柄，不是样式。页面 builder 也不进入，因为页面是内容，
不是配置值。

### 两个入口共同接收

`SettingsWindowController` 的公开入口改为：

```swift
public init(
    configuration: Configuration = .init(),
    navigator: SettingsNavigator? = nil,
    @SettingsPageBuilder pages: () -> [SettingsPage]
)
```

`SettingsRootView` 同样接收 `SettingsWindowController.Configuration`，但在 initializer 中只提取它真正渲染的
`sidebarWidth`、`sidebarIconSize` 与 `showsNavigationControls`，不把窗口标题和尺寸继续传入 SwiftUI 子树。
私有 `SettingsSidebar` 再把窄化后的 `sidebarIconSize` 传给每个 `SettingsPageIcon`。

RuntimeViewer 的调用点因此只需要：

```swift
super.init(configuration: .init(sidebarIconSize: 15)) {
    // Pages
}
```

### 默认行为

所有默认值与现有实现一致。未传 `Configuration` 的 `SettingsWindowController { ... }` 与
`SettingsRootView { ... }` 保持原有外观和行为；只有显式传值的宿主发生变化。

## 替代方案考量

### 只新增 sidebarIconSize initializer 参数

否决。它能修复 RuntimeViewer，却继续扩大散列参数列表，也不解决 controller 与 root view 的配置能力不对称。
用户明确要求把自定义项统一放入 `Configuration`。

### 把尺寸放进每个 SettingsPage

否决。图标尺寸是整个 sidebar 的视觉规则，不是页面身份或内容。逐页配置会要求 RuntimeViewer 重复八次同一个
值，也允许同一侧栏出现不一致的图标占位。

### 用 Environment 或自定义 icon builder

否决。一个构建时确定的 `CGFloat` 不需要环境传播；自定义 view builder 还会扩大图标 API，并可能把 type erasure
带进 `List` 行。直接传窄值更清楚，也保持现有 `Label` 行结构。

## 兼容性与下游影响

- **ABI 兼容性**: 不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。
- **源码兼容性**: 使用默认 initializer 或只传 `navigator` 的调用点继续编译；直接传 `title`、
  `contentWidth`、`minimumContentHeight`、`showsNavigationControls`、`sidebarWidth` 的调用点需要把这些值移入
  `Configuration`。项目公开 API 尚不稳定，本次在 RuntimeViewer 合入迁移分支前一次收敛。
- **RuntimeViewer**: 设置窗口传 `sidebarIconSize: 15`，恢复迁移前的实际 glyph 尺寸；其余默认值不变。
- **示例 App**: `title` 移入 `Configuration`，同时作为新 API 的可运行示例。
- **MachOKitUI / PrivateSymbols / LocalizationStudio**: 当前未使用 `UIFoundationSettingsUI` 的这两个入口，无需改动。
- **发布影响**: 下一版本的 Settings API 文档需把 `Configuration` 作为唯一自定义入口。

## 测试与验收

1. `Configuration` 的六个默认值与旧实现一致。
2. 自定义值完整保存在 `Configuration` 中，两个公开入口都能接收同一个类型。
3. `SettingsRootView` 把自定义 `sidebarIconSize` 传到每个 `SettingsPageIcon`，默认仍为 20 pt。
4. RuntimeViewer 使用 15 pt sidebar 图标配置并能通过 package 与 macOS App 构建。
5. UIFoundation Settings trait 的单元测试通过，原始测试进程退出码为 0。
6. 不启动 Simulator，也不执行交互式 UI 验证。

## 实施结果

- 新增 `SettingsWindowController.Configuration`，公开六个原有或新接通的自定义值；controller 与 root view
  共同接收它，`navigator` 和页面 builder 继续保持独立。
- `SettingsRootView` 只保存 sidebar width、sidebar icon size 与导航按钮开关三个窄值；私有 sidebar 把尺寸
  显式传到每个 `SettingsPageIcon`。
- RuntimeViewer 通过 `configuration: .init(sidebarIconSize: 15)` 恢复迁移前的实际 glyph 尺寸；同一调用形状
  在一个直接依赖本地 UIFoundation 的最小下游 package 中编译通过，0 warning、0 error。
- UIFoundation 的 `swift test --traits Settings` 以原始退出码 0 通过 122 项测试，0 warning、0 error；macOS
  示例 App 使用独立 DerivedData 构建通过。
- RuntimeViewer 整仓验证未进入本次源码编译：独立 SwiftPM 图在解析阶段报告当前 `RuntimeViewerCore` 仍要求
  已从 `MachOSwiftSection` 移走的 `OutputTransformer` product；上级 workspace 又锁在不含 `Settings` trait
  的 UIFoundation 0.15.1。两项均早于本次 Configuration 调用，作为验证偏差保留，不扩展任务去改依赖图。
- 已更新公开指南、示例 App、两个项目的 agent 指南与 RuntimeViewer 迁移提案。未启动 Simulator，也未做
  交互式 UI 验证。

## 决策日志

| 日期 | 决策 | 说明 |
|---|---|---|
| 2026-08-14 | Created as Draft | RuntimeViewer 迁移发现 `SettingsPageIcon.size` 无法从设置窗口外部传入。 |
| 2026-08-14 | Accepted → In Progress | 用户明确要求建立单一 `Configuration`，由外部传入，并把所有自定义项收拢其中。 |
| 2026-08-14 | Implemented | Configuration、两个公开入口、15 pt 下游调用、测试、示例与文档已同步；RuntimeViewer 整仓构建的既有依赖图阻塞已单独记录。 |
