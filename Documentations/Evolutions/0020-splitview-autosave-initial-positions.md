# 0020 - NSSplitView：autosave 之上的「仅首次」分隔线初始位置

- **状态**: Implemented
- **创建日期**: 2026-09-08
- **最后更新**: 2026-09-08

## 摘要

「第一次打开时按设计稿摆好分隔线，之后一律听用户的」是每个多栏窗口都要写一遍的需求，AppKit
只给了 `autosaveName` 的后半段 —— 有存档就恢复，没存档就均分，**没有任何入口能插进「没存档
时用我给的位置」**。宿主只能自己去 `UserDefaults` 里摸 AppKit 的私有 key 来判断是不是首次。
本库已经为 `NSWindow` 做过完全同构的一件事（`NSWindow.box.restoreFrame(autosaveName:
defaultSize:centerInScreen:)`），`NSSplitView` 这一侧还是空的。

RuntimeViewer 里手写的那份是这个模式的现状代表，它同时暴露了三个只有翻 AppKit 二进制才能确认
的细节 —— key 的确切格式、「重设 autosaveName 才会重新恢复」的短路、以及一个**会静默失效的
判据**。本提案把这三件事一次性固化成 `UIFoundationToolbox` 的一个 `.box` 扩展。

## 方案

### 一、三条实测（macOS 26.5.2 AppKit，IDA 反编译，非推断）

1. **存档 key 就是 `"NSSplitView Subview Frames <name>"`。** `+[NSSplitView
   _autosaveDefaultsKeyForName:]` 的整个函数体是一句
   `[NSString stringWithFormat:@"NSSplitView Subview Frames %@", name]`。宿主手拼的那个 key
   是对的。

2. **恢复动作挂在 setter 的「值真的变了」分支里**，所以「先设 `nil` 再设名字」是必要的，不是
   迷信：

   ```objc
   - (void)setAutosaveName:(NSString *)newName {
       if (![newName isEqualToString:_autosaveName]) {
           _autosaveName = [newName copy];
           [self _restoreFromAutosaveName];      // 恢复只在这个分支里发生
           [self invalidateRestorableState];
       }
   }
   ```

   把同一个名字再赋一遍是纯 no-op。`_restoreFromAutosaveName` 自身以 `_autosaveName.length != 0`
   开路，故中途那次 `nil`（等价地，空串）不会有副作用。

3. **「key 存在」不等于「恢复会成功」，而这正是现状判据的洞。**
   `_restoreFromAutosaveName` 把存档交给 `_walkLayoutDescriptionArray:withFrameHandler:`，后者
   有四条早退，任何一条不满足就整个放弃恢复且无任何日志：

   | 条件 | 不满足时 |
   |------|----------|
   | 存的值是 `NSArray` | 返回 `false` |
   | **`saved.count == self.arrangedSubviews.count`** | 返回 `false` |
   | 数组非空 | 返回 `false` |
   | 至少一个元素是 `NSString` 且按 `", "` 拆出 ≥ 5 段 | 返回 `false` |

   第二条是实际会踩的那条：pane 数量变过（版本升级新增了 inspector，或某个 pane 是条件性添加
   的）之后，旧存档数量对不上，AppKit 静默放弃恢复；而「key 在不在」这个判据会把这种情况判成
   「不是首次」，于是**初始位置也不应用**，最终落到 AppKit 的默认均分。症状看起来像
   「autosave 坏了」，且只在升级后出现。

   顺带记两条边界，用于写文档而非改实现：`setPosition(_:ofDividerAt:)` 会把位置 clamp 到该
   divider 的合法拖动范围（受各 pane 的 min/max 与 delegate 的
   `splitView:constrainSplitPosition:ofSubviewAt:` 影响），落进折叠阈值还会触发折叠；且 divider
   index 在 RTL 下由 `_logicalDividerIndexForVisualIndex:` 映射（`count - index - 2`）。两者都是
   `setPosition` 自身的语义，本 API 原样转交、不额外镜像。

### 二、新增 `Sources/UIFoundationToolbox/AppKit/NSSplitView+.swift`

```swift
extension NSSplitView {
    /// 用户还没拖出任何值得恢复的东西时，分隔线所在的位置。
    public enum InitialDividerPosition: Hashable, Sendable {
        /// 沿分割轴、从起始边量起的距离 —— 即 `setPosition(_:ofDividerAt:)` 本身收的那个值。
        case distanceFromStart(CGFloat)
        /// 从末端边量起的距离，也就是最后一条分隔线之后那个 pane 的初始厚度。
        case distanceFromEnd(CGFloat)
        /// 占分割轴长度的比例。
        case fractionOfLength(Double)
    }
}

extension FrameworkToolbox where Base: NSSplitView {
    /// 复刻 AppKit 的校验，回答「这个 autosave 名字下有没有一份真能用的存档」。
    public func hasRestorableDividerPositions(autosaveName: NSSplitView.AutosaveName) -> Bool

    /// 注册 `autosaveName`；只有在没有可用存档时才应用 `initialPositions`。
    /// 返回值为 `true` 表示位置来自存档，`false` 表示应用了初始位置。
    @discardableResult
    public func restoreDividerPositions(
        autosaveName: NSSplitView.AutosaveName,
        initialPositions: [NSSplitView.InitialDividerPosition]
    ) -> Bool
}
```

枚举比提案初稿多一个 `case unchanged`：位置按数组下标对应 divider，没有它就无法「只设首尾、跳过中间」
（三 pane 时首尾恰好是 divider 0 和 1，四 pane 起就需要跳）。

调用点（对应现状那 15 行）：

```swift
splitView.box.restoreDividerPositions(
    autosaveName: "…",
    initialPositions: [
        .distanceFromStart(Self.sidebarMinimumWidth),
        .distanceFromEnd(Self.inspectorMinimumWidth),
    ]
)
```

**没有 `@resultBuilder` 重载 —— 初稿写的那个语法编译不过。** 实测（Swift 6.2）：result builder
闭包里的裸隐式成员链解析不出上下文类型（`cannot infer contextual base in reference to member`），
泛型 builder、非泛型 builder、`buildPartialBlock` 与可变参数 `buildBlock` 四种写法全部失败，与
重载无关。上了 builder 反而要在每一行写全 `NSSplitView.InitialDividerPosition.distanceFromStart(…)`，
数组字面量则保留点语法。

`.distanceFromEnd` 免掉了手算 `bounds.width - x`，这也是宿主之所以要自己找延迟时机的唯一原因。

实现三步，与手写版逐条对应：

1. **在注册名字之前**读 `UserDefaults`，按上面四条校验算出 `hasRestorable`。
2. `base.autosaveName = nil` 再 `base.autosaveName = autosaveName`，强制走一次
   `_restoreFromAutosaveName`。
3. `hasRestorable == false` 时按数组顺序（divider 0、1、2……）依次 `setPosition`。顺序有意义
   —— 每次调用都会被 clamp，与手写版的行为一致。

`hasRestorableDividerPositions` 单独公开，因为宿主可能想在「没有存档」时做的不止是摆分隔线
（例如同时决定某个 pane 要不要初始折叠）。

### 三、时机：同步优先，宽度为 0 时补一次 async

`.distanceFromEnd` 与 `.fractionOfLength` 需要分割轴长度，而 `viewDidLoad` 时它还是 0 —— 这正是
手写版包一层 `DispatchQueue.main.async` 的原因。API 内部改成：分割轴长度 > 0 就同步应用（在
`viewDidLayout` 里调即走这条），否则 `DispatchQueue.main.async` 补一次；补那次若仍为 0，则只应用
不依赖长度的 `.distanceFromStart`，不再重试。

**不做**「观察 frame 变化直到拿到非零宽度」那一档：`.box` 扩展没有生命周期可挂，要做就得引入
observer 与其存续管理，超出 toolbox 小工具的定位。取舍记在决策日志里。

### 四、测试

新增 `Tests/UIFoundationTests/SplitViewAutosaveTests.swift`：

- **核心用例**：存档 count 与 `arrangedSubviews.count` 不匹配时 `hasRestorableDividerPositions`
  为 `false`，且 `restoreDividerPositions` 确实回退去应用初始位置。这是本提案存在的理由，也是
  现状唯一会静默出错的路径。
- 格式合法且 count 匹配 → `true`；存的不是数组、空数组、元素段数不足 → `false`。
- `.distanceFromEnd` / `.fractionOfLength` 的换算在水平与垂直两种 `isVertical` 下都正确。
- 延迟路径**用 `setPosition(_:ofDividerAt:)` 的 spy 子类断言**，不断言最终布局：实测从 0 宽 frame
  长起来的 NSSplitView 会进入 AppKit 自己会报警的不一致状态（`-resizeSubviewsWithOldSize: ... left
  the arranged view frames in an inconsistent state`）并从此完全不响应 `setPosition`，
  `adjustSubviews()` 也救不回来；换 `NSSplitViewController` 装进无窗口的 `NSWindow` 同样不成立。
  摆 pane 本来就是 AppKit 的职责，本模块的职责是「在正确的时机、用正确的长度发出调用」，spy 断的
  正是这一条。
- **key 前缀 canary**：让 AppKit 自己存一次（`setPosition` 后过一轮 run loop，`autosaveDelayed`
  标志决定何时落盘），断言落到的 key 就是 `"NSSplitView Subview Frames <name>"`。AppKit 哪天改
  key 格式，这里先红。实现时若这条在无窗口的测试进程里不稳定，降级为直接断言本库拼 key 的辅助
  函数，并在测试里注明原因。

测试全程只碰自己造的 autosave 名字，用后清掉，不污染 `UserDefaults.standard` 的其它键。

### 五、兼容性与下游

纯新增，无任何签名改动。源码兼容性：完全兼容。ABI 兼容性：不适用 —— 本库以 SPM 源码分发，使用
方每次重新编译。不加 trait（与 `NSWindow+.swift` 同属 `UIFoundationToolbox`，纯公开 AppKit）。

**下游点名**：**RuntimeViewer** 是直接受益者，它现在那 15 行手写版可以整段换掉，并顺带修掉第
三条实测里的洞 —— 但**本次不改 RuntimeViewer**，那是另一个仓库的批次。MachOKitUI、
PrivateSymbols、XCOrganizer 均未使用 `NSSplitView` 的 autosave，不受影响。

### 六、文档

**不新建使用指南**：这是一个方法加一个三情况枚举，`NSWindow.box.restoreFrame` 这个同构 API
也没有指南，为它单开一篇会与既有的粒度不一致。三条实测的结论写进源码 doc comment（尤其是第
三条，它解释了为什么校验要复刻而不是 `array(forKey:) != nil`），完整依据留在本提案。
`CLAUDE.md` 的「`.box` 命名空间扩展」一节补一行提及该 API 与「首次判据不能只看 key」这一句。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-08 | 创建为 Draft | 用户给出 RuntimeViewer 里的手写实现，指出「只设第一次的位置、之后走自动保存」是反复出现的需求 |
| 2026-09-08 | 做成 `FrameworkToolbox where Base: NSSplitView` 的 `.box` 扩展 | 用户选定。与既有的 `NSWindow.box.restoreFrame(autosaveName:defaultSize:)` 完全同构，裸 `NSSplitView` 与 `NSSplitViewController` 都能用；备选「做在 `XiblessSplitViewController` 上」被否 —— 只有用该基类的场景受益 |
| 2026-09-08 | 首次判据复刻 AppKit 的完整校验，不用 `array(forKey:) != nil` | 用户选定。实测 `_walkLayoutDescriptionArray:` 在 `saved.count != arrangedSubviews.count` 时静默放弃恢复，而只看 key 会把这种情况判成「非首次」，导致既不恢复也不应用初始位置，落到默认均分 |
| 2026-09-08 | 初始位置用 divider 模型（三种表达），不用「逐个 pane 声明厚度」模型 | divider 模型与 `setPosition(_:ofDividerAt:)` 一一对应，读起来即所见；pane 厚度模型必须为「剩余空间」那个 pane 造一个 `nil` 之类的空洞表达 |
| 2026-09-08 | 提供 `.distanceFromEnd` | 手写版里 `bounds.width - inspectorMinimumWidth` 那一项正是宿主需要自己找延迟时机的唯一原因；把它变成声明式表达，时机问题一并收进 API |
| 2026-09-08 | 时机策略取「同步优先 + 一次 async 兜底」，不引入 frame 观察 | 与手写版等价，且已在 RuntimeViewer 上验证够用；观察方案要引入 observer 存续管理，与 toolbox 无状态小工具的定位冲突 |
| 2026-09-08 | RTL 与 clamp 行为原样转交 `setPosition`，不做补偿 | 二者都是 `setPosition(_:ofDividerAt:)` 自身的语义（divider index 在 RTL 下经 `_logicalDividerIndexForVisualIndex:` 映射，位置受 pane 约束与 delegate clamp）；在其上再加一层镜像只会与宿主直接调用 `setPosition` 的结果不一致 |
| 2026-09-08 | 不新建使用指南，只补 `CLAUDE.md` 一行 | 同构的 `NSWindow.box.restoreFrame` 也无指南，单开一篇会破坏既有粒度；三条实测结论进 doc comment，完整依据留本提案 |
| 2026-09-08 | 本批次不改 RuntimeViewer | 跨仓库改动另开批次，与 0014 的做法一致 |
| 2026-09-08 | 状态 Draft → Accepted | 用户批准（「开工」），三处自决项（不新建指南、本批次不改 RuntimeViewer、RTL 与 clamp 原样转交）均未被推翻 |
| 2026-09-08 | 去掉 `@resultBuilder` 重载，只留数组版 | 实测 result builder 闭包里的裸隐式成员链无法解析上下文类型，四种 builder 写法全部失败；保留 builder 会逼调用方在每行写全枚举名，比数组字面量更差 |
| 2026-09-08 | 枚举补 `case unchanged` | 位置按数组下标对应 divider，缺了它「只设首尾、跳过中间」无法表达（四 pane 起就会遇到）；一行成本，补掉一个真实的表达空洞 |
| 2026-09-08 | 延迟路径改用 `setPosition` 的 spy 断言，不断言最终布局 | 实测从 0 宽长起来的 NSSplitView 进入 AppKit 自陈的不一致状态并停止响应 `setPosition`（`adjustSubviews()` 无效），`NSSplitViewController` + 无窗口 `NSWindow` 亦然。布局是 AppKit 的职责，调用时机与长度才是本模块的 |
| 2026-09-08 | 测试里不再用 `RunLoop.run(until:)` 等主队列 | 测试体本身就跑在 main queue 的一个 block 里，而 main queue 是串行的 —— 排在它后面的 block 必须等它返回或挂起，在其内部转 run loop 无济于事。实测：给 run loop 挂个 timer 让它真的跑满 50 ms，block 依然没执行；`await Task.sleep` 挂起后才执行。与 sync / async 无关，两种测试体表现一致。另有一个独立的坑：不挂 input source 时 `run(until:)` 只跑 2 µs 就返回，压根没转起来。顺带确认 AppKit 的 autosave 是同步写入，那两处等待本就多余 |
| 2026-09-08 | 落地：实现 + 15 个测试 + `CLAUDE.md` 一节，149 个测试与全 trait 构建均通过 | 变异验证：把校验换回朴素的 `array(forKey:) != nil`，3 个测试红、6 处 issue，确认核心用例真的抓得住这个 bug |
| 2026-09-08 | 状态 → Implemented，落地时分配编号 0020 | 0019 已被并行推进的 ToolbarItem 提案占用。文档同步判断：**需要**，`AGENTS.md` 的 `.box` 一节已在同批次补上；**不新建**使用指南（理由见「六、文档」）；**无新术语**，术语表不动 |
