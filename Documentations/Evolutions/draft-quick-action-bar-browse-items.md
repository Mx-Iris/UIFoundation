# Draft - QuickActionBar：搜索框旁的浏览按钮，复刻 Spotlight 的分裂动画

- **状态**: Accepted
- **创建日期**: 2026-11-13
- **最后更新**: 2026-11-13
- **实现分支 / PR**: `feature/quick-action-bar-browse-items`

## 摘要

macOS 26 起，Spotlight 的搜索框右侧有一排圆形按钮：应用、文件、操作、剪贴板。面板出现约 0.47 秒后，搜索框右端收窄，按钮像细胞分裂一样从那一端长出来，先和搜索框、彼此连成一团再分开，图标最后由模糊变清晰；输入查询、结果列表展开时，按钮又收回搜索框。QuickActionBar 现在只有搜索框。本提案给它加一组可选的浏览按钮：默认没有，宿主设置了才出现；出现与收回的动画按 macOS 27.2 的二进制逐项复刻。

## 方案

**Spotlight 的做法**（macOS 27.2 build 26B118，`SpotlightUIInternal.framework`。27.x 的 Spotlight.app 只剩外壳，界面代码在 dyld shared cache 里。地址与汇编核对写进研究报告新增的一节。）

- **几何**：按钮直径 = 收起高度 − 2，即 54；间距 10。按钮出现时，搜索框从整宽 W 收窄到 W − (54 + 10) × 按钮数，640 收到 384。第 i 个按钮（0 号紧挨搜索框）的最终圆心 x = 收窄宽度 + 10 + 27 + i × 64。收回状态下，圆心正落在收窄后搜索框的右端，缩成 0.1 倍的小点。
- **每个按钮三个开关**：
  - 位移：小点移到最终位置；没移出去之前按钮不可点。
  - 缩放：圆和图标都从 0.1 放大到 1。
  - 显现：图标的模糊半径 10 → 0，不透明度 0 → 1。
- **出现**：所有动画同一时刻启动，不错开，只有「显现」延后 0.17 秒。全部是 SwiftUI 的 `Spring(duration:bounce:)`：

  | 动的是什么 | duration / bounce |
  |---|---|
  | 融合度 100 → 0（见下） | 0.71 / 0.01 |
  | 搜索框收窄 | 0.39 / 0.39 |
  | 位移，按钮 0–3 | 0.35/0.43、0.45/0.39、0.55/0.35、0.60/0.31；第 4 个起 0.45 + 0.1i / max(0.39 − 0.04i, 0) |
  | 缩放，按钮 0–3 | 0.41/0.394、0.55/0.35、0.65/0.32、0.71/0.274；第 3 个起即 0.41 + 0.1i / max(0.394 − 0.04i, 0) |
  | 显现 | 0.49 / 0.15，延后 0.17 秒 |

- **收回**：融合度先瞬间归 0；图标以 0.20 / 0.05 隐去；同时搜索框展开、按钮缩回小点、融合度 0 → 100，这三样同用 0.41 / 0.12。
- **融合效果**：搜索框和按钮共用一块玻璃材质，形状是各自轮廓的平滑并集。「融合度」就是并集的平滑距离（点）：100 时相邻形状连成一团，0 时各自独立。按钮一边往外移、融合度一边降到 0，看起来就是一滴滴分出去。
- **触发**：面板开始出现时调出现动画；结果列表展开时收回，收起时再出现。打字本身不触发。这条路径在二进制里没有延时，录屏上搜索框却是面板出现后约 0.47 秒（60 fps 下 28–29 帧）才开始收窄；延时来自状态切换的时机，具体位置没有找到。
- **点击与键盘**：点击进入该类别的浏览模式（搜索框出现类别标记、按钮收回、结果换成该类别）；按住 ⌘ 时按钮上显示 1–4 的角标。按钮没有悬停效果，按下是系统无边框按钮的样子。

**API**

```swift
let quickActionBar = QuickActionBar()
quickActionBar.browseItems = [
    QuickActionBar.BrowseItem(title: "Applications", image: applicationsSymbol) { quickActionBar in
        quickActionBar.cancel()
        showApplications()
    },
    // …
]
quickActionBar.present(placeholderText: "Search")
```

- `BrowseItem` 有三样：`title`（tooltip 与辅助功能标签）、`image`（按 SwiftUI `.title` 的字号显示，符号图片套 `.title1` 文字样式）、`action: @MainActor (QuickActionBar) -> Void`。
- `browseItems` 默认是空数组，此时外观和行为与现在完全一样。按钮数不设上限，Spotlight 用 4 个；每个占 64 点，宽度够不够由宿主掂量。
- 面板显示期间修改 `browseItems`：按钮正显示着就先收回，再按新列表长出来。
- 点击只调 `action`，面板保持打开，要关就在里面调 `cancel()`。

**在 QuickActionBar 里怎么做**

- **玻璃结构**（macOS 26+）：现在的单块 `NSGlassEffectView` 放进一个 `NSGlassEffectContainerView`；按钮是同一容器里的圆形 `NSGlassEffectView`，排在搜索框玻璃之下。没有按钮时容器里只有搜索框一块，外观应与现在一致，实现时对照验证。
- **融合度**用容器公开的 `spacing` 表达，已逆向核实（macOS 27.2 build 26B123 的 AppKit 与 SwiftUICore）：`spacing` 原样传给 SwiftUI 的 `_GlassEffectContainer(smoothness:)`，最后落到的 `PathSet.smoothness`，正是 Spotlight 经 `_ShapeSet(smoothness:)` 设的那个值。容器在下一次 `layout()` 里同步把它交给 SwiftUI，所以逐帧改就是逐帧生效。只用公开 API 就能原样复刻。
- **动画驱动**：逐帧设 frame，不用 Core Animation，用 display link 跟屏幕刷新同步（结果列表展开那套 120 Hz 计时器不动）。逆向看到三个坑：
  - 容器每次 `layout()` 按成员视图的 frame 和 `cornerRadius` 重建形状，不读图层变换。所以圆的缩放要改 frame 和 `cornerRadius` 来表达。
  - 只改 `cornerRadius` 不会让容器重新布局，每帧要顺手标一次 `needsLayout`。
  - 不能在开了隐式动画的上下文里设 frame 或 `spacing`，否则 AppKit 自己也去插值，和逐帧驱动打架。
  - 另外，搜索框玻璃和按钮玻璃的样式设置必须完全一致，不然会被分进不同的组，不融合。
- **弹簧**：`ResizeSpring` 推广成一个通用的闭式弹簧（duration、bounce、初速度）。中途换目标时从当前位置和速度接着走，SwiftUI 的弹簧被打断时就是这样衔接的。`ResizeSpring` 改由它表达，行为不变，现有测试照旧要过。
- **图标**：模糊用 Core Image 的 `CIGaussianBlur`（公开 API，图层开 `layerUsesCoreImageFilters`），不透明度与缩放直接设在图标图层上。
- **显示条件**：有按钮、查询为空、结果列表收起、面板出现已满 0.47 秒、不在关闭中，五条同时成立才显示。在搜索结果更新、0.47 秒到点、`browseItems` 改变时重新判断，变了就跑出现或收回动画。和 Spotlight 一样，打字不直接触发，结果回来、列表展开那一刻才收回；Esc 清空查询后，列表收起和按钮长回同时发生。
- **结果列表的宽度**：现在钉死成 `width`（required），搜索框收窄时会冲突，改成随搜索框宽度走。
- 打开「减少动态效果」时不做动画，直接切到终态（Spotlight 自己也有一个关掉这组动画的开关）。

**没有问就采用的假设**

- 只在 macOS 26 及以上显示按钮，更早的系统忽略 `browseItems`：Spotlight 26 才有这排按钮，更早的系统没有玻璃，做不出融合。
- 不做键盘操作（Tab、方向键、⌘ 数字键与角标），只支持鼠标点击和辅助功能；结果列表已有的 ⌘1–⌘9 不受影响。以后要加可以单独做，不影响本提案的结构。
- 类型叫 `BrowseItem`，沿用 Spotlight 内部的叫法（browse button）。
- 0.47 秒的延时取自录屏；二进制里找到延时来源后再改。
- 不给 `SpotlightPanel` 加同样的按钮。

**测试**

- 弹簧：与 SwiftUI `Spring(duration:bounce:)` 的 `value`、`velocity` 在多个时间点比对，含非零初速度。
- 几何：W = 640、4 个按钮时收窄宽度 384，圆心 421、485、549、613，收回时圆心 384；1–5 个按钮的通式。
- 编排：每个按钮取到的弹簧参数（含第 4 个以后的公式），显现延后 0.17 秒。
- 显示条件：空查询时出现；结果展开时收回；Esc 清空后再出现；没有按钮时不建按钮视图；关闭过程中不出现。
- 点击：按钮的 `performClick` 调到 `action`；按钮中心的 hit-test 落在按钮上（macOS 27 SDK 下，挡在前面的兄弟视图会让点击静默失灵）。
- 融合、模糊这些外观只能目测，写进 demo 的人工检查清单。

**文档与 demo**

- `Documentations/QuickActionBar.md`：公开 API 表加一行，新增一节讲浏览按钮，实现说明里记各常数与出处。
- `Researchs/Spotlight-Panel-Internals.md`：新增「27.2 的浏览按钮」一节（几何、编排、触发、融合的实现、地址）。
- `AGENTS.md` 的 QuickActionBar 一条按需补陷阱；提案索引加一行。`uifoundation-widgets` skill 没写到 QuickActionBar，插件版本不动。
- 示例 App 的 QuickActionBar 演示加一个 0–4 个浏览按钮的选项，用 Spotlight 自己的四个符号（`appstore`、`folder`、`app.2.stack.3d`、`document.on.document`）；点击写进事件日志，人工检查清单加上动画几条。

**下游影响**：XCOrganizer、StarLight、RuntimeViewer 不设 `browseItems` 就不会出现按钮，源码兼容。但 macOS 26+ 上搜索框的玻璃换进了容器，外观应不变，需要目测确认。

**落地步骤**（每步都能单独构建、相关测试通过，各提交一次）

1. 通用弹簧，`ResizeSpring` 改由它表达，弹簧测试。
2. 玻璃改进容器；没有按钮时外观不变。
3. 浏览按钮：API、几何、编排、显示条件、绘制，以及上面列的测试。
4. 示例 App 演示。
5. 文档。
6. 验证：全 trait 构建、整套测试、示例 App 构建；动画由人目测。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-13 | Created as Draft | 要在 QuickActionBar 上复刻 macOS 26 起 Spotlight 搜索框旁的浏览按钮及其动画，默认不显示，设置了才出现 |
| 2026-11-13 | 融合用 `NSGlassEffectContainerView.spacing` 逐帧驱动 | 逆向确认它就是 Spotlight 设的那个并集平滑距离，公开 API 足够，不必进 `AppleInternal` |
| 2026-11-13 | 点击只调宿主的 `action`，不做浏览模式 | 用户选定。浏览模式（选中态、类别标记、搜索带上当前类别、Esc 先退出类别）要多一层 API，工作量约翻倍，留待以后单独提 |
| 2026-11-13 | 用户批准，开始实现 | 其余按本提案的方案与假设 |
