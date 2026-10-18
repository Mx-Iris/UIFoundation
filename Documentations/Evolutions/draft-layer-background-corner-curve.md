# Draft - LayerBackgroundRenderer：连续曲率圆角（cornerCurve）

- **状态**: In Progress
- **作者**: JH
- **创建日期**: 2026-10-18
- **最后更新**: 2026-10-18
- **实现分支 / PR**: `feature/layer-background-corner-curve`

## 摘要

`LayerBackgroundRenderer`（以及经 `LayerBackgroundProviding` 转发它的 `LayerBackedView`、`LayerBackedTableCellView` 等）只能画普通圆弧圆角，画不出系统控件和 SwiftUI `RoundedRectangle(style: .continuous)` 用的那种连续曲率圆角（转角从直边上更早开始弯，过渡更平滑）。新增 `cornerCurve: CALayerCornerCurve`，默认 `.circular`，现有使用方行为不变；设成 `.continuous` 时填充和完整描边都跟着这条曲线走。直接起因是 PrivateSymbols 要对齐 SF Symbols 27.0 的网格格子：官方格子是 SwiftUI 画的 `.continuous` 圆角加一圈压在边线中间的描边。

## 方案

- **API**：`LayerBackgroundRenderer` 新增 `public var cornerCurve: CALayerCornerCurve = .circular`（改动时 `setNeedsDisplay()`，与其余属性一致），`LayerBackgroundProviding` 加同名转发属性。`updateLayer()` 把它写到宿主图层的 `cornerCurve` 上，填充、`masksToBounds` 裁剪和不带 `shadowPath` 的阴影因此都跟着走。
- **完整描边（`borderPositions == .all` 且 `cornerRadius > 0`）在 `.continuous` 下改由描边子图层的原生边框来画**：设它的 `borderWidth` / `borderColor` / `cornerRadius` / `cornerCurve`，不再给它路径。原因是 Core Animation 没有公开接口给出连续曲率圆角的路径，`NSBezierPath` 也只有普通圆弧，照旧描路径的话描边是圆弧、填充是连续曲率，两者在转角处会分开。原生边框跟随 `cornerCurve`，和填充用的是同一套曲线。
  - `borderLocation` 与 `borderInsets` 的语义不变，换算成子图层的 frame 与半径：先按 `borderInsets` 内缩，再按位置外扩（`.inside` 不扩，`.center` 扩半个线宽，`.outside` 扩一个线宽），半径同步加上外扩量。三种位置下描边可见外缘与现有路径描边的位置一致。
- **`.circular` 一行不改**，继续走原来的路径描边。部分边框（`borderPositions` 不是 `.all`）也继续走路径，只把子图层上的圆角遮罩换成同一条曲线。
- **不加 trait、不加依赖、不引入 SwiftUI**。SwiftUI 的 `Path(roundedRect:cornerRadius:style:)` 能直接给出连续曲率路径，但本库是 Swift 5 语言模式且没开 `MemberImportVisibility`，`UIFoundationAppKit` 只要有一个文件 import SwiftUI，它的扩展成员就会在整个模块里可见，容易和本库的 `Label`、`Button` 等同名类型和扩展打架。目前只有 `UIFoundationSettingsUI` import SwiftUI。
- **AppKitPlus 撞名检查**：它的公开头文件里 `NSView` 没有 `cornerCurve`，不会遮住转发属性。唯一同名的是私有类 `_NSSystemBackgroundStrokeView.cornerCurve`，不在任何使用方的继承链上。
- **测试**（`UIFoundationTests/LayerBackgroundCornerCurveTests.swift`，全部比渲染出来的像素，不比图层属性）：
  1. 连续曲率确实改变了填充的转角：半径 20 时最上一行第一个被覆盖的像素比圆弧晚 5 个（2×）。
  2. 两种曲线下，内侧描边的内缘逐行落在「内缩一个线宽、半径小一个线宽」的填充起点上。实现前连续曲率这一例失败（描边内缘早了 4 个像素），接上原生边框后通过；圆弧一例前后都通过。
  3. 两种曲线 × 三种 `borderLocation`，4pt 描边在中间一行的左缘分别落在视图左缘的 0 / −2 / −4pt。
- **文档**：`AGENTS.md` 的 `LayerBackgroundRenderer` 一节补上 `cornerCurve`、「连续曲率的完整描边用原生边框」这条实现差异，以及下面两条实测（圆角宿主会被系统打开裁剪；`render(in:)` 画不裁剪的圆角背景会画偏）。`uifoundation-widgets` skill 没有写到这组属性，不用改，插件版本号不动。
- **下游影响**：RuntimeViewer、MachOKitUI 不受影响，默认值仍是 `.circular`。PrivateSymbols 的网格格子会改用 `.continuous`，并从当前钉住的 `0.38.0` 一次升到新版本（中间有 `0.39.0` 和 `main` 上未发布的 5 个提交，升级后要在那边完整构建、跑测试）。
- **发布**：合进 `main` 后打 `0.40.0` tag 并推送。这是新增 API，按惯例升次版本号；`main` 上 `0.39.0` 之后的提交会一起发出去。
- **落地步骤**：改动小，一步完成——`cornerCurve` 的实现、渲染测试与 `AGENTS.md` 进同一个提交；做完跑一遍全 trait 构建和整套测试。（已完成）
- **后续（不在本提案内）**：macOS 27.2 上，宿主图层的 `cornerRadius` 一变，AppKit 就把视图的 `clipsToBounds` 打开（同值重设不会；之后手动关掉能保住），而 `updateLayer()` 紧接着把 `clipsToBounds` 抄进 `masksToBounds`。结果是任何带圆角的 `LayerBackedView` 都会裁掉子视图和描边子图层露在边界外的部分，`.center` / `.outside` 描边只剩里面一半。这与曲线无关，圆弧也一样，而且是系统版本带来的行为变化。要不要在渲染器里保住使用方原本的 `clipsToBounds`，得单独评估：现在的使用方在 macOS 27 上可能已经依赖了这层裁剪。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-10-18 | Created as Draft | 用户：「给 UIFoundation 加我们再用」。PrivateSymbols 要对齐 SF Symbols 27.0 网格格子的连续曲率圆角，而本库的描边只能画普通圆弧 |
| 2026-10-18 | 不用 `NSViewCornerConfiguration` | 它只负责算每个角的半径（固定值、跟外层容器同心、胶囊形），不管曲线形状，也不替视图画（`cornerConfiguration` 只读，靠子类覆写，再在 `viewDidChangeEffectiveCornerRadii()` 里自己应用），而且 macOS 27 才有。官方格子也没用它：SF Symbols 27.0 的三个二进制都没有引用它，圆角来自 SwiftUI 的 `RoundedRectangle(style: .continuous)` |
| 2026-10-18 | 连续曲率的完整描边用子图层原生边框，不描路径 | Core Animation 不提供连续曲率路径；原生边框跟随 `cornerCurve`，与填充天然是同一条曲线。`.circular` 保留原路径实现，避免影响现有使用方 |
| 2026-10-18 | 不 import SwiftUI 取路径 | Swift 5 模式下扩展成员会漏到整个 `UIFoundationAppKit`，与本库同名类型冲突的风险大于收益 |
| 2026-10-18 | 用户批准，开始实现 | 经 `/accept-proposal`；实现放在 `feature/layer-background-corner-curve`。合并与打 tag 留给收尾那一步 |
| 2026-10-18 | 描边测试改比内缘，并在裁剪状态下比；删掉「`.circular` 下描边仍是路径」那条 | 第一版只比外缘，在描边还是圆弧时就通过了：AppKit 已把宿主的裁剪打开，宿主的连续曲率遮罩替描边修掉了外缘，露馅的只有内缘。「仍是路径」是在断言实现方式，而圆弧一例的像素比较已经守住了行为 |
| 2026-10-18 | 参考用的填充一律在裁剪状态下渲染 | `CALayer.render(in:)` 画不裁剪图层的圆角背景会往外偏多达 1.5pt（圆弧半径 20 时最上一行从第 31 列开始，几何上和裁剪时都是第 34 列），拿它当参考会把 2 个像素的误差算进来 |
| 2026-10-18 | 系统打开裁剪这件事记为后续，不在本分支处理 | 它与曲线无关，而且改它会改变现有使用方在 macOS 27 上的样子，超出本提案范围 |
| 2026-10-18 | 实现完成，待合并 | 验证（macOS 27.2，退出码为准）：默认配置整套 `swift test` 0（217 个测试）；全 trait `swift build` 0（AppKitPlus 按锁定的 0.6.0；中途一次误解析到 0.17.0，也编过）；全 trait 整套 `swift test` 1。后者的失败逐个核对过：`QuickActionBarPresentationTests`「Resuming a dismissal keeps the existing presentation alive」在 `main` 上同样失败，是基线问题；`MainMenuTests`「rewriting a special menu through the builder keeps it wired」只在整套并行时失败，单独跑全 trait 通过，断言的窗口菜单内容受同时开着的窗口影响；第一次全 trait 运行进程中途 SIGSEGV 退出过一次，之后两次（含 `main`）都没再出现。三者都与本改动无关。不需要另写使用指南：`AGENTS.md` 的这一节就是这组 API 的说明；没有新术语 |
