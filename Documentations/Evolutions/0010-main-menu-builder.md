# 0010 - MainMenu.Builder：按 identifier 增删改标准主菜单

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-22
- **最后更新**: 2026-08-22
- **所属愿景**: 无
- **关联提案**: [0009](0009-standard-main-menu.md)（标准主菜单）
- **实现分支 / PR**: main（与本提案同批次提交）
- **配套文档**: 并入使用指南 [`Documentations/MainMenu.md`](../MainMenu.md) 的
  「Customizing the Standard Menu」一章

## 摘要

0009 落地后，改 `MainMenu.standard()` 里的**单个**项很别扭：想换掉 File▸New 的 action、删掉
Page Setup…、在 Open… 后面插一项，都得用 builder 重写形式把整个菜单逐项重列一遍。本提案
仿照 UIKit `UIMenuBuilder` 的 **Swift 接口**（`NS_SWIFT_NAME` 后的形态，非 ObjC 选择器名）
增加一个变换层：给全部标准项打上 `ItemIdentifier`，`MainMenu.standard(customizing:)` 把
构建好的菜单树交给 `MainMenu.Builder`，宿主按 identifier 查询、四向插入、替换、删除：

```swift
app.mainMenu = MainMenu.standard { builder in
    builder.remove(.format)
    builder.remove(.filePageSetup)
    builder.item(for: .applicationSettings)?.action = #selector(AppDelegate.openSettings(_:))
    builder.replace(.fileNew) {
        NSMenuItem("New Project", action: #selector(AppDelegate.newProject(_:)), keyEquivalent: "n")
    }
    builder.insertItems(after: .fileOpen) {
        NSMenuItem("Open Workspace…", action: #selector(AppDelegate.openWorkspace(_:)), keyEquivalent: "O")
    }
}
```

变换在装配层的接线（0009 的 `wireSpecialMenus`）**之前**执行，所以删掉 Window 菜单就不会
再接 `windowsMenu`；删除留下的孤儿分隔符由 Builder 收尾时规整。

## 动机

- **单项修改的成本与改动量完全不成比例。** 现状三层 API 里，最细的粒度是「重写一个菜单的
  全部内容」：只想把 Settings… 接上宿主 action，就要把应用菜单十一项重列一遍；只想删掉
  File▸Page Setup…，就要重列 File 十一项。重列还引入第二份事实来源 —— 0009 以后标准内容
  变了（比如跟随新模板），重列过的菜单不会跟着变。
- **这是 Apple 走过并收敛过的同一条路。** UIKit 的 `UIMenuBuilder`（iOS 13）起初只有组级
  操作（`insertChild` / `insertSibling` / `replace(menu:)` / `remove(menu:)`），**element 级
  的单项操作（`insertElements(_:beforeAction:)`、`remove(action:)`、`replace(action:with:)`）
  到 iOS 26 才补齐**（见前期调研的 SDK 头文件依据）。单项粒度是真实需求，不是过度设计。
- **0009 已经铺好了一半机制。** 特殊菜单的接线就是按 `NSUserInterfaceItemIdentifier` 扫描的
  （`MainMenu.ItemIdentifier` 现有 5 个成员）；把「有 id 的项」从 5 个推广到全部标准项，
  寻址型变换层就是它的自然延伸。

## 前期调研

- **`UIMenuBuilder` 的 Swift 接口清单**（读自 Xcode 26 iOS SDK
  `UIKit.framework/Headers/UIMenuBuilder.h` 的 `NS_SWIFT_NAME` 标注；按用户要求以 Swift 形态
  为准，ObjC 选择器名 `menuForIdentifier:` 一族不作为设计蓝本）：
  - 查询：`system`、`menu(for: UIMenu.Identifier) -> UIMenu?`、
    `action(for: UIAction.Identifier) -> UIAction?`、`command(for:propertyList:)`。
  - 替换：`replace(menu:with: UIMenu)`（13+）；`replace(menu:with: [UIMenuElement])`、
    `replace(action:with: [UIMenuElement])`（26+）；
    `replaceChildren(ofMenu:from: ([UIMenuElement]) -> [UIMenuElement])`（13+，`NS_NOESCAPE`）。
  - 插入：`insertSibling(_:before/afterMenu:)`、`insertChild(_:atStart/atEndOfMenu:)`（13+）；
    `insertElements(_:before/afterMenu:)`、`insertElements(_:before/afterAction:)`、
    `insertElements(_:atStart/atEndOfMenu:)`（26+）。
  - 删除：`remove(menu:)`（13+）、`remove(action:)`（26+）。
  - 三类寻址：`UIMenu.Identifier`（组）、`UIAction.Identifier`（action）、
    `Selector + propertyList`（command）。**command 一族全部 `NS_REFINED_FOR_SWIFT`** ——
    selector 寻址是给「没有 id 的元素」的补偿通道；UIKit 需要它，因为 command 由宿主声明、
    UIKit 不能替宿主发 id。
- **UIKit 的三类元素在 NSMenu 世界坍缩为一类。** `UIMenu`（组）/ `UIAction` / `UICommand`
  的区分源自 UIKit 菜单树是元素树；`NSMenu` 是平的 `NSMenuItem` 列表 + 手工分隔符，组即
  「带 submenu 的 item」，action / command 即「带 action 的 item」。因此 UIKit 的三套寻址
  与三套动词可以合并为一套（`item(for:)` + item 级动词），selector 寻址通道不需要 ——
  我们的标准项全部由本库构建，**每个项都可以有 id**，这是比 UIKit 更有利的前提。
- **UIKit 分隔来自组模型，我们必须显式处理。** `UIMenu` 的 inline 组在渲染时自动产生边界
  分隔；`remove(menu:)` 连边界一起消失。NSMenu 的分隔符是独立 item，删除邻近项会留下
  相邻双分隔或头尾分隔，需要变换后规整（见详细设计）。
- **现状代码**：`MainMenu.ItemIdentifier` 是 `enum` 命名空间，5 个 `static let`（`services` /
  `openRecent` / `font` / `windows` / `help`），类型为 `NSUserInterfaceItemIdentifier`
  （`Sources/UIFoundationAppKit/Menu/MainMenu.swift`）；接线扫描 `wireSpecialMenus(in:)`
  递归全树。标准项工厂共约 90 个（含子菜单叶子），分布在 `MainMenu+<菜单名>.swift` 七个
  文件。`@MenuBuilder`（`NSMenu+Builder.swift`）可直接复用为插入 / 替换的 trailing closure。
- **点缩写的类型学**（决定 Identifier 的类型设计）：若 Builder 方法参数收
  `NSUserInterfaceItemIdentifier`，调用点写 `.fileNew` 需要把常量挂在
  `extension NSUserInterfaceItemIdentifier` 上 —— 污染 AppKit 类型的全局静态命名空间，违背
  本库「顶层符号最少」惯例。UIKit 的解法就是专用包装类型（`UIMenu.Identifier` 是 struct）；
  跟随之：`ItemIdentifier` 改为 struct，静态常量挂在自身上，点缩写自然成立。

## 提议方案

三块，全部落在既有 `Sources/UIFoundationAppKit/Menu/` 下，无新 trait：

1. **`ItemIdentifier` 从 enum 命名空间改为 struct**（`Hashable`、`RawRepresentable`，
   `rawValue: String` 采用 `"UIFoundation.MainMenu.file.new"` 层级串），并给**全部约 90 个
   标准项**打上 identifier —— 顶层七菜单、每个菜单的直接子项、以及 Find / Spelling /
   Substitutions / Transformations / Speech / Font / Text / Kern / Ligatures / Baseline /
   Writing Direction 的组与叶子。命名扁平、带菜单前缀（学 UIKit）：`.file`、`.fileNew`、
   `.editUndo`、`.formatFontBold`、`.writingDirectionParagraphHeader` ……现有 5 个成员中
   `services` / `openRecent` / `font` / `help` 名称沿用；`windows` 更名 `window`（顶层菜单
   统一单数），**不保留旧名**（用户裁定：0009 刚发布、无外部消费者，不背兼容包袱）。
2. **`MainMenu.Builder`**：持有已构建的菜单树，提供 UIKit 对应物合并后的一套 item 级动词
   （签名见详细设计）：`item(for:)` 查询、`insertItems` 四向插入（before / after /
   atStartOf / atEndOf）、`replace(_:with:)`、`replaceItems(of:from:)`、`remove(_:)`。
   寻址不到时**静默 no-op**（与 UIKit 行为一致，便于按条件启用的定制代码；显式检查用
   `item(for:)`）。宿主自定义项只要带上自己的 `ItemIdentifier` 同样可寻址。
3. **入口 `MainMenu.standard(applicationName:customizing:)`**：执行顺序
   **build → customize → wire** —— 变换先于接线，删除 Window / Help 菜单后不会残留
   `windowsMenu` / `helpMenu` 指派；变换结束时对被触碰过的菜单做**分隔符规整**（相邻分隔
   折叠为一、去掉菜单头尾分隔）。

### 非目标

- **不做 UIKit 的 responder 链重建模型**（`UIResponder.buildMenu(with:)` 由系统在菜单重建时
  回调）。AppKit 主菜单不存在系统驱动的重建周期，本提案是一次性变换；运行期动态改菜单
  仍然直接操作 `NSMenu`。
- **不做 selector 寻址**（UIKit 的 `command(for:propertyList:)` 一族）。它是给无 id 元素的
  补偿通道；本库标准项全员有 id，宿主自定义项可自带 id。
- **不给 `MainMenu.menu {}` 加 customizing 入口**。自由组合形式本来就逐项在手；如确有
  「组合完再变换」的需求，将来给 Builder 开独立入口即可，本次不做。
- **AppKit 自动插入的项（听写 / 表情、Window tab 项）不可寻址** —— 它们在 `run()` 之后由
  AppKit 注入，构建期不存在，本提案管不到（指南已有说明）。

## 详细设计

### `ItemIdentifier`

```swift
extension MainMenu {
    public struct ItemIdentifier: Hashable, RawRepresentable, Sendable {
        public let rawValue: String
        public init(rawValue: String)
        public init(_ rawValue: String)

        /// The AppKit identifier written onto the `NSMenuItem`.
        public var userInterfaceItemIdentifier: NSUserInterfaceItemIdentifier
    }
}
```

- 工厂内部通过 `userInterfaceItemIdentifier` 落到 `NSMenuItem.identifier`，Builder 查找时
  反向匹配 —— identifier 仍然是 AppKit 原生机制，宿主在 Interface Builder 或调试器里看到的
  就是 raw 串。
- `NSMenuItem+Convenience.swift` 增加重载 `.identifier(_ identifier: MainMenu.ItemIdentifier)`，
  供宿主给自定义项打可寻址 id。
- 静态常量按菜单分文件放（`MainMenu+File.swift` 里 `extension MainMenu.ItemIdentifier` 定义
  file 组常量，与该菜单的工厂同文件），完整清单：
  - 顶层：`.application` `.file` `.edit` `.format` `.view` `.window` `.help`
  - 应用菜单：`.applicationAbout` `.applicationSettings` `.services`(沿用)
    `.applicationHide` `.applicationHideOthers` `.applicationShowAll` `.applicationQuit`
  - File：`.fileNew` `.fileOpen` `.openRecent`(沿用) `.openRecentClearMenu` `.fileClose`
    `.fileSave` `.fileSaveAs` `.fileRevertToSaved` `.filePageSetup` `.filePrint`
  - Edit：`.editUndo` `.editRedo` `.editCut` `.editCopy` `.editPaste`
    `.editPasteAndMatchStyle` `.editDelete` `.editSelectAll` `.editFind`(组)
    `.editSpellingAndGrammar`(组) `.editSubstitutions`(组) `.editTransformations`(组)
    `.editSpeech`(组)，及五个组的全部叶子（`.editFindFind` `.editFindFindAndReplace`
    `.editFindNext` `.editFindPrevious` `.editFindUseSelection` `.editFindJumpToSelection`、
    `.editSpelling*` 五叶、`.editSubstitutions*` 七叶、`.editTransformations*` 三叶、
    `.editSpeech*` 两叶）
  - Format：`.font`(沿用，组) `.formatText`(组)，Font 组叶子（`.formatFontShowFonts`
    `.formatFontBold` `.formatFontItalic` `.formatFontUnderline` `.formatFontBigger`
    `.formatFontSmaller` `.formatFontKern`(组+四叶) `.formatFontLigatures`(组+三叶)
    `.formatFontBaseline`(组+五叶) `.formatFontShowColors` `.formatFontCopyStyle`
    `.formatFontPasteStyle`）、Text 组叶子（四个对齐、`.formatTextWritingDirection`(组+两个
    小节头+六个方向叶) `.formatTextShowRuler` `.formatTextCopyRuler` `.formatTextPasteRuler`）
  - View：`.viewShowToolbar` `.viewCustomizeToolbar` `.viewShowSidebar` `.viewEnterFullScreen`
  - Window：`.windowMinimize` `.windowZoom` `.windowBringAllToFront`
  - Help：`.helpApplicationHelp`
  - 分隔符不打 id、不可寻址（规整机制见下）。

### `MainMenu.Builder`

```swift
extension MainMenu {
    @MainActor
    public final class Builder {
        /// Fetch the identified item for direct property mutation.
        public func item(for identifier: ItemIdentifier) -> NSMenuItem?

        public func insertItems(_ items: [NSMenuItem], before identifier: ItemIdentifier)
        public func insertItems(_ items: [NSMenuItem], after identifier: ItemIdentifier)
        public func insertItems(_ items: [NSMenuItem], atStartOf identifier: ItemIdentifier)
        public func insertItems(_ items: [NSMenuItem], atEndOf identifier: ItemIdentifier)

        public func replace(_ identifier: ItemIdentifier, with items: [NSMenuItem])
        public func replaceItems(of identifier: ItemIdentifier,
                                 from transform: ([NSMenuItem]) -> [NSMenuItem])
        public func remove(_ identifier: ItemIdentifier)

        // Every inserting / replacing method has a @MenuBuilder trailing-closure overload:
        public func insertItems(after identifier: ItemIdentifier,
                                @MenuBuilder _ items: () -> [NSMenuItem])
        // …同形不逐列
    }
}
```

- 与 UIKit 的对应关系：`item(for:)` ≈ `menu(for:)` + `action(for:)` 合一；
  `insertItems(_:before:/after:)` ≈ `insertSibling` + `insertElements(before/after…)`；
  `insertItems(_:atStartOf:/atEndOf:)` ≈ `insertChild` + `insertElements(atStart/End…)`
  （目标 id 的项须带 submenu，否则 no-op）；`replace(_:with:)` ≈ 两个 `replace(menu:/action:with:)`；
  `replaceItems(of:from:)` ≈ `replaceChildren(ofMenu:from:)`（transform 不逃逸）；
  `remove(_:)` ≈ `remove(menu:/action:)`。
- 查找为递归全树、首个命中；变换即时生效（后续查询看到已变换的树，与 UIKit 语义一致）。
- Builder 记录被触碰过的 `NSMenu`，`standard(customizing:)` 收尾时仅对这些菜单做分隔符
  规整：连续分隔折叠为一、去除头尾分隔。未被触碰的菜单原样保留。

### 入口

```swift
extension MainMenu {
    public static func standard(applicationName: String? = nil,
                                customizing customize: (Builder) -> Void) -> NSMenu
}
```

既有 `standard(applicationName:)` 语义不变（等价于空 customize）。执行顺序
build → customize → wire → normalize；wire 仍按 identifier 扫描，因此被 Builder 移除 / 替换
的特殊菜单自然脱离或接上接线。

## 替代方案考量

- **给每个工厂加"排除/覆盖"参数**（如 `MainMenu.file(excluding: [.pageSetup])`）——
  只覆盖删除，改单项属性与插入仍要重列；参数面随需求膨胀。否。
- **常量挂在 `extension NSUserInterfaceItemIdentifier`** 换取点缩写 —— 约 90 个常量灌进
  AppKit 类型全局静态命名空间，违背库的命名空间惯例；UIKit 同样选择了专用 wrapper 类型。否。
- **叶子不打 id、提供 selector 寻址**（复刻 UIKit 的 `command(for:propertyList:)` 通道）——
  UIKit 走这条路是因为 command 是宿主的、UIKit 无法替宿主发 id；我们的标准项全部自产，
  id 零成本，而 selector 寻址在本菜单里天然歧义（Find 组五项共用 `performFindPanelAction:`
  仅靠 tag 区分）。否。
- **仿 UIKit 的 `buildMenu(with:)` responder 回调**——AppKit 无系统驱动的菜单重建周期，
  伪造一个（swizzle？通知？）只为形似。否，一次性变换即可。
- **Builder 惰性记录操作、apply 时统一执行** —— 与 UIKit「查询可见此前变换」的语义冲突，
  实现也更绕。否，直接在真实树上即时操作。

## 影响

### 源码兼容性（source compatibility）

**有破坏，用户已裁定不做兼容缓冲**（0009 于 2026-08-22 推送，已知消费者仅示例 App，
无外部依赖方）：

- `MainMenu.ItemIdentifier` 由 enum 命名空间改为 struct：`MainMenu.ItemIdentifier.services`
  等**拼写不变**，但常量类型从 `NSUserInterfaceItemIdentifier` 变为 `MainMenu.ItemIdentifier`。
  把常量赋给 `NSMenuItem.identifier` / 与之比较的调用点改用新增的
  `.identifier(_ : MainMenu.ItemIdentifier)` 重载与 `userInterfaceItemIdentifier` 属性；
  0009 指南中的示例同步更新。
- `windows` 更名 `window`：直接改名，不保留弃用别名。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- 仓库内：仅 `UIFoundationAppKit`（经 umbrella 传导到 `UIFoundation`）；示例 App 更新为
  customizing 用法示范。
- 下游仓库：RuntimeViewer / MachOKitUI / PrivateSymbols 均未消费 0009 的 API（昨日刚发布），
  无实际波及。

### 文档与示例

- `Documentations/MainMenu.md` 新增「Customizing the standard menu」一章（Builder 动词表、
  与 UIKit 的对应关系、静默 no-op 语义、分隔符规整规则、AppKit 自动插入项不可寻址的边界）；
  「The Three Levels」改为四层。
- 根 `AGENTS.md` 的 Main Menu 小节、两份索引同步。

## API 演进与废弃策略

- 破坏性改动直接落地，不设弃用期（用户裁定；包未打 tag，使用方跟 main，无 semver 约束）。

## 落地步骤

1. `ItemIdentifier` 改 struct + 全量常量 + 七个工厂文件逐项打 id +
   `.identifier(_:)` 重载 + `windows` 弃用别名；构建通过，0009 既有测试通过。
2. `MainMenu.Builder`（查找、四向插入、replace、replaceItems、remove、触碰记录、
   分隔符规整）+ `standard(customizing:)` 入口（build → customize → wire → normalize）。
3. 测试：全量 id 覆盖断言（每个标准项都可寻址且 id 唯一）、四向插入、replace /
   replaceItems / remove、no-op 语义、孤儿分隔符规整、`remove(.window)` 后不接线、
   customizing 与既有接线测试共存。
4. 示例 App：`App.main()` 改用 customizing 形式做一处真实定制（如把
   `.applicationSettings` 接到 Settings demo 的打开动作）。
5. 文档同批次：指南新章、`AGENTS.md`、索引、提案状态推进。

**收尾时必须判断两件事**（判断结果写进决策日志，不允许沉默跳过）：

- **要不要配套专题文章** —— 并入 0009 的使用指南 `MainMenu.md`（同一组件不另立新篇）。
- **有没有引入新术语** —— 待定（「触碰规整」等若成为固定用语则登记）。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-22 | Created as Draft | 用户提出：standard() 里改单个 item 太麻烦，参照 UIMenuBuilder 的 Swift 接口设计变换层。 |
| 2026-08-22 | Draft → Accepted → In Progress | 用户批准，附两条修订：① 不考虑兼容性 —— `ItemIdentifier` 直接改 struct、`windows` 直接更名 `window`，不保留弃用别名；② selector 构造统一改用 FrameworkToolbox（`FoundationToolbox` 模块）的 `#Selector(_: StaticString)` 宏 —— `Selector("…")` 直接初始化产生警告，`NSSelectorFromString` 无任何检查，宏在编译期做词法校验（非空、无空白、单段字符串），拼写残缺的 selector 直接报错；0009 已落地代码中的 `Selector(("…"))` 同批替换。 |
| 2026-08-22 | In Progress → Implemented | 全部落地：① `ItemIdentifier` 改 struct（raw 值规则 `UIFoundation.MainMenu.<常量名>`），约 90 个标准项全量打 id，常量与各菜单工厂同文件；`windows` 更名 `window`；`.identifier(_ : MainMenu.ItemIdentifier)` 重载；七个菜单文件的 selector 全部换 `#Selector` 宏（`import FoundationToolbox`，包内已有 `ToolbarItem.swift` 直接 import 传递依赖的先例，未动 `Package.swift`）。② `MainMenu.Builder`（递归寻址、四向插入、replace / replaceItems / remove、触碰记录、收尾分隔符规整）+ `standard(customizing:)` 入口（build → customize → normalize → wire）。③ 测试 15 项新增（`MainMenuBuilderTests` 用 internal `Builder(rootMenu:)` 直接构造、不触全局故可并行；接线交互测试放进 `.serialized` 的 `MainMenuTests`），全量 96 测试通过（原始退出码）。④ 示例 App 改用 customizing：File 菜单精简为只剩 Close（demo browser 无文档模型）、Settings… 接到 `AppDelegate.openSettings(_:)`；xcodebuild 构建通过。⑤ 指南新增「Customizing the Standard Menu」一章并改为四层、`AGENTS.md` 与两份索引同步。**收尾两判断**：配套专题文章 —— 并入 0009 的指南，不另立新篇（同一组件）；新术语 —— 无需登记（Builder / identifier 均沿用 UIKit 通用概念）。 |
| 2026-08-23 | 落地修订 | 用户裁定 `ItemIdentifier` 常量从扁平前缀命名（`.applicationAbout`、`.fileNew`）改为**嵌套命名空间**（`.Application.about`、`.File.new`），与工厂命名空间同构；组内叶子再嵌一层（`.Edit.Find.next`、`.Format.Font.Kern.tighten` 三层）。可行性先用探针验证：Swift 隐式成员链（SE-0287）支持以嵌套类型开头、任意深度、含 `switch case` 模式匹配 —— 这推翻了原详细设计「struct 静态成员必须挂在自身才能点缩写，故用扁平命名」的论证（当时未验证嵌套链）。raw 值同步改为层级路径（`UIFoundation.MainMenu.Format.Font.Kern.tighten`）；Baseline 的 `subscript` 叶子用反引号保留关键字原名。七个菜单文件、接线扫描、测试、示例 App、指南与 `AGENTS.md` 全量替换，97 测试通过、示例 App 构建通过。不留旧名（同 2026-08-22 的无兼容裁定）。 |
