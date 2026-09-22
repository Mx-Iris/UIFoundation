# Draft - UIFoundationComponent：移植上游的教学式 Example，并补齐 TappableView

- **状态**: In Progress
- **作者**: JH
- **创建日期**: 2026-09-21
- **最后更新**: 2026-09-21
- **所属愿景**: 无
- **关联提案**: [`0024`](0024-component-layout-system.md) —— 本提案完成它的落地步骤 5（TappableView）与步骤 7（示例），**确认而非推翻**它「不搬具体视图组件」的非目标，并更正了它对 AppKitPlus 的一条调研结论（更正块已附在 `0024` 正文中）。
- **实现分支 / PR**: `main`（直接落地，逐步提交）
- **配套文档**: 待定 —— 落地时与 `0024` 的 `Documentations/ComponentLayout.md` 合并登记

## 摘要

把上游 UIComponent `6.0.1`（`4c714c6`，与 `0024` 同一基线）那份 8638 行、18 章的教学式 Example 移植成 macOS 版，塞进现有的 demo browser。这填上 `0024` 的落地步骤 7。

**库侧只补一样：`TappableView`** —— `0024` 的落地步骤 5，规划做完了实现没写。它不是内容控件而是交互基础设施：`.tappableView { }` 让**任意组件**可点。

其余两块都不进库：

- **叶子组件（`Text` / `Image` / `Separator`）由 Example 自建。** 这个 target 交付的是布局系统，装什么由使用方定。而自建的那个 `Text` 恰好是「怎么写一个叶子组件」的完整范例，值得单开一章讲 —— 放进库里反而讲不成。
- **`updateProperties()` 用 AppKitPlus 现成的。** 初稿曾计划自造一个等价物，调研后确认 `NSView (UpdateProperties)` 已经提供，且带自动 Observation 追踪、比自造版更完整。

## 动机

### Example 的价值在形式，不在它演示了哪些组件

上游那份 Example 是：左侧 18 章的侧栏，右侧每个知识点「效果 + 它自己的源码」并排。源码不是手写的字符串，是 `#CodeExample(...)` 宏在编译期把示例表达式**同时求值并捕获成文本** —— 所以展示的代码永远就是上面跑着的那段，不会跷。

这个形式正是这类布局系统需要的：`justifyContent: .spaceBetween` 与 `.spaceAround` 的差别，讲十句不如并排摆两张图加两段代码。

### `TappableView` 是唯一真正缺的那块

`0024` 把它写进了范围（落地步骤 5），连 AppKit 的映射表都列好了，但实现没写。Example 里 `.tappableView` 出现 63 处，外加一整章。

### 叶子组件为什么不进库 —— 交付的是布局系统，不是控件库

`0024` 把 `Text` / `Image` / `Separator` 列为非目标，本提案**确认这个判断**。

这个 target 交付的是「不走 Auto Layout、自己算 frame、带复用与可见区域裁剪」的布局能力。装进去的内容控件由使用方自己定 —— 本库的使用方本来就有一整套自己的 AppKit 控件，再塞一个 `Text` 进来，是多一个要么不用、要么和既有控件二选一的东西。

反过来，Example 自建的那个 `Text` **本身就是最好的教材**：它要做的四件事恰好覆盖了写一个叶子组件的全部要点 —— 用 TextKit 算尺寸、覆写 `ascender` / `descender` 支持基线对齐、做成值类型描述 + `updateView(_:)` 以便复用、通过环境键读 `\.font` / `\.textColor`。放进库里，这一章就只剩「库自带了 Text」，讲不成了。

### 「直接放一个 `NSView` 进去」为什么不能替代它

这条值得单独记，因为它看起来能替代，而失败是静默的。

`extension NSUIView: Component` 随 `0024` 搬进来了（`ViewComponent.swift:118`），直接把 `NSTextField` 实例放进组件树是可以的，**而且尺寸算得对** —— `NSTextField.h:52` 明确说 `maximumNumberOfLines` 会影响 `-[NSControl sizeThatFits:]`，不等于 1 时会用多行来算。

但有三件事它做不到：

1. **复用没了。** `ViewRenderNode.contextValue(.id)` 在持有 view 实例时返回 `"view-at-<对象地址>"` —— 一个固定 id，那个实例被独占。5000 行的列表就是 5000 个常驻视图，可见区域裁剪只是不显示它们，并没有省掉创建。而长列表正是这个 target 存在的理由。要复用得走 `ViewComponent(generator:)` 加 `.reuseKey(…)`，走到那一步时你已经在写 `Text` 了。
2. **基线对齐静默算错。** `ascender` / `descender` 是 `RenderNode` 的协议成员，默认实现是 `size.height` 与 `0`（`RenderNode.swift:132`）。`.baselineFirst` / `.baselineLast` 会拿整个视图高度当基线距离，变成按底边对齐。不报错。
3. **调用点形状。** 上游写的是 `Text("x", font: .title).textColor(.secondaryLabel)`，共 1264 处。

## 前期调研

### Example 对缺失符号的依赖分布

| 符号 | 引用次数 | 归属 |
|---|---:|---|
| `Text(` | **1264** | Example 自建 |
| `textColor(` / `backgroundColor(` | 418 / 405 | 走库里已有的 `@dynamicMemberLookup`，打到自建 `Text` 的 `View` 类型上 |
| `#CodeExample` | 201 | Example 自带的本地宏包 |
| `Image(` | 137 | Example 自建 |
| `.tappableView` / `TappableView` | 63 / 18 | **进库** |
| `Separator(` | 42 | Example 自建 |
| `Flow(` | 29 | **已有**（`FlexRow.swift:4` 的 typealias 随 `0024` 搬入） |
| `updateProperties` | 每章的入口 | **AppKitPlus 已提供**，见下 |
| `PrimaryMenu` / `GlassTappable` / `SwiftUIComponent` | **0 / 0 / 0** | 不需要，`0024` 的非目标对这三个继续成立 |

逐章统计：每一章都重度依赖 `Text`（最少的 `GettingStarted` 也有 16 处），`TappableView` 与 `Environment` 各自集中在自己那一章。

### `updateProperties` —— AppKitPlus 已经有了，而且比自造的完整

上游每个章节视图长这样：

```swift
class StackExamplesView: UIView {
    override func updateProperties() {
        super.updateProperties()
        componentEngine.component = VStack { … }   // 读 @Observable 模型
    }
}
```

三件事：

1. **上游库对此一行代码都没写。** `git grep withObservationTracking|updateProperties` 在 `upstream/main` 的 `Sources/` 下只命中 DocC 文档 —— 它白拿的是 iOS 26 UIKit 的自动 Observation 追踪。
2. **AppKit 自身没有。** 实测 `grep -rn "updateProperties" $(xcrun --sdk macosx --show-sdk-path)/.../AppKit.framework/Headers/`，零命中（SDK 为 MacOSX27.0）。
3. **但 AppKitPlus 有。** `AppKitPlus/Update Properties/` 给 `NSView` 与 `NSViewController` 都加了 `setNeedsUpdateProperties` / `updateProperties` / `updatePropertiesIfNeeded`（公开 ObjC category），macOS 14+ 带**自动 Observation 追踪**：

   ```swift
   withObservationTracking { self.updateProperties() }
   onChange: { [weak self] in DispatchQueue.main.async { self?.setNeedsUpdateProperties() } }
   ```

   与初稿设计的自造版形状完全一致（包括那个主队列跳转 —— `onChange` 在 `willSet` 时触发，同步重读会拿到旧值），且多做三件事：视图控制器先于其视图更新、配置状态传递、interaction 分发。驱动方式是**按实例动态子类化**（`_NSViewEnhancementsHookInstall`）而非进程级 swizzle，只对调用过 `setNeedsUpdateProperties` 的实例生效。

**Example 工程本来就开着 `AppKitPlus` trait**，所以这一块零成本。`0024` 当初判断「AppKitPlus 帮不上这个忙」是基于 `.swiftinterface` 的误判 —— 那份文件看不见 ObjC category，更正块已附在 `0024` 正文。

**但两套 swizzle 叠加的顺序必须实测**（落地步骤 2）：AppKitPlus 按实例动态子类化接管 `layout`，而 `UIFoundationComponent` 的引擎用进程级 `method_exchangeImplementations` 换掉 `NSView.layout()`。理论上动态子类的覆写先跑、`super` 再落到被交换的实现，顺序恰好是「先 `updateProperties` 后引擎渲染」—— 但两种 swizzle 机制叠加是典型的踩坑处，顺序反了会表现为组件树永远慢一帧，且不报错。

### Example 自建叶子组件的扩展点已逐个核实

自建的前提是库把该开的口子都开了。实测：

| 自建 `Text` / `Image` / `Separator` 需要 | 可见性 |
|---|---|
| `EnvironmentKey` 协议（自定义 `\.font` / `\.textColor` 两个键） | `public` |
| `EnvironmentValues` 的 subscript 与 init | `public` |
| `CGSize.bound(to:)` | `public`（`Constraint.swift:50`） |
| `CGSize.boundWithAspectRatio(to:)` | `public`（`Constraint.swift:60`） |
| `Constraint` / `Component` / `ComponentBuilder` / `ViewComponent` / `RenderNode` | `public` |
| `RenderNode.ascender` / `.descender`（覆写以支持基线对齐） | 协议成员，可在库外覆写 |

**一个缺口都没有。** 这是「叶子组件不进库」成立的技术前提 —— 如果其中任何一项是 internal，自建就不成立，结论会反过来。

### `Text` 的尺寸计算在 AppKit 上原样成立

上游 `Text.layout(_:)` 分快慢两条路：单行且非 Swift `AttributedString` 时走 `NSAttributedString.boundingRect(with:options:context:)`；否则走 TextKit 1（`NSTextStorage` + `NSLayoutManager` + `NSTextContainer`，`usesFontLeading = false`、`lineFragmentPadding = 0`）。慢路的注释解释了原因：Swift `AttributedString` 带的 `NSInlinePresentationIntent` 之类属性，`boundingRect` 与 `CTFramesetter` 都不处理，尺寸会算错。

这两条路在 AppKit 上都成立 —— 这几个类两个平台共有。移植时要改的只有 `updateView(_:)` 那一端。

### 自建 `Text` 的宿主视图：暂定自绘 `NSView`，落地前实测

`UILabel` 在 AppKit 没有对位，两条候选：

- **`NSTextField`** —— 尺寸它算得对（见上），但**文本落点由 `NSTextFieldCell.drawingRect(forBounds:)` 决定，不等同于传入的 frame**（本库的 `InsetsTextFieldCell` 正是为覆写这一组方法而存在）。而 `Text` 的尺寸来自 TextKit，两套算法未必吻合。
- **自绘 `NSView`**，`draw(_:)` 里 `NSAttributedString.draw(with:options:)` —— 与 `boundingRect` 是同一套 API 的正反两面，严格对应。

**选自绘，但这个选择建立在一个未实测的判断上**：两套算法的偏差量没测过。列为落地步骤 3 —— 同一段文字，一路用 TextKit 算尺寸、一路交给 `NSTextField` 绘制，比两边的文字外框。若偏差为零，`NSTextField` 这条路更省事，结论照改。

### `TappableView` 的 AppKit 版必然是子集

| 能力 | UIKit | AppKit |
|---|---|---|
| 单击 / 双击 / 长按 / 高亮 | 四个手势识别器 | `NSClickGestureRecognizer`（`numberOfClicksRequired`）、`NSPressGestureRecognizer`（`minimumPressDuration: 0` 做高亮） |
| 上下文菜单 | `UIContextMenuInteraction` + 预览控制器 | `override func menu(for:) -> NSMenu?`；**预览无对应物** |
| 指针样式 | `UIPointerInteraction` | `NSTrackingArea` + `cursorUpdate(with:)`，形状不同 |
| spring loading | `UISpringLoadedInteraction` | **不提供**（`0024` 已定：`NSSpringLoadingDestination` 是拖拽悬停语义，不等价） |
| 拖放目标 | `UIDropInteraction` | `NSDraggingDestination`，语义与 API 形状都不同 |
| tvOS focus | `canBecomeFocused` / `didUpdateFocus` | 不适用 |

按 `0024` 的原则（「能降级就降级，没对应物的不提供」），AppKit 版提供前三项，后三项在 macOS 上根本不声明 —— 写到会得到编译错误而非静默失效。

**不依赖 AppKitPlus 的 `NSView (Interactions)`。** 那套是 `UIInteraction` 的移植，与手势识别器是两条路；`TappableView` 走手势，是上游的形状，也是 `0024` 定下的映射。

### `#CodeExample` 宏包

```swift
#CodeExample(VStack(spacing: 10) { Text("Item 1") })
// 展开为：{ let (component, code) = (<原表达式>, "<原表达式的源码文本>")
//          return CodeExampleComponent(content: component, code: code) }()
```

依赖两个外部包：`swift-syntax`（`602.0.0-latest`，宏实现必需）与 `Highlightr`（`2.3.0`，语法高亮；实测其 `Package.swift` 声明 `.macOS(.v10_11)`，**支持 macOS**）。

`CodeTextView` 是 `UITextView` 子类，要改成 `NSTextView`；它读 `traitCollection.userInterfaceStyle` 选主题（monokai / xcode），AppKit 侧改读 `effectiveAppearance.bestMatch(from:)`。

**这两个依赖只进 Example 的工程，不进 `Package.swift`。**

## 提议方案

### 一、库侧：`UIFoundationComponent` 加 `TappableView`

`TappableView` / `TappableViewConfig` / `.tappableView(_:)`，AppKit 交互子集见上表。完成 `0024` 的落地步骤 5。

**库侧仅此一样。** 不加 `updateProperties` 的等价物（AppKitPlus 已有），不加叶子组件（由 Example 自建）。`UIFoundationComponent` 对 AppKitPlus 的依赖关系不变 —— 仍然没有，`0024` 定下的「独立 product、不设 trait、不绑二进制依赖」保持原样。

### 二、Example 侧

在 `UIFoundationExample-macOS` 的 demo 目录加一个条目「Component Layout」，详情页就是上游 `HomeView` 的结构 —— `HStack { 章节侧栏; 选中章节的视图 }`。上游那个 App 本来就长这样。

- **自建三个叶子组件**，照上游的形状与签名（`Text` / `Image` / `Separator`），所以 18 章里的调用点一字不改。连同两个自定义环境键（`\.font` / `\.textColor`）放在 Example 的 `Leaf/` 目录下，并**单开一章讲它们是怎么写的**。
- **章节视图 `import AppKitPlus`**，基类用库的 `ComponentView`，`override func updateProperties()` 原样保留。Example 工程已开着该 trait。
- `#CodeExample` 宏包连同两个依赖搬进 Example 工程，`CodeTextView` 改 `NSTextView`。

## 非目标

- **叶子组件不进库。** `Text` / `Image` / `Separator` 留在 Example。`0024` 的非目标在此得到确认。
- **`updateProperties` 的等价物不进库。** 用 AppKitPlus 的。库不因此产生对 AppKitPlus 的依赖 —— 是 Example 自己 import。
- **不搬 `PrimaryMenu` / `GlassTappableView` / SwiftUI 集成。** 上游 Example 对这三个的引用次数实测均为 **0**。
- **不做 iOS Example。** `UIFoundationExample-iOS` 今天是个空壳（一个什么都没做的 `UITableViewController`），要先搭承载结构；AppKit 支持才是 `0024` 的主要新增工作，验证价值集中在 macOS。
- **不清理 `0024` 里因误判 AppKitPlus 而重造的轮子**（如 `box.center`）。本 target 不依赖 AppKitPlus，trait 关闭时那些仍是唯一的实现。该不该收敛是另一轮的事。
- **不与上游持续同步。** 延续 `0024`。
- **不提升平台下限**，**不动 `HStackView` / `VStackView` / `GridView`。**

## 详细设计

### 目录

```
Sources/UIFoundationComponent/
  Interaction/       TappableView / TappableView+Config / Component+TappableView

UIFoundationExample-macOS/UIFoundationExample-macOS/
  Demos/ComponentLayout/
    ComponentLayoutDemoViewController.swift   条目入口
    Chapter.swift / SidebarView.swift          章节注册表与侧栏
    Leaf/     Text / Image / Separator / FontEnvironmentKey / TextColorEnvironmentKey
    Chapters/ 18 章
    CodeExample/  本地宏包（swift-syntax + Highlightr）
```

文件名遵守本库的**唯一 basename** 规则。

### Example 侧的接线

`UIFoundationComponent` 是独立 product、不在伞包里，所以 `project.pbxproj` 要改三处：`XCSwiftPackageProductDependency` 加一条、target 的 `packageProductDependencies` 加一条、Frameworks build phase 加一条。**不动 traits 列表** —— `0024` 明确这个 product 不设 trait，而 `AppKitPlus` trait 已经在列表里。

demo 的 Swift 文件落在文件系统同步组（`PBXFileSystemSynchronizedRootGroup`）下，加文件不需要改 `project.pbxproj`。**宏包不是**：它是本地 Swift 包，要作为 package reference 加进工程。

## 替代方案考量

**把 `Text` / `Image` / `Separator` 也搬进库。** 初稿如此，被否。这个 target 交付的是布局能力，内容控件由使用方自己定；而那一章「怎么写叶子组件」会因此讲不成。

**自造 `updateProperties` 的等价物。** 初稿如此，被调研推翻 —— AppKitPlus 已有，且带自动 Observation 追踪、比自造版多三件事。自造只会多一套要与它对齐语义的东西。

**给 `UIFoundationComponent` 加 trait-gated 的 AppKitPlus 依赖**（trait 开用它的、关了用 polyfill）。否。Example 自己 import 就够了，库不必掺和；真有使用方需要，它自己开 trait 即可，与本 target 无关。

**Example 里不自建 `Text`，直接放 `NSTextField` 实例。** 否，见「动机」末节的三条。

**只挑八章不依赖交互的移植。** 省下的只有 `TappableView`（`0024` 本来就欠着）与 `Image`（最容易的那个），不划算。

**`#CodeExample` 不搬，源码写死成字符串。** 否 —— 示例与展示的代码迟早会跷，上游发明这个宏正是为此。

## 影响

### 源码兼容性（source compatibility）

**纯新增。** 不改动任何现有 target 的任何符号。`Package.swift` **零改动** —— `TappableView` 落在已有 target 里，两个新依赖只进 Example 工程。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- **RuntimeViewer（`TabsControl`）/ MachOKitUI（`TextFinder`）/ PrivateSymbols（基类）：全部零影响。** 三者都不声明对 `UIFoundationComponent` 的依赖，不参与编译，`Package.resolved` 也不变。
- **已经在用 `UIFoundationComponent` 的代码**：纯新增一个 `TappableView`，不会破坏。
- **不引入任何新的外部依赖到 `Package.swift`。**

## API 演进与废弃策略

- 无旧 API 被替代，不产生任何 `@available(*, deprecated)`。
- 上游 `TappableView` 上两个已标弃用的符号（`TappableViewConfiguration` 别名、`configuration` 属性）**不搬** —— 本库从未发布过它们，搬进来等于凭空造一个弃用项。
- 本 target 仍**不是** UIComponent 的 drop-in 替代（叶子组件、`PrimaryMenu`、SwiftUI 集成都没有），文档需注明。

## 落地步骤

每一步都应能单独构建通过（macOS `swift build`；iOS 侧走 `xcodebuild -destination 'generic/platform=iOS'`，因为 target 是跨平台的）。

1. **`TappableView`** —— 完成 `0024` 的落地步骤 5。验收：单击 / 双击 / 长按 / 右键菜单在 macOS 上均可触发。
2. **两套 swizzle 的顺序实测** —— AppKitPlus 的按实例动态子类化 vs 引擎的进程级 `method_exchangeImplementations`，验证 `updateProperties` 确实跑在引擎 `layoutSubview` 之前。顺序反了则组件树永远慢一帧且不报错。探针写完先过目再跑。
3. **文本落点实测** —— TextKit 算出的尺寸 vs `NSTextField` 的实际绘制矩形，定下自建 `Text` 的宿主视图用自绘还是 `NSTextField`。同上，先过目再跑。
4. **Example 的三个叶子组件 + 两个环境键** —— 验收：多行换行、基线对齐、复用三条各有断言。
5. **Example 接线** —— pbxproj 三处 + 宏包引入，先让一个最小章节跑起来。
6. **18 章移植** —— 分批，每批构建通过。
7. **文档** —— `0024` 的落地步骤 5 与 7 打勾；使用指南登记 `TappableView` 的 AppKit 子集，并写明「自动重建靠 `AppKitPlus` trait，库本身不提供」这条宿主契约；`AGENTS.md` 加一节；`THIRD_PARTY_LICENSES.md` 补登 Example 侧的 Highlightr 与上游 Example 代码；给本提案分配编号（当前最大 `0024`）。

**收尾时必须判断两件事**（结果写进决策日志，不允许沉默跳过）：

- 要不要配套实现说明 —— 候选主题是「两套 swizzle 叠加时 `layout` 的实际调用顺序」，取决于步骤 2 的实测结果是否反直觉。
- 有没有引入新术语 —— 初判无，`0024` 已登记的那批够用。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-09-21 | Created as Draft | 起因是「给 UIFoundationComponent 写 Example」，调研后确认上游那份 Example 好看且完整，但它依赖的东西本库还没有 |
| 2026-09-21 | 定档位：轻量档，但按完整模板写 | 纯新增、无破坏性，按 `AGENTS.md`「不确定属于哪一档时走轻量档」走轻量档、不启动多轮拷问；但本库的提案惯例与必填的「下游影响」一节要求完整模板 |
| 2026-09-21 | **初稿方向被否：叶子组件不进库** | 初稿要把 `Text` / `Image` / `Separator` 搬进库、推翻 `0024` 的非目标。用户否决：这个 target 要交付的是布局系统，装进去的控件由使用方自己定。`0024` 的非目标由此得到确认而非推翻 |
| 2026-09-21 | 自建 `Text` 反而是更好的教材 | 写一个叶子组件的四个要点（TextKit 算尺寸、覆写 ascender/descender、值类型 + `updateView` 以便复用、读环境键）它全占；放进库里，这一章就只剩「库自带了 Text」 |
| 2026-09-21 | 核实 Example 自建叶子组件的全部扩展点 | `EnvironmentKey` / `EnvironmentValues` / `CGSize.bound(to:)` / `boundWithAspectRatio(to:)` 均为 `public`，`ascender` / `descender` 是可覆写的协议成员 —— **一个缺口都没有**。这是「不进库」成立的技术前提，若其中任何一项是 internal 结论会反过来 |
| 2026-09-21 | 记下「直接放 `NSView`」为什么不能替代 | 它看起来能替代且**尺寸确实算得对**（`NSTextField.h:52`：`maximumNumberOfLines` 影响 `-[NSControl sizeThatFits:]`），但复用没了（持有实例时 id 固定为对象地址）、基线对齐静默算错（`ascender` 默认取 `size.height`）、1264 处调用点要改。初稿曾以「尺寸算不对」为由排除它，**那条论证是错的**，已更正 |
| 2026-09-21 | `TappableView` 进库 | 它不是内容控件而是交互基础设施：`.tappableView { }` 让任意组件可点，是布局系统的能力；`0024` 也已把它写进范围并规划好 AppKit 映射 |
| 2026-09-21 | **`ComponentObservingView` 取消：AppKitPlus 已有** | 初稿计划自造 `updateProperties()` 的 AppKit 等价物。用户指出 AppKitPlus 给 `NSView` 加了这个方法，实测属实：`NSView (UpdateProperties)` 提供三个方法、macOS 14+ 带自动 Observation 追踪，形状与自造版完全一致（含 `onChange` 的主队列跳转），且多做三件事（VC 先于其 view 更新、配置状态传递、interaction 分发），驱动方式是按实例动态子类化而非进程级 swizzle |
| 2026-09-21 | 库不因此依赖 AppKitPlus，由 Example 自己 import | Example 工程本来就开着该 trait。`0024` 定下的「独立 product、不设 trait、不绑二进制依赖」保持原样；重建时机由使用方决定 |
| 2026-09-21 | **更正 `0024` 对 AppKitPlus 的调研结论** | 追查上一条时发现 `0024` 写的「`extension AppKit.NSView` 一处都没有 / 这个依赖省不掉任何工作」是错的 —— 实有 17 个 `NSView` category、8 个 `NSViewController` category。根因：当初只验 `.swiftinterface`，而 **ObjC category 不出现在那里面**。原判断的另一半（无 `layoutSubviews` / `setNeedsLayout` / `isFlipped` / `NSView` 的 `sizeThatFits` / 手势）逐项复核属实。更正块已附在 `0024` 正文并记入其决策日志，复查方法（查公开头文件而非 swiftinterface）已写进 `AGENTS.md` |
| 2026-09-21 | 新增落地步骤：两套 swizzle 的顺序实测 | AppKitPlus 按实例动态子类化接管 `layout`，引擎用进程级 `method_exchangeImplementations`。理论顺序正确（动态子类先跑、`super` 落到被交换的实现），但两种机制叠加是典型踩坑处，顺序反了表现为组件树永远慢一帧且不报错 |
| 2026-09-21 | 自建 `Text` 的宿主视图暂定自绘，落地前实测 | 自绘与 `boundingRect` 是同一套 API 的正反两面，严格对应；`NSTextField` 的文本落点由 `drawingRect(forBounds:)` 决定，与 TextKit 算出的尺寸未必吻合 —— **但偏差量未实测**，测完照结果定 |
| 2026-09-21 | 搬 `#CodeExample` 宏包，连带两个依赖 | 它把同一段源码既求值又转成文本，示例与展示的代码不会脱节。两个依赖（`swift-syntax` / `Highlightr`，后者实测支持 macOS 10.11+）只进 Example 工程，`Package.swift` 零改动 |
| 2026-09-21 | Example 塞进现有 demo browser，不新建 App | 上游 `HomeView` 本来就是「侧栏 + 内容」，正好作为一个 demo 条目的详情页 |
| 2026-09-21 | 不做 iOS Example | `UIFoundationExample-iOS` 是空壳，要先搭承载结构；AppKit 支持是 `0024` 的主要新增工作，验证价值集中在 macOS |
| 2026-09-21 | 状态 Draft → Accepted → In Progress | 用户批准提案并指示开工，从落地步骤 1（`TappableView`）开始 |
| 2026-09-21 | 落地步骤 1 完成：`TappableView` + 12 条测试 | 两平台编译零警告，全量 165 swift-testing + 9 XCTest 原始退出码 0。真实点击 headless 测不了，测的是它依赖的接线，外加两条静默失败的契约：视图必须 flipped（它自己是组件宿主）、`contextValue` 必须透传（否则 `id` / `reuseKey` 丢失，diff 退回按位置匹配） |
| 2026-09-21 | **Example 的章节做成独立本地包，不放 app 源码里** | 原计划放 `Demos/ComponentLayout/`。实测不行：叶子组件叫 `Text` / `Image` / `Separator`，在 app 模块里这些名字会盖过 SwiftUI 的，而 `SettingsDemoViewController` 一个文件就有 40+ 处裸 `Text("…")` 指的是 `SwiftUI.Text`。独立模块是唯一能让两套名字不相遇的办法，而且 `#CodeExample` 宏本来也必须有自己的 target |
| 2026-09-21 | **更正：AppKitPlus 0.4.4 发布版没有 `NSView.backgroundColor`** | 源码 HEAD 的 `NSView (Appearance)` 有它，一度据此认为 Example 那 405 处 `.backgroundColor(…)` 零成本解决。实测 0.4.4 的 xcframework 头文件：`NSView` category 共 10 个，**没有 `Appearance`** —— 正是 `AGENTS.md` 记的那条（它会跨模块盖掉 `LayerBackgroundProviding` 的同名属性，因而被移除）。`NSView (UpdateProperties)` 则确实在发布版里。**查 AppKitPlus 有什么，必须查发布产物的头文件，源码 HEAD 与 swiftinterface 都会给出错误答案** |
| 2026-09-21 | 九个样式修饰符：两个白拿，七个自己写 | `contentMode`（AppKitPlus 的 `NSView (Geometry)`）与 `clipsToBounds`（macOS 14 起是 `NSView` 真实属性）走 dynamicMemberLookup 即可，再声明一次反而遮蔽真的。其余七个（`backgroundColor` / `cornerRadius` / `cornerCurve` / `borderWidth` / `borderColor` / `alpha` / `tintColor`）在 `Component` 上写成真实方法，经 `update(_:)` 落到组件已有的视图上而非包一层新的 —— 与上游语义一致 |
| 2026-09-21 | `tintColor` 只作用于 `NSImageView` / `NSButton` | `UIView.tintColor` 沿视图树继承且适用于多种控件，AppKit 无对应物；AppKitPlus 曾有一个 `tintColor` category 并已移除（沿树传播的 tint 会写进 `NSGlassEffectView` 自己的玻璃色）。诚实的对位是逐视图的 content tint，也正是章节里的实际用法（给 SF Symbol 上色） |
| 2026-09-21 | dynamicMemberLookup 会吃掉缺失符号并给出误导错误 | `view.backgroundColor = color` 在 `NSView` 上报的是「`FrameworkToolbox<NSView>` 没有这个 dynamic member」，指向完全错误的方向 —— 与 `0024` 决策日志记的动画桥接那次同型。判断这类报错时，先确认符号在目标平台上是否真的存在，别顺着 `FrameworkToolbox` 找 |
| 2026-09-21 | 本地包用 `swiftLanguageModes: [.v5]` | 与主包一致。上游章节代码写于 Swift 6 隔离规则之前，`Separator.defaultSeparatorColor` 这类可变静态属性在语言模式 6 下直接报错 |
| 2026-09-21 | **库侧多修一处：AppKit 的 `.scrollView()` 此前根本不滚动** | 超出「库侧只补 `TappableView`」，但不修则 Example 的侧栏与正文都动不了。`.scrollView()` 返回 `ViewWrapperComponent<NSUIScrollView>`，而 `ViewWrapperRenderNode.updateView` 对不遵守 `ViewWrapperComponentView` 的视图走 `view.componentEngine` —— 于是渲染出的子视图被直接塞进 `NSScrollView` 自己的 subview 列表（AppKit 用它放 clip view 与 scroller），既不滚动也可能被盖住，且不报错。修法：`ComponentScrollView` 遵守 `ViewWrapperComponentView` 并把 `contentComponentEngine` 指向 `renderingEngine`（即 documentView 的引擎），`.scrollView()` 在 AppKit 分支改返回 `ViewWrapperComponent<ComponentScrollView>`。这是 `0024` 落地步骤 4 本该暴露的缺口 |
| 2026-09-21 | Example 包的平台下限取 app 的，不取 `@Observable` 的 | 初设 `.macOS(.v14)`，app 随即报 `compiling for macOS 12.0, but module 'ComponentLayoutExample' has a minimum deployment target of macOS 14.0` —— **Example app 的 target 部署目标是 12，项目级才是 14**。改用本库既有的做法（`AGENTS.md` 记的 `UIFoundationSettings` 那条）：包下限压到 `.v12`，`HomeViewModel` / `HomeView` / `SidebarView` 三处逐个标 `@available(macOS 14.0, *)`。顺带 `.clipsToBounds()`（macOS 14）换成 `.masksToBounds()`，写它底下的 layer 属性 |
| 2026-09-21 | `CodeTextView` 必须显式建 TextKit 1 栈 | macOS 12 起按常规方式创建的 `NSTextView` 用 TextKit 2，`layoutManager` 返回 `nil`，`sizeThatFits` 会连带失效。改走 `init(frame:textContainer:)` 传入自建 container，回到 TextKit 1 —— 与 `Text` 测量用的是同一套机器，代码块的量得高度与画出高度因此一致 |
| 2026-09-21 | 又一次 dynamicMemberLookup 歧义：`.greatestFiniteMagnitude` | `CGSize(width: 0, height: .greatestFiniteMagnitude)` 报 ambiguous，写成 `CGFloat.greatestFiniteMagnitude` 即可。与 `0024` 记的 `Swift.min` / `Swift.max` 同一族 —— `FrameworkToolbox` 的 `@dynamicMemberLookup` 会给隐式成员查找多塞一个候选 |
| 2026-09-21 | 落地步骤 4 / 5 完成，第一章跑通 | 本地包 `ComponentLayoutExample`（叶子组件 + 两个环境键 + 七个样式修饰符 + `#CodeExample` 宏 + 侧栏 + HomeView + 第一章）与 app 接线（pbxproj 共十处）均完成。`xcodebuild` 构建 Example App **原始退出码 0、无新增警告**，库全量测试 165 swift-testing + 9 XCTest 仍为 0 |
| 2026-09-21 | **落地步骤 6 完成：18 章全部移植，零警告** | 9833 行，`swift build` 与 Example App 的 `xcodebuild` 均原始退出码 0、无新增警告；库全量测试 165 + 9 不变。机械替换（类型前缀、颜色/字体名、章节基类）覆盖了绝大部分，真正需要人判断的是下面几条 |
| 2026-09-21 | 转换规则必须只认章节类，不能认所有 `NSView` 子类 | 第一版规则把辅助视图 `GradientView` 也改成了 `ChapterView`，连带把它的 `override class var layerClass`（UIKit 专有）带进来。AppKit 的对位是 `makeBackingLayer()` 加显式 `wantsLayer` —— UIKit 视图恒为 layer-backed，AppKit 的不是 |
| 2026-09-21 | 七处 UIKit 概念在 AppKit 上无对应物，一律删除而非留空壳 | `previewProvider` / `previewBackgroundColor`（`NSMenu` 没有 peek 预览阶段）、`isPagingEnabled`（`NSScrollView` 不分页）、`delaysContentTouches`、`UISwitch.onTintColor`（`NSSwitch` 取系统强调色，无覆盖入口）、`UIAction` 的 `.destructive`（macOS 菜单无破坏性样式）。每处留一行注释说明为何没有，符合 `0024`「没对应物的不提供」 |
| 2026-09-21 | `NSView` 遵守 `Component`，于是样式修饰符名会遮蔽视图自身的属性 | `view.alpha = x` 报「'alpha' is a method」—— 因为 `extension NSUIView: Component` 让 `Component` 上定义的 `alpha(_:)` / `backgroundColor(_:)` 对每个视图实例都可见。章节里改用 AppKit 原生名 `alphaValue`，背景色改写 layer。这是给 `Component` 加修饰符的固有副作用，值得在指南里点明 |
| 2026-09-21 | `ChapterLink` 改用 identifier 定位，不用元类型 | 上游写 `viewType: XxxView.self`，而 `Chapter` 这边存的是工厂闭包（`NSView.init()` 不是 `required`，元类型调不动）。3 处调用点改成 `chapterIdentifier:` |
| 2026-09-21 | `AsyncImage` 自己写，不引入 Kingfisher | 上游用它加载六张示例图。改用 `URLSession` + `NSCache`（约 50 行），Example 因此不多一个第三方依赖，离线时降级为占位色而不是空白。复用视图时按 URL 校验在途请求，避免回收后串图 |
| 2026-09-21 | 章节里的 `@Observable` 需要逐个顶层声明标注，不止章节类 | 辅助类型、嵌套 `@Observable`、`extension EnvironmentValues` 都会被牵连。最终对章节文件的每个顶层声明（含 `extension`）统一补 `@available(macOS 14.0, *)`，共 33 处 |
| 2026-09-22 | **跑起来才发现的四个 bug，编译期全部看不见** | 用 Peekaboo 驱动真实 App 逐章检查。四个都是「编译通过、测试通过、界面不报错」的静默失败 |
| 2026-09-22 | **1. `.view()` 包的内容在 AppKit 上完全不渲染** | 症状：`#CodeExample` 的两个框都有正确尺寸和背景，里面空空如也；而直接的 `Text` 正常。根因与 `.scrollView()` 同源 —— `.view()` 返回 `ViewWrapperComponent<NSUIView>`，宿主不 flipped；而 `ViewWrapperRenderNode.updateView` 走的 `reloadWithExisting` **不经过 `reloadData()`**，正是 `installFlippedContainerIfNeeded()` 仅有的两个调用点之一，于是容器从不安装，内容落在可见区之外。`0024` 决策日志记过这个症状（「非 flipped 宿主上一个视图都不渲染」），但只修了直接 reload 那条路。修法：AppKit 分支改返回 `ViewWrapperComponent<ComponentView>`。**这是源码破坏性变更** —— 写出显式返回类型的调用方要改 |
| 2026-09-22 | **2. 代码块永远是空的** | `CodeComponent` 用一个共享的 `sizingTextView` 量尺寸，`sizeThatFits` 在**那个实例**上设 `textContainer.size`；真正显示的那个实例容器宽度从初始化起就是 0，一行都排不下，于是画出一个高度正确的空盒子。修法：`CodeTextView.layout()` 里把容器宽度同步到 `bounds.width`。`widthTracksTextView` 不能用 —— 它会让 AppKit 覆盖容器尺寸，而测量路径正依赖手动设置 |
| 2026-09-22 | **3. 整个组件层对辅助功能不可见** | 自绘视图不发布任何 accessibility 信息：VoiceOver 读到一片空白，UI 测试一个元素都找不到（实测 104 个元素里只有 3 个可交互，全是窗口按钮）。库侧给 `TappableView` 加了 `isAccessibilityElement` / `.button` 角色 / 从渲染子树聚合的 `accessibilityLabel` / `accessibilityPerformPress`；Example 侧给 `ComponentLabel` 加了 `.staticText` 与 `accessibilityValue`。修完元素 67 → 104、可交互 3 → 16。**写叶子组件的第四件事，`Text` 那一章应补上这条** |
| 2026-09-22 | **4. 代码高亮主题名不存在，静默回落** | 上游用 `setTheme(to: "xcode")`，而 Highlightr 的 271 个主题里**没有 xcode**。`setTheme(to:)` 对未知名字不报错、保留原主题，所以表现为「主题永远不变」而非错误。深色模式下渲染成浅色主题配色。改用确实存在的 `atom-one-dark` / `atom-one-light`，并把主题判定从视图的 `effectiveAppearance`（入窗前答 `.aqua`）改为窗口/`NSApp` 的，外加 `viewDidMoveToWindow` 时重解析 —— `viewDidChangeEffectiveAppearance` 只在**变化**时触发，深色下启动的视图从来收不到 |
| 2026-09-22 | **落地步骤 2 的顺序疑虑就此测掉** | 点击 `Tap Me!` 后计数器立刻 0 → 1，组件树没有慢一帧。AppKitPlus 的按实例动态子类化与引擎的进程级 `method_exchangeImplementations` 叠加后顺序正确，不需要那个探针 |
| 2026-09-22 | 章节文案里残留 UIKit 措辞 | 机械替换只改类型名，没改散文。5 处（「standard UIKit views (UIButton, UITextField)」「Context menus and previews」「UIKit automatically calls setNeedsUpdateProperties」等）已按 AppKit 事实改写 —— 最后一条的主语其实是 AppKitPlus |
| 2026-09-22 | **5. `Text` 在深色模式下画成黑字，等于隐形** | 用户报告「字体全是黑的」「滚到下面就变空白」。根因是同一个：`Text` 只在环境里有 `textColor` 时才写 `.foregroundColor`，而 **`NSAttributedString.draw(with:)` 的默认前景色是纯黑**，不是动态色 —— UIKit 的 `UILabel` 默认 `.label` 会跟随外观，AppKit 这条路不会。章节侧栏的 `Text(chapter.title, font:)` 没有显式颜色，于是深色背景上只剩选中项的高亮块可见，看起来就是「空白」。修法：`TextContent.resolved(textColor:)` 永远填一个颜色，默认 `labelColor`；`.attributedString` 分支只补**未指定**的区间，调用方自己上的色原样保留。**注意：当时把「滚到下面变空白」也归到这一条，那是错的 —— 见下一行** |
| 2026-09-22 | ~~滚动重渲染本身是对的~~ **这条结论是错的，原文保留以说明当时的证据不够** | 按 `diagnose-bug` 的规矩先造了能变红的回路：`ComponentScrollViewRenderingTests` 建一个内容为视口六倍的滚动视图，断言裁剪生效、documentView 高度等于内容高度、滚动后渲染的行换了一批且包含滚到的那一行。三条全绿，于是判定「空白」是黑字。**回路本身有缺陷**：行是裸 `NSView`，渲染没渲染看不出差别；而且它们是 documentView 的直接子节点，恰好绕开了真正出问题的那一层 |
| 2026-09-22 | **6. 真正的「滚到下面变空白」：`viewportBounds` 把「祖先里有滚动视图」当成了「我就是那个滚动的宿主」** | `.view()` 包裹会再起一个引擎，宿主是滚动视图里的某个普通后代。它问自己的视口在哪，`NSUIView.box.viewportBounds` 对**任何**有 `enclosingScrollView` 的视图都返回 clipView 的 bounds —— 那是文档坐标系的矩形，而它的内容在自己的坐标系里。滚动前两者原点都是 `(0, 0)` 恰好重合，一滚就不再相交，引擎读成「什么都不可见」，于是每个新进入视口的包裹视图都是空的。这解释了「顶部正常、滚下去变空」。修法：只有 `scrollView.documentView === base` 时才用 clipView 的 bounds，否则用自己的 `bounds`（与 UIKit 行为一致）。同一处误解还在 `updateScrollObservationIfNeeded()` 里 —— 嵌套宿主根本不需要监听滚动，一并收窄，顺带省掉每次滚动 ×N 次的无谓重渲染 |
| 2026-09-22 | 复现测试必须用**会裁剪**的容器 | 第一版回归测试内容写成 `NSView().size(…).inset(5).view()`，不修也能通过。原因是 `RenderNode.visibleChildren(in:)` 的默认实现**返回全部子节点、不按矩形裁**，只有 stack / flow 这类容器才重写它去裁 —— 所以一个只含 `Insets` 的包裹视图，即使拿到荒谬的可见矩形也照样渲染对。换成嵌套 `VStack` 后，去掉修复即变红 |
