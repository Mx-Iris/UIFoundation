# 0001 - NavigationController：移植 macOS App Store 的导航容器与推入/弹出转场

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-09
- **最后更新**: 2026-08-09
- **所属愿景**: 无
- **关联提案**: 无
- **实现分支 / PR**: 待定
- **配套文档**: 使用指南 [`Documentations/Navigation.md`](../Navigation.md)；逆向依据 [`Researchs/AppStore-Custom-Navigation-Internals.md`](../../Researchs/AppStore-Custom-Navigation-Internals.md)

## 摘要

AppKit 没有导航容器。macOS 版 App Store 自己造了一个，本提案把它整套搬进 UIFoundation：一个管理
视图控制器栈的 `NavigationController`，一对推入/弹出转场，以及支撑它们的一小层插值框架。同时带上
App Store 版本里最有价值的那一块 —— **双指右滑返回**，它用的是公开的 `NSEvent` 手势跟踪，不涉及私有 API。

新代码全部落在 `Sources/UIFoundationAppKit/Navigation/`，由一个默认关闭的 SPM trait `Navigation` 控制，
沿用 `TabBar` / `SystemHUD` 的做法。对现有使用方零影响。

## 动机

**AppKit 至今没有导航容器。** 需要「进入下一级、再退回来」这种层级导航时，Mac 开发者只有三条路：
用 `NSSplitViewController` 硬凑、自己写一套、或者直接不做动画切换视图。三条都不好。

AppKit 里确实有个叫 `NSViewControllerPushTransition` 的东西，名字看着正对口，但它是死的：反编译
（AppKit 26.6，`0x185268FCC`）显示它根本不做任何位移，只是让一个居中的 `NSBox` 在 20% 的压暗层上淡入，
而且 AppKit 内部没有任何地方实例化过它。指望不上。

**那为什么是 App Store 的实现，而不是 UIKit 的？**

我在 AppKitPlus 里已经移植过 UIKit 的 `_UINavigationParallaxTransition`（那边的提案 0006），移植出来的
东西有两个改不掉的短板，而这两点恰好都是 App Store 版本解决掉的：

1. **UIKit 那套只能给出一个转场动画器，给不出导航栈。** AppKit 的 `NSViewControllerPresentationAnimator`
   协议只有两个方法，拿不到转场上下文，撑不起「一个栈 + 推入/弹出/回到根」这套语义。App Store 的
   `BaseNavigationController` 本来就是完整容器，直接对得上。
2. **UIKit 那套做不了交互式返回手势。** UIKit 的交互转场依赖 `UIPercentDrivenInteractiveTransition`
   和一整套可中断、可反向的动画驱动，AppKit 没有对应物，所以 AppKitPlus 明确把它划到范围外了。
   App Store 用 `NSEvent.trackSwipeEvent(withOptions:...)` 解决 —— 公开 API，一个回调喂进度，
   二十行搞定。这是「照抄 Apple 自己在 Mac 上怎么做」相对于「把 iOS 的做法搬过来」的实质差别。

此外 App Store 这套是 **AppKit 原生**的：动画走 `NSAnimationContext`，位移改的是 `NSView.frame`，
不重新挂载视图层级，不碰任何私有 API。移植风险比 UIKit 那条路低一个量级。

**证据**：完整逆向结论（每个常量都给了地址）写在
[`Researchs/AppStore-Custom-Navigation-Internals.md`](../../Researchs/AppStore-Custom-Navigation-Internals.md)，
以下调研一节只摘对设计有决定作用的部分。

## 前期调研

### 本仓库现状

- `Sources/UIFoundationAppKit/Controller/` 下已有 `XiblessSplitViewController`、`XiblessTabViewController`
  等容器基类，但**没有任何导航语义**的东西。新增不与既有类型冲突。
- 已有的 trait 化组件（`TabBar` / `SystemHUD` / `QuickActionBar` / `StatusItemController`）确立了
  「大块移植组件走可选 trait」的先例，本提案沿用。
- 单文件 basename 在同一 target 内必须唯一（见 `AGENTS.md`「Code Style Notes」），所以泛用名要加前缀。

### App Store 的实现长什么样（已逆向验证）

四层，层与层之间干净解耦：

```
BaseNavigationController          栈、代理、滑动手势
  └── any ViewTransition          PushViewTransition / PopViewTransition
        ├── ViewPropertyInterpolator   一组 Transformation + 一条曲线
        │     └── Interpolator<Value>  （AppStoreKit）
        └── ViewPropertyAnimator       NSAnimationContext 的薄封装
```

下面两层完全不知道导航的存在，转场层完全不知道栈的存在。转场是一个**值**：描述三个视图和一串要插值的
属性，既能被手一帧帧推（交互式），也能整个交给动画器（自动），两条路走的是同一份描述。这个结构值得原样保留。

### 决定观感的那几个数（全部在汇编里确认过）

| 项 | 值 | 出处 |
|---|---|---|
| 时长 | `0.35 s` | `0x10016F4F0` |
| 曲线（推入**和**弹出同一条） | `cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)` | `0x1E47F06A0` |
| 视差量 | 旧页面反向移动 `floor(width × 0.2527)` | `0x10016E6F0` |
| 压暗色 | sRGB 纯黑，alpha `0.22` | `0x1002860A4` |
| 压暗层位置 | 夹在旧页面之上、新页面之下 | `0x10016F32C` |

三点值得单独说：

- **弹出用的是和推入完全相同的曲线**，不是反过来的。AppStoreKit 里确实有一条现成的反向曲线
  `TimingCurve.customNavigationPop`（= `customNavigation.reversed`），但它在 App Store 二进制里
  **交叉引用为零** —— 编进去了，一次都没调用。推入和弹出的 `timing` getter 因为字节完全相同被链接器
  折叠成了同一个函数，这本身就是最硬的证据。
- **视差量是 25.27%**，UIKit 是 30%（`width − round(width × 0.7)`）。两者不一样，这里跟 App Store。
- **压暗层只压旧页面**，新页面上没有蒙层。

### 动画到底是怎么驱动的

这是整套设计里最吃紧的一点，也是最容易在移植时抄错的一点。转场**从不创建 `CABasicAnimation`**。
它直接把属性赋成终值，靠动画组的隐式动画开关让 CoreAnimation 去插值：

```swift
NSAnimationContext.runAnimationGroup({ context in
    context.duration = duration
    context.timingFunction = curve.caMediaTimingFunction
    context.allowsImplicitAnimation = true
    for animation in animations { animation() }        // 里面就是 transition.apply(1.0)
}, completionHandler: { ... })
```

`prepare()` 里给三个视图挨个设 `wantsLayer = true`，就是为了这个 —— 没有图层背衬，隐式动画不会发生，
页面会瞬移。这条约束必须写进使用指南。

### 交互式返回手势

没有 gesture recognizer，只有两个 override：

```swift
override func wantsScrollEventsForSwipeTrackingOnAxis(_ axis: NSEvent.GestureAxis) -> Bool {
    axis == .horizontal
}

override func scrollWheel(with event: NSEvent) {
    guard stack.count >= 2,
          abs(event.scrollingDeltaY) < abs(event.scrollingDeltaX),
          event.scrollingDeltaX > 0,                  // 只认向右 —— 只能返回，不能前进
          event.phase == .began else { return }
    // 用栈顶两个控制器造一个弹出转场，然后：
    event.trackSwipeEvent(options: <rawValue 7>, dampenAmountThresholdMin: 0, max: 1) { amount, phase, isComplete, stop in
        transition.apply(amount)      // 已经被夹在 0…1
    }
}
```

`options = 7` 是汇编里读出来的（`0x1000C6788` 的 `MOV W2, #7`）。`NSEventSwipeTrackingOptions` 公开的
只有 `.lockDirection`（1）和 `.clampGestureAmount`（2）；**第 3 位（4）没有公开名字**。

### 一个不能照抄的地方

App Store 所有矩形都取自 `containerView.layoutFrame`，而这个属性反编译出来是：

```swift
extension LayoutMarginsAware where Self: NSView {
    var layoutFrame: CGRect { frame.subtracting(insets: NSEdgeInsetsZero) }
}
```

用的是 **`frame` 而不是 `bounds`** —— 容器在它父视图坐标系里的矩形，却被当成子视图在容器**自己**坐标系里的
frame 用。只有容器原点恰好是 `(0, 0)` 时这两者才相等。视图控制器的根视图通常确实是，所以它没出过问题，
但这是个碰巧成立的假设，移植时要改掉（见「详细设计」）。

## 提议方案

在 `Sources/UIFoundationAppKit/Navigation/` 下新增一套 macOS-only 的导航容器，由新 trait `Navigation`
门控（默认关闭）。四层结构原样保留，公开 API 按 UIKit 的习惯命名 —— 调用方脑子里的模型就是
`UINavigationController`，用 `pushViewController(_:animated:)` 比用 App Store 内部的 `setStack(_:animated:)`
好找得多。

观感常量 1:1 复刻 App Store（0.35 秒、25.27% 视差、那条 bezier、22% 黑），但全部做成可改的属性。

### 非目标

- **不做导航栏 / 返回按钮等外观件**。App Store 的 `NavigationBackButton`、`NavigationPaletteView`、
  `NavigationTitleHeaderView`、`NavigationDoubleHeaderView`、`NavigationClipView` 都深度绑定它自己的
  设计语言和 `AppStoreKit.ButtonView`，搬过来既不通用也维护不起。本提案只做容器和转场；
  标题栏、返回按钮由宿主自己画，容器提供 `topViewController` / `canPop` 和代理回调够用了。
- **不做路由层**。App Store 的 `FlowController` / `FlowDestination` / `FlowActionRunner` 是它的
  业务路由，与导航容器无关。
- **不做 UIKit 平台的版本**。iOS 那边有 `UINavigationController`。
- **不做通用的可暂停/可反向动画器**。`ViewPropertyAnimator` 就是 `NSAnimationContext` 的薄封装，
  不试图做成 `UIViewPropertyAnimator`。
- **不做工具栏联动**、不做 `NSWindow` 标题同步。
- **本轮不把插值原语提升到 `UIFoundationShared`**。`TimingCurve` / `Interpolator` / `Interpolatable`
  确实跨平台可复用，但先关在 trait 里；要提升另开提案，理由见「替代方案考量」。

## 详细设计

### 目录与文件

```
Sources/UIFoundationAppKit/Navigation/
├── NavigationController.swift              # 容器本体
├── NavigationController+Stack.swift        # push / pop / setViewControllers
├── NavigationController+Delegate.swift     # 两个代理协议
├── NavigationController+Swipe.swift        # 交互式返回
├── NavigationDimmingView.swift             # 压暗层
├── NavigationViewTransition.swift          # ViewTransition / InteractiveViewTransition 协议
├── NavigationPushTransition.swift
├── NavigationPopTransition.swift
├── NavigationTransformation.swift          # Transformation / KeyPath / Closure
├── NavigationPropertyInterpolator.swift    # ViewPropertyInterpolator + ViewPropertyAnimator
├── AnimationTiming.swift
├── TimingCurve.swift
├── Interpolator.swift
└── Interpolatable.swift
```

文件名带 `Navigation` 前缀是为了满足同 target 内 basename 唯一的约束；**类型名不带前缀**。
每个文件整体包在 `#if Navigation && os(macOS) … #endif` 里。

### 插值原语

```swift
public protocol Interpolatable {
    static func solvedValue(between startValue: Self, and endValue: Self, forInput input: CGFloat) -> Self
}

extension CGFloat: Interpolatable {}
extension Double: Interpolatable {}
extension CGPoint: Interpolatable {}
extension CGSize: Interpolatable {}
extension CGRect: Interpolatable {}

public struct Interpolator<Value: Interpolatable> {
    public let fromValue: Value
    public let toValue: Value
    public let curveFunction: CAMediaTimingFunction

    public init(fromValue: Value, toValue: Value, curve: TimingCurve)
    public func value(forInput input: CGFloat) -> Value
}
```

`Value` 而不是 `V` —— 泛型参数必须是完整描述性名称，这是硬规则。

```swift
public enum TimingCurve: Hashable, Sendable {
    case controlPoints(Float, Float, Float, Float)
    case easeInOut, easeIn, easeOut, linear

    public var caMediaTimingFunction: CAMediaTimingFunction { get }
    public var controlPoint1: CGPoint { get }
    public var controlPoint2: CGPoint { get }
    /// 沿对角线翻转控制点：`(1 − p2.x, 1 − p2.y, 1 − p1.x, 1 − p1.y)`。
    public var reversed: TimingCurve { get }

    /// App Store 推入/弹出用的曲线：`cubic-bezier(0.1878, 0.0023, 0.5399, 0.9629)`。
    public static let navigation: TimingCurve = .controlPoints(0.1878, 0.0023, 0.5399, 0.9629)
}
```

`Interpolator.value(forInput:)` 需要把贝塞尔曲线解成 y —— `CAMediaTimingFunction` 只能读控制点，
不能求值，所以要自己写一个单位三次贝塞尔求解器（牛顿迭代 + 二分兜底）。这块是纯函数，可直接单测。

### 转换与动画

```swift
public protocol Transformation {
    func apply(_ fraction: CGFloat)
}

public struct KeyPathTransformation<Target: AnyObject, Value: Interpolatable>: Transformation {
    public let target: Target
    public let property: ReferenceWritableKeyPath<Target, Value>
    public let interpolator: Interpolator<Value>
    public func apply(_ fraction: CGFloat) { target[keyPath: property] = interpolator.value(forInput: fraction) }
}

public struct ClosureTransformation<Value: Interpolatable>: Transformation {
    public let interpolator: Interpolator<Value>
    public let body: (Value) -> Void
}

public struct ViewPropertyInterpolator {
    public var transformations: [any Transformation]
    public var curve: TimingCurve
    public func apply(_ fraction: CGFloat)     // 原样透传，不加曲线
}

public struct AnimationTiming: Hashable, Sendable {
    public var duration: TimeInterval
    public var curve: TimingCurve
    public static let navigation = AnimationTiming(duration: 0.35, curve: .navigation)
}

@MainActor
public struct ViewPropertyAnimator {
    public var animations: [() -> Void] = []
    public var completions: [() -> Void] = []
    public var duration: TimeInterval
    public var curve: TimingCurve
    public var delay: TimeInterval = 0
    public func run()
}
```

**`ViewPropertyInterpolator.apply(_:)` 把 fraction 原样传给每个 transformation，不施加自己的曲线** ——
曲线在每个 `Interpolator` 内部各自生效。这不是疏忽：交互式驱动时喂进来的是未加工的手势进度，
必须落在与自动动画完全相同的缓动值上，否则松手瞬间会跳。这条要写进实现说明。

### 转场

```swift
@MainActor
public protocol ViewTransition {
    init(containerView: NSView, sourceView: NSView, destinationView: NSView)
    var timing: AnimationTiming { get }
    /// 挂载参与视图、开启图层背衬、把状态坐到起点。
    func prepare()
    func apply(_ fraction: CGFloat)
    /// 拆掉压暗层等临时视图；`isFinished` 为假表示这次转场被取消了。
    func cleanUp(isFinished: Bool)
}

@MainActor
public protocol InteractiveViewTransition: ViewTransition {
    func beginInteractive()
    func finishInteractive(from fraction: CGFloat, completion: @escaping () -> Void)
    func cancelInteractive(from fraction: CGFloat, completion: @escaping () -> Void)
}

public struct PushViewTransition: InteractiveViewTransition { … }
public struct PopViewTransition: InteractiveViewTransition { … }
```

几何（`referenceRect` 的定义见下一节，`layoutDirection` 取 `containerView.userInterfaceLayoutDirection`）：

```swift
let parallaxShift = floor(referenceRect.width * 0.2527)
let shiftSign: CGFloat = layoutDirection == .rightToLeft ? 1 : -1
let offscreenX = layoutDirection == .rightToLeft
    ? referenceRect.minX - referenceRect.width
    : referenceRect.maxX
```

| 转场 | 变换 1 | 变换 2 | 变换 3 |
|---|---|---|---|
| 推入 | `sourceView.frame`：`referenceRect` → 偏移 `shiftSign × parallaxShift` | `destinationView.frame`：`offscreenX` 处 → `referenceRect` | `dimmingView.alphaValue`：`0 → 1` |
| 弹出 | `sourceView.frame`：`referenceRect` → `offscreenX` 处 | `destinationView.frame`：偏移 `shiftSign × parallaxShift` → `referenceRect` | `dimmingView.alphaValue`：`1 → 0` |

`prepare()`（推入，弹出对称）：

```swift
sourceView.wantsLayer = true
destinationView.wantsLayer = true
containerView.addSubview(destinationView)
dimmingView.wantsLayer = true
dimmingView.frame = referenceRect
containerView.addSubview(dimmingView, positioned: .below, relativeTo: destinationView)
apply(0)
```

交互式收尾：从当前 fraction 出发，按剩余距离折算时长（`timing.duration × abs(target − fraction)`）
跑到 1（完成）或 0（取消）。**这三个方法是自己设计的，不是抄来的** —— `InteractiveViewTransition`
在 App Store 里的三个 requirement 只知道槽位和「是方法」，语义没有反编译确认。记入决策日志。

### 容器

```swift
@MainActor
open class NavigationController: NSViewController {
    public var viewControllers: [NSViewController] { get set }
    public func setViewControllers(_ viewControllers: [NSViewController], animated: Bool)

    public func pushViewController(_ viewController: NSViewController, animated: Bool)
    @discardableResult public func popViewController(animated: Bool) -> NSViewController?
    @discardableResult public func popToViewController(_ viewController: NSViewController, animated: Bool) -> [NSViewController]
    @discardableResult public func popToRootViewController(animated: Bool) -> [NSViewController]

    public var rootViewController: NSViewController? { get }
    public var topViewController: NSViewController? { get }
    /// 逐层下钻，返回最深一层导航容器的栈顶。
    public var deepestViewController: NSViewController? { get }
    public var canPop: Bool { get }
    public private(set) var isTransitioning: Bool

    public weak var delegate: (any NavigationControllerDelegate)?
    public weak var transitionDelegate: (any NavigationControllerTransitionDelegate)?

    /// 双指右滑返回，默认开启。
    public var allowsInteractivePop: Bool

    /// 子控制器视图相对容器 `bounds` 的内缩。默认 `.zero`。
    public var contentInsets: NSEdgeInsets

    @objc open func navigateBack(_ sender: Any?)
}

@MainActor
public protocol NavigationControllerDelegate: AnyObject {
    func navigationController(_ navigationController: NavigationController,
                              willShow viewController: NSViewController, animated: Bool)
    func navigationController(_ navigationController: NavigationController,
                              didShow viewController: NSViewController, animated: Bool)
}

@MainActor
public protocol NavigationControllerTransitionDelegate: AnyObject {
    func navigationController(_ navigationController: NavigationController,
                              pushTransitionFrom sourceView: NSView, to destinationView: NSView,
                              in containerView: NSView) -> (any ViewTransition)?
    func navigationController(_ navigationController: NavigationController,
                              popTransitionFrom sourceView: NSView, to destinationView: NSView,
                              in containerView: NSView) -> (any ViewTransition)?
}
```

两个代理协议都给默认空实现，宿主按需实现。

所有栈变更走同一个私有 funnel `applyStack(_:animated:)`，顺序照抄 App Store（逆向报告第 6 节）：
算出 `(from, to, operation)` → `willChangeValue` → `willShow` → 旧的 `removeFromParent` /
新的 `addChild` → 视图工作 → 赋值 `viewControllers` → `didChangeValue` → `didShow`。
非动画路径末尾要 `view.window?.recalculateKeyViewLoop()`。

### `referenceRect`：本移植与 App Store 的关键分歧

```swift
var referenceRect: CGRect { containerView.bounds.inset(by: contentInsets) }
```

App Store 用的是 `containerView.frame`（调研一节已说明为什么那是碰巧成立的）。这里改成 `bounds`
内缩 `contentInsets`：`bounds` 才是子视图 frame 该待的坐标系，`contentInsets` 替代 App Store 依赖的
`layoutMargins`（AppKit 的 `NSView` 没有这个属性，App Store 是自己定义的协议）。

### 其它偏离一览

| App Store | 本移植 | 理由 |
|---|---|---|
| `containerView.frame` | `containerView.bounds.inset(by: contentInsets)` | 见上 |
| `jet_traitCollection.layoutDirection` | `containerView.userInterfaceLayoutDirection` | 前者是 App Store 私有的 trait 系统 |
| `AppStoreKit.BackgroundView` 作压暗层 | 内部的 `NavigationDimmingView`（图层背衬 `NSView`） | 只用到纯色填充，没必要搬整个类 |
| 弹出的第一个变换是 `ClosureTransformation` | 改用 `KeyPathTransformation`，与推入对称 | 那个闭包只捕获了 `sourceView`，看不出非闭包不可的理由；`ClosureTransformation` 类型本身仍然保留，它有独立价值 |
| `objectGraph`（依赖注入） | 去掉 | 业务专属 |
| `TimingCurve.customNavigationPop` | 保留 `reversed`，但不设默认反向曲线 | 它在 App Store 里引用为零，跟随实际行为 |
| 滑动 options 常量 | 原样用 `7`，注释标出第 3 位无公开名 | 目的就是复刻手感 |

## 替代方案考量

**（一）复用 AppKitPlus 已有的 `NSNavigationParallaxTransition`。** 那是 UIKit 视差转场的移植，已经
能跑。否掉的原因是它只是个 `NSViewControllerPresentationAnimator`：没有栈，`present`/`dismiss` 语义
撑不起 `popToRoot`，而且交互式手势在那套结构下做不了（提案 0006 已把它划到范围外）。另外 AppKitPlus
是 Objective-C 二进制分发库，UIFoundation 是 Swift 源码包，把它拉成依赖会给所有使用方增加一个
xcframework 负担。两者定位不同，可以共存。

**（二）用 `CABasicAnimation` 显式驱动，而不是 `NSAnimationContext` 隐式动画。** 我在 AppKitPlus 那次
移植里正是这么做的，因为那边同时动四个属性、必须共用一个时钟。这里否掉：App Store 的做法只动
`frame` 和 `alphaValue`，三个属性都在同一个动画组里，本来就共时钟；而且改成显式动画就**丢掉了交互式
驱动的能力** —— `apply(fraction)` 能一帧帧推，正是因为它只是普通赋值。这是这套设计的核心优点，不能换掉。

**（三）用 `NSPanGestureRecognizer` 做返回手势。** 触控板的惯性、橡皮筋、`isComplete` 判定全得自己写，
而 `trackSwipeEvent` 免费给。而且它认的是滚轮/触控板的 scroll 事件，鼠标滚轮横滚也能触发，覆盖面更广。

**（四）把 `TimingCurve` / `Interpolator` / `Interpolatable` 放进 `UIFoundationShared`。** 它们确实
跨平台且与导航无关，放 Shared 更「对」。本轮否掉是因为 `UIFoundationShared` 是无条件编译进所有使用方的
公共底座，往里加三个泛用名字（尤其 `Interpolator`）会给 RuntimeViewer / MachOKitUI / PrivateSymbols
三个下游同时增加命名冲突面，而收益此刻还是假设的。先关在 trait 里，真有第二个使用者时再开提案提升 ——
这个方向是单向可逆的（收窄难，放宽容易）。

**（五）类型名加前缀避免冲突**（`NavigationTimingCurve`、`ValueInterpolator`……）。否掉：本仓库既有风格
就是裸名（`TabBar`、`StackView`、`ScrollView`），而且这些类型只在 trait 打开时才存在，冲突面已经被 trait 收窄了。

**（六）连导航栏一起搬。** 否掉，理由在「非目标」。补一句：App Store 的返回按钮是 `AppStoreKit.ButtonView`
子类，还带 vibrancy 填充层，那是它的设计语言，不是通用件。

## 影响

### 源码兼容性（source compatibility）

**纯新增，且默认不编译。** 所有新代码都包在 `#if Navigation && os(macOS)` 里，新 trait `Navigation`
默认关闭。不打开 trait 的使用方，编译产物与现在逐字节相同；打开的使用方也只是多出一批新类型，
没有任何现有符号被改动或移除。

需要留意的唯一一点：`Navigation` trait 打开后，`UIFoundation` 会 `@_exported` 出
`TimingCurve` / `Interpolator` / `Interpolatable` / `Transformation` 等泛用名。使用方若自己已有同名
顶层类型，会需要模块限定（`UIFoundation.TimingCurve`）。这不是破坏性改动 —— 只影响主动打开 trait 的一方。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- 仓库内受影响 target：只有 `UIFoundationAppKit`（新增目录），以及 `Package.swift`（新增 trait）。
  `UIFoundationShared` / `UIFoundationToolbox` / `UIFoundationUtilities` **不动**。
- **RuntimeViewer**（用 `TabBar`）、**MachOKitUI**（用 `TextFinder`）、**PrivateSymbols**（全面用本库基类）：
  三者都不会打开 `Navigation` trait，因此**零影响**。这也正是选 trait 而不是直接加进 `Controller/` 的原因。

### 文档与示例

- 新增使用指南 `Documentations/Navigation.md`，并登记进 `Documentations/README.md`。这一篇是必须的 ——
  有三条从 API 签名看不出来、违反了就出错的契约（下节列出）。
- `AGENTS.md` 新增「Navigation」小节，写进 trait 列表与关键约束。
- Example app 新增一个演示页；同时要把 `Navigation` 加进 example 的 `XCLocalSwiftPackageReference`
  的 traits 列表，否则符号根本不参与编译。

## API 演进与废弃策略

无旧 API 被替代，不需要废弃标注，不触发 semver major。

后续若把插值原语提升到 `UIFoundationShared`（替代方案四），届时在 `UIFoundationAppKit` 侧留
`public typealias` 保证源码兼容，那是另一份提案的事。

## 落地步骤

（全部完成，落地结果与本节的偏差见下一节。）

1. ✅ **插值原语 + 单测**：`Interpolatable` / `Interpolator` / `TimingCurve`，含单位三次贝塞尔求解器。
   测试断言：曲线端点、`reversed` 的数值等于 `(0.4601, 0.0371, 0.8122, 0.9977)`、各 `Interpolatable`
   在 `0 / 0.5 / 1` 处的取值。纯函数，不需要窗口。
2. ✅ **`Transformation` / `ViewPropertyInterpolator` / `AnimationTiming` / `ViewPropertyAnimator`**。
3. ✅ **`ViewTransition` 协议 + 推入/弹出转场 + 压暗层**。几何计算抽成可直接断言的纯函数
   （参考 AppKitPlus 的 `_NSNavigationParallaxLayoutEngine` 做法），测试覆盖左右两种布局方向、
   `contentInsets` 生效、25.27% 视差在具体宽度下的精确值。
4. ✅ **`NavigationController` 本体**：栈 funnel、子控制器管理、代理、`navigateBack(_:)` 与菜单项校验。
5. ✅ **交互式返回**：两个 override + `InteractiveViewTransition` 的完成/取消。
6. ✅ **Package.swift 加 trait `Navigation`**，所有文件加 `#if`。
7. ✅ **Example 演示页** + `DemoCatalog.all` 一条 + example 工程 traits 列表加 `Navigation`。
8. ✅ **文档**：`Documentations/Navigation.md`（使用指南）、`Documentations/README.md` 索引、
   `README.md` 对外章节、`AGENTS.md` 小节、本提案状态改 `Implemented` 并登记配套文档。

每一步都能单独 `swift build --traits Navigation` 通过。

**收尾时必须判断的两件事**（结论写进决策日志）：

- **配套专题文章**：**写了使用指南** [`Documentations/Navigation.md`](../Navigation.md)。落地过程中
  契约从三条变成四条，多出来的一条是「转场进行中的栈变更被延后」。**不写实现说明** —— 实现里唯一
  「代码本身看不出来」的决策是「为什么不能改用显式 `CABasicAnimation`」，它已经写在
  `ViewPropertyAnimator` 的文档注释、`AGENTS.md` 小节和使用指南第 7 节里，再单起一篇只会造成三处同源。
- **新术语**：**不建术语表**。`视差量` 在使用指南里有一句话解释且只此一处，`隐式动画驱动` 是
  CoreAnimation 的通用概念不属自造词 —— 按全局 `CLAUDE.md`「不收语言与框架的通用术语」的判据，
  两个都不够格。本仓库仍无 `Documentations/Glossary.md`，等真正出现跨篇复用的自造词再建。

## 落地结果与本提案的差异

提案是决策快照，不回头改它去迎合实现；实际落地与上面「详细设计」不一致的地方逐条记在这里。

- **文件划分**与设计一节列的清单不完全一致。实际为：`Interpolatable` / `Interpolator` /
  `TimingCurve`（含 `UnitBezierSolver`）/ `NavigationTransformation`（三个 transformation 加
  `ViewPropertyInterpolator`）/ `AnimationTiming` / `ViewPropertyAnimator` / `NavigationConfiguration` /
  `NavigationTransitionGeometry` / `NavigationDimmingView` / `NavigationViewTransition`（两个协议）/
  `NavigationParallaxTransition`（共享内核 + `PushViewTransition` + `PopViewTransition`）/
  `NavigationController` / `NavigationController+Stack` / `NavigationController+Swipe` /
  `NavigationControllerDelegate`。推入与弹出没有各自成文件：两者只在「谁从屏外进场、谁吃视差位移、
  压暗往哪个方向淡」上不同，共用一个内部内核比复制两份安全。
- **新增了 `NavigationConfiguration`**，设计一节里 `contentInsets` 曾计划挂在控制器上。合并进配置
  是为了让「一个值只有一个所有者」—— 转场和静态布局用的是同一个内缩矩形。
- **`Interpolator.value(forInput:)` 只保留 `CGFloat` 一个重载**（原计划照抄三个）。三个重载会让
  所有浮点字面量调用点报 ambiguous，这是写测试时立刻撞上的。
- **栈变更在转场进行中被延后**，提案没提这件事。原设计允许并发调用，实测会让一个视图被留在屏外。
- **子控制器只重挂差集**，而非像 App Store 那样整栈摘下再挂回。
- **交互式返回的收尾动画由 AppKit 提供**，不是自己跑 `finishInteractive` / `cancelInteractive`：
  `trackSwipeEvent` 在手指抬起后会继续把 `gestureAmount` 动画到 0 或 1 再给 `isComplete`，
  自己再补一段等于动两次。那三个协议方法保留并给了默认实现，供自定义驱动使用。
- **默认观感从「App Store」改成「UIKit 原味」，并补上了 UIKit 的 9pt 交界阴影。**
  这是评审后的翻案，理由见下一节。

- **动画路径没有自动化测试**，不是漏了。`NSAnimationContext.runAnimationGroup` 的完成回调
  **在 `swift test` 进程里根本不触发** —— 同一段代码放进普通可执行文件立刻触发（带不带
  `NSApplication` 都一样），所以是测试宿主的限制而非实现问题。等它只能换来五秒超时。
  测试因此只断言同步的三段：`prepare()` 建层级、`apply(fraction)` 在若干分数上写出的状态、
  `cleanUp(isFinished:)` 的拆除结果 —— 中间的补间是 Apple 的，不归我们测。
  动画路径改为两条人工验证：Example 的 **Controls ▸ Navigation** 演示页，以及一个临时的独立
  可执行文件（链接本包、真跑 `NSAnimationContext`）。后者跑完确认：推入后 `isTransitioning`
  归假、栈顶正确、容器只剩一个子视图、旧页面已摘除；弹出后页面回到 `(0,0,400,300)` 无残留视差；
  连续两次动画推入后延后的那次确实补上（count 3、栈顶为第二次推的那个）；`popToRootViewController`
  收敛到 1。该可执行文件是一次性的，验证完即删。
- **两处 Swift 并发的取舍**：`ViewPropertyAnimator` 的完成回调改挂 `NSAnimationContext.completionHandler`
  而不用双参数的 `runAnimationGroup(_:completionHandler:)`（后者的 handler 导入为 `@Sendable`，
  装不下普通 `() -> Void`）；`delay` 那一跳用一个私有 `@unchecked Sendable` 盒子过桥。
  两者都是为了保住仓库「零警告」的现状。

## 评审翻案：默认观感改为 UIKit 原味

**提案里「1:1 复刻 App Store」这条被执行得太字面，落地后第一轮实机评审就被否了。**

反馈原话是「AppKitPlus 那个动画很完美，现在这个就像从中间推到左边的」。查下来不是 bug ——
逐帧采样确认新页面从 440 走到 0、旧页面从 0 走到 −111、都跑满 0.35 秒，几何与时长都对。
问题在于 App Store 那套本来就比 UIKit 平，而且是三处叠加：

| | UIKit（AppKitPlus 默认） | App Store |
|---|---|---|
| 视差量 | `width − round(width × 0.7)` = 30% | `floor(width × 0.2527)` = 25.27% |
| 压暗 | 黑 10% | 黑 22% |
| **交界处竖直阴影** | **9pt，1→0** | **无** |
| 缓动 | ease-in-ease-out | 前重后轻的 bezier（半程即走完约 63%，尾巴上爬） |

**阴影是主因。** 没有它，滑进来的页面没有可见边缘，看到的主要运动就只剩旧页面往左挪 ——
也就是评审说的「从中间推到左边」。那条前重后轻的曲线又把尾部拉长，进一步强化了这个错觉。

改法照抄 AppKitPlus 的分工：**UIKit 原味当默认（`NavigationConfiguration.uiKit`），
App Store 降级为预设（`.appStore`）**，两套数值都是量出来的，可以一键互换。
新增 `edgeShadowWidth`（默认 9，App Store 预设为 0）与 `NavigationEdgeShadowView` ——
移植自 UIKit 的 `_UIVerticalEdgeShadowView`（经由 AppKitPlus），衰减是**模糊溢出**
而非线性渐变：在裁剪区外填一块不透明色块，只留它溢进来的阴影。换成 `NSGradient` 边缘会明显发硬。

**这一节是给未来的自己看的**：不要因为「提案写的是复刻 App Store」就把默认值改回去。
复刻能力仍在，只是不做默认。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-09 | Created as Draft | 逆向调研完成，结论落在 `Researchs/AppStore-Custom-Navigation-Internals.md`。 |
| 2026-08-09 | 选定 App Store 而非 UIKit 作为移植源 | 理由：UIKit 那套给不出导航栈，也做不了交互式手势；App Store 版全程 AppKit 原生、无私有 API。 |
| 2026-08-09 | 公开 API 采用 UIKit 命名 | `pushViewController(_:animated:)` 等，而非 App Store 内部的 `setStack(_:animated:)` —— 调用方的心智模型是 `UINavigationController`。 |
| 2026-08-09 | `referenceRect` 用 `bounds` 而非 `frame` | App Store 用 `frame` 是碰巧成立的假设（容器原点为零），见调研一节。 |
| 2026-08-09 | 弹出不使用反向曲线 | `customNavigationPop` 在 App Store 二进制里引用为零，跟随实际行为。 |
| 2026-08-09 | `InteractiveViewTransition` 的三个方法为自行设计 | 该协议在 App Store 里只确认了槽位与「是方法」，语义未反编译验证。 |
| 2026-08-09 | 插值原语暂不提升到 `UIFoundationShared` | 避免给三个下游增加无收益的命名冲突面；单向可逆，先收窄。 |
| 2026-08-09 | Accepted → In Progress | 提案获批，范围与门控方式按提案原样执行（不搬导航栏外观件；走默认关闭的 `Navigation` trait）。 |
| 2026-08-09 | `contentInsets` 并入 `NavigationConfiguration` | 转场与静态布局用同一个内缩矩形，拆成两处会出现两个所有者。 |
| 2026-08-09 | `Interpolator.value(forInput:)` 砍到一个重载 | 三个重载让所有浮点字面量调用点 ambiguous；`Double` 本来就能隐式转成 `CGFloat`。 |
| 2026-08-09 | 转场进行中的栈变更改为延后执行 | 并发跑两个转场会把视图留在屏外；代价是 `viewControllers` 在动画期间仍报旧值，已写进使用指南契约。 |
| 2026-08-09 | 交互式收尾交给 `trackSwipeEvent` 自己的动画 | AppKit 在抬手后会继续把 `gestureAmount` 动到 0 或 1 再给 `isComplete`，自己再补一段等于动两次。 |
| 2026-08-09 | 推入/弹出共用一个内部内核 | 两者只差三处（谁从屏外进场、谁吃视差、压暗方向），复制两份实现更容易走样。公开类型仍是两个。 |
| 2026-08-09 | 修复：转场进行中改 `configuration` 会打断动画 | `didSet` 无条件调 `layOutTopViewController()`，把正在滑动的页面拽回静止位置（拖 Example 的滑块即可复现）。加 `!isTransitioning` 守卫，新值在下一次转场生效。带回归测试，修复前失败、修复后通过。横向排查了所有会改子视图 frame 的路径，只有这一处漏了守卫。 |
| 2026-08-09 | 默认观感改为 UIKit 原味，App Store 降级为预设 | 实机评审否掉了 App Store 默认值。补 `edgeShadowWidth` + `NavigationEdgeShadowView`（移植 UIKit `_UIVerticalEdgeShadowView`），新增 `.uiKit` / `.appStore` 两个预设，默认前者。详见「评审翻案」一节。 |
| 2026-08-09 | `TimingCurve.navigation` → `.appStoreNavigation` | 有了两套观感之后，「navigation」这个名字不再唯一指向 App Store 那条曲线。同时新增 `AnimationTiming.uiKitNavigation`。 |
| 2026-08-09 | In Progress → Implemented | 全部落地：96 个测试通过（其中 36 个是本次新增），trait 开/关两种构建均零警告，Example 演示页可跑。 |
