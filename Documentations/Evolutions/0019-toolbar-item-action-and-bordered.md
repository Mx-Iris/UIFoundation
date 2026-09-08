# 0019 - ToolbarItem：target/action 下沉到中间基类，isBordered 与 isNavigational 上提

- **状态**: Implemented
- **创建日期**: 2026-09-08
- **最后更新**: 2026-09-08

## 摘要

Toolbar DSL 有两个缺口，都出在「本该属于所有 item 的东西只长在一个 item 上」。

第一，`isBordered` 与 `isNavigational` 是 `NSToolbarItem` 自己的属性（分别 macOS 10.15+ /
11.0+），对每一种 item 都成立，但本库只在 `NSToolbar.Item` 上暴露了它们，其余九个 item 类型
够不着。

第二，target/action 只有 `NSToolbar.Item` 补了链式 setter，`Button` / `View` / `Menu` /
`Group` / `PopUpButton` / `SegmentedControl` 六个都只能赋值属性 —— 而这六个恰恰包含所有「托管
自定义 view」的类型。代价已经写在下游代码里了：XCOrganizer 的 `MainWindowController.makeToolbar()`
为了给一个 `NSToolbar.Button` 挂 `#selector`，不得不把该 item 从 builder 里拉出来做成局部变量，
旁边留着一行注释 —— *"`action` has no chainable form, hence the local."* 声明式写法就此断掉一截。

顺带的账：这七个类各自复制了一份**逐字相同**的 45 行 target/action 样板（trampoline 安装、
互斥清理、两个属性），只有宿主对象不同。补链式方法如果照现状办，是把 6 份样板扩成 6 份更长的样板。

## 方案

### 一、新增中间基类 `ActionableToolbarItem: ToolbarItem`

承载全部 target/action 逻辑一次：

```swift
open class ActionableToolbarItem: ToolbarItem {
    /// 接收 target / action 赋值的对象，也是 AppKit 实际发出动作的那个对象。
    /// 默认是 `item`；托管控件的子类覆盖它指向控件本身。
    open var actionHost: any TargetActionProvider { item }

    open var target: AnyObject? { get set }
    open var action: Selector? { get set }

    @discardableResult open func target(_ target: AnyObject?) -> Self
    @discardableResult open func action(_ action: Selector?) -> Self
    @discardableResult open func target(_ target: AnyObject?, action: Selector?) -> Self

    /// 直接赋 target/action 之后，让子类丢掉自己那份类型特化的闭包处理器。
    /// 覆盖实现**只能清自己的存储** —— 在这里回头写 `action` / `target` 会形成重入。
    open func clearActionBlockStorage() {}
}
```

`TargetActionProvider` 用 `UIFoundationToolbox` 里现成的那个（`NSToolbarItem` 与 `NSControl`
都已遵循），不新造协议。

七个类改为继承它，各自只剩类型特化的 `actionBlock` / `onAction`（约 12 行），以及必要时的
`actionHost` 覆盖：

| 类 | `actionHost` |
|----|--------------|
| `Item` / `View` / `Menu` / `Group` | 默认（`item`） |
| `Button` / `PopUpButton` | `button` |
| `SegmentedControl` | `segmentedControl` |

**`Search` / `TrackingSeparator` / `Navigation` 不动**，继续直接继承 `ToolbarItem`。这是选中间
基类而不是直接往 `ToolbarItem` 上加的**唯一理由**：实测 `NSToolbarItem` 的 `target` / `action`
会 forward 到 custom view，而 `Navigation` 的 `_item.view` 就是它那个内部 `segmentedControl`。
把 target/action 放进 `ToolbarItem`，等于给 [0004](0004-appkit-navigation-toolbar-item.md) 明确
定死的「`segmentedControl` 的 target/action 只在 `init` 里接一次、外部没有任何有类型的门可以进」
开一扇后门 —— 那条契约一破，分段菜单会退化成单击弹出、单步导航静默消失。`Search` 同理（它由
delegate 驱动，暴露 target/action 只会指向它的 `NSSearchField`）。

### 二、`ToolbarItem` 基类补两个转发属性

```swift
open var isBordered: Bool { get { item.isBordered } set { item.isBordered = newValue } }
@discardableResult open func isBordered(_ isBordered: Bool) -> Self

@available(macOS 11.0, *) open var isNavigational: Bool { ... }
@available(macOS 11.0, *) @discardableResult open func isNavigational(_ isNavigational: Bool) -> Self
```

链式方法名取 `isBordered(_:)` / `isNavigational(_:)`，对齐基类既有的 `isDefault(_:)` /
`isSelectable(_:)` / `isImmovable(_:)` / `isEnabled(_:)`，而不是 `NSToolbar.Item` 上那个异类
`bordered(_:)`。

三个旧方法**标弃用、不删**：

| 位置 | 旧 | 新 |
|------|----|----|
| `NSToolbar.Item.bordered(_:)` | 写 `_item.isBordered` | `@available(*, deprecated, renamed: "isBordered(_:)")` |
| `NSToolbar.Item.isNavigational(_:)` | 写 `_item.isNavigational` | 继承基类同名方法，旧的删（签名相同，无法并存） |
| `NSToolbar.Button.bordered(_:)` | 写 `button.isBordered` | `@available(*, deprecated, renamed: "isBordered(_:)")` |

`NSToolbar.Item` 自己的 `isBordered` / `isNavigational` **属性**删掉，改为继承基类的（`_item`
就是 `item`，行为逐字相同）。`Navigation` 内部那行 `_item.isNavigational = true` 改走基类属性。

> 第二行是个例外：`isNavigational(_:)` 的旧签名与基类新签名完全一致，Swift 里无法同时存在一个
> 弃用的和一个继承的，只能删。它是窄接口，本地无任何调用点。
>
> 落地时顺带修正了一处既有的可用性标注：SDK 里 `NSToolbarItem.navigational` 是
> `API_AVAILABLE(macos(11.0))`，而 `NSToolbar.Item` 上抄成了 `@available(macOS 12.0, *)`，紧了
> 一个版本。基类按 SDK 标 11.0。

### 三、两条实测（macOS 26 SDK 探针，非推断）

1. **`NSToolbarItem.isBordered` 的 setter 会 forward 到 custom view。** `item.view` 设成
   `isBordered == false` 的 `NSButton`，再设 `item.isBordered = true`，读回 `button.isBordered
   == true`。SDK 头文件注释只写「When set on an item without a custom view…」，实测比注释宽。
   这条是 `NSToolbar.Button.bordered(_:)` 可以安全指向基类 `isBordered(_:)` 的依据 —— 两者对
   托管 `NSButton` 的效果一致，不是两个语义撞名。
2. **`target` / `action` 同样 forward 到 custom view。** 这条既证明 `NSToolbar.View` 现在把
   target/action 写在 `_item` 上是对的（会到达 view），也正是上面必须把 `Navigation` 挡在中间
   基类之外的原因。
3. `any TargetActionProvider` 可作为存在类型读写 `target` / `action` —— 该协议带
   `typealias ActionBlock = (Self) -> Void`，但 typealias 不构成 Self requirement。

三条都由一个一次性探针跑出，结论固化进测试（见下），探针不入库。

### 三点五、落地时发现并一并修掉的既有 bug：`init(…, action:)` 从未接线

改造过程中编译器指出 `SegmentedControl.commonInit()` 里有一行孤零零的 `installAction()`，追下去
是一个真 bug。

**属性观察器不会为「initializer 内部的赋值」触发**（实测：自有存储属性的 `didSet` 在 `init` 里
赋值时不触发，即使赋值发生在 `super.init()` 之后；而 `override` 继承属性的观察器、以及
`convenience init` 里的赋值**会**触发）。旧实现的 `actionBlock` 正是「存储属性 + `didSet` 里装
trampoline」，于是 `init(…, action:)` 这个便捷参数**把闭包存下来了，却什么也没接线** —— 点下去
毫无反应，且不报错。

影响面精确到两个类：带 `action:` init 参数的只有 `Item` / `Button` / `SegmentedControl` 三个
（`Menu` / `Group` / `PopUpButton` / `View` 的 init 压根没有这个参数），其中 `SegmentedControl`
因为 `commonInit()` 里补了第二次 `installAction()` 而侥幸正确 —— 原作者显然踩到过，但只在一个类
上打了补丁。

本次把 `actionBlock` 改成「计算属性 + 私有存储」后，setter 在 `init` 中必定执行，两个类自动修复；
`SegmentedControl` 那行补丁随之成为冗余，删除。回归测试
`initializerClosureIsInstalled` 覆盖这三个类，已验证它在旧形状下变红（`the initializer left the
host unwired` + `invocations → 0 == 1`），修复后转绿。

**横向排查同一模式**（「`didSet` 属性在 initializer 里被赋值」）扫过全部 `Sources/`，8 个候选
全部安全，无需改动：两个 `placeholderString` 与 `MaterialLoadingIndicator.color` 是 `override`
（观察器会触发）；`ModernSegmentedControl.controlTintColor` 走 `convenience init`（同样触发）；
`NavigationDimmingView.color` 的 `didSet` 只置 `needsDisplay`；`SystemHUD.configuration` 与
`ContentView.configuration` 由构造参数与 init 末尾的 `reloadConfiguration()` 覆盖；
`TabButton.style` 由 `TabButtonCell(textCell:style:)` 的构造参数覆盖。

### 四、源码兼容性与下游

以新增为主。破坏面三处，均已评估为零实际影响：

- 七个类的直接父类由 `ToolbarItem` 变为 `ActionableToolbarItem`。`ToolbarItem` 仍在继承链上，
  `is` / `as?` / `[ToolbarItem]` 全部不受影响；只有「声明一个继承自这七个类之一并覆盖
  `action` / `target` 的外部子类」会受影响，无已知实例。
- `action` / `target` 由子类的 `public var` 变成继承来的 `open var`，调用点写法不变。
- 三个 `bordered` / `isNavigational` 方法：两个弃用、一个删（理由见上）。

**下游点名**：Toolbar DSL 目前的唯一消费者是 **XCOrganizer**
（`XCOrganizer/Main/MainWindowController.swift:170-210`）。它用到 `NSToolbar.Button` /
`.View` / `.SegmentedControl` / `.Search`，一处 `bordered` 都没用。它走的是**远程版本依赖**
（`.package(url: …/UIFoundation, from: "0.31.0")`），所以本次改动要等它升版本才会到达，届时
编译不会断，`reindexItem` 那个局部变量则可以并回 builder（本提案落地时**不**顺手改它，那是另一个
仓库的批次）。RuntimeViewer / MachOKitUI / PrivateSymbols 均未使用该 DSL。

**注意 `init(…, action:)` 的行为在升版本后会变**：见「三点五」，那个参数此前是死的。若 XCOrganizer
之类的下游曾经因为「传了 action 却没反应」而改用别的写法绕过，升级后会变成**两条路都接上**。目前
已知的唯一消费者没有这样绕过（它用的是 `reindexItem.action = #selector(...)` 属性赋值）。

ABI 兼容性：不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 五、测试与文档

新增 `Tests/UIFoundationTests/ToolbarItemActionTests.swift`：

- 链式 `target(_:action:)` 落到正确的 `actionHost`（`Button` → `button`，`SegmentedControl` →
  `segmentedControl`，`Menu` → `item`）。
- `actionBlock` 与直接赋 target/action 互斥：设了闭包再赋 selector，闭包被清掉且 trampoline 不
  残留；反向亦然。
- 把实测 1 与 2 固化成 canary：view-based item 上 `isBordered` / `target` / `action` 的 forward
  行为一旦被某个 macOS 版本改掉，这里先红。

文档：本库没有 Toolbar DSL 的独立使用指南（只有 `ToolbarNavigation.md` 讲 `Navigation` 一项），
本次**不新建**指南；`AGENTS.md`（`CLAUDE.md` 是它的符号链接）的「Toolbar DSL」一节补了三段：两层
基类的分工与 `actionHost`、哪三个类不在中间基类里及其原因、以及「不要把 `actionBlock` 改回带
`didSet` 的存储属性」这条警告。判断记在下面的决策日志里。

落地验证（全部实跑，退出码取自原始进程而非 xcsift 摘要）：

| 项 | 结果 |
|----|------|
| `swift build`（默认 trait） | 通过 |
| `swift build --traits`（12 个 trait 全开） | 通过，5 个警告全部是既有的、与本次无关（Filter / StatusItemController / TabBar），无新增弃用警告 |
| `swift test` | 143 passed / 0 failed，退出码 0，零警告 |
| 回归测试在旧形状下 | 红（`the initializer left the host unwired`） |
| 示例 app（`xcodebuild`） | BUILD SUCCEEDED，退出码 0 |

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-08 | 创建为 Draft | 用户报告两处缺口：`ToolbarItem` 没有 `isBordered` 属性与便捷方法；托管自定义 view（如 `Button`）的 item 没有 target/action 便捷方法，只能赋值属性 |
| 2026-09-08 | target/action 下沉到**新中间基类** `ActionableToolbarItem`，而不是 `ToolbarItem` | 实测 `NSToolbarItem` 的 target/action 会 forward 到 custom view；放进 `ToolbarItem` 就等于给 `Navigation` 的内部 `segmentedControl` 开后门，与 0004 定死的封闭性冲突。备选「放 `ToolbarItem` + 给三个类各写 unavailable 覆盖」被否：约 15 个覆盖，且破坏 LSP |
| 2026-09-08 | 也否掉「不动结构、六个类各手写三个链式方法」 | 那是把 6 份 45 行样板扩成 6 份 60 行样板，缺口的成因本身就是样板复制 |
| 2026-09-08 | 基类链式方法命名 `isBordered(_:)` / `isNavigational(_:)`，不用 `bordered(_:)` | 对齐既有 `isDefault(_:)` / `isSelectable(_:)` / `isEnabled(_:)`；同时避开与 `NSToolbar.Button.bordered(_:)` 的同签名冲突（后者写的是 `NSButton.isBordered`） |
| 2026-09-08 | 两个 `bordered(_:)` 标弃用而非删除；`Item.isNavigational(_:)` 只能删 | 用户选定「旧名标 deprecated」。`isNavigational(_:)` 签名与基类新方法完全一致，无法与继承版并存，是这条规则的唯一例外 |
| 2026-09-08 | `isNavigational` 与 `isBordered` 同批上提 | 二者性质相同（都是 `NSToolbarItem` 基类属性、都只长在 `NSToolbar.Item` 上），分两次做会留下一个说不清的不对称 |
| 2026-09-08 | 不新建 Toolbar DSL 使用指南，只更新 `CLAUDE.md` | 本次改的是 API 形状而非宿主契约，且 DSL 整体尚无指南 —— 补一篇完整指南是另一件事，不搭在这次上 |
| 2026-09-08 | Draft → In Progress | 用户批准「开工」；`actionHost` 那条 get-only 存在类型可直接赋成员已实测通过，设计形状不变 |
| 2026-09-08 | 修掉 `init(…, action:)` 从未接线的既有 bug，并删除 `SegmentedControl` 里那行补丁 | 编译期暴露：`didSet` 不为 initializer 内的赋值触发（实测），改用计算属性后 setter 必定执行。属于本次改造的直接副产品，不修反而要为它写一段「为什么这里仍然是坏的」 |
| 2026-09-08 | 横向排查「`didSet` 属性在 init 里被赋值」全库 8 个候选，判定全部安全、不改动 | override 属性与 convenience init 的观察器会触发（实测），其余各有别的路径覆盖。结论写进提案「三点五」，避免下次重查 |
| 2026-09-08 | `isNavigational` 的可用性由 12.0 更正为 11.0 | SDK 是 `API_AVAILABLE(macos(11.0))`，旧标注紧了一个版本 |
| 2026-09-08 | 不写配套指南，不新增术语 | 本次改的是 API 形状，Toolbar DSL 整体尚无指南；无新概念需要进 `Glossary.md` |
| 2026-09-08 | In Progress → Implemented，落地时分配编号 0019 | 实现、测试与文档同批次提交；编号按落地规则取共享分支上的全局最大值 +1（origin/main 与本地均为 0018） |
