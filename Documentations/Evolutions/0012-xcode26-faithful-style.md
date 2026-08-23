# 0012 - WelcomePanel `.xcode26`：按实测重做成真正的 Xcode 26 复刻

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-23
- **最后更新**: 2026-08-23
- **所属愿景**: 无
- **关联提案**: [0011](0011-welcome-panel.md)（把 WelcomeKit 搬进本库）
- **实现分支 / PR**: main（与本提案同批次提交）
- **配套文档**: 逆向报告 [`Researchs/Xcode26-WelcomeWindow-Internals.md`](../../Researchs/Xcode26-WelcomeWindow-Internals.md)；落地时同批更新使用指南 [`Documentations/WelcomePanel.md`](../WelcomePanel.md)

## 摘要

`.xcode26` 目前不是 Xcode 26 的复刻 —— 它是 `.xcode15` 的几何去掉毛玻璃背景，是上游作者加样式时的
占位实现（提案 0011 已记录它带着两处漏判搬了进来）。现在有了 Xcode 26 欢迎窗口的 view hierarchy
抓包与逐项实测，本提案按实测把 `.xcode26` 整支重做：圆角 8 → **20**，两侧都换成
`NSVisualEffectView(.fullScreenUI)`，标题 30 bold → **36 bold**，操作项圆角 8 → **18（胶囊）**，
行内间距、首行位置、关闭按钮位置、图标辉光全部对齐实测值，并**顺带修掉 0011 留下的两处漏判**
（关闭按钮无图标、点按无高亮）—— 这一支反正要重写。

`.xcode14` 与 `.xcode15` 一行不动。公开 API 形状不变，改的全是观感。

## 动机

- **`.xcode26` 名不副实。** 它和 `.xcode15` 共用全部几何与配色，唯一区别是不套
  `NSVisualEffectView`。也就是说选 `.xcode26` 得到的既不是 Xcode 15 也不是 Xcode 26，而是一个
  「Xcode 15 去掉毛玻璃」的第三种东西。它作为占位存在是合理的（当时没有实测依据），现在依据有了。
- **差得不是一点点，是每一项都差。** 实测下来窗口圆角差 12 pt、标题字号差 6 pt、操作项圆角差 10 pt、
  两侧材质完全没有、图标辉光缺失、首行位置差 9 pt。这些不是「像但不够精细」，是叠加起来会让人一眼
  看出不是同一个窗口。
- **两处漏判正好在这一支上。** 0011 决定原样搬，代价是 `.xcode26` 的关闭按钮没有图标、操作项点按
  没有反馈。既然这一支要整个重写，继续保留这两个缺口就没有意义了 —— 保真的对象应该是 Xcode 26，
  不是 WelcomeKit 里那个半成品。

## 前期调研

完整逐项实测见逆向报告
[`Researchs/Xcode26-WelcomeWindow-Internals.md`](../../Researchs/Xcode26-WelcomeWindow-Internals.md)。
本节只摘对方案有决定性影响的四条。

### ① 整窗是一个 SwiftUI 视图，但不需要照搬结构

`IDEKit.WelcomeWindow`（borderless，740 × 460）的 content view 是单个
`NSHostingView<IDEKit.WelcomeView<IDEWelcomeViewModel>>`。视图树里**没有任何
`NSVisualEffectView`，也没有 `NSGlassEffectView`**：两侧的半透明由裸 `CABackdropLayer` 提供，文字
全部由 SwiftUI 光栅化进 A8 backing store。所以结构上没有可抄的东西，只能按测量值重建。

### ② 材质就是 `.fullScreenUI`，**不需要私有 API**（本提案最关键的一条）

从抓包的 `encodedPresentationLayer` 解出的滤镜链，与现场实例化全部 14 个
`NSVisualEffectView.Material` 逐一比对，只有一个全项命中：

| | 抓包实测 | `.fullScreenUI` | `.hudWindow` | `.underWindowBackground` |
|---|---|---|---|---|
| backdrop 底色 | 0.1569 @ **0.5** | 0.1569 @ **0.5** ✓ | 0.1569 @ 0.4 | 0.1569 @ 0.8 |
| colorSaturate | **1.8** | **1.8** ✓ | 1.6 | 2.4 |
| lighten 层 | **0.095** | **0.095** ✓ | 0.08 | 0.14 |
| chameleon | 0.05 | 0.05 ✓ | 0.05 | 0.05 |
| gaussianBlur | 60 | 30 | 30 | 30 |

模糊半径的 2 倍差是**单位差不是配方差**：抓包读的是 presentation layer 的设备像素值，那台机器
`backingScaleFactor = 2`，60 设备像素 = 30 pt。因此本提案**不引入 `UIFoundationAppleInternal`
依赖**，`WelcomePanel` trait 保持纯公开 AppKit。

### ③ 字号靠反推，两项是硬命中

文字没有字体信息留下，改用「哪个字号能同时复现测得的宽和高」反推：

- **标题**：measured 107 × 43。regular 39 pt / medium 37.9 / semibold 37.1 的行高分别是 46 / 45 / 44，
  全部对不上；**bold 36.0 pt** 宽 106.75、行高 43，宽高双中。
- **操作项文字**：三个字符串共用一个字体是强约束。**semibold 13 pt** 给出 133.56 / 140.41 / 147.32
  （实测 134 / 140.5 / 147.5），且行高 16 吻合 —— 与现有实现一致，这一项**不用改**。
- **版本号**：字符串未知，"Version 26.0" 在 13 pt regular 下为 75.62 × 16，与实测 76 × 16 相符，
  按「likely 而非 proven」处理，也**不用改**。

### ④ 浅色抓包：几何完全不变，只有配色变

作者随后提供了浅色抓包（同一个 Xcode 进程，切外观后再抓一次）。逐帧比对的结论很干净：

- **所有几何一字不差** —— 窗口、图标、标题层、三个药丸、关闭按钮、列表行与单元格，两份抓包的
  frame 完全相同。**几何与外观无关**，上面每个尺寸等于被测了两遍。
- **材质在浅色下同样命中 `.fullScreenUI`**：backdrop rgba(0.9646, 0.9648, 0.9646, 0.48)、
  `darkenBlendMode` + rgba(0.96, 0.96, 0.96, 1)、chameleon 0.05 —— 与现场实例化的 `.fullScreenUI`
  在 Aqua 下逐位一致。混合模式随外观自动翻转（深 lighten / 浅 darken）是 `NSVisualEffectView`
  自己的事，复刻方不用管。
- **图标辉光只在深色下存在** —— 浅色抓包里根本没有投影层。这恰好就是 WelcomeKit 原本的写法
  （`isDark ? appIconImageShadow : nil`），说明那个写法是对的，把辉光做成 `.xcode26` 默认值后
  会自动继承这个行为，**不需要额外处理**。

仍未解决的一条：深色下右窗格叠加色是 (48, 44, 47)，比中性灰偏紫 4/255，匹配不上任何系统色；
浅色下却是干净的纯白。是壁纸经 chameleon 染上去的还是设计如此，两份同壁纸抓包判不出来。偏差不到
2%，按实测值写死即可。

## 提议方案

把 `.xcode26` 的每一项对齐实测值，改动集中在 `WelcomePanel+Style.swift` 的样式表，加上四处需要
新增样式开关的调用点。

1. **两侧都套 `NSVisualEffectView(.fullScreenUI, .behindWindow)`**，各自叠一层平铺色：
   左 `windowBackgroundColor`（深 @ 0.75 / 浅 @ 0.9），右深 rgba(0.1882, 0.1725, 0.1843) @ 0.5 /
   浅白 @ 0.6。
   结构上 `.xcode26` 从此与 `.xcode15` 同形（`view = visualEffectView`，内容视图叠在上面），
   只是材质与叠加色不同。
2. **窗口圆角 8 → 20**（`clipsToBounds` 已在 0011 落地时处理好，只改数值）。
3. **标题字号 30 bold → 36 bold**（仅 `.xcode26`；`.xcode15` 保持 30 bold）。
4. **操作项**：圆角 8 → 18（胶囊）、底色改白 @ 0.032、行内图标中心距行首 19.5、文字左边距 38、
   首行 y = 287（表格底部内边距 50 → 41）。
5. **图标辉光变成 `.xcode26` 的默认值**（宿主未指定 `appIconImageShadow` 时）：色
   rgba(0.0902, 0.4157, 0.8784, 0.55)、radius 50、offset (0, 2)。现有代码已经按
   `isDark ? shadow : nil` 施加，与实测的「浅色无辉光」一致，无需额外分支。
6. **关闭按钮位置 12 → 13**，并**修掉两处漏判**：`HoverButton` 与 `ActionCellView` 里写死的
   `style == .xcode15` 改为「非 `.xcode14`」。
7. ~~**最近项目列表**：行首顶部内边距 10、单元格左右缩进 16。~~ **落地时证否 —— 无需改动**：
   实测这两个数是 `NSTableView.Style.sourceList` 自带的（AppKit 自己加 10 pt 首行内边距与 16 pt
   单元格缩进），我们本来就用 `.sourceList`，所以右侧列表已经与 Xcode 一致。顺带测出
   `intercellSpacing.width` 在视图型表格里**完全被忽略**，现有那句 `(10, 0)` 横向是空操作。
   改为加一条断言钉住 `.sourceList`，换样式会让两个内边距同时静默消失。
8. 同批更新：使用指南的样式表与「已知问题」一节（两处缺口不再是缺口）、两个 canary 测试
   （改成断言修复后的行为）、几何测试的 `.xcode26` 期望值。

### 非目标

- **不动 `.xcode14` 与 `.xcode15`**。它们各自对着自己那一代 Xcode，本次的实测依据只覆盖 26。
- **不引入私有 API**。`.fullScreenUI` 已经逐位一致（调研 ②），不用 `CABackdropLayer` 自己搭。
- **不引入 `NSGlassEffectView`**。实测证明 Xcode 26 自己也没用 Liquid Glass 玻璃视图，用了反而不像。
- **不改公开 API 形状**。`Style` 不加新 case，`Configuration` 不加新字段；新增的全是 `internal`
  样式属性。
- **不做整行通栏点击区**。Xcode 的操作项点击区是 460 pt 通栏（药丸只有 348），我们的表格左右各缩
  56 pt，点击区等于药丸。视觉完全一致，只有「点药丸左边 20 pt 的空白」行为不同 —— 记为已知偏离，
  不为它重排单元格。
- **不追右窗格叠加色偏紫的成因**。按实测值写死（偏差 <2%），在指南里注明。

## 详细设计

### 样式表新增的 internal 属性（`WelcomePanel+Style.swift`）

```swift
extension WelcomePanelController.Style {
    /// The backdrop behind the left pane; `nil` means the pane paints itself flat (xcode14).
    var welcomeViewMaterial: NSVisualEffectView.Material? { get }
    /// The backdrop behind the recent-project list.
    var projectViewMaterial: NSVisualEffectView.Material { get }
    /// Flat colour laid over the left pane's backdrop.
    var welcomeViewOverlayColor: NSColor { get }      // 取代 welcomeViewBackgroundColor 的角色
    var actionCellCornerRadius: CGFloat { get }        // 8 / 8 / 18
    var actionCellBackgroundColor: NSColor { get }     // 从 ActionCellView 移上来，按样式取值
    var actionCellIconCenterOffset: CGFloat { get }    // 行首到图标中心：11.5+12 / 19.5
    var actionCellLabelLeading: CGFloat { get }        // 46.5 / 38
    var actionTableViewBottomSpacing: CGFloat { get }  // 50 / 41
    var closeButtonInset: CGFloat { get }              // 12 / 13
    var appIconDefaultShadow: NSShadow? { get }        // 仅 xcode26 非 nil
    var projectListTopInset: CGFloat { get }           // 0 / 10
    var projectCellHorizontalInset: CGFloat { get }    // 0 / 16
}
```

### 逐项对照（深浅两色均已实测）

| 项 | 现在 | 改为 |
|---|---|---|
| 窗口圆角 | 8 | **20** |
| 左窗格 | 无材质，`black @ 0.2`（深）/ `white`（浅） | `.fullScreenUI` + `windowBackgroundColor`，深 @ 0.75 / 浅 @ 0.9 |
| 右窗格 | `.underWindowBackground` + `clear`（深）/ `white @ 0.6`（浅） | `.fullScreenUI` + 深 rgba(0.1882, 0.1725, 0.1843) @ 0.5 / 浅白 @ 0.6 |
| 标题字号 | 30 bold | **36 bold** |
| 版本字号 | 13 regular | 不变 ✓ |
| 操作项字号 | 13 semibold | 不变 ✓ |
| 操作项尺寸 | 348 × 36，间距 8 | 不变 ✓ |
| 操作项圆角 | 8 | **18** |
| 操作项底色 | 白 3% / 黑 5% | 深 **白 3.2%** / 浅 **rgba(0.3725) @ 9.6%** |
| 行内图标 | 左缩进 11.5，宽 24 | 中心距行首 **19.5** |
| 行内文字 | 左边距 46.5 | **38** |
| 首行 y | 278 | **287**（表格底部内边距 41） |
| 图标辉光 | 宿主传才有 | **默认带**（仅深色，可被 `appIconImageShadow` 覆盖） |
| 关闭按钮 | (12, 12) | **(13, 13)**，且**有图标了** |
| 点按高亮 | 无 | **有** |
| 列表行高 | 44 | 不变 ✓ |
| 列表首行内边距 | 0 | **10** |
| 列表单元格缩进 | `intercellSpacing` 10 | **左右各 16** |

## 替代方案考量

- **新增 `.xcode26Faithful`，保留现有 `.xcode26`。** 已评估并否决（作者决策）。理由：现有
  `.xcode26` 不对应任何真实 Xcode 版本，保留它等于长期维护两个都叫「26」、长得像但都不对的样式，
  以后每次改都要先想「改哪个」。
- **用 `UIFoundationAppleInternal` 的 `CABackdropLayer` 自己搭材质。** 否 —— 调研 ② 证明公开的
  `.fullScreenUI` 已经逐位一致，用私有 API 只会让这个 trait 变得不能上架。
- **用 `NSGlassEffectView`（macOS 26）做 Liquid Glass。** 否 —— 实测 Xcode 26 自己没用；用了就不是
  复刻而是二次创作。
- **只改配色不改几何。** 否 —— 差异是叠加的，圆角 8 vs 20 和标题 30 vs 36 是一眼可见的两项，
  改一半等于没改。

## 影响

### 源码兼容性（source compatibility）

**API 层面纯兼容** —— 不加不减不改任何公开符号，`Style` 不加 case，`Configuration` 不加字段。
现有调用点一行都不用动。

**观感层面是破坏性的** —— 任何已经在用 `.xcode26` 的宿主，升级后窗口会明显变样（更圆、更亮、
标题更大、多一层毛玻璃）。这正是本提案的目的，但必须在 CHANGELOG / 指南里写清楚，不能让人以为是
回归。有意保持旧观感的宿主没有退路（不保留旧样式是上一节的明确决策）—— 考虑到这个 trait 上周才
落地、默认关闭，实际受影响的宿主预计为零。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- **本仓库**：只动 `UIFoundationAppKit` 的 `WelcomePanel/` 目录、`WelcomePanelTests`、示例 demo 与文档。
- **RuntimeViewer / MachOKitUI / PrivateSymbols**：零影响，`WelcomePanel` trait 默认关闭且它们都没开。

### 文档与示例

- 使用指南 `Documentations/WelcomePanel.md`：样式表整段重写；「已知问题」删掉两处 `.xcode26` 缺口
  （改为「已修复，见 0012」），新增「浅色模式配色未实测」与「点击区不通栏」两条已知偏离；
  「与原库的差异」新增一节说明 `.xcode26` 已不再是 WelcomeKit 的那一支。
- 根 `AGENTS.md` 的 Welcome Panel 章节：更新「两处 `.xcode26` 缺口故意保留」的说法，改为指向 0012。
- 逆向报告已落盘：`Researchs/Xcode26-WelcomeWindow-Internals.md`。
- 示例 demo 的人工验收清单：删掉「确认两处缺口」，改为「对着 Xcode 26 真窗口比圆角、材质、字号」。

## API 演进与废弃策略

- 无被替代的公开 API，不产生任何 `@available(*, deprecated)` 标注。
- 观感变更不需要 semver major（本库尚未 1.0，且该 trait 上周才引入、默认关闭）；建议在 release note
  里单列一条。

## 落地步骤

0. ~~【阻塞】拿到浅色模式抓包~~ —— **已完成**（2026-08-23）：浅色抓包已量完，值见调研 ④，
   阻塞解除。
1. 样式表：新增上述 internal 属性，`.xcode14` / `.xcode15` 全部填现值（保证零行为变化），
   `.xcode26` 填实测值。`swift build --traits WelcomePanel` 通过。
2. 材质与叠加色：`WelcomeViewController.loadView` 改为按 `welcomeViewMaterial` 决定是否套
   `NSVisualEffectView`；`ProjectsViewController` 的材质改为按样式取。两侧叠加色用
   `NSColor(name:dynamicProvider:)` 按外观给深浅两组实测值。
3. 几何：圆角 20、标题 36 bold、操作项圆角/底色/内间距、首行位置、关闭按钮位置、图标默认辉光。
4. 修两处漏判：`HoverButton` 与 `ActionCellView` 的 `style == .xcode15` 改为「非 `.xcode14`」。
5. 列表：首行顶部内边距 10、单元格左右缩进 16。
6. 测试：几何测试更新 `.xcode26` 期望值；两个 canary 从「钉住缺口」改为「断言已修复」；
   新增材质与叠加色的断言。**判定成败只认 `swift test` 退出码**。
7. 示例 App 构建通过；**人工验收**：对着真的 Xcode 26 欢迎窗口比圆角、材质明暗、标题字号、
   药丸形状（这一步只能由作者做）。
8. 文档四处 + 提案状态改 `Implemented`。

**收尾时必须判断两件事**（结果写进决策日志）：

- **配套专题文章**：逆向报告已落盘，判定**不再单独写实现说明** —— 该记的（材质就是 `.fullScreenUI`、
  模糊半径的单位陷阱、字号靠反推）都在报告里，实现说明只会复述。指南按上节更新。
- **新术语**：预计无。落地时复核。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-23 | Created as Draft | 作者提供 Xcode 26 欢迎窗口的 view hierarchy 抓包，要求研究如何复刻。 |
| 2026-08-23 | 定落地方式 | 作者选定**改现有 `.xcode26`**，不新增样式；并同意顺带修掉 0011 保留的两处漏判。 |
| 2026-08-23 | 定浅色模式处置 | 作者将再提供一份浅色抓包，浅色配色按实测填 —— 列为落地第 0 步的阻塞项。 |
| 2026-08-23 | 浅色抓包到位，阻塞解除 | 几何在两种外观下逐帧一致（等于全部尺寸测了两遍）；材质在 Aqua 下同样命中 `.fullScreenUI`；叠加色与药丸底色补齐深浅两组；**实测确认图标辉光仅深色存在**，与既有 `isDark ? shadow : nil` 写法吻合。 |
| 2026-08-23 | Draft → Accepted → In Progress | 作者审阅后批准（「开工」），直接进入实现。 |
| 2026-08-23 | 落地证否第 7 项 | 列表的 10 pt 首行内边距与 16 pt 单元格缩进是 `.sourceList` 自带的，不是 Xcode 配的；我们已经在用该样式，故右侧列表零改动。同时测出 `intercellSpacing.width` 在视图型表格里被忽略。改为加断言钉住表格样式。 |
| 2026-08-23 | 记录一条测试工具陷阱 | 实现期间撞上：`#expect` 里 `CGFloat` 与 **`Double` 变量**比较，值相同也判 false（宏外同一比较为 true），错误信息里两侧还打印得一模一样。已写进 `AGENTS.md` 的 Build & Test 一节 —— 本套件几何断言密集，不记会反复踩。 |
| 2026-08-23 | In Progress → Implemented | 样式表新增 11 个 internal 属性；两侧材质改 `.fullScreenUI`、圆角 20、标题 36 bold、胶囊操作行、行内间距与首行位置对齐、关闭按钮 13、深色自带图标辉光；两处漏判修掉。测试 13 → **18**（两个 canary 反转为「已修复」断言，新增材质 / chrome / 首行位置 / 辉光 / `.sourceList` 五项），`swift test` 退出码 0，全库 115 测试通过；示例 App `xcodebuild` 通过；关 trait 构建通过。**收尾判断**：① 不另写实现说明 —— 逆向报告已落盘，该记的都在里面，指南与 `AGENTS.md` 已同批更新；② 无新术语。**人工验收未做** —— 需作者把 demo 面板与真的 Xcode 26 欢迎窗口并排比对。 |
| 2026-08-23 | 材质定为公开 API | 实测证明 `.fullScreenUI` 与抓包滤镜链逐位一致（模糊半径差是设备像素 vs 点的单位差），因此不引入 `UIFoundationAppleInternal`，trait 保持可上架。 |
