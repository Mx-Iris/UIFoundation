# 0022 - GlassEffectReplicaView：在 split view 的玻璃侧栏里复刻系统玻璃

- **状态**: Implemented
- **创建日期**: 2026-09-18
- **最后更新**: 2026-09-18
- **配套文档**: 使用指南 [`GlassEffectReplica.md`](../GlassEffectReplica.md)、逆向报告 [`Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md`](../../Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md)

## 摘要

macOS 26 起 `NSSplitViewController` 给 sidebar / inspector item 套的是一个 `NSGlassEffectView`
（私有 `_variant` 17 / 18），它的颜色由窗口服务器按窗口背后的内容加一层桌面取色实时合成，随窗口位置
和激活状态漂移。放在这块玻璃里的任何 `NSColor`、任何 `NSVisualEffectView` material、甚至同配置的第二块
玻璃都只能接近它（嵌套玻璃实测 rgb(41, 41, 45) 对 rgb(40, 40, 43)）。侧栏里的导航转场需要一个和背景
完全一致的不透明页面背景，否则两页交叠时互相透出。

本提案在 `UIFoundationAppleInternal` 下新增 `GlassEffectReplicaView`：它自带一块 `NSGlassEffectView`，
从外层玻璃拷贝全部配置（含私有 variant），再把自己的 `CABackdropLayer` 塞进外层玻璃的 backdrop group。
同一组只采样一次背景，两块玻璃对同一份输入跑同一套 filter，实测在激活、非激活、移动、缩放四种状态下
逐像素一致，且不透明。配套暴露 `NSGlassEffectView` 的私有配置与 backdrop group 访问器。落在既有的
`AppleInternal` trait 下，不加新 trait，不加依赖。

## 方案

- 新增私有头 `NSGlassEffectView_Private.h`：`_variant`、`_subvariant`、`_adaptiveAppearance`、
  `_backdropGroupName`、`_groupIdentifier`。后两个只是记录它们**不**通到 CA 层，防止下一个人再试。
- `NSGlassEffectView` 扩展：`isPrivateConfigurationSupported`（三个私有 setter 都在才算）、
  `glassBackdropLayer`（跳过 content holder 子树，找 SwiftUI 建的第一个 `CABackdropLayer`）、
  `glassBackdropGroupName`、`matchGlassConfiguration(of:)`、`enclosingGlassEffectView(of:)`。
- macOS 27 新增的 `effectIsInteractive` 也在拷贝范围内，但走 KVC：`isEffectInteractive`（可选值）
  加能力探测 `isInteractiveEffectSupported`。直接写属性名的版本在 Xcode 26.x 上编译不过（该声明只在
  macOS 27 SDK 里，`#available` 补不出来），而 KVC 撞上不存在的 key 会抛 `NSUnknownKeyException`，
  Swift 接不住，所以探测是必需的而非防御性的。
- `GlassEffectReplicaView: LayerBackedView`：进窗口时解析外层玻璃并拷贝配置；分组动作用定时器按帧率
  重试（最多两秒），并在每次 `layout()`、外观变化、窗口 key 状态变化时再校验一次，因为玻璃的 layer 树
  要等 run loop 转一圈才建出来（`layoutSubtreeIfNeeded` / `displayIfNeeded` / `CATransaction.flush`
  都催不出来，已实测）。外层没有玻璃时自己的玻璃保持隐藏，等于透明。
- `GroupPinnedBackdropLayer: CABackdropLayer`：分组名不是设一次就完 —— 窗口变 key 时 SwiftUI 会把它
  自己生成的 `SwiftUI:<identity>` 写回同一个 layer（实测 485→773、505→631，系统那层不动）。所以把
  SwiftUI 建的那个 layer 用 `object_setClass` 换成这个子类（KVO 的同一招），之后所有对 `groupName` 的
  写入都被钉住的名字顶掉。子类不能有存储属性（实例不是我们分配的），钉住的名字放关联对象。
- 未经询问就取的假设：
  - variant 号从活的外层玻璃上拷，不写死 17 —— 26.x 头文件里同样有 `_variant` 与 `_glassVariant`，
    但那边的取值没有重新读过。
  - 第一帧允许"未分组"（差一个 tint 台阶）：SwiftUI 建层之前无法分组，而导航转场里 push 进来的页在
    屏幕外、pop 回来的页被上面那页盖着，启动时层还没建等于透明，三种首帧都看不见。
  - 不做 `NSGlassEffectContainerView` 路线：外层玻璃是 AppKit 的，无法把它挪进容器。
  - 不做 `CAPortalLayer` 路线：外层 RootView 的渲染里已经包含内容的 portal 副本，portal 它会把
    被盖住那一页的内容一起带进来。
- 测试：配置拷贝、外层查找、玻璃外保持隐藏、玻璃内配置一致四条同步断言；分组那条只在测试进程
  真的渲染出 backdrop layer 时断言，否则视为环境不渲染而跳过。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-18 | Created as Draft | RuntimeViewer 侧栏转场在 macOS 27 上找不到匹配背景色，用户要求把有用的私有 API 收进 `UIFoundationAppleInternal`。 |
| 2026-09-18 | Accepted | 用户在聊天中同意方向与私有 API 落点。 |
| 2026-09-18 | 放弃 `_backdropGroupName` / `_groupIdentifier` 路线 | 两者只存 ivar，SwiftUI 更新后 `CABackdropLayer.groupName` 仍是自己生成的名字（实测）。 |
| 2026-09-18 | 分组写在 `CABackdropLayer` 上，并在 `layout()` 复核 | 实测 SwiftUI 在缩放窗口、缩放玻璃本身后不会改回 groupName；复核只是为它将来重建 layer 树兜底。 |
| 2026-09-18 | 改为 isa swizzle 钉住 groupName，并监听窗口 key 通知 | 上一条在真实 app 里被推翻：窗口变 key 时 SwiftUI 把自己的名字写回同一个 layer（485→773 / 505→631）。只靠"设一次 + layout 复核"，激活窗口后复刻玻璃就退回 +2。钉住之后写入无效；通知只为 layer 被整个换掉兜底。 |
| 2026-09-18 | 用定时器而非 `CATransaction` 完成回调重试 | 完成回调在 `swift test` 进程里不派发；定时器在任何进程都跑，测试里 150 ms 内即分组成功。 |
| 2026-09-18 | 定时器跑满两秒，不因第一次找到 layer 就停 | 页面重新进窗口（导航 pop）时，`viewDidMoveToWindow` 那一刻找到的还是上次留下的旧 layer，SwiftUI 一两拍后才换成新的、未钉住的 layer（实测名字 465）；提前停就永远钉不到新的那个。 |
| 2026-09-18 | Implemented | 代码、测试、指南、逆向报告同批落地；编号待落到共享分支时分配。 |
