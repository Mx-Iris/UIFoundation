# 0024 - UIFoundationComponent：并入 UIComponent 的声明式布局系统并补齐 AppKit 支持

- **状态**: In Progress
- **作者**: JH
- **创建日期**: 2026-09-21
- **最后更新**: 2026-09-21
- **所属愿景**: 无
- **关联提案**: [`0014`](0014-running-application-merge.md) —— 同为「把一个完整的库整体并入本库、落成独立 target、不进伞包」的形态。它最终被撤销，其撤销理由是本提案必须正视的风险先例，见「替代方案考量」末节。
- **实现分支 / PR**: `feature/component-layout-system`（worktree `.worktrees/UIFoundation-ComponentLayout`）
- **配套文档**: 待定 —— 落地时登记 `Documentations/ComponentLayout.md`

## 摘要

把 [lkzhao/UIComponent](https://github.com/lkzhao/UIComponent) v6.0.1 的声明式布局内核与渲染引擎搬进本库，落成一个**独立 target + 独立 product** `UIFoundationComponent`（不进 `UIFoundation` 伞包），并补齐它自诞生起就没有的 AppKit 支持。

UIComponent 是一套**不使用 Auto Layout、自己算 frame** 的声明式布局系统：`VStack`/`HStack`/`ZStack`/`FlexRow`/`FlexColumn`/`Waterfall` 等组件把约束逐层传下去、把尺寸逐层报上来，算出一张扁平的「谁该出现在哪个 frame」清单，再由渲染引擎按可见区域裁剪、按 ID 做增量 diff、按 reuse key 复用视图。它填的是本库现在没有的一块：**长列表与大量子视图场景下的声明式布局**。

本提案同时补齐它的 AppKit 支持 —— 坐标系翻转、`NSView.layout()` 布局周期、`NSScrollView` 滚动容器、`TappableView` 的 AppKit 交互实现。

## 动机

### 本库现有的两套布局都够不着这个场景

1. **`HStackView` / `VStackView`（`Sources/UIFoundationShared/View/StackView/`）** 是 `NSStackView` / `UIStackView` 的声明式包装，走 Auto Layout。约束求解的成本随子视图数量超线性增长，且它没有视图复用、没有可见区域裁剪 —— 一个两千行的列表会真的建两千个视图并解两千组约束。它适合表单、设置页这类约束驱动、元素数量有限的界面，这也是它今天在本库里的实际用法。

2. **`GridView` / `GridRow`（`NSGridView` DSL，macOS-only）** 是固定网格，不解决「内容驱动的流式排布」。

AppKit 侧没有 `UICollectionViewCompositionalLayout` 的等价物；`NSCollectionView` 的 flow layout 只能做等距网格，要做瀑布流或 flex 换行就得自己写 `NSCollectionViewLayout` 子类，每次都从头写。

### UIComponent 有这套能力，但只支持 UIKit

实测（基线 `6.0.1`，即 `upstream/main` 的 `4c714c6`）：

- `Sources/UIComponent/UIComponent.swift` 全文是 `@_exported import Foundation` + `@_exported import UIKit` —— 整个模块靠这一个 umbrella 文件拿到 UIKit，所以各源文件里连 `import UIKit` 都不写。
- Sources 下 `UIView` 出现 **241 处，散在 43 个文件**；`UIEdgeInsets` 50 处、`UIMenu` / `UIScrollView` / `UIImage` 各 18 处。
- **全库搜不到一处 `isFlipped`**。UIComponent 的布局模型假设原点在左上、y 向下增长；`NSView` 默认原点在左下。这一条没有任何现成处理。

### 为什么不走现有那个 fork

`AppKitSupportProgram/UIComponent` 这个 fork 在 2024 年做过一次 AppKit 适配（commit `ff77f87`），但**它今天在两个平台上都编译不过**，实测如下：

| 平台 | 结果 | 首个错误 |
|---|---|---|
| iOS | BUILD FAILED | `Sources/UIComponent/Extensions/UIFoundation+Typealias.swift:30` —— `public typealias NSUIView = NSUIView`，自己指向自己，`error: circular reference`。`NSUIViewController`、`NSUIEdgeInsets` 同样写法 |
| macOS | 编译中断 | `Sources/UIComponent/Components/Layout/Utility/ContextOverrideComponent.swift:3` —— `error: no such module 'UIKit'` |

iOS 侧改掉那 3 行自引用、再给 `NSView+Extension.swift` 补一个 `import QuartzCore`（它的 `_layer` 属性在平台守卫之外用到 `CALayer`），即 `BUILD SUCCEEDED` —— 已在临时副本实测。

macOS 侧的坑要深得多：上次合并上游时带进来 **26 个裸写 `import UIKit` 的文件**（主要是上游把 `Component+Modifier.swift` 拆成 `ComponentModifiers/` 那一批），从来没人适配过。机械补齐 import 后剩余的实质错误覆盖 `Text`、`SwiftUI`（`UIHostingController`）、`TappableView`、`PrimaryMenu`、`Component+Mask`、`TextColorEnvironmentKey` 等，且如上所述**坐标系翻转、`NSView.layout()` 布局周期、`NSScrollView` 滚动容器三件事根本没开始做**。

继续维护这个 fork 的成本也实测过：把它合并到上游 `6.0.1` 会产生 **52 个冲突文件**，其中 **22 个是纯 import 噪音**（上游 v6 做了一次 "simplify imports"，把用不到的 `import UIKit` 整个删掉，而 fork 恰好把这些 import 换成了条件编译块，于是行行撞车）。也就是说，每跟一次上游，一半的冲突处理量是在处理跟功能无关的噪音。

换句话说：**那个 fork 既不能用，维护成本也不划算**。与其修它，不如把这套布局系统按本库的惯例吸收进来。

## 前期调研

### 渲染是扁平的 —— 这一条决定了 AppKit 坐标系方案

`ComponentEngine.render(shouldUpdateViews:)`（`6.0.1:Sources/UIComponent/Core/ComponentView/ComponentEngine.swift:276`）：

```swift
let newVisibleRenderables = renderNode._visibleRenderablesWithUniqueIDs(in: visibleFrame)
contentSize = renderNode.size * zoomScale
let newViews: [UIView] = ComponentViewDiffApplier.apply(
    componentEngine: self,
    newRenderables: newVisibleRenderables,
    shouldUpdateViews: shouldUpdateViews
)
```

`Renderable` 只有三个字段（`6.0.1:Sources/UIComponent/Core/Model/RenderNode/Renderable.swift`）：

```swift
public struct Renderable {
    public var id: String
    public var frame: CGRect
    public var renderNode: any RenderNode
}
```

`ComponentViewDiffApplier` 把这批 renderable **全部直接挂到同一个 `containerView`**（`componentEngine.contentView ?? hostingView`）上 —— 没有中间层级，`frame` 就是相对容器的最终坐标。

**结论：AppKit 的坐标翻转只需要保证「那一个容器视图」是 flipped，不需要逐层转换。** 这把一件看起来要改遍全库的事，缩成了一个视图类的 `isFlipped` 覆写。

### `bounds.size` 在两个平台上不是一回事 —— 落地时实测才暴露

上游给每个渲染出来的视图定位，用的是这一对写法而不是直接赋 `frame`：

```swift
view.bounds.size = frame.size
view.center = frame.center
```

UIKit 上这是有意为之：视图带 transform 时直接赋 `frame` 会落到别处，这一对则不受影响。

但 **AppKit 的 `bounds` 与视图尺寸无关** —— 它是视图自己的坐标空间。赋值给它不改变 frame，于是视图保持原有尺寸（新建的视图就是零），而 `center` 照样把它挪到了正确位置。

实测症状：`Renderable` 的 frame 全部正确（`(0, 0, 100, 50)` 与 `(0, 50, 100, 50)`），视图实际 frame 却是 `(50, 25, 0, 0)` 与 `(50, 75, 0, 0)` —— **位置对、尺寸为零，画面上什么都没有**。不崩溃、不报错、无警告。

全库共 13 处这样的赋值，散在 `Animator`、`TransformAnimator`、`FadeAnimator`、`ComponentViewDiffApplier` 与 legacy render 路径里。它们现已统一走 `componentApplyFrame(_:)`（见「详细设计」）。

### AppKitPlus 帮不上这个忙

本库的 `AppKitPlus` trait 引入的 [AppKitPlus](https://github.com/AppKitSupportProgram/AppKitPlus-Release) 号称「ports UIKit's APIs onto AppKit」。下载 0.4.4 的 xcframework 解出 `arm64-apple-macos.swiftinterface`（2432 行）实测，它导出的是：

- configuration 体系：`NSListContentConfiguration`、`NSBackgroundConfiguration`、`NSContentUnavailableConfiguration`、各 `*ConfigurationState`
- trait 体系：`NSTraitDefinition` 及约 20 个 `NSTrait*`
- diffable data source 的 snapshot / transaction 类型

**没有** `layoutSubviews`、`setNeedsLayout`、`isFlipped`、`sizeThatFits`、手势相关的任何移植，`extension AppKit.NSView` 一处都没有。AppKit 适配这件事必须自己做，这个依赖省不掉任何工作。

### 命名冲突只有两个

把 UIComponent `6.0.1` 的 131 个顶层 public 类型与本库现有的 195 个逐一比对，重名的只有：

| 名字 | 本库的那个 | UIComponent 的那个 |
|---|---|---|
| `Component` | `Sources/UIFoundationShared/NSAttributedStringBuilder/Components/Component.swift:13` 的协议，**受 `#if NSAttributedStringBuilder` trait 门控** | 核心协议 |
| `Spacer` | `Sources/UIFoundationShared/View/StackView/Spacer.swift:11`，`public final class Spacer: NSUIView`，**无 trait 门控，永远存在** | `public struct Spacer: ComponentBuilder`，弹性占位（固定尺寸的那个叫 `Space`） |

因为本提案的产物是**独立 product、不进伞包**，两个名字都不必改：只有同时 `import UIFoundation` 和 `import UIFoundationComponent` 且写裸名字时才需要模块名限定。

### 本库已经具备的基础设施

- `UIFoundationTypealias` 已有完整的 `NSUIView` / `NSUIColor` / `NSUIFont` / `NSUIEdgeInsets` / `NSUIScrollView` 等别名，平台守卫统一写 `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`。搬迁时直接消费，不再自建一套。
- `UIFoundationToolbox` 的 `.box` 命名空间、`AssociatedObject` 宏（引擎需要把 `ComponentEngine` 关联到视图上，上游用的是裸 `objc_setAssociatedObject`）。
- 「整库并入、独立 target、不进伞包」有 `0014` 的完整先例可循。

### 上游 v6.0.1 相对旧版的实质变化

搬迁基线取 `6.0.1` 而非 fork 上那个旧基线，能白拿这些：新的 ID diff 渲染管线（`IDDiffHelper` + `ComponentViewDiffApplier`，旧管线作为 `useLegacyRenderingMode` 保留）、`FadeAnimator`、`MeasureSizeComponent`、`ReverseIf`、按轴控制 reload 的 `ReloadAxis`、`TransformAnimator` 的分离式插入/更新/删除时序。同时上游删掉了 `CachingItem` / `CacheEngine` 这套缓存 API —— 本提案不搬它。

## 提议方案

新建 target `UIFoundationComponent`（跨平台）与同名 product，把 UIComponent `6.0.1` 的**布局内核 + 渲染引擎 + TappableView** 搬进来，按本库惯例完全吸收，并补齐 AppKit 实现。

### 搬什么

| 层 | 内容 |
|---|---|
| 内核 | `Component` / `RenderNode` / `Constraint` / `Environment` 体系 / `ComponentBuilder` 等结果构建器 |
| 布局组件 | `VStack` / `HStack` / `ZStack`、`FlexRow` / `FlexColumn` / `FlexLayout` / `Flexible`、`Waterfall`、`Pager` / `DynamicPager`、`DynamicStack`、`Insets` / `VisibleFrameInsets`、`Offset`、`Absolute`、`Space` / `Spacer`、`Badge` / `Background` / `Overlay`、`ConstraintReader` / `ConstraintOverrideComponent`、`VisibleBoundsObserverComponent`、`MeasureSizeComponent`、`ForEach` / `Join` / `ReverseIf` |
| 渲染引擎 | `ComponentEngine`、`Renderable`、`ReuseManager`、`IDDiffHelper`、`ComponentViewDiffApplier`、legacy render 路径、`Animator` 体系（`BaseAnimator` / `TransformAnimator` / `FadeAnimator` / `WrapperAnimator`）、`ViewComponent` / `ViewRenderNode` / `ViewWrapperComponent` |
| 通用修饰符 | `.size()` / `.flex()` / `.inset()` / `.offset()` / `.lazy()` / `.reuseKey()` / `.id()` / `.animator()` / `.view()` / `.update()` / `.environment()` / `.background()` / `.overlay()` / `.badge()` / `.mask()` / `.measureSize()` 等不依赖具体控件的那些 |
| 交互 | `TappableView` 全套（单击 / 双击 / 长按 / 右键菜单 / 高亮态）+ `.tappableView()` 修饰符 |
| 宿主 | `ComponentView` / `ComponentScrollView` 及 `NSUIView.componentEngine` 扩展 |

### 非目标

- **不搬具体视图组件**：`Text`、`Image`、`PrimaryMenu`、`GlassTappableView`、`Separator`、SwiftUI 集成（`SwiftUIComponent`）。它们与本库既有的控件体系重叠最多，且各自都带一堆 UIKit-only 的包袱（`UILabel` 的排版行为、`UIHostingController`、`UIGlassEffect`）。需要叶子节点时用 `ViewComponent<NSUITextField>()` 这类通式，或另开提案单独处理。
- **不搬 `CachingItem` / `CacheEngine`** —— 上游 v6 已删除。
- **不做与上游的持续同步**。搬进来即成为本库自己的代码，按本库惯例重组目录、文件名与代码风格，使用 `NSUI*` 别名。上游后续的改进由人工评估后择要移植，不保留机械 diff 的能力。
- **不动现有的 `HStackView` / `VStackView` / `GridView`**。两套布局并存，分工写进使用指南（见「文档与示例」）。
- **不提供 macOS 上没有合理对应物的能力**：`UISpringLoadedInteraction`（AppKit 的 `NSSpringLoadingDestination` 是拖拽悬停语义，不等价）、tvOS focus 相关。调用方在 macOS 上写到这些会得到编译错误，而不是静默失效。
- **不提升包的平台下限**。跟随本库现有的 macOS 12 / iOS 13；布局内核不需要更新的 API。

### 不加 trait

本提案的产物**不设 SPM trait**，这是与 `TabBar` / `QuickActionBar` / `WelcomePanel` / `SpotlightPanel` 那批 port 的唯一形式差异，理由是 trait 在这里是多余的一层：

**SPM 的 target 只有被依赖时才编译。** `UIFoundationComponent` 是独立 product 且不被 `UIFoundation` 伞包依赖，下游不声明依赖就完全不参与编译 —— 这正是 trait 想达成的隔离，已经由 product 边界实现了。再叠一个 trait，下游要同时做「声明 product 依赖」和「打开 trait」两件事，漏掉后者就是一串 `cannot find type in scope`，而错误信息不会指向真正的原因。

那批 port 需要 trait 是因为它们的源码住在 `UIFoundationAppKit` / `UIFoundationShared` 这些**本来就会被伞包编译**的 target 里，只能靠 `#if` 把自己摘出去。本提案有自己的 target，不存在这个问题，因此也不需要给几十个文件逐个挂 `#if`。

## 详细设计

### target 与目录

```
Sources/UIFoundationComponent/
  Core/            Component / RenderNode / Constraint / Environment / 结果构建器
  Layout/          Stack、Flex、Waterfall、Pager、Insets、Offset、Absolute、Space …
  Engine/          ComponentEngine、Renderable、ReuseManager、IDDiffHelper、
                   ComponentViewDiffApplier、Animator、宿主类与 swizzle
  Modifiers/       Component+* / RenderNode+*
  Support/         布局算法自用的几何与集合工具
  Interaction/     TappableView、Component+TappableView
```

依赖 `UIFoundationTypealias`、`UIFoundationToolbox` 与 `AssociatedObject`，不依赖 `UIFoundationShared`（避免把 `Spacer` / `Component` 两个重名符号拉进同一个编译单元）。

**平台桥接一律住在 `UIFoundationToolbox`，不在本 target**（见下一节）。本 target 内只剩六个文件带平台条件编译，且每一处都是架构分化而非 API 拼写差异：umbrella 的 import、`ViewWrapperComponent`（`NSVisualEffectView` 没有 `contentView`）、`ComponentView`（两个平台的宿主类结构不同）、`ComponentEngine` 与 `ComponentEngine+AppKit`（flipped 容器与滚动观察）、`NSUIView+ComponentEngine`（swizzle 的 selector 不同）。

文件名遵守本库的**唯一 basename** 规则：feature 作用域的文件带前缀（`ComponentEngine+Render.swift`、`TappableView+Config.swift`），类型名独特的保持原名。

### 坐标系：flipped 容器

```swift
// Platform/ComponentHostingView.swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
/// 引擎渲染的默认落点。UIComponent 的布局模型以左上角为原点，
/// 而 NSView 默认原点在左下 —— 容器必须 flipped，否则整张布局上下颠倒。
open class ComponentHostingView: NSView {
    open override var isFlipped: Bool { true }
}
#endif
```

`componentEngine` 用在**任意** `NSView` 上时，引擎在首次 reload 前检查宿主的 `isFlipped`：为 `false` 就自动建一个 `ComponentFlippedContainerView` 填满宿主并设为 `contentView`，所有 renderable 挂在它上面。`contentView` 这条通路上游已经有了（原本用于 zoom，见 `ComponentEngine.contentView` 与 `ComponentViewDiffApplier.Context.containerView`），这里是复用而非新增机制。

如此一来两条路都通：用本库提供的宿主类是零成本的直路；把引擎挂到你自己的 `NSView` 子类上也不会得到一张颠倒的布局。**不 swizzle `NSView.isFlipped`** —— 那会波及进程内所有 AppKit 视图，包括系统控件。

### 布局周期

| | UIKit | AppKit |
|---|---|---|
| 布局入口 | swizzle `layoutSubviews` | swizzle `layout()` |
| 标脏 | `setNeedsLayout()` | 垫片映射到 `needsLayout = true` |
| bounds 变化 | swizzle `setter: bounds` | 同左（`NSView` 有 `setBounds:`） |
| 尺寸询问 | swizzle `sizeThatFits(_:)` | `NSControl` 走 `sizeThatFits(_:)`，其余返回 `bounds.size` |

上游只在 UIKit 分支做了这些（`6.0.1:Sources/UIComponent/Core/ComponentView/UIView+ComponentEngine.swift`），AppKit 侧的 `layout()` 是本提案要补的核心缺口之一 —— 没有它，macOS 上引擎的布局周期根本不会被触发。

### 滚动容器

```swift
#if canImport(AppKit) && !targetEnvironment(macCatalyst)
open class ComponentScrollView: NSScrollView {
    /// 内建的 flipped documentView，引擎作用于它而非 scroll view 本身。
    public let componentDocumentView: ComponentHostingView
}
#endif
```

`NSScrollView` 必须有 `documentView` 才能滚动，这与 `UIScrollView`「自己就是容器」的模型不同，所以不把引擎直接挂在 scroll view 上。映射关系：

| 引擎概念 | UIKit | AppKit |
|---|---|---|
| `contentSize` | `UIScrollView.contentSize` | `documentView.frame.size` |
| `contentOffset` | `bounds.origin` | `clipView.bounds.origin` |
| `contentInset` | `adjustedContentInset` | `contentInsets`（`automaticallyAdjustsContentInsets = false`） |
| 可见区域变化 | swizzle `setter: bounds` | `NSView.boundsDidChangeNotification`（需 `clipView.postsBoundsChangedNotifications = true`） |
| `scrollTo(id:animated:)` | `setContentOffset(_:animated:)` | `clipView.animator().setBoundsOrigin(_:)` / `scrollToVisible(_:)` |
| safe area 联动 | `safeAreaInsetsDidChange` swizzle | 不适用，macOS 无 safe area |

### 平台桥接放在 `UIFoundationToolbox` 的 `.box` 命名空间

两个平台在**拼写**上的差异（`alphaValue` 对 `alpha`）和在**形状**上的差异（`NSView.layer` 可选、AppKit 没有 `sizeThatFits`）都不是布局系统特有的问题，所以桥接层不住在本 target，而是作为 `.box` 扩展放进 `UIFoundationToolbox`，任何跨平台代码都能用：

| 文件 | 提供 |
|---|---|
| `Shared/NSUIView+Geometry.swift` | `backingLayer`、`setFrame(_:)`、`occupiedFrame`、`sizeThatFits(_:)`、`contains(_:)`、`setNeedsLayout()`、`layoutIfNeeded()`、`center`、`alpha`、`insertSubview(_:at:)`、`maskView` |
| `Shared/NSUIView+Scrolling.swift` | `enclosingComponentScrollView`、`viewportBounds`、`contentOffset`、`contentInset`、`zoomScale`、`setContentSize(_:)`、`scrollRectToVisible(_:animated:)` |
| `Shared/NSUIView+Animation.swift` | `animate(withDuration:…)` 三个重载、`performWithoutAnimation(_:)` |
| `Shared/NSUIViewAnimationOptions.swift` | UIKit 上是 `UIView.AnimationOptions` 的别名；AppKit 上是等价的 `OptionSet` 加一个 `timingFunction` |
| `Shared/NSUIEdgeInsets+.swift` | UIKit 侧的 `box.zero`，与 AppKit 既有的 `NSEdgeInsets.box.zero` 对齐 |

**走 `.box` 而不是裸扩展，是为了不往进程里每个 `NSView` 上挂 `alpha` / `center` 这种名字。** `CLAUDE.md` 记的 AppKitPlus 教训正是这一条：扩展加过的属性名，子类再声明就是非法覆盖，而且这个限制随模块传导到每个下游。`.box` 没有这个问题 —— 成员住在 `FrameworkToolbox<Base>` 上，子类声明同名属性完全合法，而且真实成员优先。

**调用点不必写 `.box`。** `NSObject` 在 `FoundationToolbox` 里已经遵守 `FrameworkToolboxDynamicMemberLookup`，所以属性直接写 `view.backingLayer`、`view.viewportBounds`、`view.center`；静态属性同样可以（`NSUIEdgeInsets.zero`），Swift 6.1 的 [SE-0438 Metatype Keypaths](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0438-metatype-keypath.md) 让 metatype 上的 keypath 成立，无需 feature flag。两条限制：

- **方法必须带 `.box`**（`view.box.setFrame(_:)`、`NSUIView.box.animate(…)`）。`@dynamicMemberLookup` 只经由 keypath 解析，方法没有 keypath。
- **leading-dot 写法不触发 lookup**。`let insets: NSUIEdgeInsets = .zero` 在 AppKit 上报 `has no member 'zero'`，写全 `NSUIEdgeInsets.zero` 才行 —— 隐式成员查找只看类型自身的静态成员。

同一机制上还踩到一个坑：桥接属性原名 `maskView`，在 UIKit 上编译失败并报 `'maskView' has been renamed to 'mask'`。`UIView.maskView` 是 iOS 9 时代废弃改名的真实成员，而**真实成员优先于 dynamicMemberLookup，被 `@available(renamed:)` 标记的也算**。改名为 `maskingView` 后两个平台一致走桥接。

`box.setFrame(_:)` 是其中最关键的一个 —— 它替换了上游 13 处 `bounds.size` + `center` 的写法，原因见「前期调研」。

复用而非重造：`CGRect.box.inset(by:)`、`box.insertSubview(_:belowSubview:)`、`NSEdgeInsets.box.zero` 都是 Toolbox 原有的（后两者在此次改动中从 macOS-only 补成跨平台）。

### TappableView（AppKit）

| 能力 | UIKit | AppKit |
|---|---|---|
| 单击 | `UITapGestureRecognizer` | `NSClickGestureRecognizer` |
| 双击 | `numberOfTapsRequired = 2` | `numberOfClicksRequired = 2` |
| 高亮态 | `UILongPressGestureRecognizer(minimumPressDuration: 0)` | `NSPressGestureRecognizer(minimumPressDuration: 0)` |
| 长按 | `UILongPressGestureRecognizer` | `NSPressGestureRecognizer` |
| 上下文菜单 | `UIContextMenuInteraction` | `override func menu(for event: NSEvent) -> NSMenu?` |
| spring loading | `UISpringLoadedInteraction` | **不提供** |

### Animator

`UIView.animate(withDuration:)` → `NSAnimationContext.runAnimationGroup`；涉及 `transform` 的动画在 AppKit 走 layer。`TransformAnimator` 的插入/更新/删除三段时序（上游 `2c22625` / `d0e18f1`）在两个平台保持同一套语义。

## 替代方案考量

**继续修 `AppKitSupportProgram/UIComponent` fork。** 否。它两个平台都编译不过（见「动机」），且每次跟上游要处理 52 个冲突、其中 22 个是 import 噪音。修好它之后本库仍然要多一个外部依赖，而这个依赖的维护者是我们自己 —— 成本没省，只是换了个地方付。

**把上游 UIComponent 当外部包依赖，在本库里写 AppKit 适配层。** 不可行。`RenderNode` 的关联类型 `View` 硬绑 `UIView`，`ComponentEngine` 内部一路 `(view as? UIScrollView)`，`@_exported import UIKit` 让整个模块在 macOS 上连编译都进不去。适配层无从下手 —— 要改的是模块内部，不是它的表面。

**自己从零写一个布局引擎。** 否。Flex 的换行与 baseline 对齐、Waterfall 的列高分配、可见区域裁剪、ID diff + 视图复用，这些是 UIComponent 积累了数年的东西，重写一遍既没有新意也容易在边界情况上翻车。

**进 `UIFoundation` 伞包。** 否。`Spacer` 与本库 StackView 的 `Spacer` 硬冲突（后者无 trait 门控、永远存在），进伞包就必须改名，而改名会破坏本库现有调用方；改 UIComponent 那边的则要跟它的全部文档与示例脱节。独立 product 两边都不用改。

**引擎内部逐个翻转 frame，不要求容器 flipped。** 技术上可行（渲染是扁平的），但可见区域计算、滚动偏移、`contentSize` 变化后的重排全都要反着算一遍，任何一处漏翻都表现为「某些行位置对、某些行位置错」，极难定位。flipped 容器把这件事收敛到一个 `isFlipped` 覆写。

**`0014` 的教训。** `0014`（RunningApplicationKit 整体并入）走的是同一个形态，最终于 2026-09-05 撤销，能力退回原仓库。两者的差别在于：那次并入的是作者自己维护、且仍在原仓库活跃的库，并入后出现了「两处都要改」的重复维护；而 UIComponent 的 fork 已经破损、不具备继续维护的价值，本提案是**吸收而非镜像**，不保留双份。但体量的风险是真的 —— 131 个公开类型会是本库单个 target 里最大的一块，落地步骤因此拆成可独立验证的八步，任何一步走不通都能停在一个能编译、能测的状态上。

## 影响

### 源码兼容性（source compatibility）

**纯新增。** 不改动任何现有 target 的任何符号。`HStackView` / `VStackView` / `Spacer` / `GridView` 全部原样保留，行为不变。`Package.swift` 的改动只有新增 target 与 product 两处。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- **本仓库内**：新增 `UIFoundationComponent` target 与 product。现有 target 无一依赖它，编译图不变。
- **`UIFoundationTypealias` 新增两个别名**（纯新增）：`NSUIScrollView`、`NSUIVisualEffectView`。
- **`UIFoundationToolbox` 新增一批 `.box` 扩展**，见「详细设计」的表格。这些对所有使用 Toolbox 的代码可见，是本提案里**唯一扩大了既有 target 公开表面**的部分。两处是把现有 API 从 macOS-only 补成跨平台（`box.insertSubview(_:belowSubview:)` / `(_:aboveSubview:)` 现在在 UIKit 上也有，`box.zero` 现在 `UIEdgeInsets` 侧也有），其余为新增符号，不改动任何既有签名。
  - 一并修掉了 `insertSubview(_:belowSubview:)` 文档注释里把「below」写成「above」的笔误。
- **已知下游仓库**：RuntimeViewer（`TabsControl`）、MachOKitUI（`TextFinder`）、PrivateSymbols（基类）**全部零影响** —— 不声明对新 product 的依赖就完全不参与编译，`Package.resolved` 也不变。
- 新 product 不引入任何新的外部依赖（纯 AppKit / UIKit + 本库已有的 `UIFoundationTypealias`、`UIFoundationToolbox`）。

### 文档与示例

同批次落地，缺一项即视为未完成：

- **新增** `Documentations/ComponentLayout.md` 使用指南 —— API 总览、宿主必须遵守的契约（容器必须 flipped 或交由引擎代管、reuse key 的语义、可见区域裁剪对副作用代码的影响）、**与 `HStackView` / `VStackView` 的分工判据**（约束驱动的有限元素界面用后者，内容驱动的长列表用前者）、AppKit 与 UIKit 的已知行为偏离。
- **更新** `THIRD_PARTY_LICENSES.md` —— 登记 UIComponent：上游 `https://github.com/lkzhao/UIComponent`，作者 Luke Zhao，MIT，代码位置 `Sources/UIFoundationComponent/`，并逐条列出修改（改用 `NSUI*` 别名、目录重组、删除 `Text`/`Image`/`PrimaryMenu`/SwiftUI 集成、新增 AppKit 实现）。
- **更新** `Documentations/README.md` 与 `Documentations/Evolutions/README.md` 索引。
- **更新** `CLAUDE.md` / `AGENTS.md` —— 在「Key Patterns & Conventions」下加一节，形式对齐 `Tab Bar (ported from …)` 那批。
- **更新** `Documentations/Glossary.md` —— 登记 `render node`、`renderable`、`visible frame`、`reuse key`、`flipped 容器` 五条（本表目前无词条）。
- **示例**：`UIFoundationExample-macOS` 与 `UIFoundationExample-iOS` 各加一个演示页，覆盖 Stack / Flex / Waterfall / 长列表复用 / TappableView 交互。

## API 演进与废弃策略

- 无旧 API 被替代，不产生任何 `@available(*, deprecated)`。
- `HStackView` / `VStackView` **不废弃** —— 两套布局解决不同问题，见「文档与示例」的分工判据。
- 不需要 semver major 跃迁（纯新增 product）。
- 搬进来的 API 相对 UIComponent 上游有删减（见「非目标」），文档中需注明本 target **不是** UIComponent 的 drop-in 替代。

## 落地步骤

每一步都应能单独构建通过，两个平台都要验证（`swift build` 默认打 macOS；iOS 侧走 `xcodebuild -destination 'generic/platform=iOS'`）。

1. ~~**骨架与内核**~~ / 2. ~~**渲染引擎（UIKit）**~~ / 3. ~~**AppKit 坐标系与布局周期**~~ —— **已合并为一步并完成**。
   原计划把「内核」与「引擎」分开落地，实际做不到：`RenderNode` 协议本身引用 `Animator` 与 `ReuseManager`，而 `Component` / `RenderNode` 的 `@dynamicMemberLookup` 依赖 `Component+ViewUpdates` / `RenderNode+ViewUpdates` 里的 `subscript(dynamicMember:)`。只搬内核连编译都过不去，于是三步合一。
   已完成：新建 target + product；搬入 87 个源文件（内核 / 布局组件 / 引擎 / 通用修饰符）；统一改用 `NSUI*` 别名；`ComponentView` 与 `ComponentScrollView` 的 AppKit 实现；`NSView.layout()` swizzle；AppKit 垫片（几何、动画、遮罩、子视图插入、滚动访问）；命名规范化（`R` → `ResultRenderNode`、`CKContext` → `ComponentReuseContext`、ReuseManager 与 ForEach 的单字母泛型参数）。
   **验收结果**：macOS `swift build` 与 iOS `xcodebuild` 均通过且零警告；`ComponentLayoutCoordinateTests` 四条坐标断言全绿；全量测试 153 swift-testing + 9 XCTest 原始退出码 0。
4. **滚动容器实测** —— `ComponentScrollView` 的代码已在位（内建 flipped documentView、clipView bounds 观察、`componentSetContentSize` 改写 documentView frame）。仍缺**运行期验证**：滚动时可见区域是否正确裁剪、`scrollTo(id:)` 是否到位、大列表复用是否生效。
5. **TappableView** —— 两平台交互实现。验收：单击 / 双击 / 长按 / 右键菜单在 macOS 上均可触发。
6. **测试补齐** —— 上游测试全量跨平台化（`SizingTest` / `LazyLayoutTest` / `ReuseTest` / `ViewDiffTests` / `MeasureSizeTests` 等），加上滚动与交互的 AppKit 专项测试。
7. **示例** —— 两个 Example App 各加演示页。
   **已知阻碍**：Example 的 xcodeproj 用 `relativePath = ../../UIFoundation` 引用本包。从 worktree 里看，该路径解析到 `.worktrees/UIFoundation`，而 SPM 以**目录名**作为包 identity，worktree 目录名 `UIFoundation-ComponentLayout` 与包名 `UIFoundation` 不符，实测报 `unable to override package 'UIFoundation' because its identity 'uifoundation' doesn't match override's identity (directory name) 'uifoundation-componentlayout'`。符号链接无效（SPM 解析真实路径）。落地时需要先决定：把 worktree 改成同名、把 worktree 挪进一层子目录、还是把 example 验证放到合并回 `main` 之后做。
8. **文档** —— 使用指南、许可证登记、`CLAUDE.md`、术语表、两处索引，并给本提案分配编号（当前最大为 `0023`）。

**收尾时必须判断两件事**（结果写进决策日志，不允许沉默跳过）：

- 要不要配套专题文章 —— 使用指南已在计划内；另需判断是否值得写一篇实现说明记录「为什么 flipped 容器而不是逐个翻转 frame」「`NSScrollView` 的 documentView 模型与 `UIScrollView` 的差异如何收敛」。
- 有没有引入新术语 —— 已确认有，见「文档与示例」列出的五条。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-09-21 | Created as Draft | 起因是「合并 UIComponent 上游 v6 并适配 AppKit」，调研后确认那个 fork 两平台均编译失败、维护不划算，改为把布局系统并入本库 |
| 2026-09-21 | 定范围：内核 + 渲染引擎 + TappableView | 只要内核则开箱不可用（算出 frame 无处安放）；整库搬则与本库既有控件体系重叠过多。TappableView 单独纳入，因为没有它列表的行无法响应点击 |
| 2026-09-21 | 定归属：独立 target + 独立 product，不进伞包 | 不进伞包使 `Spacer` / `Component` 两处重名都不必改名，两边现有调用方与上游文档都不受影响 |
| 2026-09-21 | 定形态：完全吸收，不保留与上游同步的能力 | 与 `TabBar` / `QuickActionBar` / `WelcomePanel` 一致。保留同步能力要求文件结构与类型名贴住上游，会在本库里留下一块风格格格不入的飞地 |
| 2026-09-21 | 定坐标系：flipped 容器，不 swizzle `isFlipped` | 实测渲染是扁平的（`ComponentViewDiffApplier` 把全部 renderable 挂在同一个容器上），翻转只需作用于一个容器；swizzle 会波及进程内所有 AppKit 视图 |
| 2026-09-21 | 定滚动容器：`ComponentScrollView` 内建 flipped documentView | `NSScrollView` 必须有 documentView，与 `UIScrollView` 自身即容器的模型不同；由库内建可让调用方写法与 iOS 侧最接近 |
| 2026-09-21 | 定 API 表面：能降级就降级，没对应物的不提供 | `UISpringLoadedInteraction` / tvOS focus 在 macOS 上不提供空实现 —— 静默失效比编译错误更难发现 |
| 2026-09-21 | 定共存：不废弃 `HStackView` / `VStackView` | 两者解决不同问题（约束驱动 vs 内容驱动），分工写进使用指南 |
| 2026-09-21 | 定：**不加 trait** | 独立 product 边界已实现 trait 想要的隔离（target 只有被依赖时才编译）。叠一层 trait 会让下游多一个漏掉就报错误信息的步骤。那批 port 需要 trait 是因为源码住在伞包会编译的 target 里，本提案有自己的 target，不存在这个前提 |
| 2026-09-21 | 状态 Draft → Accepted → In Progress | 用户批准提案并指示开工；实现分支 `feature/component-layout-system`，worktree `.worktrees/UIFoundation-ComponentLayout` |
| 2026-09-21 | 落地步骤 1–3 合并 | `RenderNode` 协议引用 `Animator` 与 `ReuseManager`，`@dynamicMemberLookup` 依赖两个 modifier 文件里的 `subscript(dynamicMember:)` —— 只搬「内核」编译不过，内核与引擎在上游架构里不可分割 |
| 2026-09-21 | 13 处 `bounds.size` + `center` 改走 `componentApplyFrame(_:)` | AppKit 的 `bounds` 是视图自身坐标空间而非尺寸，赋值不改 frame。症状是每个视图位置正确、尺寸为零，静默画不出任何东西 —— 见「前期调研」 |
| 2026-09-21 | 容器 frame 改在 `didFinishLayout` 里设，而非只在 `layoutSubview` | `visibleFrame` 把视口换算到容器坐标系，容器尺寸还是零时会裁掉全部 renderable。表现为非 flipped 宿主上一个视图都不渲染 |
| 2026-09-21 | `TransformAnimator.update` 的两段动画合并为一段 | 上游把位置与尺寸分成两个独立动画，而 AppKit 无法单独表达尺寸那一半。合并后行为等价：只变其一时，另一半从当前值动画到同一个值 |
| 2026-09-21 | 新增 `ComponentDisplayableView.renderingEngine` | `ComponentScrollView`(AppKit) 必须把引擎重定向到 documentView，而 `componentEngine` 定义在 `NSUIView` 的 extension 上、无法被子类覆盖（与 CLAUDE.md 记载的 AppKitPlus 同名属性冲突是同一条规则） |
| 2026-09-21 | 命名规范化 | `associatedtype R` → `ResultRenderNode`（35 处）、`CKContext` → `ComponentReuseContext`、`ReuseManager<T>` → `<ReusedView>`、`ForEach<S, D>` → `<DataSequence, DataElement>`，以符合「不使用任何缩写」的编码规范 |
| 2026-09-21 | 平台桥接迁入 `UIFoundationToolbox` 的 `.box` 命名空间 | 这些差异（`alphaValue` 对 `alpha`、可选的 `NSView.layer`、AppKit 没有 `sizeThatFits`）不是布局系统特有的，放 Toolbox 才能被其它跨平台代码复用。走 `.box` 而非裸扩展，是为了不给进程内每个 `NSView` 挂上 `alpha` / `center` 这类名字 —— 即 AppKitPlus 那条同名属性冲突的教训 |
| 2026-09-21 | 关联对象改用 `@AssociatedObject` 宏 | 三处手写的 `objc_setAssociatedObject`（引擎实例、复用上下文、AppKit 的遮罩视图）换成本库既有的宏，与 `NSView.actionHandlers` 的写法一致 |
| 2026-09-21 | 动画桥接必须是跨平台的，不能只做 AppKit | 先只在 AppKit 侧定义 `box.animate`，iOS 构建随即失败 —— 且错误信息把调用解析到了 `CATransaction.box.performWithoutAnimation`，报「requires that 'NSUIView' inherit from 'CATransaction'」，与真正的原因（UIKit 侧没有这个方法）毫无关系 |
| 2026-09-21 | `.box` 扩展内的 `min` / `max` 必须写成 `Swift.min` / `Swift.max` | `FrameworkToolbox` 带 `@dynamicMemberLookup`，会把裸 `min` 截走并报「property 'min' requires that 'Base' conform to 'Sequence'」 |
| 2026-09-21 | 调用点省掉属性上的 `.box` | `NSObject` 已遵守 `FrameworkToolboxDynamicMemberLookup`，实例属性与静态属性（SE-0438，Swift 6.1，无需 feature flag）都可直接访问。方法仍需 `.box`；leading-dot 写法不触发 lookup，静态属性要写全类型名 |
| 2026-09-21 | 桥接属性 `maskView` 更名 `maskingView` | `UIView.maskView` 是废弃改名的真实成员，而真实成员优先于 dynamicMemberLookup —— 即使标了 `@available(renamed:)`。iOS 侧因此编译失败并报「'maskView' has been renamed to 'mask'」，与桥接本身毫无关系 |
