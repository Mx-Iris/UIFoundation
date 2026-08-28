# 呈现样式：实现说明

> 配套提案见 [选择器呈现样式（表格与列表）](../Evolutions/0016-picker-presentation-styles.md)。
> 本文记录**实际落地的实现**、与提案的差异，以及当前覆盖范围与已知降级。面向维护者。


> **本文描述的代码已随 RunningApplicationKit 整体并入本库**（见
> [0014 - RunningApplication：把 RunningApplicationKit 整体并入本库](../Evolutions/0014-running-application-merge.md)），
> 路径与提案编号已同步更新到并入后的位置。并入时接入了本库的基类与 `.box` 扩展，
> 因此本文提到的布局代码有一部分改用了 `makeConstraints` / `HStackView` / `XiblessViewController`；
> 几何与行为未变，具体清单见 0014。

## 背景与目标

两个标签页各自可选表格或列表呈现。完整动机见提案，这里只留一句结论：**表格里大量格子在重复
同一件事** —— 实测 400 个进程中 391 个平台是 `macOS`、只有 22 个在沙盒里、207 个没有架构值。

## 关键设计决策

### 列表仍然是 NSTableView，不是新控件

列表样式是**一个占满宽度的列 + 隐藏表头**，底下仍是同一个 `NSTableView` 和同一个
`NSTableViewDiffableDataSource`。

这样选中、type-select、右键菜单、骨架屏切换、快照 diff 全部原样复用，两种样式之间不存在
「这个功能只有表格有」的坑。代价是列表行的布局要塞进一个 cell view
（`ListRowTableCellView`）里，而不是用 `NSStackView` 自由排布。

替代方案是换 `NSCollectionView` 或自绘。否决理由：那要重新实现上面列的每一项能力。

### 样式默认值：公开类型不变，optional 只在内部

`rowHeight`、`cellSpacing`、`iconSize` 需要「没设过就跟着样式走，设过就听调用方的」。

直觉做法是把公开属性改成 optional —— **这会破坏读取端**。实际做法是公开属性保持非 optional 的
计算属性，背后存一个 optional：

```swift
private var explicitRowHeight: CGFloat?
public var rowHeight: CGFloat {
    get { explicitRowHeight ?? style.defaultRowHeight }
    set { explicitRowHeight = newValue }
}
```

三个好处：公开类型零变化；未设置的值在**运行时切换样式后会自动跟着变**；已设置的值不会被样式
悄悄覆盖。

### 弃用别名里唯一的真实约束：旧 init 的 `allowsColumns` 不能有默认值

旧 `init` 的参数原本全都有默认值。若原样保留，`ProcessConfiguration()` 会在新旧两个 init 之间
产生歧义，编译失败。

解法是**旧 init 里唯独 `allowsColumns` 不给默认值**，于是只有显式写出该标签才会匹配到它：

```swift
@available(*, deprecated, message: "Use init(style:…allowsFields:…) instead")
public init(
    title: String = "Running Processes",
    // …
    allowsColumns: [ProcessField],   // 没有默认值 —— 这正是消歧义的关键
    refreshInterval: TimeInterval = 2.0
)
```

**下次维护若有人"顺手"给它补一个默认值，所有无参构造会立刻编译失败。** 代码里有注释，这里再记
一次。

### 三个只在真机上现形的 bug

它们全部通过编译、通过当时的全部测试，然后出现在用户的截图里。共同点是**都不在类型系统的
射程内，也不在纯函数的射程内**。

**1. 初始化时设 `.list` 完全不生效。** 基类 `viewDidLoad` 里 `configureColumns()` 跑在子类
`applyBaseConfiguration(...)` **之前** —— 建列时 `presentationStyle` 还是默认的 `.table`。
只有运行时切换那条路是对的。修法是把配置从「子类推给基类」改成「基类向子类拉取」：

```swift
// 基类 viewDidLoad
applyBaseConfiguration(currentBaseConfiguration())   // 先落配置
configureColumns()                                    // 再按 style 建列
```

子类改为覆盖 `currentBaseConfiguration()`，不再自己调 `applyBaseConfiguration`。

**2. 列表的那一列宽 100pt。** `NSTableColumn` 的默认宽度就是 100，而我建列时没设过。
`resizingMask = .autoresizingMask` 只在**表格 frame 变化时**重新分配宽度 —— 切换样式时窗口
尺寸没动，于是永远不触发。结果是每行只有 100pt 可用，标题和副标题都被压成六个字符加省略号。
修法是建列时显式给宽度，并在 `viewDidLayout` 里 `sizeLastColumnToFit()`。

**3. 空的徽章容器一直可见。** `badgeStackView.isHidden` 只在 `badges` 的 `didSet` 里设置，
而 `badges` 初值就是 `[]` —— 赋 `[]` 被 `guard badges != oldValue` 挡掉，`rebuildBadges()`
从未执行。一个可见且没有 arranged subview 的 `NSStackView` 没有任何依据推算高度，AppKit 因此
每个无徽章的行报一次「Height and vertical position are ambiguous」。Applications 页整页都没有
徽章，于是 10 行报 10 条。修法是 init 里直接 `isHidden = true`。

### 骨架屏：一个复合 cell，而不是两个列 cell

提案写的是「把两条文字条当两列解释」。落地时发现**不能真的当两列** ——
`SkeletonTableViewCoordinator` 按 `tableColumn.identifier` 查 `columns` 数组，而列表样式只有
一个真实列 `listRow`，喂两个虚拟列描述符会查不到、返回 `nil`、骨架直接不显示。

改成协调器多一个 `listRowLayout` 开关，命中时vends 一个复合的 `SkeletonListRowCellView`
（图标方块 + 两条文字条）。**两条文字条仍然按 `columnIndex` 0 / 1 去读 `SkeletonAppearance`**，
所以 `textBarWidthFractions`、`shimmerColumnStagger` 这些调参全部照用 —— 提案「不新增骨架屏
公开 API」的承诺守住了，只是内部实现方式和当初设想的不同。

### 列表行的字段分配写死在基类

`allowsFields` 决定显示哪些字段，但「哪些上标题行、哪些进副标题」是固定规则，写在
`RunningItemPickerViewController` 而不是各子类：

| 位置 | 字段 |
|---|---|
| 行首图标 | `icon` |
| 标题行 | `name` |
| 标题行右侧徽章 | `platform`、`sandboxed` |
| 副标题（`·` 分隔，按配置顺序） | 其余全部 |

子类只需覆盖 `fieldValue(_:for:)` 提供自己的字段取值（`executablePath` / `bundleIdentifier`），
排布逻辑不重复。

**徽章只在有信息时渲染**：平台是 `macOS` 不渲染，非沙盒不渲染。这是整个样式存在的理由 ——
表格列必须在每一行印一个值，徽章不必。

### 表格也上徽章，但规则与列表相反

表格初版每一列都是同色文字，只有 Sandbox 列有勾叉 —— 读起来很平。现在 Platform 与 Arch 两列
改用与列表相同的 pill（`BadgeTableCellView`，共用 `BadgeView`）。

**关键差异是缺省值的处理，两种样式刻意不同**：

| | 列表 | 表格 |
|---|---|---|
| 平台是 `macOS` | 不渲染徽章 | 渲染，但用 `secondaryLabelColor` 压下去 |

理由是两种呈现的气质不同：列表的行本来就长短不一，少一个徽章很自然；而表格里一整列空格
读起来像坏了 —— 这正是之前 Arch 列被抱怨的原因。所以表格「照常显示、把不值得注意的压暗」，
列表「不值得注意的直接不画」。

**PID 不用 pill**，尽管它也在上色的列里。pill 是给**分类值**的形式，而 PID 是**唯一标识符** ——
装进胶囊会暗示这个数字能把行分组。改用等宽数字（`monospacedDigitSystemFont`）加次要色：
等宽让整列数字对齐，次要色让它退到背景。

表格默认行高因此从 25pt 提到 **28pt**（pill 在 25pt 里过于局促）。**弃用的旧 init 仍然显式传
25pt**，所以走旧 API 的调用方一点变化都没有 —— 这一点有测试钉住。

**配色一个系统家族一个色**（`Platform.badgeColor`，定义在 UI 层而非 `Platform.swift`，
它是呈现关注点）：iOS 系蓝、tvOS 系紫、watchOS 系粉、visionOS 系靛、Mac Catalyst 青、
DriverKit 棕、判不出橙、Sandboxed 绿。

**模拟器与真机同色**，靠文字区分 —— 颜色回答的是「这是哪个平台」，若 iOS 与 iOS Simulator
不同色，颜色就不再回答这个问题了。

初版所有非模拟器平台统一用 `secondaryLabelColor`，结果 Mac Catalyst 和 DriverKit 在深色下
糊成一片灰。`badgeColor` 的 switch **刻意不写 `default`** —— 新增平台必须在此处指定颜色，
不能静默继承别人的。

`Architecture` 另有一套：实测 1428 个进程里 arm64e 占 41.7%、arm64 占 29.4%、x86_64 只有 1 个。
所以两个 ARM 变体用相近的冷色（蓝 / 靛）表达「都是原生」又能区分，而 x86_64 与 i386 用橙 ——
在这台机器上跑它们意味着翻译，那才是值得一眼看到的。

沙盒徽章原本是一枚绿色锁形 SF Symbol，改成文字 `Sandboxed`；`ListRowBadge` 因此从带两个 case
的枚举简化为 `struct { text, color }`，`BadgeView` 的 symbol 分支一并删除。

## 模块结构

```
Sources/UIFoundationRunningApplication/
├── PickerPresentationStyle.swift    # Style 枚举与它的默认值（行高、间距、表头/排序控件可见性）
├── ListRowTableCellView.swift       # 列表行 cell：图标 + 标题 + 徽章 + 副标题；ListRowColumn.identifier
├── SkeletonListRowCellView.swift    # 列表行的骨架占位（图标方块 + 两条文字条）
├── DeprecatedNames.swift            # 弃用的 typealias，集中在此便于下个 minor 整文件删除
└── RunningItemPickerViewController.swift  # 样式分派、列表行组装、排序控件、运行时切换
```

## 核心算法与数据流

```
configureColumns(fields)
  ├─ 记录 configuredFieldIdentifiers 与 sortableFields（有 title 的才可排序）
  ├─ 移除所有既有列
  ├─ .table → 每个字段一列 + 每列一个骨架描述符
  └─ .list  → 一个 listRow 列 + skeletonCoordinator.listRowLayout
  └─ applyStyleToChrome()：表头显隐、排序控件显隐、搜索框在两行之间迁移

dataSource cell provider
  ├─ .list  → makeListRowCellView(item)  ← 组装规则集中在基类
  └─ .table → 子类的 makeCellView(for:item:)
```

运行时切换走 `applyStyleChange(baseConfiguration:reconfigureColumns:)`：先记下选中项，
重配 chrome 与列，`reloadData()` 后重新 apply 快照，再按 item 身份把选中项找回来并滚动到可见。
**不能用 diff 动画** —— cell view 的类型变了。

## 与提案的差异

| 差异 | 说明 |
|---|---|
| 骨架屏是**复合 cell**，不是两个列 cell | 提案设想把两条文字条当两列喂进现有模型。实际不行：协调器按列标识符查表，列表只有一个真实列。改为复合 cell，但两条文字条仍按 columnIndex 0/1 读外观参数，因此「不新增公开 API」的目标不变。 |
| 搜索框在列表样式下移到自己一行 | 提案只说「搜索框右侧放排序下拉」。落地时按预览的样子做成两行：标题行照旧，下面一行是占满宽度的搜索框 + 排序下拉。表格样式仍是标题行右侧的 300pt 搜索框。 |
| 新增 `setStyle(_:)` 便捷方法 | 提案只定了 per-tab 的 `style`。实际加了 `applicationStyle` / `processStyle` 两个属性外加一个同时设置两者的 `setStyle(_:)`，Example 的切换器用它。 |
| **图标尺寸两个标签页统一**，不再按页取不同默认值 | 提案依据实测（应用页 21/21 独立图标、进程页 400 个只有 2 种）让两页取 34pt 与 22pt。**跑起来看到实际效果后推翻**：在两页之间切换时尺寸跳变，读起来像渲染 bug，而不像有意的信息设计。统一为 28pt —— 44pt 行高里上下各留 8pt。原来的推理本身没错，只是它优化的是单页可读性，代价是跨页一致性，而后者更显眼。 |

## 验证

**单元测试**：`Tests/UIFoundationTests/RunningApplication/ConfigurationTests.swift`，与既有的 Mach-O 测试
一样只覆盖纯函数部分 —— 样式默认值、显式值覆盖、样式变更后未设置的值是否跟随、
`BaseConfiguration` 转发、字段可排序性、以及弃用别名的读写等价。

**这套测试里有一条是回归测试**：`initialSortField` 曾经在转换成 `BaseConfiguration` 时被整个
漏掉，编译完全正常、排序静默失效。变异验证过：把那两行转发删掉，三个断言立刻变红。

**结构验证**（一次性，不在套件里）：实例化 picker、放进窗口、逐个标签页切换样式，断言
列数（表格 6/7 列 → 列表 1 列）、列标识符、表头有无、行高（25 ↔ 44）、排序控件显隐、
排序菜单内容（不含 icon 那个空标题项）、以及切回表格后一切复原。**这条验证抓出了上面那个
漏传 bug** —— 单看编译和单元测试都发现不了。

**布局与结构测试**：`ListRowLayoutTests.swift` 与 `PickerStructureTests.swift`。这两组是套件里
唯一走出纯函数的地方，理由很实在：上面那三个 bug 加上文字列的约束问题，**没有一个是纯函数测得到的**。

- `ListRowLayoutTests` —— 单个行的内部布局：文字列是否铺到行的右边缘、长标题是否被无谓截断、
  徽章是否紧跟标题、隐藏图标后文字是否收回那块空间、空徽章容器是否隐藏、以及整行有无布局歧义。
  **行是用约束定尺寸的，不是设 frame** —— 设 frame 会带来 autoresizing 约束，把真实表格里会暴露
  的歧义掩盖掉。
- `PickerStructureTests` —— 加载完成后的整体结构：初始化时的 style 是否真的生效、列表是否只有一列、
  表头与排序控件的显隐、排序菜单内容、列宽、以及运行时切换后这一切是否复原。
  **picker 装在真实 `NSWindow` 里**，理由同上：给游离的 view 赋 frame 会让 AppKit 顺手 autoresize
  列，正好盖住「列停在默认宽度」这个 bug。

这些测试仍然是确定性的、不依赖环境的：不读真实进程、真实图标，也不读跑测试的机器的任何信息。

**变异验证**（一次性）：三个 bug 逐个改回原样，测试逐个变红。

其中列宽那条有个教训值得记：最初的断言是「列宽 ≈ 表格宽度」，**改回 bug 后它居然还是绿的** ——
因为测试里的那次 layout 恰好触发了 autoresizing，把列撑开了，掩盖了「代码根本没设宽度」这件事。
换成断言「建列之后、任何 layout 之前，宽度不是默认的 100」才咬得住。**测最终效果容易被间接行为
糊弄，测代码本身做了什么才可靠。**

同一轮变异还发现 `titleRowStackView` 里那个用来吸收剩余宽度的 spacer **完全没有作用** ——
`NSStackView` 默认的 `.gravityAreas` 本来就不拉伸 arranged subview。实测有无 spacer 时徽章位置
逐点相同，已删除。

**未做**：交互式 UI 验证。徽章配色在深浅色下的表现、骨架屏动画，仍需人运行 Example 用眼睛看。
Example 里已经加好了 Table / List 切换器。

## 已知降级

- **切换样式时滚动位置只能尽力保持**。行高从 25 变 44（或反向），像素级还原没有意义；
  实现是把选中项滚回可见区域。没有选中项时回到列表顶部。
- **列表样式下没有列头排序指示器**。排序方向靠排序下拉按钮标题里的 ↑ / ↓ 表示。
- **切回表格样式时，列头不会显示当前排序的指示箭头**。排序本身是生效的，只是
  `NSTableView.sortDescriptors` 没有跟着回填。
- **`ListRowTableCellView` 的徽章每次配置都重建**。行内徽章最多两个，重建成本可忽略；
  若将来徽章变多需要改成复用。
- **列表样式忽略字段的 `preferredWidth` / `minWidth` / `maxWidth` / `headerAlignment`**。
  这些是表格专用概念，`PickerField` 协议仍然要求它们，列表分支只是不读。

## 后续工作

- `Style` 是枚举且已按可扩展方式实现，将来加 `.grid` 之类不需要动分派结构。
- 弃用别名（`DeprecatedNames.swift` 整个文件，加上两个 configuration 里的 `allowsColumns`
  属性与旧 init 重载）计划在下一个 minor 移除。

## 延伸阅读

- 配套提案：[选择器呈现样式（表格与列表）](../Evolutions/0016-picker-presentation-styles.md)
- 相关提案：[0015 - 进程平台识别与模拟器标记](../Evolutions/0015-simulator-platform-detection.md)
- 术语：[field 与 column、style](../Glossary.md)
