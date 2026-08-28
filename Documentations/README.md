# UIFoundation 文档索引

跨项目复用的 AppKit 基础组件与基类。**新增或重命名任何文档都必须同步更新这份索引。**

> **项目类型：库（源码分发）**。SPM library product，使用方每次重新编译，无 ABI 约束，
> 但**源码兼容性必须评估** —— 本库是多个项目的公共底座，一处改动会同时传导到多个下游仓库。
> 提案见 [`Evolutions/README.md`](Evolutions/README.md)。

## 使用指南

九篇都是面向调用方的完整指南：怎么用、宿主必须遵守什么契约、有哪些已知偏离。
**接入任何一个组件前先读对应那篇。**

- [MainMenu](MainMenu.md) —— 纯代码构建 MainMenu.xib 等价的标准主菜单，四级粒度自定义，
  含仿 `UIMenuBuilder` 的 `MainMenu.Builder`（全部标准项可按 identifier 查询 / 插入 / 替换 /
  删除，变换先于接线、孤儿分隔符自动规整）。
  **含一条接线契约**：Services / Window / Help / Font 四处系统接线发生在 `MainMenu.menu {}` /
  `standard()` 装配时（按 identifier 扫描），单项工厂零副作用。另有 AppKit 自动插入项清单
  （手工重复添加会出现两份）、Open Recent 无公开接线的现状与替代做法，以及逐项对照模板 xib
  的保真笔记（`print:` 而非 `printDocument:`、Find 组的 tag、Font 菜单里五项直接 target
  `NSFontManager` 等）。

- [SettingsWindow](SettingsWindow.md) —— System Settings 形状的设置窗口与原生 SwiftUI
  `SettingsScene`，后者可由 macOS 26 AppKit 通过 `NSHostingSceneRepresentation` 注册；另带一个会自己
  持久化的 `@Observable` 设置模型。**含一条踩了就静默漏存的契约**：`accessPersistedValues()` 必须读取
  每个编码属性。另有 section 级失效粒度、为什么 `AppSettings` 不遵守 `DynamicProperty`、`@Observable`
  与 Codable 的配合方式，以及侧栏禁折叠为何不需要 swizzle 的实测结论。

- [Navigation](Navigation.md) —— 视图控制器导航栈与推入/弹出转场，移植自 macOS App Store 自己那套。
  含四条宿主必须知道的契约：**容器独占子视图 frame，禁止从外部给页面加约束**、
  页面会被强制图层背衬、交互式返回会吃掉横向滚动事件、转场进行中的栈变更是**延后**而非立即生效。
  另有可调的观感参数（时长/视差/压暗曲线，默认值全部逆向自 App Store 二进制）、自定义转场的写法，
  以及与 App Store 实现的已知偏离。
- [TabBar](TabBar.md) —— 标签栏控件。含三条宿主必须知道的契约：**item 按身份而非位置匹配**、
  选中态归谁所有、`reloadTabs(animated:)` 到底动画了什么。另有 `SystemStyle` 的几何、
  堆叠、滚动与批量关闭行为，以及与系统实现的已知偏离。
- [TextFinder](TextFinder.md) —— 表格与大纲视图的 ⌘F 查找。**含一条踩了就静默出错的契约**：
  宿主禁止直接调用 `textFinder.performAction(_:)`，必须走 `textFinderClient.performTextFinderAction(_:)`
  —— 索引是惰性的，直接调会搜到空文档且不报错。另有表格的 run-length 快路径与大纲的外部索引机制。
- [SystemHUD](SystemHUD.md) —— 系统风格的 HUD 提示。
- [ToolbarNavigation](ToolbarNavigation.md) —— `NSToolbar.Navigation`，Safari 式的后退 / 前进工具栏项。
  数据由组件**主动拉取**（借 `NSToolbarItem` 的验证周期），所以没有「历史变了要通知它」这一步。
  含三条宿主契约：历史行的**索引 0 是最近的一条**、跑在验证周期上的两个问题必须廉价、
  窗口非 key 时刷新会延后。观感由库定死，控件不暴露也不转发样式 —— 这正是两条被 API 完全藏住的
  AppKit 行为得以结构性锁死的方式；另有第三条「踩坑」的实测证否。
- [WelcomePanel](WelcomePanel.md) —— Xcode 式的欢迎窗口（左侧图标 / 版本 / 操作项，右侧最近项目），
  三种样式对应三代 Xcode。项目列表由组件**主动拉取**（赋 data source 时、`showWindow(_:)` 时、
  窗口重新可见时各一次）。含七条宿主契约，其中最容易踩的是**窗口对象不可达**
  （`window` 被标为 unavailable，只能走 `showWindow(_:)` / `close()`）与
  「启动时显示」复选框只有 `.xcode14` 才有。`.xcode26` 是**按 Xcode 26 抓包实测重做的复刻**
  （毛玻璃 = `.fullScreenUI`，圆角 20，标题 36 bold，胶囊操作行，深色自带图标辉光）。

- [RunningApplication](RunningApplication.md) —— 运行中的应用与 BSD 进程：值类型模型（架构 /
  平台 / 沙盒判定）、两个观察者，以及一个带搜索与排序的选择器（表格与列表两种呈现）。
  **不在伞包里**，要单独依赖 product 并 `import UIFoundationRunningApplication`。
  含四条宿主契约，最容易踩的是 **`platform` 为 `nil` 的含义是「不知道」而不是「不是模拟器」**
  （约 5% 的受保护进程读不到路径），以及行高 / 图标尺寸的默认值**随样式变、显式设过就锁死**。
  另有「架构判不出模拟器」的成因、只标 guest 进程的判据，以及两种样式对「不值一提的值」
  刚好相反的处理。

## 实现说明

面向维护者：最终怎么实现的、为什么这么实现、有什么降级。

| 文档 | 说明 |
|------|------|
| [Internal/PlatformDetection.md](Internal/PlatformDetection.md) | 平台识别的落地细节：内核为什么问不到、slice 四级回退的实测依据、变异测试结论与已知降级 |
| [Internal/PresentationStyles.md](Internal/PresentationStyles.md) | 表格与列表两种呈现的落地细节：为什么列表仍是 NSTableView、样式默认值怎么不破坏公开类型、骨架屏与提案的差异 |

## 术语表

| 文档 | 说明 |
|------|------|
| [Glossary.md](Glossary.md) | 本库术语：field 与 column 之别、style、guest 进程、platform 与 architecture 之别、ExclaveCore / ExclaveKit |
