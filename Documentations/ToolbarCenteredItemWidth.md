# ToolbarCenteredItemWidth —— 让工具栏居中的项按工具栏宽度的比例取宽

`UIFoundationAppleInternal`（`AppleInternal` trait）下 `NSToolbar.box.preferredCenteredItemWidthRatio`：读写 AppKit
的私有属性 `preferredPrincipalItemWidthRatio`，让 `centeredItemIdentifiers` 指定的那一项按工具栏宽度的比例取宽，
窗口缩放时跟着变。Xcode 26 工具栏正中的 Activity View 就是这样占工具栏宽的 40%。决策记录见
[`Evolutions/0034-toolbar-centered-item-width-ratio.md`](Evolutions/0034-toolbar-centered-item-width-ratio.md)，逆向依据见
[`Researchs/AppKit-NSToolbar-CenteredItemWidthRatio-Internals.md`](../Researchs/AppKit-NSToolbar-CenteredItemWidthRatio-Internals.md)。

## 什么时候需要它

工具栏中间放一个随窗口变宽变窄的项（状态胶囊、地址栏一类）时。公开 API 里，项的宽度只能来自它自己视图的约束，
而约束够不到工具栏视图，没法写「工具栏宽的 40%」。

## 用法

```swift
toolbar.centeredItemIdentifiers = [.activity]
toolbar.box.preferredCenteredItemWidthRatio = 0.4

// The centered item's view: pin both a minimum and a maximum width.
let maximumWidth = activityView.widthAnchor.constraint(lessThanOrEqualToConstant: 2000)
maximumWidth.priority = NSLayoutConstraint.Priority(450)
NSLayoutConstraint.activate([
    activityView.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
    maximumWidth,
])
```

工具栏把这一项摆成 `ceil(比例 × 工具栏宽)` 那么宽，不超过它的最大宽度，也不超过左右两侧的项留下的空间，并以工具栏的
视觉中心居中。AppKit 缺这个私有属性时，读回 `nil`，赋值什么都不做。

## 必须遵守的契约

以下各条都是在 macOS 27.2 上实测的。

1. **项的视图要同时钉住最小和最大宽度。** 最小宽度决定比例什么时候作废（契约 2）；最大宽度决定作废时、或者没设
   比例时这一项有多宽。工具栏测量最大宽度时，会在优先级 200 下把视图往 10000 点拉，所以不钉最大宽度（或者钉的
   优先级不高于 200）时，这一项会占满两侧剩下的全部空间。Xcode 钉的是 ≤ 2000、优先级 450。
2. **算出的宽度小于最小宽度时，比例整个作废，不是取最小宽度。** 这一项会退回最大宽度，和没设比例一样。工具栏 1200
   点宽、最小 160 时，0.13（156 点）作废、0.14（169 点）照用。比例要配一个不会小于最小宽度的工具栏宽。
3. **赋值不会马上重排。** 已经在窗口里的工具栏，要等下一次布局（窗口缩放、项变化）才用上新比例；在把工具栏装进
   窗口之前赋值最省事，Xcode 就是这么做的。
4. **0 或负数表示没有偏好。** 新建的工具栏读回 −1。

## 坑

- **数值不是契约。** 新系统要用 `ToolbarCenteredItemWidthTests` 重新核对。早先从 26.6 反汇编读出的「小于最小宽度就取
  最小宽度」，读的是只有 Touch Bar 才走的那条路径；工具栏走的路径会把这种比例作废，与 27.2 实测一致（2026-11-05 更正，
  见调研报告第 2 节）。
- **居中项前后能变宽的项会把它挤偏。** AppKit 先把各项的最小宽度排下，余下的空间在前面一组、居中项、后面一组之间平分，
  各组最多长到自己的最大宽度；前面那组长过了居中项该在的位置，居中项就往后滑。要它不动，前后的项要么宽度固定，要么
  让视图测出 10000 点以上的最大宽度：这样的项在这一步只按最小宽度算。RuntimeViewer 的工具栏标题就是这样处理的。
- macOS 15.8 的 dyld cache 里有这个选择子，但没有反编译核实过它在 15 上的行为。
