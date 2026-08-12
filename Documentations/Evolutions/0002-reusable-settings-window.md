# 0002 - SettingsWindow：把 RuntimeViewer 的设置窗口抽成可复用框架

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-12
- **最后更新**: 2026-08-12
- **所属愿景**: 无
- **关联提案**: 无
- **实现分支 / PR**: 待定
- **配套文档**: 使用指南 [`Documentations/SettingsWindow.md`](../SettingsWindow.md)

## 摘要

macOS App 的「设置」窗口每次都要重写一遍同样的东西：一个左侧分页列表、一个 `Form`、一份存到
Application Support 的 JSON、以及一套「改了就自动存」的防抖逻辑。RuntimeViewer 已经把这套做完了，
但它和 RuntimeViewer 自己的设置项焊死在一起。

本提案把其中**与业务无关的那一层**搬进 UIFoundation：一个泛型的 `SettingsStore`（存储策略 +
防抖自动保存）、泛型化的 `AppSettings` 属性包装器、一个用 result builder 注册页面的
`SettingsWindowController`，外加 `SettingsForm` / `SettingsPageIcon`。宿主只提供自己的 `Codable`
设置结构体和各页面视图。

新代码落在两个新 target —— `UIFoundationSettings`（模型层：存储 + 状态 + 访问）与
`UIFoundationSettingsUI`（UI 层：窗口 + 导航 + 表单），**都只做 macOS**，由同一个默认关闭的 SPM
trait `Settings` 控制，**不引入任何新的外部依赖**。落地后 RuntimeViewer 删掉自己那份重复实现，
改为依赖本库。

## 动机

**同一套壳已经写了不止一遍，而且每次都写成了不可复用的形状。** RuntimeViewer 的
`RuntimeViewerSettingsUI` 共 3243 行，其中真正与 RuntimeViewer 业务绑定的是 8 个设置页面
（`Components/` 下的 2253 行，光 Transformer 页就 1044 行）；剩下的 250 行是任何 App 都要重写一遍的东西：

| 文件 | 行数 | 内容 |
|---|---|---|
| `SettingsWindowController.swift` | 81 | 窗口 + `NSHostingController` 承载 + 禁止侧栏折叠 |
| `SettingsRootView.swift` | 83 | `NavigationSplitView` 骨架（页面列表**硬编码为 private enum**） |
| `SettingsIcon.swift` | 92 | 圆角渐变方块图标 |
| `SettingsStorage.swift` | 48 | Application Support 下的 JSON 读写 |
| `SettingsForm.swift` + `RuntimeViewerSettingsStyle.swift` | 34 | `.formStyle(.grouped)` 包装、隐藏侧栏开关按钮 |

**这 250 行现在一行都拿不走**，原因是三处硬编码：

1. `SettingsRootView.swift:19` 的 `private enum SettingsPage: String, CaseIterable`
   把 8 个页面写死在枚举里 —— 换一个 App 就要改这个文件。
2. `AppSettings.swift:8` 的属性包装器签名是
   `ReferenceWritableKeyPath<RuntimeViewerSettings.Settings, Value>` —— 类型直接钉死在
   RuntimeViewer 的 `Settings` 上。
3. `SettingsStorage.swift:14` 的目录名 `"RuntimeViewer"` / `"RuntimeViewer-Debug"` 写在源码里。

**顺带能修掉一个现存的设计负担。** RuntimeViewer 的 `Settings` 是
`@Observable final class`，自动保存靠在**每一个**属性上手写 `didSet { scheduleAutoSave() }`
（`Settings.swift:14-47`，七个属性重复七遍）。加一个设置项就要记得加一次 `didSet`，忘了就静默不保存。
改成「值类型 + 由 store 统一持有」之后，`store.value` 一处 `didSet` 覆盖所有嵌套改动，宿主一行都不用写。

## 前期调研

### RuntimeViewer 现状（本提案的搬运源）

- 逻辑层 `RuntimeViewerPackages/Sources/RuntimeViewerSettings/`：`Settings`（142 行，`@Observable`
  class）、`SettingsStorage`（48 行）、以及三份纯业务的字段定义（`Settings+Types` 179 行、
  `Settings+Theme` 181 行、`Settings+Update` 54 行）。
- UI 层 `RuntimeViewerPackages/Sources/RuntimeViewerSettingsUI/`：上表 5 个壳文件 + `Components/` 下 8 个页面。
- 外部依赖：**MetaCodable**（`@Codable` / `@Default` / `@MemberInit`）、**swift-dependencies**
  （`@Dependency(\.settings)`）、**SwiftUIIntrospect**（隐藏侧栏开关按钮）、**FoundationToolbox**（`@Loggable`）。
- `@AppSettings` 的实际用法覆盖两种深度，抽象层必须都支持：
  - 整段：`@AppSettings(\.general)`（`GeneralSettingsView.swift:8` 等 5 处）
  - 叶子标量：`@AppSettings(\.update.automaticallyChecks)`（`UpdateSettingsView.swift:11-14` 共 4 处）
- 设置在 UI 之外还有 **13 个文件**通过 `@Dependency(\.settings)` 读取（MCP bridge、主题流、
  后台索引协调器、外观控制器等）。回接时这些调用点都要跟着动，见「下游影响」。

### UIFoundation 现状

- **整个仓库一行 SwiftUI 都没有**：`grep -rl "import SwiftUI" Sources` 零命中。这套东西是纯 SwiftUI，
  因此只能新开 target，不能塞进任何现有 target。
- **搬运源目前是跨平台的，但本提案不跟。** RuntimeViewer 的 `RuntimeViewerApplication`
  **无条件**依赖 `RuntimeViewerSettings`（`Package.swift:432`），只有 `RuntimeViewerSettingsUI`
  带 `condition: .when(platforms: appkitPlatforms)`；iOS 端 `RuntimeViewerUsingUIKit` 确实
  `import RuntimeViewerApplication`（多个文件），所以设置逻辑现在**是在 iOS 上编译的**。
  尽管如此，**本提案按用户决定只做 macOS**。代价写在「下游影响」里：
  回接时 RuntimeViewer 的 iOS 端要自己处理。
- 现有依赖只有两个：`FrameworkToolbox`、`AssociatedObject`（`Package.swift:76-88`）。
- 包最低平台 macOS 10.15（`Package.swift:57`），而本提案要用的
  `NavigationSplitView` / `.formStyle(.grouped)` 是 macOS 13+、`@Observable` 是 macOS 14+。
  SPM 不支持单 target 抬高最低版本，只能整套代码打 `@available(macOS 14, *)`。
- `XiblessWindowController`（`Sources/UIFoundationAppKit/Controller/XiblessWindowController.swift:5`）
  已经是本库的东西 —— RuntimeViewer 的设置窗口本来就 `import UIFoundation` 在用它。
- 既有 trait 化组件（`TabBar` / `SystemHUD` / `QuickActionBar` / `StatusItemController` / `Navigation`）
  确立了「大块组件走默认关闭的 trait」的先例，本提案沿用。

### 验证过什么

前三条在 `swiftc -typecheck -target arm64-apple-macos14.0` 下编译通过；后两条是**实际跑起来**
（`NSHostingView` 挂进离屏窗口、数 `body` 求值次数）测出来的，原型与输出见决策日志。

- **`WritableKeyPath` 覆盖两种深度。** `\DemoSettings.general` 与
  `\DemoSettings.updates.automaticallyChecks` 同一套 API 都能写，对得上 RuntimeViewer 的现有用法。
- **宿主端可以用 typealias 把泛型参数消掉。**
  `typealias Setting<Value> = AppSettings<DemoSettings, Value>` 之后，调用点写回
  `@Setting(\.general)` —— 与 RuntimeViewer 现在的写法**逐字符同构**，回接时页面代码不用改。
- **整套骨架（storage / store / property wrapper / page builder / root view / form / icon）
  一次编译通过**，没有需要私有 API 或编译器绕路的地方。
- **不经 Environment 也能刷新视图 —— 这是本设计成立的前提，已实测。**
  属性包装器直接读 `Root.store.value[keyPath:]`（静态入口，无任何注入机制），改动后视图确实重绘：
  `body` 求值次数从 1 变 2。原因是 SwiftUI 的 `body` 求值本身包在 observation tracking 里，
  期间读到的任何 `@Observable` 属性都会建立依赖，与这个属性是怎么拿到的无关。
- **刷新不来自 `DynamicProperty` 一致性 —— 对照实验证实。** 三组并排渲染：遵守 `DynamicProperty` 的
  包装器、去掉一致性的同款包装器、以及完全不用包装器直接在 `body` 里读静态 store。
  三组的 `body` 求值次数逐次完全相同（1 → 2 → 3），即**都刷新，且行为无差别**。
  结论：刷新只由 observation tracking 决定；`DynamicProperty` 在这个纯计算包装器里是空壳，
  它的 `update()` 服务的是包装器内部需要 SwiftUI 管理的存储（上一版的 `@Environment` 就是），现已不存在。
- **但失效粒度退化到「整个设置对象」，这是实测出来的代价。**
  改一个视图**根本没读**的兄弟字段（`general.untouched`），该视图**同样**重绘了
  （`body` 求值次数 2 → 3）。原因是追踪粒度落在 `store.value` 这一个属性上：值类型的嵌套写入
  是「读出 → 改 → 整体写回」，所以每次改动都在动 `value` 本身。见「影响」一节对代价的评估。

### 侧栏折叠：一条推测，落地时已实测推翻

RuntimeViewer 用**全局** `method_exchangeImplementations` 交换 `NSSplitViewItem.canCollapse`
的 getter（`SettingsWindowController.swift:57-73`），靠判断 window 类型来限定作用范围。

Apple 文档确认 `canCollapse` 本身可写（`var canCollapse: Bool { get set }`，macOS 10.10+）。
那么**为什么当初要 swizzle getter 而不是直接赋 false**，源码里没有留下理由。写提案时的推测是
SwiftUI 会在布局时重设该属性把赋值覆盖掉。

**实测（macOS 26）推翻了这个推测，也解释了当初为什么会绕路：**

1. **直接赋值完全有效。** `canCollapse = false` 赋上之后，经过一轮 run loop、一次 SwiftUI 更新
   （改选中项触发重新求值）、一次窗口 resize，三次复查都保持 `false`。初始值是
   `[true, false]`（侧栏可折叠、detail 不可），赋值后 `[false, false]` 并保持。**不需要任何 swizzle。**
2. **真正的坑不在覆盖，而在「找不到」。** SwiftUI 的 `NavigationSplitViewController`
   **不是 hosting controller 的 child** —— `NSHostingController` 底下的控制器树只有它自己。
   该控制器只能通过 `NSSplitView.delegate` 拿到。第一版实现照着「递归遍历 `children`」写，
   拿到的是空数组，等于什么都没做，而且**不会报错**。这大概率就是上游绕到 swizzle 的原因：
   赋值这条路看起来「不生效」，而实际是压根没找到对象。
3. **macOS 26 上 SwiftUI 根本不建 toolbar。** 一个 AppKit 宿主窗口里的裸 `NavigationSplitView`
   没有 `NSWindow.toolbar`，因此也没有那个 sidebar toggle item。隐藏逻辑在这台机器上是空操作，
   保留它是为了会安装该按钮的旧系统（**旧系统未实测**）。
4. **时机不构成问题。** 从配置视图 `viewDidMoveToWindow` 起 `NSSplitView` 就已存在，
   主队列的第一轮 async 即可拿到。实现仍保留有限次重试，兜住 delegate 尚未挂上的情况。

结论：实现走「视图树找 `NSSplitView` → 取 delegate」，直接赋值，不 swizzle。
`SettingsWindowChromeTests` 把这条行为钉住 —— 它独立重新推导查找路径，
因此一个写错的查找路径无法自己给自己放行（已用「把赋值改成 `true`」验证过测试会翻红）。

## 提议方案

新增**两个** target，同受 trait `Settings`（默认关闭）控制，都作为独立 product 而不并入
`UIFoundation` 伞形：

| Target | 层 | 内容 | 平台 |
|---|---|---|---|
| `UIFoundationSettings` | 模型层 | 存储 + 状态 + 访问（`SettingsStorage` / `SettingsStore` / `PersistentSettings` / `AppSettings`） | macOS 14+ |
| `UIFoundationSettingsUI` | UI 层 | 窗口 + 导航 + 表单 + 图标 | macOS 14+ |

**两层分开而不是合成一个 target**，理由是模型层与 UI 层的使用场景本来就不重合：设置的读写遍布
整个 App（服务、协调器、视图模型），而设置**窗口**只有一处会用到。分开之后，只想读设置的模块
不必把 `NavigationSplitView` 和窗口控制器一起拖进来。这个划分与 RuntimeViewer 现有的
`RuntimeViewerSettings` / `RuntimeViewerSettingsUI` 一一对应，回接时不需要重新切分代码。

**两个 target 都只做 macOS。** 模型层本身不 import AppKit、技术上能跨平台，但本提案不为此付出
任何代价：不加平台条件编译、不做 iOS 验证、不承诺 iOS 可用。理由见「非目标」。

四块内容：

1. **存储层** —— `SettingsStorage` 协议 + `FileSystemSettingsStorage`（Application Support 下的原子写 JSON）。
2. **状态层** —— `SettingsStore<Value>`：`@MainActor @Observable`，持有一个 `Codable & Sendable`
   **值类型**，`value` 的 `didSet` 统一触发防抖保存。
3. **访问层** —— `PersistentSettings` 协议（唯一要求是一个静态 `store`）+ 泛型化的
   `AppSettings<Root, Value>` 属性包装器，支持任意深度 `WritableKeyPath`。
   **store 从类型本身取（`Root.store`），不经 Environment、不经任何依赖容器。**
4. **UI 层** —— `SettingsWindowController` + `SettingsRootView` +
   `SettingsPage` / `@SettingsPageBuilder` + `SettingsForm` + `SettingsPageIcon`。
   因为 store 走类型级入口，**UI 层不需要任何泛型参数**。

宿主端完整用法：

```swift
struct Settings: PersistentSettings {
    var general = General()
    var updates = Updates()

    @MainActor
    static let store = SettingsStore(
        defaultValue: Settings(),
        storage: FileSystemSettingsStorage(applicationDirectoryName: "MyApp")
    )
}

typealias Setting<Value> = AppSettings<Settings, Value>   // 消掉第一个泛型参数

let controller = SettingsWindowController {
    SettingsPage("General", symbol: "gearshape") { GeneralPage() }
    SettingsPage("Updates", symbol: "arrow.down.circle") { UpdatesPage() }
}
```

页面里的写法与 RuntimeViewer 现状同构：

```swift
struct GeneralPage: View {
    @Setting(\.general)                        // 整段
    private var general

    @Setting(\.updates.automaticallyChecks)    // 叶子标量
    private var automaticallyChecks

    var body: some View {
        SettingsForm {
            Section {
                Toggle("Quit After Closing Last Window", isOn: $general.quitsAfterLastWindowClosed)
                Toggle("Check for Updates Automatically", isOn: $automaticallyChecks)
            }
        }
    }
}
```

设置窗口之外读写（RuntimeViewer 那 13 个非视图调用点）：

```swift
if Settings.current.updates.automaticallyChecks { … }   // current 即 store.value
Settings.current.general.sidebarMaxExpansionDepth = 5
```

### 非目标

- **不搬任何 RuntimeViewer 的设置项与页面。** General / Theme / Notifications / Transformer /
  Indexing / MCP / Updates / Helper 八个页面全部留在 RuntimeViewer。
- **不搬页面内的自定义控件**（外观三图卡片选择器、主题色行、Token 输入框、FlowLayout 等）。
  它们连着 xcassets 图片资源，且通用性存疑；将来真有第二个使用者再单独提案。
- **不做依赖注入。** UIFoundation 只提供 `SettingsStore` 类型，不提供、也不要求
  swift-dependencies / Environment 之外的任何注入机制。宿主想怎么全局访问是宿主的事。
- **不引入 MetaCodable。** 它服务的是「字段声明带默认值」，而字段声明整个属于宿主。
  宿主用 Swift 原生属性默认值即可，`Codable` 合成 init 会填上。
- **不做 iOS / Catalyst / tvOS / visionOS。** 两个 target 都只面向 macOS。模型层碰巧不依赖
  AppKit，但**不因此就顺手放开** —— 放开意味着要为这些平台做条件编译、验证和长期维护，
  而目前没有任何一个使用方需要它。将来真有需要，那时的改动是纯放开（模型层不必返工）。
- **不做设置项搜索**（macOS 系统设置里那个搜索框）、
  **不做 `Settings` scene（SwiftUI App 生命周期）适配** —— 本提案只覆盖 AppKit 生命周期的独立窗口。
- **不进 `UIFoundation` 伞形模块。** 伞形是 macOS 10.15 且不含 SwiftUI，把一个 macOS 14 的
  SwiftUI target `@_exported` 进去会把门槛传染给所有使用方。

## 详细设计

以下签名均已编译验证（macOS 14 目标）。

### 存储层

```swift
public protocol SettingsStorage: Sendable {
    func save(_ data: Data) async throws
    func load() async throws -> Data
}

public struct FileSystemSettingsStorage: SettingsStorage {
    public enum LoadError: Error { case noStoredData }

    public init(
        applicationDirectoryName: String,
        fileName: String = "Settings.json",
        searchPathDirectory: FileManager.SearchPathDirectory = .applicationSupportDirectory
    )
}
```

相对 RuntimeViewer 版本的三处改动：目录名成为**必填参数**（原本硬编码 `"RuntimeViewer"`）；
`createDirectory` 从计算属性的副作用移到 `save()` 里（原本每次读 `fileURL` 都尝试建目录，包括只读的 `load()`）；
`load()` 在无文件时抛 `LoadError.noStoredData`，语义与原版 `SettingsStorageError.noData` 一致。

### 状态层

```swift
@available(macOS 14.0, *)
@MainActor
@Observable
public final class SettingsStore<Value: Codable & Sendable> {
    public var value: Value { didSet { scheduleAutoSave() } }

    public init(
        defaultValue: Value,
        storage: any SettingsStorage,
        autoSaveDelay: Duration = .seconds(1)
    )

    public func load() async          // 读盘并整体替换 value，不触发自动保存
    public func save() async throws   // 立即落盘，取消待执行的防抖任务
}
```

**为什么 `Value` 必须是值类型**（约束上写不出来，只能靠文档与用法保证）：`didSet` 只在
`value` 这个属性被整体赋值时触发。`store.value.general.appearance = .dark` 在值语义下是
「读出 → 改 → 写回」，所以会触发；若 `Value` 是 class，改的是对象内部，`value` 本身没变，
`didSet` 不响，**设置将静默不保存**。这一条是本设计最容易踩的坑，必须写进使用指南。

`load()` 内部用一个 `isApplyingStoredValue` 标志抑制自动保存 —— 否则每次启动读盘都会立刻回写一次。

**迁移不需要额外 API**：宿主在 `await store.load()` 之后直接改 `store.value`，改动会经正常路径
触发一次保存，迁移结果自然落盘。RuntimeViewer 那段 `migrateLegacyThemeProfileIfNeeded()` 就这么接。

### 访问层

```swift
@available(macOS 14.0, *)
public protocol PersistentSettings: Codable, Sendable {
    @MainActor static var store: SettingsStore<Self> { get }
}

@available(macOS 14.0, *)
extension PersistentSettings {
    /// 设置窗口之外的读写入口，等价于 `store.value`。
    @MainActor public static var current: Self { get set }
}

@available(macOS 14.0, *)
@MainActor
@propertyWrapper
public struct AppSettings<Root: PersistentSettings, Value> {
    public init(_ keyPath: WritableKeyPath<Root, Value>)

    public var wrappedValue: Value { get nonmutating set }   // Root.store.value[keyPath:]
    public var projectedValue: Binding<Value> { get }
}
```

**store 从 `Root.store` 这个类型级入口取**，`AppSettings` 内部不持有 store、不读 Environment、
不碰任何依赖容器。宿主用 `typealias Setting<Value> = AppSettings<Settings, Value>` 消掉第一个泛型参数，
调用点就回到 RuntimeViewer 现在的写法。

之所以敢这么做，是因为「不经 Environment 也能刷新」已经实测确认（见「前期调研」）：SwiftUI 在
`body` 求值期间开着 observation tracking，属性包装器在这期间读 `Root.store.value` 就足以建立依赖。

**`AppSettings` 不遵守 `DynamicProperty`** —— 对照实验证实它与刷新无关（同一份代码去掉一致性、
以及完全不用属性包装器直接读 store，三组刷新行为完全一致）。它在这里是空壳，因为这个包装器是纯计算、
没有任何需要 SwiftUI 管理的内部存储；`DynamicProperty.update()` 的用途正是让 SwiftUI 在 `body`
求值前注入/刷新包装器内部的 `@State` / `@Environment` 之类存储。上一版走 Environment 时它是必需的，
改静态入口后不再是。`projectedValue` 也不依赖它（`$` 语法只要求存在该属性）。

**因此不保留这层一致性** —— 留着会让人以为刷新靠它，删的时候不敢删。将来若真要在包装器内部加
SwiftUI 管理的存储，那时再加回来，那是个纯新增的改动。指南里要写明刷新来自 observation tracking。

### UI 层

```swift
@available(macOS 14.0, *)
public struct SettingsPage: Identifiable {
    public enum Icon {
        case symbol(String, tint: Color?)
        case text(String, tint: Color?)
        case image(Image)
    }

    public init<Content: View>(
        _ title: String,
        id: String? = nil,
        symbol: String,
        tint: Color? = nil,
        @ViewBuilder content: @MainActor @escaping () -> Content
    )
}

@available(macOS 14.0, *)
@resultBuilder
public enum SettingsPageBuilder { /* buildBlock / buildExpression / buildOptional / buildEither / buildArray */ }

@available(macOS 14.0, *)
public struct SettingsRootView: View {
    public init(
        sidebarWidth: CGFloat = 185,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    )
}

@available(macOS 14.0, *)
@MainActor
open class SettingsWindowController: XiblessWindowController<SettingsWindow> {
    public init(
        title: String = "Settings",
        contentWidth: CGFloat = 715,
        minimumContentHeight: CGFloat = 400,
        @SettingsPageBuilder pages: () -> [SettingsPage]
    )
}

@available(macOS 14.0, *) public struct SettingsForm<Content: View>: View
@available(macOS 14.0, *) public struct SettingsPageIcon: View
```

`SettingsPage` 的 `id` 默认取 `title`；显式传 `id` 是为了让标题本地化后选中态不失效
（RuntimeViewer 原版直接拿 `rawValue` 当 id，标题即 id，本地化后会断）。

### 两处替代外部依赖的实现

**隐藏侧栏开关按钮**（原本靠 SwiftUIIntrospect）：用一个小 `NSViewRepresentable`
（`WindowConfigurationReader`）取 `view.window`，然后按 identifier
`com.apple.SwiftUI.navigationSplitView.toggleSidebar` 找到 toolbar item 隐藏。逻辑与原版相同，
只是取 window 的手段从 Introspect 换成自建，省掉一个依赖。

**注意**：macOS 26 上 SwiftUI 给 AppKit 宿主窗口里的裸 `NavigationSplitView` **不建 toolbar**，
这段因此是空操作（安全跳过）。保留是为旧系统，且旧系统未实测。

**禁止侧栏折叠**（落地时按实测定稿，见前文「侧栏折叠」一节）：**走视图树**找到 `NSSplitView`、
取其 `delegate as? NSSplitViewController`，对每个 `splitViewItem` 直接赋 `canCollapse = false`。
赋值有效且不被覆盖，因此提案初稿准备的二级方案（用 `@DynamicSubclassHook` 对具体实例做
isa-swizzle）**不需要，也没有实现**。

配置在 `viewDidMoveToWindow` 之后的主队列轮次里应用；`configure` 返回是否找到了控制器，
没找到就再排一轮，最多 8 次 —— 实测第一轮即可命中，重试只为兜住 delegate 尚未挂上的情况。

**无论如何都不搬 RuntimeViewer 的全局 `method_exchangeImplementations`。** 它把整个进程里所有
`NSSplitViewItem` 的 `canCollapse` getter 换掉，靠 `viewController.view.window?.isKind(of:)`
过滤——一个基础库不该对宿主 App 里毫不相干的分栏视图动手，何况那个判断在 view 尚未上屏（`window == nil`）时
会走进原实现，行为随时机漂移。

### 目录与命名

```
Sources/UIFoundationSettings/          // 模型层：不 import AppKit
├── SettingsStorage.swift              // 协议 + FileSystemSettingsStorage
├── SettingsStore.swift
├── PersistentSettings.swift           // 协议 + current
└── AppSettings.swift                  // 属性包装器

Sources/UIFoundationSettingsUI/        // UI 层
├── SettingsPage.swift                 // SettingsPage + SettingsPageBuilder
├── SettingsRootView.swift
├── SettingsWindowController.swift     // + SettingsWindow
├── SettingsForm.swift
├── SettingsPageIcon.swift
└── SettingsWindowSupport.swift        // WindowReader、隐藏 toolbar item、禁折叠
```

`UIFoundationSettingsUI` 依赖 `UIFoundationSettings` + `UIFoundationAppKit`（要
`XiblessWindowController`）。模型层只 import `Foundation` / `Observation` / `SwiftUI`
（`AppSettings.projectedValue` 需要 `Binding`），不碰 AppKit —— 这是分层的边界，
**不是**为跨平台留的后门。

文件名在 target 内唯一（`AGENTS.md`「Code Style Notes」的硬性要求）。因为是独立 target，
不需要像 `TabBar+…` 那样加前缀。

## 替代方案考量

**照搬 swift-dependencies。** 回接时 RuntimeViewer 改动最小（`@AppSettings` 一字不动）。
否决理由：给一个 UI 基础库压上依赖注入框架，会传染给每一个使用方 —— UIFoundation 现在只有两个依赖，
且都是「扩展语法糖」性质。静态 `Root.store` 达到同样效果，而且宿主用 typealias 之后调用点写法一样，
这个依赖买不到任何东西。RuntimeViewer 那边继续用 swift-dependencies 把 store 包一层是它自己的自由。

**用 SwiftUI Environment 注入 store**（`@Environment(SettingsStore<Root>.self)`，由
`SettingsRootView` 用 `.environment(store)` 下发）。这条路我验证过，编译与刷新都成立，
但**被明确否决**：它把「取到 store」这件事绑在视图树上，于是设置窗口之外那 13 个非视图调用点
（MCP bridge、主题流、后台索引协调器……）根本用不了同一套入口，得另开一条路；
页面也从此无法脱离 `SettingsRootView` 单独预览。静态入口两个问题都没有。
代价是同一个设置类型全进程只有一个 store 实例 —— 对「设置」这个语义而言这本来就是事实。

**保持 `Value` 为 `@Observable` class，与 RuntimeViewer 现状一致。** 好处是失效粒度更细：
class 上每个分区是独立属性，改 `theme` 不会惊动只读 `general` 的视图；而值类型方案里所有改动
都落在 `store.value` 一个属性上，实测确认会波及所有读设置的视图。
否决理由：class 方案要靠每个属性手写 `didSet { scheduleAutoSave() }` 才会保存，
漏一个就静默失效 —— 这正是当前要修掉的负担。粒度的代价在设置窗口这个场景里可以承受，
见「影响 → 失效粒度」。

**`@Observable` class + `withObservationTracking` 全量追踪**（既保住细粒度，又不用手写 `didSet`：
在 tracking 闭包里把整个对象编码一遍以读遍所有属性，`onChange` 里触发保存并重新注册）。
否决理由：`onChange` 是一次性的、且在 willSet 时机触发，要正确工作就得处理重新注册的时序、
编码开销、以及「拿到的是旧值」这三件事。为消除一个在设置窗口里察觉不到的重绘而引入这套机制，
不划算。**这条路留档，是因为将来若真出现热路径读设置的使用方，它是第一个该重新评估的选项。**

**页面注册用协议（`protocol SettingsPageProviding`）而非值类型 + result builder。** 否决理由：
协议方案要求每个页面单独开一个类型来承载 id / title / icon，比直接写值类型啰嗦；且本仓库既有 DSL
（`ViewHierarchyBuilder` / `MenuBuilder` / `GridContentBuilder`）都是「值类型 + result builder」，
换风格没有理由。

**把设置项也一并抽象**（提供 `Appearance` / `UpdateChannel` 这类常见设置项的现成模型与页面）。
否决理由：这类「通用设置项」的通用性是假的 —— RuntimeViewer 的外观设置连着它自己的
`AppearanceController` 和三张 xcassets 图片，换个 App 就要改。等到出现第二个真实使用者再谈。

**做成 SwiftUI `Settings` scene 而非 `NSWindowController`。** 否决理由：`Settings` scene 只在
SwiftUI App 生命周期下可用，而 RuntimeViewer（以及本库的典型使用方）是 AppKit `NSApplicationDelegate`
生命周期。`NSWindowController` 两边都能用。

## 影响

### 源码兼容性（source compatibility）

**纯新增。** 新 target + 新 trait，默认关闭。现有使用方不打开 `Settings` trait 就完全感知不到，
既有 API 一个都没动。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 失效粒度（值类型方案的已知代价）

实测确认：改任何一个设置项，**所有**在 `body` 里读过设置的视图都会重绘一次，
哪怕它读的是完全无关的字段。追踪粒度落在 `store.value` 这一个属性上，而值类型的嵌套写入
必然要整体写回 `value`。

**在设置窗口里这不构成问题**：同一时刻只有一个页面在屏，页面就是一个 `Form`、几十个控件，
重绘一次察觉不到；而设置项的改动频率是「用户点一下」级别，不是每帧。

**会构成问题的场景**：宿主在主界面的高频路径上直接读设置（例如每次绘制文本都读一次字体大小）。
判据是「读设置的 SwiftUI 视图是否处在会被频繁触发的位置」。真遇到了，缓解手段按代价从低到高：
把设置值取出来存进视图自己的 `@State`、在非视图层缓存快照、
或重新评估「替代方案考量」里那条 `withObservationTracking` 全量追踪的路子。

RuntimeViewer 现状会**变差一点**：它现在是 class 上七个独立分区属性，改 `theme` 不惊动读 `general`
的视图；回接后退化为全局粒度。已知它读设置的 13 个调用点里没有 SwiftUI 热路径
（多为服务与协调器，读一次做决策），因此判断可以承受 —— 但这是回接时要复核的一条。

### 下游影响

**本仓库内**：新增 target `UIFoundationSettings` 与 product 同名；`Package.swift` 加 trait `Settings`。
现有 target 的依赖关系不变。Example App 加一个 demo（需在其 `XCLocalSwiftPackageReference` 的
traits 列表里加上 `Settings`，否则符号不参与编译，demo 链接不上）。

**RuntimeViewer**（本提案承诺回接，是唯一已知下游）。完整迁移清单：

**① 包声明**

`RuntimeViewerPackages/Package.swift:98` 的 `UIFoundationTraits` 集合加 `"Settings"`；
`RuntimeViewerSettings` target 加 `UIFoundationSettings` 依赖，`RuntimeViewerSettingsUI` target 加
`UIFoundationSettingsUI` 依赖 —— 两侧的分层一一对应。

**⓪ 先决条件：iOS 端要有个说法。** 本库两个 target 都只做 macOS，而 RuntimeViewer 现在
`RuntimeViewerApplication`（被 iOS 端 `RuntimeViewerUsingUIKit` import）无条件依赖
`RuntimeViewerSettings`。回接后 iOS 端会编译不过，三选一：
① iOS 端已不维护，直接给 `RuntimeViewerSettings` 依赖加 `.when(platforms: appkitPlatforms)`，
并把 `RuntimeViewerApplication` 里读设置的地方用 `#if os(macOS)` 圈起来（`ContentTextViewModel`
等）；② RuntimeViewer 自己保留一份 iOS 可用的最小实现；③ 将来若确有需要，再提一个提案把本库的
模型层放开到 iOS —— 模型层本就不 import AppKit，那时的改动是纯放开，不返工。
**回接开工前必须先定这个，否则做到一半会卡住。**

**② 逻辑层 `RuntimeViewerSettings/`**

| 文件 | 改动 |
|---|---|
| `SettingsStorage.swift` | **删除**（-48 行），改用 `FileSystemSettingsStorage(applicationDirectoryName:)`；`DEBUG` 下的 `"RuntimeViewer-Debug"` 分支挪到构造点 |
| `Settings.swift` | `@Observable final class` → `struct Settings: PersistentSettings`；删掉 7 处 `didSet { scheduleAutoSave() }`、`scheduleAutoSave()`、`saveNow()`、`load()`、`saveTask`、`storage`、`shared`（-80 行左右）；新增 `static let store`；`@Loggable` 一并去掉（它只服务于已删除的存取方法） |
| `Settings.swift` 里的 `migrateLegacyThemeProfileIfNeeded()` | **保留**，但要改调用点：它现在是 `load()` 的尾巴，而 `load()` 归 store 所有了，迁移逻辑得自己找地方站 —— 放在 App 启动 `await Settings.store.load()` 之后 |
| `Settings+Types/Theme/Update.swift` | **不动**。MetaCodable 的 `@Codable` / `@Default` / `@MemberInit` 全作用在嵌套 struct 上，不受顶层 class→struct 影响 |
| `UpdaterClient*.swift` | 不动（与设置存储无关） |

**③ UI 层 `RuntimeViewerSettingsUI/`**

| 文件 | 改动 |
|---|---|
| `AppSettings.swift` | **删除**（-32 行），换成一行 `typealias AppSettings<Value> = UIFoundationSettings.AppSettings<Settings, Value>` |
| `SettingsForm.swift` / `SettingsIcon.swift` / `RuntimeViewerSettingsStyle.swift` / `SettingsRootView.swift` / `SettingsWindowController.swift` | **全部删除**（-270 行） |
| 新增一个薄文件 | 8 个 `SettingsPage` 的注册 + 窗口单例，替代原来那个 private enum（约 40 行） |
| `Components/` 8 个页面 | **调用点一字不改** —— `@AppSettings(\.general)` 与 `@AppSettings(\.update.automaticallyChecks)` 靠上面那行 typealias 原样成立；只改 import |
| `Resources/` | 不动（外观选择器那三张图仍归 RuntimeViewer） |
| `AppCoordinator.swift:22` | `settingsWindowController.showWindow(nil)` 不变，只是单例改由 RuntimeViewer 自己持有 |

**④ 13 个调用点，按语义分三类**

- **只读**（`WindowLifecycleController`、`AppearanceController`、`ContentTextViewModel`、
  `RuntimeConnectionNotificationService`、`RuntimeBackgroundIndexingCoordinator`、
  `MCPBridgeServer`）：`settings.general.x` → `Settings.current.general.x`，机械替换。
- **写入**（`MainViewModel.swift:173,181` 的字号增减）：
  `settings.theme.fontSize = …` → `Settings.current.theme.fontSize = …`。
  **这里有静默出错的陷阱**：设置从引用变值之后，
  `var copy = Settings.current; copy.theme.fontSize = 14` 改的是副本，不落盘也不通知任何人。
  迁移时必须逐个确认写入落在 `Settings.current` 上，而不是某个中间变量。
- **观察**（三处，见下）。

**⑤ 三处观察循环 —— 迁移的真正难点**

它们都建立在 `@Observable` 的追踪上，struct 化后**都还能工作，但触发频率变粗**：追踪从
「class 上的某个分区属性」退化为「`store.value` 这一个属性」，于是**任何**设置改动都会唤醒它们。

| 位置 | 机制 | 迁移后的行为 | 判断 |
|---|---|---|---|
| `ResolvedThemeStream.swift:29` | `Observable.tracking { ResolvedTheme(settings:) }` + `distinctUntilChanged` + `share(replay:1)` | 改 MCP 端口也会重算一次 `ResolvedTheme`（14 colors + 2 dictionaries），但 `distinctUntilChanged` 拦住重复推流 | **可接受但确有回退** —— 这个类的存在理由恰恰是压掉重复重算（见其文件头注释），迁移把它拉回去一点。频率是「用户改任一设置」级别，不是每帧 |
| `UpdaterService.swift:112` | 递归 `withObservationTracking { _ = settings.update }` | 任何设置改动都会 re-apply 一遍 Sparkle 属性 | **无害**，写入幂等 |
| `MCPService.swift:164` | `SwiftNavigation.observe` + 手工前后值比较 | 闭包唤醒得更频繁，但内部比较拦住误重启 | **无害**，已有比较兜底 |

`Observable+Tracking.swift:23-31` 那段注释在这里要重读一遍：**读必须发生在 tracking 闭包内部**，
否则追踪静默失效。迁移后 `ResolvedTheme(settings: Settings.current)` 的读发生在闭包内，成立；
但若有人图省事先 `let snapshot = Settings.current` 再传进去，追踪就永久停摆且不报错。

**⑥ 测试**

`SettingsUpdateTests.swift` **一行不改** —— 它只测 `Settings.Update` 这个纯值类型的
`allowedChannels` / `timeInterval` / `displayName`，完全不碰 `Settings` 本身的存取。

**⑦ 依赖注入**

是否保留 `@Dependency(\.settings)` 由 RuntimeViewer 自己决定：静态入口 `Settings.current`
已经够用，想继续走依赖容器就把 store 注册进去，两者不冲突。
**RuntimeViewer 的最低系统版本必须已经是 macOS 14+** —— 它现在就在用 `@Observable`，所以成立。

**MachOKitUI / PrivateSymbols / StarLight**：不受影响（不打开新 trait 就不参与编译）。

### 文档与示例

- 新增使用指南 `Documentations/SettingsWindow.md`：必须写清四条调用方契约 ——
  ① 设置模型必须是值类型（是 class 就静默不保存）；② macOS 14 门槛；③ 页面 id 与本地化；
  ④ 失效粒度是全局的，别在高频路径上直接读设置。
  另需提醒一处命名：本库导出的 `AppSettings` 是属性包装器，宿主的设置模型**别也叫这个名字**
  （RuntimeViewer 的模型叫 `Settings`，正好不撞）。
- `Documentations/README.md` 索引加一行。
- `Documentations/Evolutions/README.md` 提案表加一行。
- `CLAUDE.md` / `AGENTS.md` 加一节（与 TabBar / SystemHUD 等同格式）。
- Example App 加一个 `SettingsDemoViewController`（按钮打开设置窗口，两三个示例页面）。

## API 演进与废弃策略

- 本提案不替代任何既有 API，无废弃项。
- `SettingsStorage` 是协议，将来加方法必须带默认实现，否则破坏外部实现者。
- `SettingsPage.Icon` 是 public enum，加 case 是源码破坏性的（宿主可能 switch）。
  预计将来会加 `.imageResource` 之类，届时评估是否需要改成结构体 + 静态工厂。**落地时按 enum 实现，
  但在指南里注明它不承诺 case 稳定。**
- 不需要 semver major 跃迁（纯新增）。

## 落地步骤

每步单独可构建：

1. `Package.swift` 加 trait `Settings` + 两个 target/product：`UIFoundationSettings`（模型层）与
   `UIFoundationSettingsUI`（UI 层，依赖前者 + `UIFoundationAppKit`），各放一个空文件占位，
   确认 `swift build --traits Settings` 通过。
2. 模型层（`SettingsStorage` / `SettingsStore` / `PersistentSettings` / `AppSettings`），
   带单元测试：防抖只保存一次、`load()` 不触发回写、嵌套 keyPath 改动会触发保存。
3. UI 层（`SettingsPage` / `SettingsRootView` / `SettingsForm` / `SettingsPageIcon`）。
4. 窗口层（`SettingsWindowController`）+ **实测**侧栏折叠：先试直接赋值 `canCollapse = false`，
   被 SwiftUI 覆盖则退到实例级 isa-swizzle。把实测结论写进决策日志（它是「详细设计」里那条推测的落点）。
5. Example App 加 demo（记得在 traits 列表里加 `Settings`）。
6. 写 `Documentations/SettingsWindow.md`，更新三处索引与 `CLAUDE.md` / `AGENTS.md`。
7. **另起一轮**：RuntimeViewer 侧回接（不在本仓库的 commit 里）。

收尾判断：
- **配套专题文章**：要写使用指南 —— 「设置模型必须是值类型，否则静默不保存」是一条从签名完全看不出来、
  违反了就出错的契约，正是指南的判据。**实现说明暂不写**，除非第 4 步的侧栏折叠实测逼出了非直觉的实现。
- **新术语**：暂无。若第 4 步用到 isa-swizzle，则「isa-swizzle 与 method swizzling 之别」登记进全局术语表
  （跨项目通用，不进项目表）。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-12 | Created as Draft | 调研 RuntimeViewer 的 `RuntimeViewerSettings` / `RuntimeViewerSettingsUI` 共 3243 行，识别出可复用部分约 250 行。三个方向由用户拍板：搬「壳 + 泛型存储」、零新依赖、承诺回接 RuntimeViewer。 |
| 2026-08-12 | 验证泛型 Environment 注入可行 | `@Environment(SettingsStore<Root>.self)` 在泛型 `@MainActor` 属性包装器内成立。整套骨架原型在 `-target arm64-apple-macos14.0` 下编译通过。**此方案随后被否**，见下一行。 |
| 2026-08-12 | 注入层改为静态入口，不用 Environment | 用户要求 `AppSettings` 泛型化搬过来、但不走环境变量。改为 `PersistentSettings` 协议提供 `static var store`，`AppSettings` 直接读 `Root.store`。**实测确认不经 Environment 也能刷新视图**（`NSHostingView` 挂离屏窗口数 `body` 求值次数：改动后 1 → 2），因为 SwiftUI 的 `body` 求值本身开着 observation tracking。副作用是 UI 层不再需要泛型参数，且设置窗口之外的调用点有了统一入口 `Settings.current`。 |
| 2026-08-12 | In Progress → Implemented | 落地步骤 1–6 全部完成：两个 target + trait、模型层、UI 层、窗口层、Example demo、文档。`swift build --traits Settings` 与不带 trait 的构建都通过；全量测试 63 项通过（退出码 0，非 xcsift 摘要）；Example App `xcodebuild` 通过。第 7 步 RuntimeViewer 回接不在本仓库，另起一轮。 |
| 2026-08-12 | 实测结掉「侧栏折叠」那条推测 | 三件事：① `canCollapse = false` 直接赋值有效，经 run loop / SwiftUI 更新 / resize 三次复查均保持，**不需要任何 swizzle**，初稿备用的 isa-swizzle 二级方案未实现；② SwiftUI 的 `NavigationSplitViewController` **不在 hosting controller 的 children 里**，只能经 `NSSplitView.delegate` 取得 —— 第一版实现照「遍历 children」写，拿到空数组、静默无效，这多半也是上游当初绕到 swizzle 的原因；③ macOS 26 上 SwiftUI 不给 AppKit 宿主窗口的裸 `NavigationSplitView` 建 toolbar，隐藏 toggle 是空操作（保留供旧系统，旧系统未实测）。详见提案「侧栏折叠」一节。 |
| 2026-08-12 | 修 demo 撑宽窗口的布局 bug | 用户反馈：点开该 demo，浏览器窗口被撑到极宽且缩不回去。原因是 Auto Layout 把 `NSHostingView` 的 SwiftUI 理想宽度当作**硬下限**，而我把三个计数面板做成了横排。实测：横排要求最小宽度 **1006 pt**，改竖排后 **339 pt**。修法是竖排 + 文本 `.fixedSize(horizontal: false, vertical: true)` + 对 hosting view 与 labels 降低水平压缩阻力 + 内容宽度上限 640 pt。**横向排查同类**：detail 区顶部那个共享的 `summaryLabel` 是同一个机制（换行属性挡不住单行 intrinsic 宽度撑窗口），对每个 demo 都成立，一并修掉；经验写进 `AGENTS.md` 的 Example App 一节。 |
| 2026-08-12 | demo 改回独立窗口 + 补 `.plainSymbol` 图标 | 用户指出设置面板本就该是独立窗口，把它内嵌进 demo 的 detail 区是本末倒置 —— 已改为只由 `SettingsWindowController` 打开，计数面板留在 demo 窗口里，反而更能说明「在另一个窗口改设置，这边读设置的视图跟着重绘」。内嵌用法与 `SettingsRootView` 的公开 API 保留（确有 App 这么做），上一行那个 bug 也因此仍然有效。另据用户提供的 RuntimeViewer 设置窗口截图，其侧栏用的是**朴素单色 SF Symbol**（源码里是 `SettingsIcon(symbol:color: .clear)`），而本库只有彩色圆角徽章；`.symbol(name, tint: .clear)` 能去掉底色却去不掉阴影，阴影会落到字形上。因此新增 `Icon.plainSymbol(_:tint:)` 与配套 `SettingsPage(_:id:plainSymbol:tint:content:)` —— 这是回接 RuntimeViewer 的硬需求，否则回接时图标风格对不上。 |
| 2026-08-12 | 修一个 chrome 越界 bug（写真实 demo 时暴露） | 把设置面板**内嵌**进 demo（宿主自己有侧栏）时发现：`settingsWindowChrome()` 原先从 window 向下全遍历，会把**宿主的**侧栏一并锁死。实测两条相关事实：① SwiftUI 的 `.background()` 视图**不在** `NavigationSplitView` 自己的 `NSSplitView` 内，其祖先链是 `AppKitPlatformViewHost` → `NSHostingView` → 宿主容器，所以「向上找最近的 NSSplitView」找到的是宿主那个；② 窗口内向下搜索会同时找到两个。改为「逐层向外、在每层子树内搜索、命中即停，并排除自身祖先链上的 split view」。新增回归测试 `embedding leaves the host's own sidebar collapsible`，已确认它在旧实现下失败（报 chrome escaped its scope）、另两个旧测试则照样通过 —— 说明这条测试是必要的。 |
| 2026-08-12 | Example demo 补成「能看见看不见的东西」 | 初版 demo 只证明「能用」。补充后它展示三件在代码里看不出来的性质：① 三个并排面板 + 计数器暴露失效粒度；② 自定义 `CountingSettingsStorage` 让防抖可见（连点 stepper 只产生一次写盘）；③ 「Mutate a Copy」按钮复现值语义陷阱，显示改副本后 store 纹丝不动、无任何报错。另外顺带覆盖了条件页面（builder 的 `if`）、显式页面 id、`.text` 图标形式。 |
| 2026-08-12 | 实测失效粒度的边界 | 三面板并排实测：改 `appearance` 会让读 `general` 的面板重绘、反之亦然（证实粗粒度），但**不读设置的面板始终不重绘**。因此波及面是「读过设置的视图」而非整棵视图树 —— 这条边界原先没写清，已补进指南 §6 的表格。 |
| 2026-08-12 | 修掉一处测试脆弱性 | 存储测试单独跑绿、全量跑红：它们用固定 `sleep` 等防抖，而自动保存任务是 main-actor 隔离的，并行执行时窗口 chrome 测试正在同一个 actor 上驱动真实窗口布局，保存任务排不上。改为**轮询**等待（最长 3 s，正常 10 ms 内命中）；「不该发生保存」这类断言无状态可轮询，仍用固定等待但把余量提到防抖的 6 倍。连跑 5 轮全量测试均通过。 |
| 2026-08-12 | 测试有效性双向验证 | 两处关键实现都做了「破坏 → 测试翻红 → 恢复 → 转绿」：把 `value` 的 `didSet` 摘掉，3 个存储测试失败；把 `canCollapse` 赋成 `true`，2 个 chrome 测试失败。避免绿色测试其实什么都没测。`SettingsWindowChromeTests` 另行独立推导查找路径，因此写错的查找路径无法自证通过。 |
| 2026-08-12 | Accepted → In Progress | 用户批准，开始实现。按落地步骤 1–6 在本仓库落地；第 7 步（RuntimeViewer 回接）另起一轮，且开工前需先定「下游影响 ⓪」的 iOS 处置。 |
| 2026-08-12 | 拆成模型层 / UI 层两个 target，都只做 macOS | 起因是查 `Package.swift:432` 发现 RuntimeViewer 的设置逻辑现在在 iOS 上编译，一度据此把模型层设计成跨平台；用户随后明确 **iOS 不考虑**，但认可两层分开。最终形态：分层保留（读设置的模块不必拖进窗口和 `NavigationSplitView`，且与 RuntimeViewer 现有划分一一对应），平台统一收到 macOS。iOS 的连带后果记进「下游影响 ⓪」，作为回接的先决条件。 |
| 2026-08-12 | 去掉 `DynamicProperty` 一致性 | 用户决定。对照实验已证明它与刷新无关，留着会让人误以为是刷新机制而不敢删。将来若包装器内部需要 SwiftUI 管理的存储，再加回来即可（纯新增改动）。 |
| 2026-08-12 | 澄清刷新机制与 `DynamicProperty` 无关 | 对照实验（遵守 / 不遵守 / 不用包装器三组并排）刷新行为完全一致，`body` 求值次数同为 1 → 2 → 3。据此修正了详细设计里「保留 `DynamicProperty` 是为了 `projectedValue` 的 `Binding` 语义」这句错误说法 —— `projectedValue` 同样不依赖它。一致性仍保留，但理由改为惯例与前瞻，且指南须注明它不负责刷新。 |
| 2026-08-12 | 记录失效粒度代价 | 同一次实测发现：改一个视图没读的兄弟字段，视图**同样**重绘（2 → 3）。追踪粒度落在 `store.value` 一个属性上，是值类型方案的固有代价。判断在设置窗口场景可承受，已写入「影响 → 失效粒度」并给出缓解手段与复核点。 |
