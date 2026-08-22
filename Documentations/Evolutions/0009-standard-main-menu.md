# 0009 - MainMenu：纯代码 macOS App 的标准主菜单

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-22
- **最后更新**: 2026-08-22
- **所属愿景**: 无
- **关联提案**: 无
- **实现分支 / PR**: main（与本提案同批次提交）
- **配套文档**: 使用指南 [`Documentations/MainMenu.md`](../MainMenu.md)

## 摘要

AppKit 没有任何公开 API 能生成 Xcode App 模板里 `MainMenu.xib` 那份标准主菜单。纯代码启动的
App（`NSApplication.shared` + `app.run()`，不用 storyboard / xib）要么手写两百多行菜单装配代码，
要么专门保留一个只装主菜单的 Interface Builder 文件。本提案在本库既有的 `@MenuBuilder` DSL 之上
新增一个 `MainMenu` 命名空间：一行拿到与模板 xib 等价的完整主菜单，也可以按「顶层菜单」与
「单个标准菜单项」两级粒度自由组合、替换与混入自定义项；`windowsMenu` / `helpMenu` /
`servicesMenu` / font menu 这四处特殊接线在装配时自动完成。目标写法：

```swift
@main
enum App {
    static func main() {
        let app = NSApplication.shared
        app.delegate = AppDelegate.shared
        app.setActivationPolicy(.regular)
        app.mainMenu = MainMenu.standard()          // 或 MainMenu.menu { … } 自定义
        app.run()
    }
}
```

## 动机

- **纯代码 AppKit 工程没有主菜单的体面来源。** SwiftUI App 由框架自动生成主菜单；storyboard
  工程由 xib 提供；纯代码工程两头都不沾。标准主菜单有七个顶层菜单、约八十个菜单项，每项都要
  写对 selector、key equivalent 与 modifier，还要记得把 Services / Window / Help 子菜单接到
  `NSApplication` 的对应属性上 —— 任何一处漏接都是静默失效（Services 菜单空白、Window 菜单不列
  窗口、Help 没有搜索框）。这段代码在每个纯代码工程里被重抄一遍。
- **本仓库自己就是受害者。** 示例 App 的 `Main.storyboard` **仅为主菜单保留**（见根目录
  `CLAUDE.md`「Example App」一节："the storyboard is kept **only** for the main menu"）。本提案
  落地后示例 App 换用 `MainMenu.standard()`，storyboard 即可删除 —— 它同时充当第一个真实消费者
  与验证场景。
- **既有 DSL 只解决了「怎么写一个菜单」，没解决「标准主菜单长什么样」。**
  `Sources/UIFoundationAppKit/Menu/` 的 `@MenuBuilder` 与 `NSMenuItem` 链式便利方法已经把菜单
  构建做得很顺手，但标准内容（哪些项、什么 action、什么快捷键、哪些子菜单要接线）仍然要使用方
  自己考古。这份「考古结果」正是库应该固化的东西。

## 前期调研

- **现状代码怎么走的** —— `Sources/UIFoundationAppKit/Menu/NSMenu+Builder.swift` 提供
  `@MenuBuilder`（产出 `[NSMenuItem]`，支持 `if` / `for` / optional / `String` 与 `NSView` 直写）；
  `NSMenuItem+Convenience.swift` 提供 `init(_:action:keyEquivalent:modifiers:)`、
  `init(_:submenu:)` 与全套链式修饰（`.shortcut(_:holding:)`、`.tag(_:)`、`.state(_:)` 等）。
  新 API 直接建于其上，**不需要新的 result builder**。
- **仓库内无既有实现** —— 全仓 grep `mainMenu` / `windowsMenu` / `helpMenu` / `servicesMenu`
  零命中（Sources 与示例 App 均无）。
- **特殊接线全部有公开 API**：`NSApplication.windowsMenu` / `.helpMenu` / `.servicesMenu`
  三个可写属性，加 `NSFontManager.shared.setFontMenu(_:)`。Help 菜单的内建搜索框、Window 菜单的
  窗口列表、Services 菜单的内容都由 AppKit 在接线后自动维护。
- **前人怎么做的** —— Jeff Johnson 的 "Working without a nib" 系列（lapcatsoftware.com）是纯代码
  主菜单的公认参考，逐篇覆盖了上述接线与 Open Recent 的私有菜单名技巧；开源包
  `j-f1/MenuBuilder` 只做 DSL，不提供标准主菜单内容 —— 与本库现状相同，佐证「标准内容」才是
  空缺。
- **AppKit 会自动往标准菜单里塞项**（均为经验事实，落地时在示例 App 实测确认，结论写回本节）：
  - Edit 菜单：AppKit 自动追加 "Start Dictation…" 与 "Emoji & Symbols"（可被
    `NSDisabledDictationMenuItem` / `NSDisabledCharacterPaletteMenuItem` defaults 关闭）。标准
    `edit()` **不得**手工添加这两项，否则重复。
  - Window 菜单：接为 `windowsMenu` 后，tab 相关项（Show Tab Bar / Show All Tabs）与 macOS 15+
    的全屏平铺项由 AppKit 自动补入，无需手工提供。
  - App 菜单：macOS 13 起 AppKit 会把 "Preferences…" 自动改写为 "Settings…"；我们直接按运行
    OS 给正确标题，不依赖该改写。
- **删掉 storyboard 后 `@main` 不能再挂在 NSApplicationDelegate 上**（示例 App 实测，
  2026-08-22，落地后由用户发现并修正）：`@main` 合成的入口调用 `NSApplicationMain`，而
  AppKit 的 `NSApplicationMain` 只通过主 storyboard / nib 实例化并连接 delegate（不像 UIKit
  的 `UIApplicationMain` 接受 delegate 类名参数）。storyboard 一删，delegate 永远不会被创建，
  进程在跑但 `applicationDidFinishLaunching` 不触发、窗口不出现。无 storyboard 的 App 必须
  手写入口（即摘要里的 `@main enum App` 形式）：自己创建 delegate、赋给
  `NSApplication.shared.delegate`、设 activation policy 与主菜单后 `run()`。落地初版曾在指南里
  建议「app-delegate 形式从 `applicationWillFinishLaunching` 设菜单」，已证伪并撤下。
  **精确机制随后由反编译确认**（用户提供 `NSApplicationMain` 与 `-[NSApplication run]` 的
  IDA 反编译）：`NSDelegateClass` 的实例化代码**只存在于 storyboard 分支**（且从不 release，
  以此对冲 `NSApplication.delegate` 是 weak）；无 storyboard / nib 时 `NSApplicationMain`
  退化为 `sharedApplication` + `run()`，与手写入口同构；`run()` 自己兜住其余启动初始化
  （update cycle、sudden / automatic termination、memory pressure source、逐事件
  autorelease pool），唯一值得手写入口复刻的是 `run()` 之前那个 autorelease pool。
  完整逐段分析见
  [`Researchs/AppKit-NSApplicationMain-Internals.md`](../../Researchs/AppKit-NSApplicationMain-Internals.md)。
- **Open Recent 是唯一没有公开接线的部分**（落地后实测 + 反编译定论，完整机制见
  [`Researchs/AppKit-OpenRecentMenu-Internals.md`](../../Researchs/AppKit-OpenRecentMenu-Internals.md)）：
  1. 文档型 App 中 AppKit 自动维护 Open Recent —— **已证实**，但机制是按私有菜单名
     `NSRecentDocumentsMenu` 认领：`-[NSDocumentController _installOpenRecentMenus]` 先
     `+[NSMenu _menusWithName:]` 查名，查到（xib 经 `systemMenu` 属性登记的那种）就接管
     那一个（清空重灌 + delegate 惰性填充），查不到才按 `openDocument:` action 定位 Open…
     项另插一个。**代码构建的菜单没有名字 → 系统另插 → File 菜单出现两个 Open Recent**
     （用户在 document-based App 中实测截图）。因此标准 File 菜单**移除了自带的
     Open Recent**：文档型系统自动补（能用的那个），非文档型系统不插（插入条件含
     `documentClassNames` 非空）也本不该有。`File.openRecent()` 工厂保留给手动维护
     recent 列表的宿主。
  2. 私有 `-[NSMenu _setMenuName:]` 设 `"NSRecentDocumentsMenu"` —— 反编译确认这不只是
     Jeff Johnson 的民间技巧，`_installOpenRecentMenus` 自己就用它注册 "Revert To" 子菜单；
     若需要「与 xib 完全同权」（被接管、带图标）可落 `UIFoundationAppleInternal`，未立项。
  顺带证实：同函数按 `saveDocument:` 等标准 action 定位后注入 Duplicate / Rename… /
  Move To… / Revert To / Share —— **「selector 逐字照抄模板」正是文档型 App 全套系统增强
  能落在代码菜单上的前提**。
- **标准内容清单已按模板 xib 逐项 dump 定稿**（2026-08-22，Xcode 26 的
  `Templates/File Templates/User Interface/Main Menu.xctemplate/___FILEBASENAME___.xib`，
  与 `Application.xctemplate` 内嵌的主菜单同构）。修正 / 确认的关键点：
  - File▸Print… 的 action 是 **`print:`**，不是 `printDocument:`；Revert to Saved 确认带 ⌘R。
  - Edit▸Find 一组确认用 **`performFindPanelAction:`** 加 tag（Find…=1、Find and Replace…=12、
    Find Next=2、Find Previous=3、Use Selection for Find=7）；Jump to Selection 是
    `centerSelectionInVisibleArea:`，无 tag。
  - Format▸Font 里 Show Fonts / Bold / Italic / Bigger / Smaller **五项直接 target
    `NSFontManager`**（xib 里的独立 object），其余项走 first responder。Bold/Italic 是
    `addFontTrait:`（tag 2 / 1），Bigger/Smaller 是 `modifyFont:`（tag 3 / 4）。
  - Text▸Writing Direction 子菜单里有两个 **`enabled=NO` 的小节头**（Paragraph / Selection），
    六个方向项标题带 **制表符前缀**（`"\tDefault"` 等），action 分别是
    `makeBaseWritingDirection*:` 与 `makeTextWritingDirection*:` 三对。
  - Settings…（xib 里叫 Preferences…）**没有任何 action 连接**，key ⌘,。
  - xib 用 `systemMenu` 属性标记特殊菜单：`apple` / `services` / `recentDocuments` / `font` /
    `window` / `help`。其中 services / font / window / help 有公开接线 API；`apple` 无需接线
    （主菜单第一项自动成为应用菜单）；`recentDocuments` 即 Open Recent，无公开等价物（见下条）。

## 提议方案

在 `Sources/UIFoundationAppKit/Menu/` 下新增 `MainMenu` 命名空间（`@MainActor public enum`），
不加 SPM trait（与既有 Menu / Toolbar DSL 一致：纯公开 AppKit API、无资源、无依赖，无条件编译进
`UIFoundationAppKit`）。API 分三层，层层可下沉：

1. **整菜单一行拿到**：`MainMenu.standard()` 返回与模板 xib 等价的完整 `NSMenu`，并完成四处
   特殊接线。
2. **顶层菜单级组合**：`MainMenu.menu { … }` 接受 `@MenuBuilder`，七个标准顶层菜单各有工厂
   （`application()` / `file()` / `edit()` / `format()` / `view()` / `window()` / `help()`），
   每个既可用默认内容，也可传 `@MenuBuilder` 重写内容；任意自定义 `NSMenuItem`（既有 DSL 构建）
   可混排其间。
3. **标准单项级组合**：每个顶层菜单对应一个嵌套命名空间（`MainMenu.File` 等），把标准项暴露为
   单项工厂（`MainMenu.File.close()`、`MainMenu.Edit.findGroup()` …），供重写菜单内容时按需
   取用，不必重抄 selector 与快捷键。

**接线不做在单项工厂里，做在装配层。** `window()` / `help()` / `application()`（内含 Services）
/ `format()`（内含 Font）产出的 `NSMenuItem` 用 `NSUserInterfaceItemIdentifier` 打标；
`MainMenu.menu { … }` 与 `MainMenu.standard()` 在装配时扫描标记，把命中的子菜单写到
`NSApp.windowsMenu` / `.helpMenu` / `.servicesMenu` / `NSFontManager.shared.setFontMenu(_:)`。
工厂本身零副作用 —— 单独创建一个 `MainMenu.window()` 不会动全局状态。

标题默认英文（与模板 xib 只带开发语言一致），全部可经参数覆盖；App 名解析顺序
`CFBundleDisplayName` → `CFBundleName` → `ProcessInfo.processInfo.processName`，可经参数覆盖。

### 非目标

- **不做多语言本地化。** 模板 xib 本身也只带开发语言；所有标题可由参数覆盖，宿主自行本地化。
  若将来要出带 `xcstrings` 的版本，另立提案。
- **不做菜单项的 enable / validate 逻辑。** 全部交给 responder chain 的标准
  `validateMenuItem(_:)` 机制 —— 这正是标准主菜单 action 全部指向 first responder 的意义。
- **不封装 App 启动骨架。**（`NSApplication` 配置、`run()`、delegate 装配等）只管菜单。
- **不提供运行时动态更新 API。** `NSMenu` 本身可变，宿主拿到实例后直接改。
- **不做 Open Recent 的私有 API 接线。** 见前期调研；若实测路径 1 不成，另行小提案决定是否在
  `UIFoundationAppleInternal` 提供增强。
- **不动 UIKit / Catalyst。** 文件级 `#if canImport(AppKit) && !targetEnvironment(macCatalyst)`，
  与既有 Menu DSL 相同。

## 详细设计

### 装配层与顶层菜单工厂

```swift
@MainActor
public enum MainMenu {
    /// The complete template-equivalent main menu, wired and ready for `NSApp.mainMenu`.
    public static func standard(applicationName: String? = nil) -> NSMenu

    /// Assembles a main menu from top-level items and performs the special-menu wiring
    /// (`windowsMenu` / `helpMenu` / `servicesMenu` / font menu) for tagged items.
    public static func menu(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenu

    // Top-level standard menus. Each returns an `NSMenuItem` carrying its submenu.
    // The no-builder form ships the template-default content; the builder form
    // replaces the content while keeping the identifier-based wiring.
    public static func application(applicationName: String? = nil) -> NSMenuItem
    public static func application(applicationName: String? = nil,
                                   @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem
    public static func file() -> NSMenuItem
    public static func file(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem
    public static func edit() -> NSMenuItem
    public static func edit(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem
    public static func format() -> NSMenuItem
    public static func format(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem
    public static func view() -> NSMenuItem
    public static func view(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem
    public static func window() -> NSMenuItem
    public static func window(@MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem
    public static func help(applicationName: String? = nil) -> NSMenuItem
    public static func help(applicationName: String? = nil,
                            @MenuBuilder _ items: () -> [NSMenuItem]) -> NSMenuItem
}
```

自定义用法示例（省略 Format，插入自定义菜单）：

```swift
app.mainMenu = MainMenu.menu {
    MainMenu.application()
    MainMenu.file {
        MainMenu.File.new(action: #selector(AppDelegate.newProject(_:)))
        MainMenu.File.open()
        NSMenuItem.separator()
        MainMenu.File.close()
    }
    MainMenu.edit()
    NSMenuItem("Project") {                       // 既有 DSL 的自定义菜单
        NSMenuItem("Build", action: #selector(AppDelegate.build(_:)), keyEquivalent: "b")
    }
    MainMenu.window()
    MainMenu.help()
}
```

### 标准单项工厂（嵌套命名空间）

每个顶层菜单一个嵌套 `enum`，成员即该菜单的标准项；需要宿主动作的项（如 Settings…）接受
`action` / `target` 参数，标题一律可覆盖。示意（完整清单见下表，签名形状同此）：

```swift
extension MainMenu {
    @MainActor
    public enum Application {
        public static func about(applicationName: String? = nil) -> NSMenuItem
        public static func settings(action: Selector? = nil, target: AnyObject? = nil) -> NSMenuItem
        public static func services() -> NSMenuItem        // identifier-tagged for wiring
        public static func hide(applicationName: String? = nil) -> NSMenuItem
        public static func hideOthers() -> NSMenuItem
        public static func showAll() -> NSMenuItem
        public static func quit(applicationName: String? = nil) -> NSMenuItem
    }
}
```

### 标准内容清单（待模板 dump 核对后定稿）

所有 action 均指向 first responder（`target = nil`），除注明者外。

| 菜单 | 项 | Action | 快捷键 |
|------|----|--------|--------|
| **应用** | About〈App〉 | `orderFrontStandardAboutPanel:` | — |
| | Settings…（macOS 13-：Preferences…） | 宿主提供，默认 `nil` | ⌘, |
| | Services ▸（空子菜单，接 `servicesMenu`） | — | — |
| | Hide〈App〉/ Hide Others / Show All | `hide:` / `hideOtherApplications:` / `unhideAllApplications:` | ⌘H / ⌥⌘H / — |
| | Quit〈App〉 | `terminate:` | ⌘Q |
| **File** | New / Open… | `newDocument:` / `openDocument:` | ⌘N / ⌘O |
| | Open Recent ▸ Clear Menu | `clearRecentDocuments:` | — |
| | Close / Save… / Save As… / Revert to Saved | `performClose:` / `saveDocument:` / `saveDocumentAs:` / `revertDocumentToSaved:` | ⌘W / ⌘S / ⇧⌘S / ⌘R |
| | Page Setup… / Print… | `runPageLayout:` / `printDocument:` | ⇧⌘P / ⌘P |
| **Edit** | Undo / Redo | `undo:` / `redo:` | ⌘Z / ⇧⌘Z |
| | Cut / Copy / Paste / Paste and Match Style / Delete / Select All | `cut:` / `copy:` / `paste:` / `pasteAsPlainText:` / `delete:` / `selectAll:` | ⌘X / ⌘C / ⌘V / ⌥⇧⌘V / — / ⌘A |
| | Find ▸（Find… / Find and Replace… / Next / Previous / Use Selection / Jump） | `performFindPanelAction:` 带 tag（或 `performTextFinderAction:`，dump 定） | ⌘F / ⌥⌘F / ⌘G / ⇧⌘G / ⌘E / ⌘J |
| | Spelling and Grammar ▸ / Substitutions ▸ / Transformations ▸ / Speech ▸ | 各标准 selector（`showGuessPanel:`、`toggleContinuousSpellChecking:`、`uppercaseWord:`、`startSpeaking:` 等） | 模板同款 |
| **Format** | Font ▸（Show Fonts / Bold / Italic / Underline / Bigger / Smaller / Kern ▸ / Ligatures ▸ / Baseline ▸ / Show Colors / Copy Style / Paste Style；接 font menu） | `orderFrontFontPanel:`、`addFontTrait:`(tag) 、`modifyFont:`(tag) 等 | ⌘T / ⌘B / ⌘I / ⌘U / ⌘+ / ⌘- / ⇧⌘C / ⌥⌘C / ⌥⌘V |
| | Text ▸（对齐 / Writing Direction ▸ / Ruler 三项） | `alignLeft:` 等 | ⇧⌘{ 等 |
| **View** | Show Toolbar / Customize Toolbar… | `toggleToolbarShown:` / `runToolbarCustomizationPalette:` | ⌥⌘T / — |
| | Show Sidebar / Enter Full Screen | `toggleSidebar:` / `toggleFullScreen:` | ⌃⌘S / ⌃⌘F |
| **Window** | Minimize / Zoom / Bring All to Front（接 `windowsMenu`） | `performMiniaturize:` / `performZoom:` / `arrangeInFront:` | ⌘M / — / — |
| **Help** | 〈App〉Help（接 `helpMenu`） | `showHelp:` | ⌘? |

### 文件布局

遵守 unique-basename 规则，全部落在 `Sources/UIFoundationAppKit/Menu/`：
`MainMenu.swift`（命名空间 + `standard()` + `menu {}` + 接线）、`MainMenu+Application.swift`、
`MainMenu+File.swift`、`MainMenu+Edit.swift`、`MainMenu+Format.swift`、`MainMenu+View.swift`、
`MainMenu+Window.swift`、`MainMenu+Help.swift`。

## 替代方案考量

- **直接摊在 `NSMenu` / `NSMenuItem` 的 static 扩展上**（`NSMenu.standardMain()` 等）——
  七个菜单工厂加几十个单项工厂会灌进 AppKit 类型的静态命名空间，且绕开本库「顶层符号最少、
  嵌套命名空间」的既有惯例（`TabBar` / `StatusItemController` / `SystemHUD` 先例）。否。
- **工厂创建时立即接线**（`MainMenu.window()` 一执行就写 `NSApp.windowsMenu`）—— 实现最省事，
  但把全局副作用藏进看似纯粹的工厂：宿主只是构建了一个 item 还没装进主菜单，全局状态已被改。
  改为装配层按 identifier 扫描接线，工厂保持零副作用。否。
- **内嵌一份编译好的 MainMenu.nib 资源，加载后修改** —— 不可组合、App 名占位难以替换干净、
  给「无资源、纯代码构建」的 target 平添 nib 资源，与做这个库的初衷相反。否。
- **加 SPM trait** —— 该组件是纯公开 AppKit API、无资源无依赖、代码量与 Toolbar DSL 相当；
  trait 的先例（TabBar / SystemHUD / Navigation …）都是带完整子系统的大件。跟随 Menu / Toolbar
  DSL 无条件编译。否。

## 影响

### 源码兼容性（source compatibility）

**纯新增**，不改动任何既有声明。唯一风险是新顶层符号 `MainMenu` 经 umbrella `@_exported`
进入 `UIFoundation` 后与下游同名类型冲突 —— 落地前在三个已知下游仓库 grep `MainMenu`
确认（见下游影响）。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- 仓库内：仅 `UIFoundationAppKit`（经 umbrella 传导到 `UIFoundation`）。
- 下游仓库：RuntimeViewer、MachOKitUI、PrivateSymbols —— 纯新增不受行为影响。撞名排查结果
  （2026-08-22）：PrivateSymbols（本地 checkout）与 RuntimeViewer（GitHub 浅克隆）均无
  `MainMenu` 顶层类型声明（RuntimeViewer 只有 `MainMenuItemRepresentable` 协议，标识符不同，
  不冲突）；**MachOKitUI 未能定位**（GitHub 无此名仓库、本机无 checkout），无法执行排查 ——
  即使撞名，后果也只是该仓库内使用点需显式写 `UIFoundation.MainMenu`（本模块类型优先于
  import 的同名类型，不会破坏既有编译），留待其下次升级依赖时自然暴露。RuntimeViewer 若也是
  纯代码主菜单（或仍用 xib），是本 API 的潜在第二个消费者，但回接不在本提案范围内。
- 示例 App：换用 `MainMenu.standard()` 并删除仅为主菜单保留的 `Main.storyboard`
  （同步清理 Info.plist 的 storyboard 引用）—— 既是验证场景也是用法示范。

### 文档与示例

- 新使用指南 `Documentations/MainMenu.md`：三层 API、接线契约（**接线发生在
  `MainMenu.menu {}` / `standard()` 装配时**，单独取顶层菜单工厂需自行接线）、AppKit
  自动插入项清单（Edit 的听写 / 表情、Window 的 tab 项）、Open Recent 的现状与限制。
- 根 `CLAUDE.md` 增设小节；`Documentations/README.md` 与 `Evolutions/README.md` 索引同步。
- 示例 App 的改造本身就是示例。

## API 演进与废弃策略

- 纯新增，无被替代旧 API，无废弃标注。
- 无需 semver major 跃迁。

## 落地步骤

1. **Dump 模板 xib 定稿清单** —— 解开当前 Xcode App 模板的 `MainMenu.xib`，逐项核对
   selector / tag / key equivalent / modifier，修正本提案的清单表（尤其 Edit▸Find 一组），
   结论写回「前期调研」。
2. **实现装配层与七个菜单工厂 + 单项工厂**（文件布局见详细设计），构建通过。
3. **单元测试**：`standard()` 的结构断言（顶层菜单数与标题、代表性项的 action /
   keyEquivalent / modifier / tag）；装配后 `NSApp.windowsMenu` / `.helpMenu` /
   `.servicesMenu` / `NSFontManager` font menu 的接线断言；builder 重写形式保留接线的断言。
4. **示例 App 回接**：删 storyboard，`AppDelegate` 侧改为 `MainMenu` 装配；实测三件事并把
   结论写回提案 —— Edit 菜单自动插入项是否重复、Window 菜单 tab 项是否自动出现、Open Recent
   路径 1 是否成立。
5. **文档同批次落地**：`Documentations/MainMenu.md` 使用指南、根 `CLAUDE.md` 小节、两份索引、
   下游三仓库的撞名 grep 结果记录。

**收尾时必须判断两件事**（判断结果写进决策日志，不允许沉默跳过）：

- **要不要配套专题文章** —— 已判定需要使用指南（接线时机与 AppKit 自动插入项都是从 API 签名
  看不出来的契约）。
- **有没有引入新术语** —— 「接线（wiring）」若在指南中成为固定用语，登记进项目术语表。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-22 | Created as Draft | 用户提出：提供与 MainMenu.xib 等价、可自定义的主菜单 API，使纯代码 macOS 工程可直接 `app.mainMenu = …`。 |
| 2026-08-22 | Draft → Accepted → In Progress | 用户批准（「开工」），按落地步骤开始实现。 |
| 2026-08-22 | In Progress → Implemented | 全部落地：① 模板 xib 逐项 dump 定稿（修正 `print:`、确认 Find tag 组、发现 Font 菜单五项 target `NSFontManager`、Writing Direction 小节头，结论已写回前期调研与详细设计）；② 实现 `MainMenu.swift` + 七个菜单文件 + `NSMenuItem.identifier(_:)` 修饰；③ `MainMenuTests` 12 项结构 / 接线断言（初版把带 submenu 项的 action 误期望为空 —— AppKit 的 `setSubmenu:` 自动设 `submenuAction:`，已修正并记入指南保真笔记），全量 81 测试通过（以原始退出码为准）；④ 示例 App 回接：删除 `Main.storyboard` 与两处 `INFOPLIST_KEY_NSMainStoryboardFile`，`applicationWillFinishLaunching` 改用 `MainMenu.standard()`，xcodebuild 构建通过；⑤ 下游撞名排查结果记入「下游影响」（MachOKitUI 未能定位，已注明）。**收尾两判断**：配套专题文章 —— 需要，已写使用指南 `Documentations/MainMenu.md` 并登记索引（接线时机与 AppKit 自动插入项是签名看不出的契约）；新术语 —— 无（"wiring/接线" 属普通用语，项目尚无术语表，不为此新建）。**遗留待人工验证**（无法 headless 测试、agent 不自行启动 GUI）：Edit 菜单自动插入项不重复、Window 菜单 tab 项自动出现、文档型 App 的 Open Recent 自动路径；请在示例 App 里人工确认，指南已按「未验证」措辞如实描述。 |
| 2026-08-22 | 落地修正 | 用户实测发现：删 storyboard 后 `@main` 挂在 NSApplicationDelegate 上界面起不来（`NSApplicationMain` 只经 storyboard/nib 创建 delegate），示例 App 已由用户改为手写 `@main enum App` 入口。同步修正：指南撤下 app-delegate 形式的错误建议、改为入口所有权契约；`AGENTS.md` 的 Main Menu 小节与 Example App 描述更新；本提案前期调研补记该实测事实。 |
| 2026-08-22 | 落地修正 | 对照 `NSApplicationMain` 反编译逐项核对手写入口的差异后，给示例 App 的 `App.main()` 补上 `autoreleasepool` 包住 `run()` 之前的准备阶段（`NSApplicationMain` 在装载前 push 池、`run()` 前 pop；手写入口没有它时，准备期 autorelease 的对象会活到进程结束）。指南 Quick Start 片段与 `AGENTS.md` 入口契约同步，并补记 `NSApplication.delegate` 是 weak、宿主必须强持有 delegate 的坑（`NSApplicationMain` 靠从不释放实例化出的 delegate 来规避）。其余差异（`NSPrincipalClass` 支持、启动 signpost、ImageIO 预热）经评估不需要在手写入口复刻。 |
| 2026-08-22 | 调研落盘 | `NSApplicationMain` / `-[NSApplication run]` 的反编译分析写成研究报告 `Researchs/AppKit-NSApplicationMain-Internals.md`（关键发现：`NSDelegateClass` 只在 storyboard 分支被消费；`run()` 兜住其余启动初始化；差异清单与手写入口参考实现）。指南入口契约段与 `AGENTS.md` 的 Main Menu 小节已链接该报告；本提案前期调研同步补记精确机制。 |
| 2026-08-22 | 落地修正 | 遗留验证项之一定案：用户在 document-based App 实测发现 File 菜单出现**两个 Open Recent**（系统自动插入的 + 本库标准内容自带的），随后反编译 `-[NSDocumentController _installOpenRecentMenus]` 与 `-[NSMenu _finishedMakingConnections]` 定论机制 —— 系统按私有菜单名 `NSRecentDocumentsMenu` 认领 xib 菜单（故 xib 从不重复），代码菜单无名不可见、按 `openDocument:` 另插。修正：**标准 File 菜单移除 Open Recent**（文档型系统自动补、非文档型本不该有），`File.openRecent()` 工厂保留给手动填充场景并新增专项测试；调研写成 `Researchs/AppKit-OpenRecentMenu-Internals.md`，前期调研、指南与 `AGENTS.md` 同步。全量 97 测试通过，示例 App 构建通过。剩余待人工验证：Edit 菜单自动插入项不重复、Window 菜单 tab 项自动出现。 |
