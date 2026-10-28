# UIFoundation 文档索引

跨项目复用的 AppKit 基础组件与基类。**新增或重命名任何文档都必须同步更新这份索引。**

> **项目类型：库（源码分发）**。SPM library product，使用方每次重新编译，无 ABI 约束，
> 但**源码兼容性必须评估** —— 本库是多个项目的公共底座，一处改动会同时传导到多个下游仓库。
> 提案见 [`Evolutions/README.md`](Evolutions/README.md)。

## 使用指南

十九篇都是完整指南：怎么用、宿主必须遵守什么契约、有哪些已知偏离，以及维护时看似能简化、实则不能动的实现细节。
**接入或修改任何一个组件前先读对应那篇。** 根目录的 `AGENTS.md` 只给每个组件留一行指向这里，细节一律写在指南里。

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
- [SpotlightPanel](SpotlightPanel.md) —— macOS 26 Spotlight 面板的复刻（浮动毛玻璃平台、查询框向下长成结果列表），
  几何、弹簧参数、缩放与内容模糊全部来自对 Spotlight 二进制的实测。**它只复刻外壳，不搜索任何东西**，
  结果由宿主通过 data source 提供。含五条宿主契约，其中最容易踩的是**失焦即关闭是本库的默认值而非 Spotlight 的行为**，
  以及**面板宽度与标准展开高度是选定值而非实测值**（Spotlight 那两个常量落在未覆盖的私有框架里）。
  另有「顶边钉死」的定位算法、非等比的消失缩放、比透明度慢近一倍的模糊曲线，以及与 Spotlight 的已知偏离。
- [TabBar](TabBar.md) —— 标签栏控件。含三条宿主必须知道的契约：**item 按身份而非位置匹配**、
  选中态归谁所有、`reloadTabs(animated:)` 到底动画了什么。另有 `SystemStyle` 的几何、
  堆叠、滚动与批量关闭行为，**装饰层为什么必须退出 hit-test**（macOS 27 SDK 下系统控件改走手势识别器，
  被盖住就收不到点击），以及与系统实现的已知偏离。
- [TextFinder](TextFinder.md) —— 表格与大纲视图的 ⌘F 查找。**含一条踩了就静默出错的契约**：
  宿主禁止直接调用 `textFinder.performAction(_:)`，必须走 `textFinderClient.performTextFinderAction(_:)`
  —— 索引是惰性的，直接调会搜到空文档且不报错。另有表格的 run-length 快路径与大纲的外部索引机制。
- [PlaybackSlider](PlaybackSlider.md) —— Music 全屏播放器的时间进度条：静止时 7 pt 无滑块的胶囊，按下即跳到指针处、
  用弹簧长到 16 pt，松手缩回；按下和松手各通知委托一次。plus-lighter 混合要开 `AppleInternal` trait，不开时普通混合、
  略暗。另有为什么要松手才跳转播放位置、容器的命中测试为什么必须交回滑块本身，以及测试里为什么不能投递真实点击。
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
- [GlassEffectReplica](GlassEffectReplica.md) —— `AppleInternal` trait 下的 `GlassEffectReplicaView`：放进
  macOS 26+ split view 给 sidebar / inspector 套的那块 `NSGlassEffectView` 里，拷贝其配置并加入同一个
  Core Animation backdrop group，渲染结果逐像素一致且不透明（侧栏导航转场的页面背景）。**含一条踩了就差一个
  色阶的契约**：第一帧在 SwiftUI 建出 layer 树之前不保证一致，只能靠页面从屏幕外进入或被盖住来掩护。
  另有「必须落在玻璃内容里」「内容加在它上面」两条契约，以及为何 `_backdropGroupName` 走不通的实测。
- [TableViewRowHeightEstimation](TableViewRowHeightEstimation.md) —— `AppleInternal` trait 下的
  `tableView.box.estimatesRowHeights`：关掉 AppKit 的私有行高估算。带分组行、有可展开条目的 source list 大纲，
  滚到靠后位置时重载或展开会把行留在旧的估算位置，再一滚动就两行叠画；关掉估算后 AppKit 精确计算每一行的位置。
  **含一条踩了就等于没关的契约**：每次设置 delegate，AppKit 都会把估算重新打开，所以要在设置 delegate 之后关，
  delegate 代理自己重设 delegate 时也要跟着再关。另有「切换不会挪动屏幕上已有的行」（所以只能在行显示之前切，
  或切换后自己 `reloadData()`）、为何不用应用级默认值 `NSTableViewCanEstimateRowHeights`，以及关掉估算后带动画
  收起的一处存疑现象。
- [ScrollPockets](ScrollPockets.md) —— `AppleInternal` trait 下 `NSScrollView.box` 的 scroll pocket 封装：让浮在列表上的
  自制栏也有 macOS 26 的滚动边缘效果（登记容器、常显一条边、样式、只读查看 pocket），以及栏要回答的
  `NSView.barScrollPocketElementStyle`。**含一条踩了就没有效果、却看不出错的契约**：底部 pocket 的高度跟滚动视图自己的
  `contentInsets.bottom` 走，只设 clip view 的 inset 时高度为 0。另有顶部 pocket 跟安全区而不跟 inset、登记要配对撤销、
  私有方法会在小版本之间消失（27.0 的 `_registeredPocketContainersOnEdge:` 在 27.2 已删）。
- [NotificationMessages](NotificationMessages.md) —— 在 macOS 27 / iOS 26 之前的系统上，用 AppKit / UIKit 预置的类型化通知消息
  （`NSWindow.Backport.DidBecomeKeyMessage` 配 `.didBecomeKey` 之类，AppKit 137 个、UIKit 71 个），转换行为逐个照抄苹果二进制。
  **含两条踩了就静默收不到的契约**：`NSWorkspace` 的消息只在 `NSWorkspace.shared.notificationCenter` 上发；
  带属性的消息缺一个值或类型不对，观察者就不被调用（手动 `post` 的通知最容易踩）。另有经子类找不到父类消息的四组类型、
  `NSTableView` 与 `NSOutlineView` 四对同名标识符的歧义、在苹果原生可用处简写会选苹果的那个，以及迁回原生的步骤。
- [AsyncDocument](AsyncDocument.md) —— `AsyncDocument<Snapshot>`：读写都是 async 的 NSDocument 子类。子类实现四个方法：
  主线程同步取快照、后台 async 写盘、后台 async 读盘、主线程同步填回。另附 `NSDocument.box` 上 9 个 async 方法，
  把 `canClose`、带面板的保存这类回调式操作改成可以 `await`。**含一条踩了就静默卡死的契约**：`write` 和 `readSnapshot`
  绝不能跳回主线程，恢复版本、复制文档、手动保存的文档都是主线程在等它们。另有：不开 `autosavesInPlace` 就是同步写盘；
  后台打开时 `init` 不在主线程（Swift 6 子类因此需要基类的 `nonisolated init()`）；被 `final` 封住的 NSDocument 原有读写方法；
  与 SwiftUI `DocumentGroup` 的三处实测差别；版本浏览器的一处未实测风险。
- [AppKitPlus](AppKitPlus.md) —— 打开 `AppKitPlus` trait 后会变什么：`LayerBackedView` 与 `LayerBackedViewController`
  换用 AppKitPlus 的基类、`NSEdgeInsets` 的相等性改由 AppKitPlus 提供，以及为什么不管开不开 trait，macOS 下限都是 12。
  **含一条踩了就连下游一起编不过的契约**：trait 打开时，子类不能声明 AppKitPlus 已经加到该类上的同名属性
  （`center`、`transform`、`layoutMargins` 等），这条限制会随模块传给每个下游。另有升级 AppKitPlus 前的撞名排查
  （查公开头文件，不查 `.swiftinterface`）和版本下限的来历。
- [LayerBackground](LayerBackground.md) —— `LayerBackedView` 与它背后的图层背景管线（圆角、背景色、边框、阴影），
  以及怎样把它装到不能继承它的 `NSView` 子类（如 `NSTableCellView`）上。**含一条踩了就静默失效的契约**：
  本身已有 `backgroundColor` 的类（`NSTextField`、`NSTableView`、`NSScrollView`）不能遵守这个协议，否则协议的属性
  被遮蔽、收不到值。另有 macOS 27.2 上设圆角会自动打开裁剪、连续圆角边框的画法，以及按像素测试时参照物要先裁剪。
- [QuickActionBar](QuickActionBar.md) —— 从 DSFQuickActionBar 移植的 Spotlight 式浮动操作栏：公开 API、两段式 Escape
  （先清空查询再关闭）、可以中途反转的收起动画、Spotlight 的弹簧尺寸动画，以及与上游的差异。另有在测试进程里驱动它的
  两个坑：窗口不会成为 key，所以要直接发 `cancelOperation:`；content source 要活到结果返回之后。
- [FilterUI](FilterUI.md) —— 从 filter-ui 移植的 AppKit 过滤控件（搜索框、token 框、可过滤菜单）：公开 API 版与
  私有 API 版 `FilteringMenu` 的分工、资源与 `defaultLocalization`。**含一条命令行下必踩的坑**：`swift build` /
  `swift test` 不跑 `actool`，资源取出来全是 `nil`，跟资源有关的测试只能走 `xcodebuild`。
- [CustomToolTip](CustomToolTip.md) —— `AppleInternal` trait 下替换 AppKit 工具提示外观的 `CustomToolTipManager`：
  全局与单个视图的样式、按引用计数安装、对 `NSToolTipManager` 单例的 isa-swizzle 钩子、在系统材质与图层背景内容视图
  之间切换，以及用到的私有头文件。

## Agent 插件

- [`AgentPlugins/uifoundation/`](../AgentPlugins/uifoundation/) —— 使用方的 coding agent 安装的插件 `uifoundation`，
  带两个英文 skill：`uifoundation-widgets`（写 AppKit 代码前先查本库已有的组件与构建器，以及 `Label`、
  `ScrollView`、构建器的坑）与 `uifoundation-settings-layer`（在 `PersistentSettings` 上搭设置层，含两条踩了就
  静默不存盘的规则）。**改了它们描述的公开 API，同一提交里更新对应 skill 并升插件版本号**（规则见 `AGENTS.md`）。
  安装方式见 README 的 Agent Plugin 一节，由来见提案 [0028](Evolutions/0028-agent-plugin.md)。

## 术语表

| 文档 | 说明 |
|------|------|
| [Glossary.md](Glossary.md) | 本库术语。现有一条：快照模型（`AsyncDocument` 的读写拆法）。原有五条随 RunningApplication 的撤销一并移除（见 [0014](Evolutions/0014-running-application-merge.md)） |
