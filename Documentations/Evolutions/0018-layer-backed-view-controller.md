# 0018 - LayerBackedViewController：LayerBackedView 的控制器对位

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-09-05
- **最后更新**: 2026-09-05
- **所属愿景**: 无
- **实现分支 / PR**: `main`（直接落地）
- **关联提案**: [0017](0017-appkitplus-layer-backed-view.md)（把 `LayerBackedView` 的基类换成 `NSLayerBackedView`）
- **配套文档**: 无独立指南 —— 契约写在 `CLAUDE.md` 的「View Base Class Hierarchy」一节

## 摘要

0017 把视图那一半换到了 AppKitPlus 的 `NSLayerBackedView` 上，控制器那一半还留在原地：
本库所有代码构建的控制器都走 `XiblessViewController<View: NSUIView>`，它继承的是
`NSUIViewController`。结果是 trait 开启时，页面视图拿到了 AppKitPlus 的 layer-backing 默认值与
safe-area 冻结，但**控制器拿不到 AppKitPlus 给它准备的那一套钩子** ——
`viewWillFirstLayout` / `viewDidFirstLayout` / `viewWillFirstAppear` / `viewDidFirstAppear` /
`viewUpdateLayer` / `viewSafeAreaInsetsDidChange`，以及 `setView:` 里那条把视图与控制器接起来的
接线（`setViewControllerProxy:` / `_setupLayoutGuidesForView:` /
`_setupAdditionalSafeAreaInsetsForView:` / `_setObservedView:`）。

本提案新增 `LayerBackedViewController<View: LayerBackedView>`，形状照抄
`XiblessViewController`（`contentView` + `@autoclosure` 生成器 + `contentViewDidChange`），
基类按 trait 二选一：trait 开启时是 `NSLayerBackedViewController`，关闭时回退 `NSViewController`。
纯新增，只动 `UIFoundationAppKit` 一个 target，不加 trait，`XiblessViewController` 一行不改。

## 方案

### 新增文件

`Sources/UIFoundationAppKit/Controller/LayerBackedViewController.swift`：

```swift
#if AppKitPlus && canImport(AppKitPlus)
public typealias LayerBackedViewControllerBase = NSLayerBackedViewController
#else
public typealias LayerBackedViewControllerBase = NSViewController
#endif

open class LayerBackedViewController<View: LayerBackedView>: LayerBackedViewControllerBase {
    public lazy var contentView: View = contentViewGenerator() { didSet { … } }
    public init(viewGenerator: @autoclosure @escaping () -> View = View())
    open func commonInit()
    open override func loadView()                                   // view = contentView
    open func contentViewDidChange(_ oldContentView: View)
}
```

基类 typealias 的写法与 `LayerBackedViewBase` 完全对齐，包括那条
`#if AppKitPlus && canImport(AppKitPlus)` 的双重判断 —— trait 开启不等于产品真的链接进了这个
target（Xcode 使用方可以只开 trait），少了 `canImport` 那一半会挂在 `import` 上而不是回退。

### 三条实测事实，决定了实现只能是这个形状

以下均在本机核对（AppKitPlus 0.2.1 的 `arm64` 切片，`otool -oV` / `-tV`）：

1. **`NSLayerBackedViewController` 的接线全部挂在 `setView:` 上，不在 `loadView` 里。**
   `-[NSLayerBackedViewController setView:]` 依次调用 `setViewControllerProxy:`（仅当新视图是
   `NSLayerBackedView` 时）、`_setupLayoutGuidesForView:`、`_setupAdditionalSafeAreaInsetsForView:`，
   `super` 之后再 `_setObservedView:`（safe-area 的 KVO）。因此照 `XiblessViewController` 的做法
   覆写 `loadView()` 并 `view = contentView`，**六个钩子与 safe-area 观察全都还在** ——
   这是本提案成立的前提，也是测试里第一条金丝雀要盯的东西。
2. **AppKitPlus 没有给 `NSViewController` 添加名为 `contentView` 的成员。**
   它加的是 `navigationController` / `navigationItem` / `hidesBottomBarWhenPushed` /
   `contentUnavailableConfiguration` 等（`NSViewController+NavigationController.h`、
   `NSViewController+ContentUnavailableConfiguration.h`）。所以本类声明 `contentView`
   不会触发 `CLAUDE.md` 里记的那条「子类不得声明 AppKitPlus 已加到该类上的属性名」 ——
   那是 Swift 直接判为非法覆写（`overriding non-open property outside of its defining module`）、
   且会随模块传导到每个下游的坑。**下次升级 AppKitPlus 时这条要重新核对**，`NSViewController`
   已在 `CLAUDE.md` 列的必查宿主清单里。
3. **`-[NSLayerBackedViewController loadView]` 会把根视图的 `autoresizingMask` 设成
   `[.width, .height]`（`0x12`）。** 本类覆写掉 `loadView` 之后这行就没了，所以在覆写里补上，
   让「用本类」和「直接继承 `NSLayerBackedViewController`」的根视图行为一致。
   `contentViewDidChange` 的默认实现同样补。

### trait 关闭时的钩子回退：只补两个 first-appear 钩子

trait 关闭时基类是 `NSViewController`，AppKitPlus 那六个钩子一个都不存在。本提案只补其中两个：

```swift
#if !(AppKitPlus && canImport(AppKitPlus))
open func viewWillFirstAppear() {}
open func viewDidFirstAppear() {}
#endif
```

由本类的 `viewWillAppear()` / `viewDidAppear()` 各带一个 `Bool` 驱动，**顺序与 AppKitPlus 一致：
先 `super`，再判标志位，再发钩子**（实测其实现即是这个顺序）。这两个钩子控制器自己就能做到，
零外部依赖，于是子类覆写它们的代码在 trait 两侧都能编译。

另外四个不补：`viewWillFirstLayout` / `viewDidFirstLayout` / `viewUpdateLayer` /
`viewSafeAreaInsetsDidChange` 都需要视图反向通知控制器，而 `LayerBackedView` 目前只有自己的
`firstLayout()`，没有到控制器的通道 —— 补它们等于给全库视图根类加一条弱引用回调，
范围明显超出本提案。**子类覆写这四个中的任何一个，trait 关闭时会编译失败，必须自己写 `#if`。**
这条写进 `CLAUDE.md` 的「View Base Class Hierarchy」一节。

### 测试

新增 `Tests/UIFoundationTests/LayerBackedViewControllerTests.swift`，与
`LayerBackedViewBaseClassTests` 同样的「两侧都要过」写法：

- 基类金丝雀：trait 开时 `superclass()` 是 `NSLayerBackedViewController`，关时是 `NSViewController`；
- **接线金丝雀（trait 开专属）**：`loadView()` 之后 `controller.layerBackedView === controller.contentView`
  —— 该属性由 `setView:` 那条路径判定，它成立即证明覆写 `loadView` 没有把接线弄丢；
- `loadView()` 装的是 `contentView`，且 `autoresizingMask == [.width, .height]`；
- 视图加载后替换 `contentView`，`view` 跟着换；未加载时替换不触发 `contentViewDidChange`
  （`XiblessViewController` 那条「不得提前触发 `loadView`」的行为要一并守住）；
- first-appear 钩子在 trait 两侧都只发一次：连调两次 `viewWillAppear()` / `viewDidAppear()`，
  计数各为 1。

### 不做的事

- **不迁移库内既有控制器。** `ScrollViewController` / `VisualEffectViewController` 的根视图是
  `NSScrollView` / `NSVisualEffectView`，不满足 `View: LayerBackedView` 约束，本来就迁不了；
  `WelcomePanel` 的两个内部控制器能迁，但那是独立的一次行为变更，不塞进本提案。
- **不加示例 app demo。** 这是基类不是控件，没有可看的东西。
- **不动 `XiblessViewController`。** 两个类的 `contentView` 机制会有约四十行重复代码；
  Swift 没有多继承，抽公共实现要么改既有类要么引入协议 + 关联对象，都比重复四十行贵。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-05 | 创建为 Draft | 用户要求：新增 `LayerBackedViewController<View: LayerBackedView>`，继承 `NSLayerBackedViewController`，AppKitPlus 不可用时继承 `NSViewController` |
| 2026-09-05 | 覆写 `loadView()` 而不是覆写 `viewClass` 类属性 | 覆写 `viewClass` 只能指定类、拿不到 `@autoclosure` 生成器传进来的实例；实测接线在 `setView:` 上，覆写 `loadView` 不会丢钩子 |
| 2026-09-05 | trait 关闭时只补两个 first-appear 钩子，另四个不补 | 前者控制器自己就能做到、零成本；后者需要给 `LayerBackedView` 加一条到控制器的回调通道，改的是全库视图根类，范围失衡 |
| 2026-09-05 | 在覆写的 `loadView()` 里补 `autoresizingMask = [.width, .height]` | 与被覆写掉的 `-[NSLayerBackedViewController loadView]` 保持一致。代价是与 `XiblessViewController` 不一致，但那是既有类，不为对齐而改动它 |
| 2026-09-05 | 本次只加新类，不迁移库内既有控制器 | 纯增量、零回归风险；能迁的只有 `WelcomePanel` 的两个内部控制器，值得单独一次变更 |
| 2026-09-05 | 状态 Draft → Accepted | 用户批准，可以开始实现 |
| 2026-09-05 | 状态 Accepted → Implemented，落地编号 0018 | 全 trait 与默认两侧各跑一遍 `swift build` + `swift test`：默认侧 118 个用例原始退出码 0 全绿；全 trait 侧新套件 7 个用例全过，唯一失败是 `FilterResourcesTests` 的 24 个 issue —— CLI 不跑 `actool`、xcassets 查找必然返回 `nil`，`CLAUDE.md` 已记为既有现象，与本次改动无关 |
| 2026-09-05 | 不写独立指南，不新增术语表条目 | 契约（覆写 `loadView` 为何安全、四个钩子要自己写 `#if`、`autoresizingMask` 补齐）已写进 `CLAUDE.md` 的「View Base Class Hierarchy」一节；`LayerBackedViewControllerBase` 是代码标识符而非项目术语，不进 `Glossary.md` |
