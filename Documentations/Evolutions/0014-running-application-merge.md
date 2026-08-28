# 0014 - RunningApplication：把 RunningApplicationKit 整体并入本库

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-27
- **最后更新**: 2026-08-27
- **所属愿景**: 无
- **关联提案**: 本次同批并入两份原库历史提案（见「文档迁移」一节）；移植先例见
  [`0011`](0011-welcome-panel.md)（WelcomeKit）
- **实现分支 / PR**: main（与本提案同批次提交）
- **配套文档**: 使用指南 [`Documentations/RunningApplication.md`](../RunningApplication.md)；实现说明 [`Internal/PlatformDetection.md`](../Internal/PlatformDetection.md) 与 [`Internal/PresentationStyles.md`](../Internal/PresentationStyles.md)；术语表 [`Glossary.md`](../Glossary.md)

## 摘要

把独立仓库 [`Mx-Iris/RunningApplicationKit`](https://github.com/Mx-Iris/RunningApplicationKit)
（作者本人的库，本地位于 `/Volumes/Repositories/Private/Personal/Library/macOS/RunningApplicationKit`，
HEAD `a229465`，2026-08-26，已发布到 tag `0.5.0`）整体搬进 UIFoundation，落在新的默认关闭
trait `RunningApplication` 下的**独立 target** `UIFoundationRunningApplication`，仅 macOS 11+。

它做三件事：把「正在运行的应用 / BSD 进程」包装成值类型模型（带架构、平台、沙盒判定）、
提供两个观察者 actor（应用用 KVO，进程用轮询），以及一个开箱即用的选择器 UI
（搜索、排序、右键菜单、骨架屏，表格与列表两种呈现）。目标写法不变：

```swift
let picker = RunningPickerTabViewController()
picker.delegate = self
NSWindow(contentViewController: picker).makeKeyAndOrderFront(nil)
```

**本次只做 UIFoundation 这一侧**：原仓库原地保留、四个下游继续依赖旧包，迁移与归档另开一轮。
理由见「落地范围」。

## 动机

- **它就是本库的定位。** 零外部依赖、纯 AppKit + Darwin 系统调用，没有任何业务逻辑；
  内容是数据模型、观察者、一套表格 UI。把它单独放一个仓库，等于让每个用到它的 App
  多背一条 SPM 依赖，而这条依赖提供的东西和 UIFoundation 是同一类。
- **它已经在和本库抢同一批消费者。** 本机四个下游里，RuntimeViewer 同时依赖
  RunningApplicationKit 和 UIFoundation。两个仓库、两套版本号、两次 `swift package update`，
  换来的是同一类东西。
- **它自带的一批内部件与本库重复**，其中 `TableCellView` 与本库顶层符号直接冲突。
  也就是说：这套代码只要进本库就**必须**做去重，不存在「先原封搬进来、永远不整理」这个选项
  （但可以分两阶段做，见「落地节奏」）。
- **作者要求搬。** 这是本次的直接触发原因，不再另找论证。

## 前期调研

### 原库现状（HEAD `a229465`，2026-08-26）

- `Package.swift`：swift-tools 6.2，`swiftLanguageModes: [.v6]`，平台 `macOS 11`，
  **零外部依赖**，无资源、无 ObjC target。
- `Sources/RunningApplicationKit/` 共 27 个 Swift 文件、4080 行。
- `Tests/RunningApplicationKitTests/` 共 7 个文件、1260 行，全部 swift-testing，
  **确定性、与环境无关** —— 不读真实进程、不读真实二进制、不读本机任何状态。
- `Example/` 一个独立 `.xcodeproj`，通过本地路径依赖本库；界面是 picker 加两个
  segmented control（骨架屏 / 真内容、表格 / 列表）。
- `Documentations/`：2 份 Evolution 提案（0001 平台识别、0002 呈现样式，均 Implemented）、
  2 份 Internal 实现说明、1 份 Glossary（4 个词条）。
- 已发布 tag 至 `0.5.0`；LICENSE 为 MIT，Copyright 归 Mx-Iris（与本库同一作者）。

### 公开符号清单（20 个）

| 类别 | 符号 |
|---|---|
| 选择器 | `RunningPickerTabViewController` 及其嵌套 `Configuration` / `ApplicationConfiguration` / `ProcessConfiguration` / `ApplicationField` / `ProcessField` / `Style` / `IconSizeMode` / `Delegate` |
| 模型 | `RunningApplication`、`RunningProcess`、`RunningItem`、`Architecture`、`Platform` |
| 枚举与工具 | `RunningProcessEnumerator`、`SkeletonAppearance` |
| 观察者 | `RunningApplicationObserver`、`RunningProcessObserver`（含嵌套 `Target`）|
| 弃用别名 | `ApplicationColumn`、`ProcessColumn`（本次删除，见下）|

个别 picker 视图控制器（`RunningApplicationPickerViewController` /
`RunningProcessPickerViewController`）与泛型基类 `RunningItemPickerViewController` 是
internal，本次维持不变。

### 与本库重复的部分（去重清单，已逐条核对双方实现）

| 原库内部件 | 本库已有的等价物 | 备注 |
|---|---|---|
| `TableCellView`（禁 coder init 的空壳基类） | `TableCellView`（`Base/TableCellView.swift:8`） | **顶层名冲突**，语义不同，见下 |
| `NSTableView.makeView(ofClass:modify:)` | `.box.makeView(ofClass:)`（`UIFoundationToolbox`） | 实现逐行等价 |
| 各 cell 的 `init(frame:)` 内组装 | `TableCellView.setup()` / `firstLayout()` 生命周期 | 机械迁移 |
| 裸 `NSLayoutConstraint.activate([...])` | `makeConstraints { make in … }` / `.box.addSubview(_:fill:)` | 集中在 5 个文件 |
| `NSViewController` + 手写 `loadView()` | `XiblessViewController<View>` | 2 处 |
| 裸 `NSStackView` 装配 | `HStackView` / `VStackView` | 8 处 |

**两个 `TableCellView` 语义不同，不是同一个东西改个名就能合。** 本库那个带
`setup()` / `firstLayout()` 生命周期，并在 `init` 里自动把 `identifier` 设成类名
（正好是 `.box.makeView(ofClass:)` 依赖的约定）；原库那个只是禁掉 `init?(coder:)` 的空壳，
子类一律在 `init(frame:)` 里组装。合并的动作是：各 cell 子类的组装体从 `init(frame:)`
挪进 `setup()`，并删掉它们各自设 identifier 的代码。

### 不重复、必须原样保留的部分

`BSDProcess`（`proc_listpids` / `proc_pidpath` / `proc_pidinfo` / `sysctl` / `csops`）、
`MachOPlatform`（读 `LC_BUILD_VERSION`）、`Platform` / `Architecture` 枚举、两个观察者 actor、
`ThreadSafeCache`。本库没有任何等价物，也不该有。

### 文件名与类型名的碰撞面

- **文件名零碰撞**：原库 27 个文件名与本库现有源码无一重名。且落在独立 target 内，
  SwiftPM 的「同 target 内 basename 必须唯一」规则不跨 target，`Platform.swift` /
  `Architecture.swift` 这类泛名可以照原样保留。
- **类型名一处碰撞**：`TableCellView`。其余同名项（`Configuration` / `Delegate` / `Style`）
  都是嵌套类型，不构成冲突。

## 详细设计

### target 与 trait

新增 target `UIFoundationRunningApplication` 与同名 product，trait 名 `RunningApplication`
（默认关闭）。**不进 umbrella** —— 与 `UIFoundationSettings` 同构，理由一致：
它的平台下限（macOS 11）高于 umbrella（macOS 10.15），进 umbrella 等于替所有使用方抬地板。

```swift
.target(
    name: "UIFoundationRunningApplication",
    dependencies: [
        "UIFoundationAppKit",       // TableCellView, XiblessViewController
        "UIFoundationToolbox",      // .box extensions
        "UIFoundationUtilities",    // makeConstraints
        "UIFoundationShared",       // HStackView / VStackView
    ],
    swiftSettings: swiftSettings + [.swiftLanguageMode(.v6)],
)
```

- **语言模式**：包级是 `.v5`，本 target 用 per-target 的 `.swiftLanguageMode(.v6)` 保住
  原库的 Swift 6 严格并发。**退路已定**：若与 Swift 5 模式的 `UIFoundationAppKit`
  摩擦到卡住（跨模块引用未标注 `@MainActor` / `Sendable` 的类型），就把本 target 也降到
  `.v5`，不为此去改全库共用的基座代码。
- **平台差**：SPM 的 `platforms:` 是包级的，无法给单个 target 抬下限。照
  `UIFoundationSettings` 的成例：每个公开类型贴 `@available(macOS 11.0, *)`，
  每个文件头 `#if RunningApplication && os(macOS)`。
- **无资源、无 ObjC target、无新外部依赖。**

### 命名

公开类型名**全部保持原样**，包括 `Platform` / `Architecture` / `RunningItem` 这类泛名。
不加命名空间前缀、不嵌套进宿主类型。理由：独立 target 不进 umbrella，`import` 是显式的，
撞名风险比想象中小；而四个下游已经在用这些名字，改名等于在「换 package 依赖 + 换 import」
之外再加一层迁移成本，换来的只是防一个假想冲突。

### 落地节奏 —— 分两阶段

**第一阶段：原样搬运。** 建 target、搬 27 个源文件与 7 个测试文件，只做两件事：
文件头加 `#if RunningApplication && os(macOS)`，以及给编译器实际报到的地方补
`@available(macOS 11.0, *)`（包级 `platforms:` 是 macOS 10.15，逐个标注是唯一路径；
按报错补而非盲目全标，以免留下一堆并不需要的标注）。

**此阶段不 `import UIFoundationAppKit`，因此两个 `TableCellView` 分属不同 module、并不冲突** ——
撞名要到第二阶段引入基座时才需要处理。验收是 `swift build --traits RunningApplication`
与 `swift test --traits RunningApplication` 全绿。**此时代码与原库逐行可比，任何差异都是搬运错误。**

**第二阶段：接入基座并重写。** 先把 `ListRowLayoutTests` / `PickerStructureTests`
扩到能盖住每个 cell 的关键几何，**确认扩充后的测试在旧实现上全绿**，再动手按去重清单重写。

两阶段之间可验证，出了问题能分清是搬坏的还是改坏的。这是本提案唯一的节奏安排，
不拆成两份提案 —— 它们是同一件事的两半。

### 验收标准

原库自己的记录写着：**四个布局 / wiring bug 编译干净、其它测试全绿，只在截图里现形**
（样式在初始化时被忽略、表格列卡在 100pt 默认宽、文本列塌缩而非填满、空 stack view 未隐藏）。
所以「编译通过 + 现有测试绿」在这里**不构成验收**。第二阶段的门槛是：

1. 扩充后的布局测试先在旧实现上全绿（证明它抓的是几何，不是实现细节）；
2. 重写后仍全绿；
3. demo 里四种组合（骨架屏 × 表格 / 列表）人工过一遍。

测试仍按现有惯例托管在真实 `NSWindow` 里、靠约束定尺寸 —— frame 赋值出来的视图会带上
autoresizing，恰好掩盖这一类故障。

### 一并清掉的债

删除 `DeprecatedNames.swift` 及配套的 `allowsColumns` 属性与各 configuration 上多出来的
初始化器重载（原库 README 写着「下一个 minor 移除」）。下游本来就要改 package 依赖与 import，
这是清理的最佳时机；否则等于让 UIFoundation 一开局就背一个从未在本库发布过的 API 的弃用别名。

### 明确的非目标

- **不提升通用件。** `BadgeView`、骨架屏一套（`SkeletonTableCellView` /
  `SkeletonListRowCellView` / `SkeletonTableViewCoordinator` / `SkeletonAppearance`）
  维持 internal。它们确实通用，但目前的 API 是照 picker 的需求长的；提升要重新设计对外形状，
  那是另一份提案的事。本次是移植，不是重设计。
- **不改运行时行为。** 包括原库已知的降级（约 5% 的受保护系统进程读不到路径，
  因而 `platform` 与 `architecture` 均为 `nil`）—— 只记录，不修。
- **不动下游。**

## 文档迁移

| 原库文档 | 去处 |
|---|---|
| `Evolutions/0001-simulator-platform-detection.md` | 重编号为 [`0015`](0015-simulator-platform-detection.md) |
| `Evolutions/0002-picker-presentation-styles.md` | 重编号为 [`0016`](0016-picker-presentation-styles.md) |
| `Internal/PlatformDetection.md` | `Documentations/Internal/`（本库首次启用该目录）|
| `Internal/PresentationStyles.md` | 同上 |
| `Glossary.md`（4 个词条）| **新建** `Documentations/Glossary.md`，本库首份项目术语表 |
| `README.md`（英文，含完整用法）| 素材并入根 `README.md` 与新写的中文指南 |

两份历史提案**正文一字不改**（提案是决策快照，落地后保持原貌），仅在文件头部加一段移植说明，
标注原路径到新路径的映射。编号在本提案落地的那个 commit 里按目标分支现状统一分配。

另需新写 `Documentations/RunningApplication.md` 完整使用指南（照 `TabBar.md` /
`WelcomePanel.md` 的规格：API、宿主必须遵守的契约、已知降级），并同步
`Documentations/README.md` 索引、根 `README.md`、`CLAUDE.md`。

`THIRD_PARTY_LICENSES.md` **不登记** —— 同为作者本人的库，照 WelcomeKit / SystemHUD 的先例。

## 示例 App

`Demos/RunningApplicationPickerDemoViewController.swift` 一个文件，内嵌 demo browser 的详情面板，
顶部保留原 Example 那两个 segmented control（骨架屏 / 真内容、表格 / 列表）。
需要在 `UIFoundationExample-macOS.xcodeproj` 的 `XCLocalSwiftPackageReference` 里
补上 `RunningApplication` trait，否则符号不会被编进包、demo 链接不上。

四种组合并排可切，正好也是第二阶段重写后人工验收的入口。

## 影响

### 源码兼容性

**对本库现有使用方：零影响。** 纯新增，新 target 不进 umbrella，trait 默认关闭；
不动任何既有 target 的任何文件。

**对原库现有使用方（下游迁移时才发生）：破坏性。** 迁移动作是三条：
换 package 依赖并打开 `RunningApplication` trait、`import RunningApplicationKit`
换成 `import UIFoundationRunningApplication`、把 `allowsColumns` / `ProcessColumn` /
`ApplicationColumn` 换成新拼写。类型名与 API 形状本身不变。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### API 演进与废弃策略

本次删除的两个弃用别名从未在本库发布过，不构成本库的破坏性变更。

### 下游影响（逐个点名）

本提案落地后，四个下游**均无任何变化**（原仓库原地保留，它们照旧依赖 `0.5.0`）。
以下是各自迁移时的预估面，供下一轮提案参考：

| 下游 | 依赖形态 | 迁移面 |
|---|---|---|
| RuntimeViewer | `Package.swift` local / remote 双路径，`from: "0.5.0"` | 最大；已同时依赖 UIFoundation，迁移后少一条依赖 |
| HopperMCP | `.xcodeproj` 直连 | 待查 |
| MachInjector | `.xcodeproj` 直连（Example 亦有） | 待查 |
| LookInside | `.xcodeproj` 直连 | 待查 |

### 平台与最低版本

本 target macOS 11+，仅 macOS。包级 `platforms:` 不变，umbrella 与其它 target 的下限不受影响。

## 备选方案

### 原仓库退化成薄壳，只做 re-export（否决）

UIFoundation 成为唯一实现，原仓库保留 URL 与版本号，内容只剩转发。好处很实在：
GitHub URL 与四个下游的 `Package.swift` 一行都不用改。否决理由是它把「一次性迁移成本」
换成了「永久性维护成本」—— 多一个空壳仓库、多一层版本对齐，而下游迟早还是要改 import
才能用上新东西。

### 只搬通用部件，Running* 业务留在原仓库（否决）

把 Badge / 骨架屏 / 列表行 / 表格基建搬进 UIFoundation，原仓库反过来依赖 UIFoundation。
好处是 UIFoundation 的「UI 基础件」定位不被业务污染。否决理由是拆分工作量最大、
原仓库仍要维护，而「运行中的应用与进程」本身就是一个跨项目复用的基础能力，
不比 TabBar 或 WelcomePanel 更「业务」。

### 并入 `UIFoundationAppKit` 并加 trait 门控（否决）

与 TabBar / WelcomePanel 完全同构，直接进 umbrella，`import UIFoundation` 就能用。
否决理由是代价太具体：必须把 4000 行 Swift 6 严格并发代码降到 Swift 5 语言模式，
并给全部公开类型补 `@available(macOS 11)` 门控 —— 前者要重新验证一遍并发正确性，
后者无论如何都躲不掉。独立 target 只需付后者。

### 一次性改完四个下游并归档原仓库（否决）

一步到位不留中间态。否决理由是收尾不了：四个仓库各有自己的构建验证链，
其中 RuntimeViewer 与 LookInside 都是大工程，混在一份提案里没有一个能算「完成」。

### 类型名嵌套进命名空间（否决）

照 TabBar 的做法把一切嵌进一个宿主类型（`RunningPicker.Platform` 之类）。
否决理由有二：没有一个天然的宿主类型（这里是三组各自独立的能力，不像 TabBar 那样有个控件当核心），
以及四个下游的每一处调用都要改。

### 保留弃用别名（否决）

见「一并清掉的债」。

### 重写布局时只靠现有两份测试保绿（否决）

否决理由写在「验收标准」里：当年那四个 bug 就是从这道门溜过去的。

## 决策日志

本提案动笔前的四轮澄清提问，逐条记录结论与被否的方向：

| 轮次 | 问题 | 结论 |
|---|---|---|
| 1 | 搬的边界与原仓库归宿 | 整体并入、原仓库最终归档；否决薄壳、只搬通用件、双份维护 |
| 1 | 落地形态 | 独立 target + trait，保 Swift 6；否决并入 AppKit target |
| 1 | 去重程度 | 接入现有基座、删重复件 |
| 1 | 文档迁移 | 重编号并入总表；否决留档原仓库、否决并行编号子目录 |
| 2 | 命名 | `UIFoundationRunningApplication` / trait `RunningApplication` |
| 2 | 类型名 | 保持原名；否决命名空间嵌套、否决部分重命名 |
| 2 | 落地范围 | 只做 UIFoundation 侧；否决一并改四个下游、否决只迁 RuntimeViewer |
| 2 | 测试归属 | 并入现有 `UIFoundationTests` + trait 门控 |
| 3 | 去重边界 | **连布局与 VC 基类一起改**（比提问时的推荐更彻底一档）|
| 3 | 通用件 | 不提升，保持 internal |
| 3 | 弃用别名 | 趁机删掉 |
| 3 | 术语表 | 新建 `Documentations/Glossary.md` |
| 4 | 重写的验收标准 | **先补布局测试、确认旧实现上全绿，再重写** |
| 4 | Swift 6 摩擦的退路 | 新 target 降到 v5；否决改全库基座、否决临场再议 |
| 4 | demo 形态 | 内嵌详情面板 + 两个调试开关 |
| 4 | 历史提案的旧路径 | 正文保原貌 + 头部加移植说明 |
| 5 | 落地节奏 | 分两阶段、一份提案 |
| 5 | 使用指南 | 新写 `Documentations/RunningApplication.md` |

## 落地结果

三条结论，都是做完之后才知道的：

- **Swift 6 与 Swift 5 基座的摩擦没有发生，退路没用上。** 改写过程中确实冒出过一批
  `main actor-isolated default value in a nonisolated context`，看上去正是预判的那种摩擦；
  但它们是**级联错误** —— 当时旧基类刚被删、新基类还没接上，类暂时失去了父类，属性默认值
  也就失去了本该从 `NSTableCellView` 继承来的 MainActor 隔离。父类接上后全部消失。
  本 target 保持 `.swiftLanguageMode(.v6)`，一处 `@MainActor` 标注都没有补。
  **教训是这类报错要先确认父类解析成功再判断，否则会误判成语言模式冲突而无谓降级。**
- **第一阶段与原库逐行比对，预期之外的差异为 0。** 27 个源文件的全部差异只有三类：
  trait 门控、`@available(macOS 11.0, *)`、以及被门控行带来的空行。
- **`@available` 标注按报错迭代补，5 轮收敛，共 21 处。** 盲目全标会留下大量并不需要的标注；
  逐轮补到编译器不再报为止，落点集中在 11 个文件。

## 风险

- ~~**Swift 6 target 引用 Swift 5 基座的摩擦程度未知。**~~ 已证否，见「落地结果」。
- **第二阶段的重写面比它看起来大。** 五个文件里 `NSLayoutConstraint.activate` 只有 8 处，
  但 anchor 约束共 48 条、`NSStackView` 装配 8 处，且它们正是历史上出过四个 bug 的地方。
  测试先行是唯一的防线。
- **进程枚举与 picker 的高层行为在原库就没有测试。** 本次不补 —— 补它需要真实进程环境，
  与原库「测试确定性、与环境无关」的原则冲突。这是继承过来的已知缺口，已写进指南的
  「已知降级」一节。

## 测试增量

第二阶段动手前新增 `TableCellLayoutTests`（15 个测试），覆盖此前完全没有几何断言的表格 cell
一族、徽章药丸的内边距与 hugging、以及全体 cell 的布局无歧义性。**先在旧实现上跑绿**，
再开始重写 —— 这是这一档去重唯一能变红的防线。

写这批测试时撞上一处值得记住的坐标系陷阱：`NSTextField` 的 `frame` 比它的 **alignment rect**
左右各宽 2pt，而 Auto Layout 约束作用在 alignment rect 上。对 `frame` 断言等于在断言 AppKit
的绘制余量，需要一个 ±2 的容差 —— 而那个容差恰好会吞掉一个真实的 2pt 回归。这批测试因此统一
通过 `alignmentFrame(_:in:)` 断言。

并入后全套测试 192 个、20 个 suite，全绿。
