# 0013 - MainMenu：每个多项子菜单的工厂都提供 customizing 参数

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-25
- **最后更新**: 2026-08-25
- **所属愿景**: 无
- **关联提案**: [`0009`](0009-standard-main-menu.md)（标准主菜单）、[`0010`](0010-main-menu-builder.md)（`MainMenu.Builder`）
- **实现分支 / PR**: `main`（工作区，尚未提交）
- **配套文档**: [`MainMenu.md`](../MainMenu.md) —— 新增「Where a Customization Attaches」一节

## 摘要

`MainMenu.Builder`（0010）目前只有一个入口：`MainMenu.standard(customizing:)`。也就是说
**「按 identifier 改单个项」这项能力只在「整根菜单栏」这一个粒度上存在**。本提案把同一个
`customizing customize: (Builder) -> Void` 参数补齐到每一个**产出多项子菜单**的工厂上 ——
顶层装配方法 `menu {}`、七个顶层菜单工厂（`application` / `file` / `edit` / `format` /
`view` / `window` / `help`）、七个分组子菜单工厂（`Edit.find` / `spellingAndGrammar` /
`substitutions` / `transformations` / `speech`、`Format.font` / `text`），共 15 个新重载。
同时把 `Builder` 的寻址根从「一个 `NSMenu`」扩展到「一个 `NSMenuItem` 自身 + 它的 submenu 子树」，
使 `MainMenu.file { $0.item(for: .file)?.title = "档案" }` 能改到 File 项本身。

纯新增，不动任何既有签名与行为。

## 动机

### 缺口一：`menu {}` 这条路上完全拿不到 Builder

0009 给了四级粒度，0010 给第 2 级（`standard(customizing:)`）装上了 Builder，把「改一个项要
把整个菜单重列一遍」这件事解决掉了。但第 3 级 —— `MainMenu.menu { … }` 手工挑选和排列顶层菜单 ——
**没有跟着解决**。一个宿主只要不想要完整七件套（比如不需要 Format 菜单），它就掉出了
`standard()` 的射程，于是 0010 解决过的那个复列问题原样回来了：

```swift
// 现状：想自选顶层菜单，又想删掉 File 的 Page Setup，只能把 File 整份重抄
app.mainMenu = MainMenu.menu {
    MainMenu.application()
    MainMenu.file {                 // ← 9 项全部重列，只为了少 1 项
        MainMenu.File.new()
        MainMenu.File.open()
        NSMenuItem.separator()
        MainMenu.File.close()
        MainMenu.File.save()
        MainMenu.File.saveAs()
        MainMenu.File.revertToSaved()
        NSMenuItem.separator()
        MainMenu.File.print()
    }
    MainMenu.edit()
    MainMenu.window()
    MainMenu.help()
}
```

重列的代价不只是行数：这 9 行是**对模板保真度的复制**，宿主抄漏一个 tag（Find 组的
`performFindPanelAction:` 靠 tag 区分动作）或抄错一个 selector（`print:` 而非
`printDocument:`）都不会报错，只会静默失去功能。0009 的保真笔记与 `MainMenuTests` 的逐项断言
守的正是库这一侧；宿主一旦重列，这层保护就不在了。

### 缺口二：分组子菜单没有任何定制入口

`Edit.find()` / `Edit.substitutions()` / `Format.font()` 这类工厂产出的是**多项子菜单**，
但它们既没有 `title` 参数，也没有 builder。宿主想改 Find 子菜单里的一个快捷键，只有两条路：

1. 把 6 项重列（同上，保真度的复制）；
2. 先把整棵树建好，再走 `standard(customizing:)` 从根上绕回来 —— 但这要求宿主必须用
   `standard()`，缺口一的宿主用不了；而且它把「我只是想调一下 Find 菜单」写成了对整棵主菜单的变换，
   读者要跨越整个文件才能看出这次定制的作用域其实只有一个子菜单。

### 为什么现在提

这两个缺口是同一件事的两面：**Builder 的作用域被绑死在了「整棵主菜单」上，而工厂是按菜单为单位
提供的**。粒度对不齐，宿主就只能在「全用标准」和「整份重写」之间二选一。把 customizing 参数下放到
每一个多项子菜单的工厂上，作用域就跟着工厂走了 —— 定制写在哪个菜单上，就只作用于哪个菜单。

## 前期调研

- **现状代码**：
  - `Sources/UIFoundationAppKit/Menu/MainMenu.swift:80` —— 唯一的 customizing 入口
    `standard(applicationName:customizing:)`：建树 → `Builder(rootMenu:)` → `customize` →
    `normalizeTouchedMenus()` → `wireSpecialMenus`。
  - 同文件 `:105` —— `menu(_ items:)`：建树 → `wireSpecialMenus`，中间没有变换环节。
  - `MainMenu+Builder.swift:22` —— `Builder` 目前只有 `init(rootMenu: NSMenu)`，
    `locate(_:in:)` 从 rootMenu 的 `items` 开始递归，**不检查根自身**（`NSMenu` 上也没有
    identifier 可检查）。
  - 七个顶层菜单工厂各有两个重载（标准内容 / 自定义内容），形如
    `MainMenu+File.swift:35` 与 `:53`。
  - 分组工厂：`Edit.find()`（6 项）、`spellingAndGrammar()`（6 项）、`substitutions()`（8 项）、
    `transformations()`（3 项）、`speech()`（2 项）、`Format.font()`（15 项）、
    `Format.text()`（10 项）—— 全部为多项子菜单，全部无定制入口。
  - `Application.services()` 的 submenu 为**空**（内容由 AppKit 在接线后填充），
    `File.openRecent()` 的 submenu **只有 Clear Menu 一项**。

- **重载消歧实测**（关键前提，2026-08-25，Swift 6.2 / macOS 26）：三个重载共存
  （无闭包 / `@MenuBuilder` 内容闭包 / `customizing` 闭包）时，尾随闭包能靠**闭包有没有参数**
  正确消歧。四种形态全部编译通过且选中预期重载：

  | 写法 | 选中 |
  |------|------|
  | `M.file { Item("New") }` （单表达式内容） | 内容重载 |
  | `M.file { Item("New"); Item("Open") }` （多语句内容） | 内容重载 |
  | `M.file { builder in builder.remove(1) }` | customizing 重载 |
  | `M.file { $0.remove(2) }` | customizing 重载 |

  单表达式那一行是真正的风险点 —— `{ Item("New") }` 在 `(Builder) -> Void` 上下文里也是合法的
  （参数可省略、结果可丢弃），所以专门测了；实测不歧义。这条决定了**可以用重载而不必用
  默认参数**（见「替代方案考量」）。

- **`Builder.locate` 是全树递归**，因此分组工厂的 customizing 不需要为内联的 Kern / Ligatures /
  Baseline / Writing Direction 另开工厂 —— `MainMenu.Format.font { $0.remove(.Format.Font.Kern.tighten) }`
  直接可用。

- **本仓库内的既有调用点**（`Tests/UIFoundationTests/MainMenu{,Builder}Tests.swift`、
  `UIFoundationExample-macOS/.../AppDelegate.swift:13`）共 20 余处，其中
  `MainMenuTests.swift:194` 的 `MainMenu.window { MainMenu.Window.minimize() }` 正是上表第一行
  的真实形态。全套测试编译通过即为「新重载没有改变既有解析」的守卫。

## 提议方案

### 一、15 个 customizing 重载

在既有的「标准内容」重载旁各加一个「标准内容 + 定制」重载。判据是用户给定的规则：
**产出的 submenu 有多个 item 才提供**。

| 层级 | 方法 | 新签名 |
|------|------|--------|
| 装配 | `menu` | `menu(_ items:customizing:)`（第二个尾随闭包） |
| 顶层菜单 | `application` | `application(applicationName:customizing:)` |
| 顶层菜单 | `file` / `edit` / `format` / `view` / `window` | `xxx(title:customizing:)` |
| 顶层菜单 | `help` | `help(applicationName:title:customizing:)` |
| 分组 | `Edit.find` / `spellingAndGrammar` / `substitutions` / `transformations` / `speech` | `xxx(customizing:)` |
| 分组 | `Format.font` / `Format.text` | `xxx(customizing:)` |

### 二、Builder 的根扩展到「菜单项自身」

`Builder` 增加一条以 `NSMenuItem` 为根的初始化路径：寻址时**先比对根项自身的 identifier**，
再递归它的 submenu。这样 `.file` / `.Edit.find` 这些「菜单项本身」的 identifier 在对应工厂的
customizing 闭包里可寻址，宿主能改标题、快捷键、图标 —— 对没有 `title` 参数的分组工厂来说，
这是唯一途径。

### 非目标

- **不给 `Application.services()` 加** —— submenu 为空，内容由 AppKit 在接线后填充，给一个
  customizing 等于承诺一件做不到的事。
- **不给 `File.openRecent()` 加** —— submenu 只有 Clear Menu 一项，不满足判据。
- **不给单项工厂加**（`Edit.undo()` 等约 70 个）—— 它们不构造菜单，返回值就是那个项，
  直接用链式修饰符改即可。
- **不给「自定义内容」重载加**（`file(title:) { 自己写的 items }`）—— 内容既然是现写的，
  直接写对就行，不需要事后再按 identifier 找回来改。
- **不给分组工厂加 `title` 参数** —— 改标题走 builder，不为一件事再开一路参数。
- **不新增** Kern / Ligatures / Baseline / Writing Direction 的独立工厂 —— 全树递归的寻址
  已经够到它们了。
- **不改任何既有签名、默认值与运行时行为**。

## 详细设计

### `Builder` 的双根

```swift
extension MainMenu {
    public final class Builder {
        // 既有
        init(rootMenu: NSMenu)
        // 新增：以一个菜单项为根，寻址范围 = 该项自身 + 它的 submenu 子树
        init(rootItem: NSMenuItem)
    }
}
```

根项自身可被 `item(for:)` 命中，因此可直接改属性。四个「需要容器菜单」的动词对**根项自身**
无处施为，按 0010 已有的「寻址不到就静默 no-op」契约处理，不新增报错路径：

| 动词 | 作用于根项自身时 |
|------|-----------------|
| `item(for:)` | ✅ 返回根项 |
| `insertItems(atStartOf:)` / `insertItems(atEndOf:)` | ✅ 作用于根项的 submenu |
| `replaceItems(of:from:)` | ✅ 作用于根项的 submenu |
| `insertItems(before:)` / `insertItems(after:)` | 静默 no-op（根项没有容器菜单） |
| `replace(_:with:)` / `remove(_:)` | 静默 no-op（同上） |

作用于**子树内**任何项的动词一律照常工作。

### 顶层菜单工厂

```swift
extension MainMenu {
    public static func file(title: String = "File") -> NSMenuItem                    // 既有
    public static func file(title: String = "File",
                            @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem  // 既有
    public static func file(title: String = "File",
                            customizing customize: (Builder) -> Void) -> NSMenuItem  // 新增
}
```

新增重载的实现形状对 15 个方法完全一致：**先建标准内容，再交给 Builder 变换，最后规整被
碰过的菜单**：

```swift
public static func file(title: String = "File", customizing customize: (Builder) -> Void) -> NSMenuItem {
    let fileItem = file(title: title)
    let builder = Builder(rootItem: fileItem)
    customize(builder)
    builder.normalizeTouchedMenus()
    return fileItem
}
```

### 装配方法

`menu` 的 customizing 是**第二个尾随闭包**，读起来是「先声明菜单，再改它」，与执行顺序一致：

```swift
public static func menu(@MenuBuilder _ items: () -> [NSMenuItem],
                        customizing customize: (Builder) -> Void) -> NSMenu
```

```swift
app.mainMenu = MainMenu.menu {
    MainMenu.application()
    MainMenu.file()
    MainMenu.help()
} customizing: { builder in
    builder.remove(.File.pageSetup)
}
```

顺序契约与 `standard(customizing:)` 完全一致：**变换先于接线**。因此在 `menu {}` 的 customizing
里删掉 Window 菜单，不会留下悬空的 `NSApp.windowsMenu`。

### 工厂层 customizing 与接线的关系

工厂（`file()` / `Format.font()` 等）**本身不接线** —— 接线只发生在 `standard()` / `menu {}`
的装配步骤（0009 的既有契约：按 identifier 扫描成品树）。所以工厂层的 customizing 必然先于接线，
无须额外约定。一个推论值得写进指南：在 `Format.font { $0.item(for: .Format.font)?.identifier = nil }`
里抹掉 identifier，这个子菜单就不会再被装作 font menu —— 这与「接线由 identifier 驱动」是同一条
规则，不是新行为。

### 组合语义

各层 customizing 互不干扰，按建树顺序由内向外执行：

```swift
app.mainMenu = MainMenu.standard { rootBuilder in      // ③ 最后，作用于整棵树
    rootBuilder.remove(.Format.text)
}
// 与
MainMenu.file { fileBuilder in                          // ② 其次，作用于 File 子树
    fileBuilder.remove(.File.pageSetup)
}
```

注意 `standard(customizing:)` 内部调用的仍是各工厂的**无参**版本 —— 它不会替宿主注入任何
工厂层定制，两条路互不隐含。

## 替代方案考量

- **用默认参数而非重载**（`file(title:_ items:) ` + `customizing: (Builder) -> Void = { _ in }`）
  —— 否。给 customizing 加默认值后，`MainMenu.file()` 这种不带闭包的调用会在
  「标准内容」与「标准内容 + 空定制」两个重载间歧义；而把默认值加在唯一一个方法上又与既有的
  `file(title:_ items:)` 抢尾随闭包。重载的代价只是多 15 个方法，且与 `standard` 现有形状一致。

- **只给七个顶层菜单加，不给分组加** —— 否。缺口二（`Edit.find()` 无任何入口）原样留着，
  而顶层菜单的 customizing 因为全树递归其实已经能改到分组内部，反倒会让人以为分组只能整份重列。

- **Builder 的根只含 submenu，不含菜单项自身** —— 否。`Edit.find()` / `Format.font()` 这些工厂
  没有 `title` 参数，根不含自身就等于「这些分组的标题永远改不了，除非整份重列」，正好是本提案
  要消除的那个成本。

- **给分组工厂加 `title` 参数**（`Edit.find(title: "查找")`）—— 否。只解决标题一件事，图标、
  快捷键、identifier 还是够不着；而且七个分组各加一个参数，与 builder 形成两套并行的定制机制。

- **给「自定义内容」重载也配 customizing**（`file { … } customizing: { … }`）—— 否。内容是宿主
  现写的，需要什么直接写成什么；为它再开一路等于承认「写出来的东西还得再按 id 找回来改」。
  代价对比：每个菜单从 3 个重载涨到 4 个（共多 15 个方法），换来的场景是「自定义内容里混入了
  标准工厂项，想统一改一遍」—— 这个场景直接把那几项换成别的写法即可。

- **给 `Application.services()` / `File.openRecent()` 也加，追求「没有例外」** —— 否。
  services 的 submenu 内容不归我们所有（AppKit 填充），openRecent 只有一项且宿主本来就要自己
  填内容。一致性在这里买到的是两个空承诺。

## 影响

### 源码兼容性（source compatibility）

**纯新增**。15 个新重载 + `Builder` 的一条新初始化路径，不修改任何既有签名、默认值或行为。

唯一的理论风险是「新增重载改变既有调用点的解析」。已由前期调研的消歧实测（四种形态）排除，
并由本仓库 20 余处既有调用点（含 `MainMenu.window { MainMenu.Window.minimize() }` 这一真实的
单表达式形态）在落地时全量编译通过守住。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- 本仓库内：仅 `UIFoundationAppKit` 一个 target；示例 App 的 `AppDelegate.swift:13`
  已在用 `standard(customizing:)`，不受影响。
- 下游仓库（RuntimeViewer / MachOKitUI / PrivateSymbols）：`MainMenu` 是 0009 才引入的新组件，
  纯新增重载对未使用者零影响；使用者的既有调用形态由上述消歧实测覆盖。

### 文档与示例

- [`MainMenu.md`](../MainMenu.md) —— 「The Four Levels」需要改写：定制不再是第 2 级独有的，
  而是**每一级都带的**。新增一节说明作用域规则（定制写在哪个工厂上就只作用于哪个菜单）、
  根项自身可寻址、以及五个动词对根项 no-op 的表格。
- 项目 `CLAUDE.md` 的 **Main Menu** 一节 —— 同步「四级」的表述与新的 customizing 覆盖面。
- 示例 App：不改（现有 `standard(customizing:)` 的用法仍是最典型的入口）。

## API 演进与废弃策略

- 无 API 被替代或废弃，不需要 `@available(*, deprecated)`。
- 不需要 semver major 跃迁（纯新增）。

## 落地步骤

1. **`Builder` 双根** —— 加 `init(rootItem:)` 与根项自身的寻址；补 `MainMenuBuilderTests`
   覆盖：根项可 `item(for:)`、四个动词对根项 no-op、子树内动词照常。
2. **七个顶层菜单工厂的 customizing 重载** —— 补测：定制生效、无定制时与标准版逐项等价、
   `MainMenu.window { MainMenu.Window.minimize() }`（内容重载）仍走内容分支。
3. **七个分组工厂的 customizing 重载** —— 补测：`Edit.find { $0.item(for: .Edit.find)?.title = … }`
   改到分组标题、`Format.font { $0.remove(.Format.Font.Kern.tighten) }` 改到内联子菜单的叶子。
4. **`menu(_:customizing:)`** —— 补测：变换先于接线（在 customizing 里删掉 Window 后
   `NSApp.windowsMenu` 不被赋值）、孤儿分隔符已规整。
5. **文档同批更新** —— `MainMenu.md`、项目 `CLAUDE.md`、`Evolutions/README.md` 状态行。
6. **全量验证** —— `swift build` / `swift test`（认原始退出码，不认 xcsift 摘要）+ 示例 App
   `xcodebuild` 构建通过。

**收尾判断**：

- **配套专题文章** —— 不新开。本提案引入的契约（作用域规则、根项自身可寻址、五个动词 no-op）
  是既有 `MainMenu.md` 的自然延伸，写进那一篇；另起一篇会把同一个组件的契约切成两处。
- **新术语** —— 无。「Builder」「ItemIdentifier」「接线」均为 0009 / 0010 已登记的用词。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-25 | Created as Draft | 用户要求：「MainMenu 每一个构造 Menu 的方法都需要提供 customizing 参数」。 |
| 2026-08-25 | 范围判据定为「submenu 有多个 item 才给」 | 用户补充：「subMenu 有多个 item 就要提供，单独的 item 不需要」。据此排除约 70 个单项工厂、`Application.services()`（空 submenu）与 `File.openRecent()`（1 项）。 |
| 2026-08-25 | Builder 根包含菜单项自身 | 否掉「只含 submenu 内容」。理由：`Edit.find()` / `Format.font()` 无 `title` 参数，根不含自身则其标题永远改不了。代价是五个动词对根项静默 no-op，沿用 0010 已有契约。 |
| 2026-08-25 | `menu` 的 customizing 用第二个尾随闭包 | 否掉「customizing 在前」（`menu(customizing:_:)`）。理由：参数顺序与执行顺序相反，读起来别扭。 |
| 2026-08-25 | 「自定义内容」重载不配 customizing | 否掉「字面满足『每一个方法都有』」。理由：内容是现写的，不需要事后按 id 找回来改；且每个菜单会涨到 4 个重载。 |
| 2026-08-25 | 用重载而非默认参数 | 实测三重载下四种闭包形态均正确消歧（见前期调研），故不必靠默认参数规避；默认参数反而会让 `MainMenu.file()` 歧义。 |
| 2026-08-25 | Accepted | 用户批准，实现开始。 |
| 2026-08-25 | Implemented | 15 个重载 + `Builder` 双根落地。验证：`swift build` 0 警告 0 错误、`swift test` 108 项全通过（认原始退出码，非 xcsift 摘要）、示例 App `xcodebuild` BUILD SUCCEEDED。**配套文章判断**：不新开专题，契约写进既有 `MainMenu.md` 的新一节「Where a Customization Attaches」——同一组件的契约切成两处只会让人漏读。**新术语判断**：无，「Builder」「ItemIdentifier」「接线」均为 0009 / 0010 已有用词。 |
