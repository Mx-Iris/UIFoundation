# GlassEffectReplica —— 在系统玻璃里复刻一块一模一样的玻璃

`UIFoundationAppleInternal`（`AppleInternal` trait）下的 `GlassEffectReplicaView` 是一块不透明的视图，
放进 macOS 26+ `NSSplitViewController` 给 sidebar / inspector item 套的那块 `NSGlassEffectView` 里，
渲染结果与周围逐像素一致。典型用途是侧栏里的导航转场：两页各自带一块复刻玻璃，滑动交叠时互不透出，
而停下来时又看不出页面和侧栏的边界。决策记录见
[`Evolutions/0022-glass-effect-replica-view.md`](Evolutions/0022-glass-effect-replica-view.md)，
逆向依据见 [`Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md`](../Researchs/AppKit-NSGlassEffectView-SplitViewItem-Internals.md)。

## 用法

```swift
final class SidebarPageView: NSView {
    private let backgroundView = GlassEffectReplicaView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(backgroundView)               // 先加，它要在最底下
        backgroundView.frame = bounds
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(outlineScrollView)            // 内容都在它上面
    }
}
```

不需要告诉它外层玻璃是哪块：进窗口时它沿 superview 链找最近的 `NSGlassEffectView`，拷贝配置，
然后加入那块玻璃的 backdrop group。`enclosingGlassEffectView` 与 `isSharingBackdropGroup` 只读，用来诊断。

它为什么能一样：同一个 Core Animation backdrop group 只采样一次窗口背后的内容，组里每一层对同一份
输入跑同一套 filter。而单纯嵌套一块同配置的玻璃会去采样外层玻璃的输出，再叠一次桌面取色，
实测差 +1/+1/+2。

## 宿主必须遵守的契约

1. **它必须落在某块 `NSGlassEffectView` 的内容里。** 外面没有玻璃时它保持透明，什么也不画，也不报错。
   如果一个窗口在不同系统上有时有玻璃有时没有，这正是想要的行为。
2. **第一帧不保证一致。** SwiftUI 要等 run loop 转一圈才建出玻璃的 layer 树，而且视图每次重新进入窗口
   都会重建一遍（导航 pop 回来的页面实测拿到的是新 layer、新名字）。所以复刻玻璃在进窗口和窗口 key 状态
   变化后按帧率轮询两秒、每一拍都钉住当前的 layer，之后每次 `layout()` 再复核。在钉住之前它是一块普通的
   嵌套玻璃，差一个 tint 台阶。从屏幕外推进来的页、被上面那页盖着的页都看不到这一帧；一块直接在可见位置
   `addSubview` 出来的复刻玻璃会闪一下。
3. **内容加在它上面。** 复刻玻璃是最底下的子视图，`addSubview(_:)` 会保持这一点；
   `addSubview(_:positioned: .below, relativeTo: nil)` 会把东西塞到玻璃下面，被完全盖住。
4. **全部是私有 API。** `_variant` / `_subvariant` / `_adaptiveAppearance` 与 `CABackdropLayer.groupName`。
   新系统上私有 setter 消失时 `NSGlassEffectView.isPrivateConfigurationSupported` 变为 false，
   复刻玻璃仍会分组但拷不到 variant；侧栏突然"不对"时先看这两个值。
5. **macOS 27 的 `effectIsInteractive` 是用 KVC 读写的，不要"顺手"改成直接写属性。**
   拷贝配置时这一项走的是 `NSGlassEffectView.isEffectInteractive`（可选值，`nil` 表示这个系统没有），
   底下是 `value(forKey:)` / `setValue(_:forKey:)`。原因是这个属性只在 macOS 27 SDK 的头文件里有声明，
   直接写出名字的代码在 Xcode 26.x 上**编译不过** —— `if #available(macOS 27.0, *)` 管的是运行时版本，
   变不出 SDK 里没有的声明。代价是编译器不再替你检查名字，所以读写前必须先问
   `NSGlassEffectView.isInteractiveEffectSupported`：KVC 撞上类里没有的 key 会抛 `NSUnknownKeyException`，
   而 Objective-C 异常在 Swift 里接不住，直接终止进程（本机 macOS 26.5 实测）。
6. **分组名是钉在 layer 上的，不是设一次。** 窗口变 key 时 SwiftUI 会把它自己的名字写回同一个
   `CABackdropLayer`（实测），所以复刻玻璃把那个 layer 的类换成 `GroupPinnedBackdropLayer`，之后的写入
   全部被钉住的名字顶掉。如果你自己去读复刻玻璃的 `glassBackdropLayer`，看到类名不是 `CABackdropLayer`
   是正常的；不要自己改它的 `groupName`，改了也不生效。
7. **不要指望它在 `swift test` 里渲染。** 测试进程不一定跑 Core Animation 提交，分组那一步观测不到；
   `GlassEffectReplicaViewTests` 里那条断言只在外层玻璃真的建出 backdrop layer 时才检查
   （本机实测是会渲染的，150 ms 内分组成功）。

## 已知偏离

- variant 号从活的外层玻璃拷贝，没有写死。sidebar 是 17（`.abuttedSidebar`，注意不是叫 `.sidebar`
  的 16）、inspector 是 18（`.inspector`），`_adaptiveAppearance` 是 `.off`（关掉的是按背景明暗切换
  浅色 / 深色，与窗口 key 状态无关）。七个私有设置的取值表在 macOS 26.6 与 27.0 上逐项核对过，见私有头
  与 [`Researchs/AppKit-NSGlassEffectView-PrivateConfiguration.md`](../Researchs/AppKit-NSGlassEffectView-PrivateConfiguration.md)。
  编号仍然不是契约，所以照旧拷贝而不写死。
- 外层玻璃的 `contentView` 里那些被 `CAPortalLayer` 重画的内容（见逆向报告第 3 节）不受影响：
  复刻玻璃只是内容的一部分，照样被 portal 进外层的渲染。
