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
| [0009](0009-standard-main-menu.md) | MainMenu：纯代码 macOS App 的标准主菜单 | Implemented | AppKit 没有 API 能生成 MainMenu.xib 那份标准主菜单，纯代码工程只能手抄或留一个只装菜单的 xib。在既有 `@MenuBuilder` DSL 之上新增 `MainMenu` 命名空间：`MainMenu.standard()` 一行拿到模板等价主菜单，`MainMenu.menu { … }` 按顶层菜单 / 单个标准项两级粒度自定义；`windowsMenu` / `helpMenu` / `servicesMenu` / font menu 在装配时按 identifier 自动接线，工厂零副作用。纯新增、无 trait；示例 App 已换用并删除了仅为主菜单保留的 storyboard。配套使用指南见 [`MainMenu.md`](../MainMenu.md)。 |
| [0010](0010-main-menu-builder.md) | MainMenu.Builder：按 identifier 增删改标准主菜单 | Implemented | 0009 里改 `standard()` 的单个项要把整个菜单重列一遍。仿 UIKit `UIMenuBuilder` 的 Swift 接口（`NS_SWIFT_NAME` 形态）加一个变换层：`ItemIdentifier` 改为 struct 并给全部约 90 个标准项打 id，`MainMenu.standard(customizing:)` 把建好的树交给 `MainMenu.Builder` 做查询 / 四向插入 / 替换 / 删除，变换先于接线执行，孤儿分隔符收尾规整。UIKit 三类元素（组 / action / command）在 NSMenu 里坍缩为 item 一类，故三套寻址合并为一套、不做 selector 通道。小范围源码破坏：`ItemIdentifier` 常量类型变化、`windows` 更名 `window`（旧名弃用保留）。 |
| [0011](0011-welcome-panel.md) | WelcomePanel：把 WelcomeKit 的 Xcode 式欢迎窗口移植进本库 | Implemented | 把作者自己的独立仓库 `Mx-Iris/WelcomeKit`（Xcode 式欢迎窗口：左侧图标 / 版本 / 三个操作，右侧最近项目列表，三种样式）整体搬进本库，落在新 trait `WelcomePanel`（默认关闭）下，仅 macOS。公开 API 收进 `WelcomePanelController` 一个顶层符号，其余全部嵌套；内部重复件（图层背衬视图基类、`Then`、`ConstraintMaker`、`ArrayBuilder` 等约 500 行）换成本库已有的基类与 `.box` 扩展 —— 其中四个类名与本库顶层符号直接冲突，去重是搬迁的前提而非可选项。**运行时行为一律保持原样**，包括 `.xcode26` 样式已知的两处漏判（关闭按钮无图标、操作项点按无高亮），只记录不修。 |
| [0012](0012-xcode26-faithful-style.md) | WelcomePanel `.xcode26`：按实测重做成真正的 Xcode 26 复刻 | Implemented | 0011 搬进来的 `.xcode26` 只是 `.xcode15` 的几何去掉毛玻璃，不对应任何真实 Xcode 版本。依据 Xcode 26 欢迎窗口的 view hierarchy 抓包逐项实测重做：圆角 8→20、两侧改用 `NSVisualEffectView(.fullScreenUI)`（**实测其滤镜链与抓包逐位一致，故不需要私有 API**）、标题 30→36 bold、操作项圆角 8→18 胶囊、行内间距与首行位置对齐、图标蓝色辉光变默认；并顺带修掉 0011 故意保留的两处漏判（关闭按钮无图标、点按无高亮）。`.xcode14` / `.xcode15` 不动，公开 API 形状不变，但**观感是破坏性变更**。逆向依据见 [`Researchs/Xcode26-WelcomeWindow-Internals.md`](../../Researchs/Xcode26-WelcomeWindow-Internals.md)。深浅两份抓包均已实测：**几何在两种外观下逐帧一致，只有配色变，且图标辉光仅深色存在**。 |
| [0013](0013-main-menu-factory-customizing.md) | MainMenu：每个多项子菜单的工厂都提供 customizing 参数 | Implemented | 0010 只给 `standard()` 装了 `MainMenu.Builder`，于是「按 identifier 改单个项」这项能力只存在于「整根菜单栏」这一个粒度上：用 `menu {}` 自选顶层菜单的宿主拿不到 builder，`Edit.find()` / `Format.font()` 这类分组子菜单更是毫无入口，想改一项就得整份重列（连带复制那些抄错也不报错的 tag 与 selector）。本提案把同一个 `customizing:` 参数补齐到全部 15 个**产出多项子菜单**的工厂上，并把 Builder 的寻址根从 `NSMenu` 扩展到「菜单项自身 + 其 submenu 子树」，使无 `title` 参数的分组标题也改得到。判据是「submenu 有多个 item 才给」，故排除约 70 个单项工厂、空 submenu 的 `Application.services()` 与只有一项的 `File.openRecent()`。纯新增，不动任何既有签名；三重载下四种闭包形态的消歧已实测。 |
