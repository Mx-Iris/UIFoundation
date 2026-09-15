# 0021 - SpotlightPanel：按二进制实测复刻 macOS 26 的 Spotlight 面板

- **状态**: Implemented
- **创建日期**: 2026-09-15
- **最后更新**: 2026-09-15
- **所属愿景**: 无
- **配套文档**: 使用指南 [`SpotlightPanel.md`](../SpotlightPanel.md)、逆向报告 [`Researchs/Spotlight-Panel-Internals.md`](../../Researchs/Spotlight-Panel-Internals.md)

## 摘要

本库现有的 `QuickActionBar` 是 `dagronf/DSFQuickActionBar` 的移植，它的动画参数在此前一轮里
已经逐位对齐了 Spotlight（present / dismiss 的 spring 参数、1.12 × 0.95 的非等比缩放、40 pt
动画留白、28 pt 圆角、window level 23 全部实测相同），**但它的骨架不是按 Spotlight 的架构长
的**：窗口定位用的是一个 `/1.3` 的魔数、展开高度写死一个常量、尺寸变化没有防抖、没有位置记忆、
没有内容驱动尺寸的契约，键盘表只有四条。这些不是「补几个方法」能改好的，因为 Spotlight 把
「内容要多高」和「窗口该多高」拆成了一整层协议（`SPSizingDelegate` + `ResultPlatterBehavior`），
而 `QuickActionBar` 里根本没有这一层可以挂。

本提案**不改 `QuickActionBar`**，而是在 `UIFoundationAppleInternal` 下按 Spotlight 26.6.2 的
二进制实测重新实现一个 `SpotlightPanel`：窗口与面板几何、完整动画（含 `QuickActionBar` 缺的那
条内容模糊曲线）、内容驱动的尺寸策略、结果列表、完整键盘表、搜索历史、过滤 token 栏、inline
补全与导航栈。**搜索内容由宿主通过 data source 提供** —— 复刻的是外壳与交互，不是搜索后端。
落在新 trait `SpotlightPanel`（默认关闭）下，对现有使用方零影响。

## 方案

### 一、逆向实测数据（macOS 26.6.2 Spotlight.app，IDA 反编译，非推断）

以下是实现要照着写的硬数据。完整的反编译过程与函数地址落在 `Researchs/Spotlight-Panel-Internals.md`。

#### 1. 动画配方

出现与消失各是**两条独立的曲线组**，分别挂在 layer 和 window 上，用一个 `dispatch_group`
汇合后回调：

| | layer（`transform.scale.x/y`） | window `alphaValue` | window `contentBlurRadius` |
|---|---|---|---|
| **出现** | 1.12 / 0.95 → 1.0，`CASpringAnimation(perceptualDuration: 0.28, bounce: 0.41 / 0.32)` | 0 → 1，spring(0.28, 0.41) | 不参与（起始即 0） |
| **消失** | 1.0 → 1.12 / 0.95，spring(0.45, 0.05) | 1 → 0，spring(0.28, 0.41) | 0 → 25，**spring(0.51, 0.05)** |

三点值得单独记住：

- **缩放是非等比的**：横向 1.12、纵向 0.95，所以消失时面板是「横着摊开」而不是整体放大。
  `bounce` 两轴也不同（0.41 / 0.32）。
- **模糊那条曲线独立且更慢**（0.51 对 0.28），所以观感是「先虚化、后消失」，不是同步淡出。
  终值 25.0 来自非动画降级分支里直接写的终态，不是推断。
- 动画整体受 `SUIUtilities.isInvocationAnimationEnabled` 和
  `NSAccessibilityEnhancedUserInterfaceEnabled()` 两道门控，关掉时直接写终态并回调。

#### 2. 定位公式

`-[SPSpotlightPanel defaultPositionOriginForWindowSize:screen:]` 化简后：

```
y = screen.minY + (screenHeight + standardExpandedHeight) / 2 − windowHeight
```

意思是：**把一个「标准展开高度」的面板垂直居中，取它的顶边，然后不论当前面板多高，顶边永远钉
在那里。** 折叠时面板偏上，展开后正好整体居中。`QuickActionBar` 现在的
`(height − collapsedHeight) / 1.3` 是按折叠高度算锚点的，所以展开后会偏下。

公式里的 `standardAppBrowseHeight` = `ResultPlatterBehavior.gridBrowse.minHeight + heightCollapsed`。
加号左边那项在 `SpotlightUIShared.framework` 里，**本轮没有取到具体数值**；公式的形状才是要点，
该常量由本库自己定（暂定值见下）。

#### 3. 尺寸常量（`SearchConstants`，括号内为旧版 Spotlight 的值）

| 常量 | 实测值 |
|---|---|
| `heightCollapsed` | **56**（旧 52） |
| `minHeightExpanded` | **430** |
| `windowCornerRadius` | **28**（旧 16） |
| `animationWindowPadding` | **40**（四边） |
| `windowPadding` | `NSDirectionalEdgeInsetsZero` |
| `standardHorizontalContentInset` | **20**（旧 0） |
| `heightTopLevelFilters` | **160** |
| `separatorHeight` | **1** |
| `tokenCornerRadius` | **10**（旧 5） |

#### 4. 面板属性

```objc
becomesKeyOnlyIfNeeded      = YES
releasedWhenClosed          = NO
level                       = 23
isOpaque                    = NO
backgroundColor             = clearColor
hidesOnDeactivate           = NO
isMovable                   = NO
autorecalculatesKeyViewLoop = YES
CGSSetConnectionProperty(CGSMainConnectionID(), … , @"SetsCursorInBackground", kCFBooleanTrue)
```

#### 5. 屏幕变化时的重定位

`recomputeFrame:forVisibleScreenArea:` 的策略是**粘边优先、否则按比例**，阈值 100 pt：某一侧
间距小于 100 pt 就保持该固定间距贴边，否则按左右（上下）间距比例插值。用于换显示器、改分辨率、
Dock 显隐。

#### 6. 尺寸契约

```objc
@protocol SPSizingDelegate
- (CGFloat)windowHeightForMinimumSize:(CGSize)min preferredSize:(CGSize)preferred
                          maximumSize:(CGSize)max useStoredSizeIfNeeded:(BOOL)stored
                     usePreferredSize:(BOOL)usePreferred;
- (void)didInvalidateContentWithMinimumSize:… animated:(BOOL)animated;
@end
```

配 `ResultPlatterBehavior` 八个字段（`minHeight` / `preferredHeight` / `maxHeight` /
`heightCanPersist` / `includeFilterBarHeight` / `collapseForEmptyResponse` / `animated` /
`width`）和 `ExpansionState` 四态（`uninitalized` / `collapsed` / `expanding` / `expanded`），
外加两个独立防抖器（`windowSizingDebouncer`、`expansionDebouncer`）。

### 二、目标与非目标

**目标**：窗口与面板几何（定位、位置记忆、屏幕重定位）、完整动画、内容驱动的尺寸策略、结果
列表、完整键盘表、搜索历史、过滤 token 栏、inline 补全、导航栈。

**非目标**，且都是明确排除而非「以后再说」：

- **搜索后端**。不接 CoreSpotlight / Metadata 查询。内容一律由宿主提供，本组件不知道结果是什么。
- **预览面板**。Spotlight 的 `SPAppPreviewController` / QuickLook 那一套不做。
- **链接 Apple 私有框架**。不 dlopen 也不链接 `SearchUI.framework` / `SpotlightUIShared.framework`
  —— 那能最像，但每次系统更新都可能整个失效。所有控件自己用公开 AppKit 画。
- **抢占系统热键**。不碰 `CGSSetSymbolicHotKeyWithExclusion` / `CGSNewConnection` + mach port
  那条路径。⌘Space 归系统，宿主要全局热键自己用 `RegisterEventHotKey` 或
  `NSEvent.addGlobalMonitor`。
- **SwiftUI**。Spotlight 自己是 `NSHostingView<MainWindowView>` 混合结构，本复刻纯 AppKit，与本库
  其余组件一致。

### 三、打包与命名

- **新 trait `SpotlightPanel`，默认关闭**，声明为
  `.trait(name: "SpotlightPanel", enabledTraits: ["AppleInternal", "Navigation"])`
  —— 已确认 `PackageDescription.Trait` 支持 `enabledTraits`，所以宿主只写一个 trait 即可，不必
  自己记住要连带打开另外两个。
- 源码在 `Sources/UIFoundationAppleInternal/SpotlightPanel/**`，每个文件包
  `#if SpotlightPanel && os(macOS) … #endif`。放 AppleInternal 的唯一理由是
  `_setContentBlurRadius:`；那条曲线是观感的一部分，不是可选装饰。
- **唯一顶层符号 `SpotlightPanel`**，其余全部内嵌（与 `TabBar` / `WelcomePanel` / `SystemHUD`
  一致）。文件按唯一 basename 规则前缀成 `SpotlightPanel+X.swift`。
- 新私有头 `Sources/UIFoundationAppleInternalObjC/include/NSWindow_Private.h`（`NSWindow` 是公开
  类，按本库约定用 `<Class>_Private.h` 形态 re-open）。CGS 那两个符号沿用本 target 已有的
  `@_silgen_name` 做法。
- 不进伞包的额外 product —— 它随 `AppleInternal` 一起挂在 `UIFoundation` 下，与 Tooltip 同路径。

### 四、模块结构

五层，下面三层不知道上面两层的存在：

```
SpotlightPanel                      宿主入口：present / dismiss / dataSource / delegate
 ├── SpotlightPanel.Controller      导航栈根，持有搜索栏 + 结果列表
 │     └── (复用) NavigationController        ← 本库 Navigation trait
 ├── SpotlightPanel.PlatterBehavior + SizingDelegate   内容 → 窗口高度
 ├── SpotlightPanel.AnimationCoordinator     present/dismiss、断言集合、模糊
 └── SpotlightPanel.Panel           NSPanel 子类：几何、定位、位置记忆、屏幕重定位
```

**导航栈复用本库已有的 `Navigation`，不仿 Spotlight 的 `NSPageController`。** Spotlight 用
`NSPageController` + live transition 拿到横向推入/弹出和两指滑动返回；本库的
`NavigationController`（提案 0001，移植自 macOS App Store）提供的是同一组交互，已经有测试也有
使用指南。再造一个 `NSPageController` 版本只会多一份要维护的转场代码。

### 五、分期

三期，每期都能单独交付和验收：

| 期 | 内容 | 验收 |
|---|---|---|
| **一** | `Panel` + `AnimationCoordinator` + `PlatterBehavior`/`SizingDelegate` + 搜索框 + 结果列表 + 完整键盘表 | 可用的命令面板，观感与 Spotlight 一致 |
| **二** | 位置记忆与拖动（含 `NSAlignmentFeedbackFilter`）、屏幕变化重定位、搜索历史 | 多屏 / 拖动 / 历史可用 |
| **三** | 过滤 token 栏、inline 补全、导航栈接入 | 交互层补齐 |

一期结束就应该更新示例 App（新增一个 demo，并在 `XCLocalSwiftPackageReference` 的 traits 里加
`SpotlightPanel`）。

### 六、本轮未问、自行假定的事项

按默认档，下列决定是自己拍的，写在这里供推翻：

1. **`standardExpandedHeight` 暂定 430**（即 `minHeightExpanded` 实测值），因为它在 Spotlight 里
   的真实组成项取不到。宿主可通过配置覆盖。
2. **键盘表照抄 Spotlight 的 13 条**（`selectAll:` / `copy:` / `paste:` /
   `quickLookPreviewItems:` / `deleteBackward:` / `insertTab:` / `insertBacktab:` /
   `insertNewline:` / `cancelOperation:` / `moveUp:` / `moveDown:` / `moveLeft:` / `moveRight:`），
   其中 `quickLookPreviewItems:` 因为不做预览面板，改为转发给 delegate 由宿主决定。
3. **结果行用 `NSTableView` + `alwaysEmphasized` 等价实现**（失焦仍保持强调色），行视图由宿主
   提供，与 `QuickActionBar` 的 data source 形状类似但不共享类型。
4. **无障碍降级**：`accessibilityDisplayShouldReduceMotion` 为真时跳过动画直接写终态，对应
   Spotlight 的两道门控。
5. **不做 `SessionAnalytics` 等价物**，但按项目规范用 `OSToolbox` 的 `@Loggable` / `@Signpostable`
   给 present / dismiss / 尺寸失效三处埋点。

### 七、测试

- 几何与尺寸策略（定位公式、粘边重定位、`PlatterBehavior` 钳制）可无显示器断言，这是测试重点。
- 动画只断言**配方**（spring 的 `perceptualDuration` / `bounce`、from/to 值、keyPath 集合），
  不断言视觉 —— 与 `SelfSizingRowViewsTests` 断言动画上下文而非动画本身同一思路。
- 断言里的 `CGFloat` 必须两边同类型，别与 `Double` 变量比（见 `CLAUDE.md` 的 Swift Testing 一节）。

### 八、下游影响

**零。** 新 trait 默认关闭，不改任何既有 target 的源码，`QuickActionBar` 一行不动。已知下游
（RuntimeViewer、MachOKitUI、PrivateSymbols）不受影响。

顺带修正一处文档失准：`CLAUDE.md` 称 `UIFoundationAppleInternal` 是 separate product，实际它是
伞包在 `AppleInternal` trait 下的条件依赖，没有独立 product。本批次一并改掉。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-15 | Created as Draft | 用户要求：不管原有 `QuickActionBar`，在 Internal target 另起一个与 Spotlight 一模一样的复刻 |
| 2026-09-15 | 范围 = 外壳 + 交互层，数据由宿主提供 | 复刻体验而非做搜索后端；接 CoreSpotlight 会让 UIFoundation 从 UI 库变成应用框架 |
| 2026-09-15 | 只用 `NSWindow` / CGS 级私有 API，不链 Apple 私有框架、不抢系统热键 | 链私有框架最像但每次系统更新都可能整个失效；热键抢占是进程级副作用，不该由一个 UI 组件引入 |
| 2026-09-15 | 新 trait `SpotlightPanel`，`enabledTraits: ["AppleInternal", "Navigation"]` | 与 TabBar / WelcomePanel / SystemHUD 的打包方式一致；`enabledTraits` 已确认可用，宿主不必自己记住连带 trait |
| 2026-09-15 | `QuickActionBar` 原样保留，不弃用也不删除 | 它是 DSFQuickActionBar 的 MIT 移植且 trait 默认关闭，留着零成本；两者独立演进，不共享代码 |
| 2026-09-15 | 导航栈复用本库 `Navigation`（0001），不仿 `NSPageController` | 两者交互等价（横向推入弹出 + 两指滑动返回），本库那份已有测试与使用指南，再造一份只是多一处要维护的转场代码 |
| 2026-09-15 | 纯 AppKit，不引入 SwiftUI | Spotlight 自身是混合结构，但本库其余组件一律 AppKit-first |
| 2026-09-15 | 分三期交付，一期即可独立验收 | 整体工作量过大，一次性落地无法验收也无法回退 |
| 2026-09-15 | 状态 Draft → Accepted → In Progress | 用户批准（「开工」），一期实现开始 |
| 2026-09-15 | `UIFoundationAppleInternal` 新增 `OSToolbox` 依赖 | 提案第六节第 5 条要求用 `@Loggable` / `@Signpostable` 埋点；本库此前无任何日志，故这是一次新增依赖，范围仅限该 target |
| 2026-09-15 | 一期落地完成，状态置 Implemented | 面板 / 动画 / 尺寸策略 / 结果列表 / 键盘表全部实现，25 个测试通过（原始退出码 0），已验证金丝雀可变红 |
| 2026-09-15 | 无障碍降级只读 `accessibilityDisplayShouldReduceMotion` | 实测 `NSAccessibilityEnhancedUserInterfaceEnabled()` 未暴露给 Swift（`cannot find … in scope`），而 reduce motion 才是用户实际会设的那个开关 |
| 2026-09-15 | 动画回调类型选 `@MainActor () -> Void` 而非 `@Sendable () -> Void` | 回调必然在主线程触发；标 `@Sendable` 会逼每个调用点写 `assumeIsolated`，而 `@MainActor` 闭包本身就是 Sendable |
| 2026-09-15 | 几何算法多一个吃 `CGRect` 的重载 | `NSScreen` 构造不出来，而定位公式正是最该断言的一段；`defaultOrigin(forWindowSize:inScreenFrame:)` 让它可测 |
| 2026-09-15 | 测试 target 直接依赖 `UIFoundationAppleInternal` | 伞包只转出 public 成员，动画层的 internal 部分（`AnimationState.translation`、`makeSpringAnimation`）需要 `@testable import` 该模块本身 |
| 2026-09-15 | 补充两条本轮新增实测 | `topLevelBrowseButtonSpacing` = 10；浏览按钮是边长 `collapsedHeight − 2` 的正方形（`+[SearchConstants topLevelBrowseButtonSizeWithCollapsedWindowHeight:]` 只有四条指令）。已写进逆向报告 |
| 2026-09-15 | 不新增术语表条目 | `PlatterBehavior` / `ExpansionState` 等名字都是组件局部术语，且已在使用指南里就地定义；`Documentations/Glossary.md` 收的是跨组件的项目术语，这批不够格 |
| 2026-09-15 | 「模糊是否可用」从 `NSWindow` 扩展改为 `SpotlightPanel.isContentBlurSupported` | 写 Example 时才发现它是 internal，而使用指南已经把它当成宿主能查的东西写进契约第 4 条；挂在 `NSWindow` 上还会污染那个类型的命名空间，与本库的 `.box` 约定相悖 |
| 2026-09-15 | Example 扩成完整演示台 | 初版只有一个按钮加两个复选框，与 SystemHUD / Navigation 那几个可实时调参的 demo 不成比例。现覆盖几何 7 项、平台尺寸 5 项、行为 4 项，只读展示实测动画配方与环境状态（模糊可用性 / Reduce Motion），加事件日志与一个自动演示「消失中途反转」的按钮 —— 那条人工检查靠手速在 120 ms 内按两次键不可靠 |
| 2026-09-15 | **修复：起始模糊必须硬编码为 0，不能取自起始状态** | 落地版写的是 `startingState.blurRadius`，而 present 的起始状态是 `.dismissed`（blur 25），加上 present 刻意不动画模糊 —— 于是面板一出现就把窗口模糊写成 25 且此后再不改，它盖住的一切永久糊掉（用户截图证实）。重看反编译：Spotlight 的 `_setContentBlurRadius:` 调用在挑选起始 alpha 的 if/else **之外**，两个方向都是硬编码 0.0 |
| 2026-09-15 | 用探针测试摸清私有 API 的真实形状，再写断言 | 与其反复让用户肉眼试，先写一次性探针把事实打出来：setter 是 `_setContentBlurRadius:`、**getter 是 `_contentBlurRadius`**（不是 `contentBlurRadius`）、不带下划线的两个拼法根本不是 selector 但都是合法 KVC key、`setValue(_:forKey:)` 往返有效（动画路径成立）。探针跑完即删，结论进了私有头与逆向报告 |
| 2026-09-15 | 新增 `SpotlightPanelContentBlurTests`，6 条 | 按规范「修复必带复现测试并永久保留」：已验证把 bug 放回去后两条断言变红（读到 25.0）、修复后全绿。同类横向排查过 —— `alphaValue` 两个方向都参与动画，取起始状态是对的，模糊是唯一单向动画的属性，故此模式仅此一处 |
| 2026-09-15 | **修复：内容必须自己裁剪到圆角** | 实测 `NSGlassEffectView` **不会**把 contentView 裁到玻璃形状：表格的选中条方角直接穿过 28 pt 圆角，列表底部被硬切。改为 `contentView` 自带 `cornerRadius` + `masksToBounds` |
| 2026-09-15 | 结果表改用 `.inset` 样式 | `.plain` 给的是通宽方角高亮，与圆角平台冲突；`.inset` 自带圆角与左右留白，接近 Spotlight 的画法 |
| 2026-09-15 | **修复：首次搜索推迟到入场动画结束** | 原来 `present()` 里立即发起搜索，于是 layer 缩放动画（0.28 s）与结果到达触发的窗口展开同时跑；而缩放的居中位移是按**构建动画那一刻**的 layer bounds 算的，窗口中途长高就会让面板收尾时明显偏心。`QuickActionBar` 有同样的处理 |
| 2026-09-15 | 窗口 resize 改为逐帧驱动（`WindowFrameAnimator`） | 依据是 `QuickActionBar` 的先例：model frame 与视觉 frame 必须同步，否则 Auto Layout 会按终值布局内容。**但必须说明：回放实验证明这一条在无显示的测试进程里测不出与 `animator()` 的差别**，所以它是按先例选的实现，不是被测试证否 `animator()` 后选的 |
| 2026-09-15 | 更正一条测试文档 | `SpotlightPanelWindowFrameAnimatorTests` 起初声称能抓住 `animator()` 写法；把旧写法放回去后套件仍全绿，故改写注释如实说明它守不住这一点，不留假装在守护的测试 |
| 2026-09-15 | **修复：查询框在折叠高度内居中，而不是被拉满** | 探针实测：24 pt 文字的 `NSTextField` 内在高度是 28，但它的 cell 绘制区会填满给它的任何高度并把文字画在**顶部** —— 钉到 56 pt 就让查询文字贴着上边、下面空 28 pt。改为外套一个 56 pt 容器、字段用内在高度居中 |
| 2026-09-15 | 查询框补 2 pt 前导修正 | 同一次探针量到：无边框无 bezel 的 `NSTextField` 仍把 cell 排在 x = −2，不补的话查询文字比下方所有内容左 2 pt |
| 2026-09-15 | 探针证否「玻璃会内缩 contentView」的猜测 | 截图上的双层圆角轮廓一度被我判为裁剪 bug。实测 `NSGlassEffectView` 的 contentView 与 glass **frame 完全一致**（`(0,0,680,400)` 对 `(0,0,680,400)`），那两圈是 Liquid Glass 自身的边缘，不是缺陷；裁剪保留 |
| 2026-09-15 | 新增 `SpotlightPanelContentLayoutTests`，3 条 | 已双向验证：把拉伸写法放回去后变红（读到 56.0 而非 28.0），修复后全绿 |
| 2026-09-15 | **选中行改为自绘中性色，不用系统强调选中** | 与真 Spotlight 并排比对后发现的最刺眼差异。探针量出 `selectedContentBackgroundColor` = (0.153, 0.365, 0.376)（用户的强调色），而 Spotlight 是中性灰；另实测 `.inset` 样式**仍把全宽 bounds 交给 row view**（内缩只作用于 cell），故圆角与内缩必须自绘。同时把 `isEmphasized` 从 `true` 改为恒 `false` —— 它驱动 cell 的 `backgroundStyle`，留 true 会让浅色外观下行文字变白、压在浅灰带上看不见 |
| 2026-09-15 | 分隔线左右内缩 `horizontalContentInset` | 对比图里 Spotlight 的分隔线不到边，我们是通宽 |
| 2026-09-15 | 查询框新增可选前导 SF Symbol，默认 `magnifyingglass` | Spotlight 有放大镜，我们没有。做成 `Configuration` 项，传 `nil` 即可去掉 |
| 2026-09-15 | `Metrics` 新增 `resultSelectionCornerRadius` / `resultSelectionHorizontalInset`（10 / 8） | 两个都是**选定值而非实测** —— Spotlight 的结果行由私有框架 `SearchUI` 绘制，本轮逆向未覆盖。已在指南与源码里标注 |
| 2026-09-15 | **修复：窗口去掉 `.titled`，改为纯 borderless** | 用户第三次报「展开看起来还是有两层」。探针实测：`styleMask` 含 `.titled` 时 `contentLayoutRect` 只有 478（窗口内容 510），frame view 是 `NSThemeFrame` 且挂着 `NSTitlebarContainerView` —— 它是个真正的有框窗口，窗口服务器按 **760×510 的窗口矩形**描边并投影，而平台板在里面内缩 40 pt（`animationPadding`），于是外面凭空多出一圈圆角。`.titled` 当初是我为「更重的投影」自己加的，逆向报告里没有任何依据 |
| 2026-09-15 | 推翻上一轮「那两圈是 Liquid Glass 自身边缘」的结论 | 那次探针问的问题不对：只量了 glass 与 contentView 的 frame（确实一致，那条结论本身没错），却没往上量到窗口层。外圈一直是窗框，不是玻璃 |
| 2026-09-15 | 新增 `SpotlightPanelWindowChromeTests`，5 条 | 已双向验证：把 `.titled, .fullSizeContentView` 放回去后 3 条变红（`contentLayoutRect` 读到 478 而非 510、`.titled` 在位、`NSTitlebarContainerView` 在位），去掉后全绿。其中一条守的是 borderless 带来的新前提 —— `canBecomeKey` 的 override 从「重述默认值」变成「唯一让查询框能聚焦的东西」，删掉就没人能打字了 |
| 2026-09-15 | 排除 `NSBox` 分隔线的嫌疑 | 同一次探针量到它的 frame 是 5 pt 高，一度像是偷了 4 pt 布局高度；但 `alignmentRectInsets` 是上下各 2，而 Auto Layout 约束作用在对齐矩形上，56 + 1 + 373 = 430 精确成立。不是 bug，不改 |
| 2026-09-15 | 落地时分配编号 0021 | 共享分支上的全局最大编号是 0020（`origin/main`），按 evolution 规约在落地提交里改名并同步全部同仓链接（`AGENTS.md`、使用指南、逆向报告、15 个源文件的文件头）。文档同步判断：**需要**，`AGENTS.md`、使用指南、两份索引均在同批次更新；**无新术语**，术语表不动 |
