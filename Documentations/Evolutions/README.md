# Evolution 提案索引

- **项目类型**: 库（源码分发）

SPM library product，使用方以源码依赖并重新编译，未开启 library evolution，
也不以 `binaryTarget` 分发。

**「ABI 兼容性」一节填「不适用 —— 本库以 SPM 源码分发，使用方每次重新编译」即可；
「源码兼容性」一节必填。**

本库有一条特有的注意事项：**它是多个项目的公共底座，「下游影响」一节必须逐个点名**。
已知下游包括 RuntimeViewer（`TabsControl`）、MachOKitUI（`TextFinder`）、
PrivateSymbols（全面改用本库基类）。改动一个组件的行为，等于同时改动这些项目的行为。

另外，本库既有组件的对外契约写在使用指南里（见[上级索引](../README.md)）。
提案若改动了这些契约，**必须在同一批次更新对应指南** —— 契约变了而指南没变，
比没有指南更糟。

提案格式与流程见全局 `CLAUDE.md` 的「Evolution 提案制」一节，用 `/evolution <描述>` 创建。

## 提案

| # | 标题 | 状态 | 摘要 |
|---|------|------|------|
| [0001](0001-appstore-style-navigation-controller.md) | NavigationController：移植 macOS App Store 的导航容器与推入/弹出转场 | Implemented | AppKit 没有导航容器，本提案把 macOS App Store 自己那套搬进来：视图控制器栈、推入/弹出转场、双指右滑返回。落在新 trait `Navigation`（默认关闭）下，对现有使用方零影响。配套使用指南见 [`Navigation.md`](../Navigation.md)，逆向依据见 [`Researchs/AppStore-Custom-Navigation-Internals.md`](../../Researchs/AppStore-Custom-Navigation-Internals.md)。 |
| [0002](0002-reusable-settings-window.md) | SettingsWindow：把 RuntimeViewer 的设置窗口抽成可复用框架 | Implemented | 每个 macOS App 都要重写一遍的设置窗口壳：分页导航、`Form`、Application Support 下的 JSON、改了就自动存的防抖。从 RuntimeViewer 抽出与业务无关的那 250 行，做成泛型 `SettingsStore`、泛型化的 `AppSettings` 属性包装器（store 走类型级静态入口，不走 Environment）、result builder 注册页面。分模型层 `UIFoundationSettings` 与 UI 层 `UIFoundationSettingsUI` 两个 target，均仅 macOS，落在新 trait `Settings`（默认关闭）下，**不引入任何新外部依赖**。配套使用指南见 [`SettingsWindow.md`](../SettingsWindow.md)。RuntimeViewer 回接尚未进行，先决条件见提案「下游影响 ⓪」。 |
| [0003](0003-settings-navigation-history.md) | SettingsNavigator：设置窗口的页面历史导航 | Implemented | 设置窗口加一对 Xcode 式的前进 / 后退 chevron，并把「当前在哪一页」从 `SettingsRootView` 的私有 `@State` 里取出来，做成宿主可以在代码里直接读写的 `SettingsNavigator`。历史是唯一事实来源、侧栏选中项由它派生，避开了「选中项 + 标志位」那类时序 bug。子页面下钻不做 —— 实测页内直接写 `NavigationStack` 已自带返回按钮。纯新增，仅动 `UIFoundationSettingsUI` 一个 target。 |
| [0004](0004-appkit-navigation-toolbar-item.md) | NSToolbar.Navigation：AppKit 的后退 / 前进工具栏项 | Implemented | AppKit 没有任何内建的导航工具栏项（SwiftUI 侧有，见 0003），RuntimeViewer 已手搓了一个。把它抽进本库既有的 toolbar DSL，重点不是搬那三十行代码，而是把它踩出来的两条 AppKit 行为契约固化进 API 形状：分段菜单只有在控件 `action` 非 nil 时才走长按弹出，以及空 `NSMenu` 仍会弹出空盒子所以必须整个摘掉。数据走 data source 拉取（借 `NSToolbarItem.validate()` 的验证周期），事件走 delegate 通知，条数与行内容分两级以避免逐行图标解析跑在热路径上。纯新增，仅动 `UIFoundationAppKit`，不加 trait。落地时实测**证否了第三条「踩坑」**（挂菜单不会带出下拉箭头）；`NSSegmentedControl` 最终**完全不暴露**，也不提供任何样式转发 —— 观感由库定死，宿主只接数据与回调，这样契约一才真的没有入口可破。配套使用指南见 [`ToolbarNavigation.md`](../ToolbarNavigation.md)。 |
| [0005](0005-observable-settings-model.md) | SettingsStore：改用可观察引用模型并保留属性级失效 | Implemented | 把 0002 的值类型根 Store 改成 `@Observable` class 模型：业务监听按顶层属性失效，Store 则通过模型明确列出的 `accessPersistedValues()` 独立监听所有编码字段并防抖保存。用 generation 处理 Observation 的 willSet 回调、加载换对象与显式保存竞态；RuntimeViewer 同批接回，`transformer` 不再被 `theme` 修改唤醒。 |
| [0006](0006-settings-window-configuration.md) | SettingsWindowController.Configuration：集中管理设置窗口自定义项 | Implemented | 用单一 `Configuration` 收拢窗口标题、窗口尺寸、侧栏宽度、侧栏图标尺寸与导航按钮开关；RuntimeViewer 可显式恢复迁移前的 15 pt glyph 尺寸。 |
| [0007](0007-settings-scene.md) | SettingsScene：让 SwiftUI 与 AppKit 共用原生设置 Scene | Implemented | 在 window controller 与可嵌入 root view 之外增加真正的 SwiftUI `Settings` Scene；SwiftUI App 可直接声明，macOS 26+ 的 AppKit App 可通过 `NSHostingSceneRepresentation` 注册和打开。 |
| [0008](0008-top-level-settings-configuration.md) | SettingsConfiguration：把共享配置移出 Window Controller | Implemented | 配置同时服务 controller、scene 与 root view，不再嵌套于任一呈现入口；删除尚未发布的旧嵌套名称，不保留 alias。 |
