# Draft - QuickActionBar.Configuration：收拢外观参数，圆角可自定义

- **状态**: In Progress
- **作者**: JH
- **创建日期**: 2026-11-28
- **最后更新**: 2026-11-28
- **所属愿景**: 无
- **关联提案**: [0039](0039-quick-action-bar-browse-items.md)（浏览按钮，定下了 macOS 26+ 的玻璃底板结构）、[0006](0006-settings-window-configuration.md)（同类的 Configuration 收拢先例）、[0021](0021-spotlight-panel-replica.md)（`SpotlightPanel.Configuration`，本提案照抄它的形状）
- **实现分支 / PR**: `feature/quick-action-bar-configuration`
- **配套文档**: [`QuickActionBar.md`](../QuickActionBar.md)（同批更新，不另写新指南）
- **网页版**: 同目录同名的 `.html`

## 摘要

给 `QuickActionBar` 加一个存在 bar 上的值类型 `QuickActionBar.Configuration`，把现在散在
`present(…)` 九个参数和两个实例属性里的外观与行为设置收进去，并新增一项 `cornerRadius`，
让宿主自定义底板圆角——现在 macOS 26+ 写死 28 pt、更早的系统写死 10 pt。`present` 只留每次打开才
变的三个参数：`parentWindow`、`initialSearchText`、`didClose`。旧的九参数 `present` 与
`requiredClickCount` 标废弃并转发到新 API，`rowHeight` 早已不起作用、标废弃。所有默认值与现在一致，
三个下游 App 不改代码照常编译，只多废弃警告。

## 动机

1. **圆角改不了。** 底板圆角是两处常量，没有任何入口：
   - macOS 26+：`GlassPlatterView.platterCornerRadius = 28`
     （`Sources/UIFoundationAppKit/QuickActionBar/Internal/QuickActionBar+GlassPlatterView.swift:43`），
     在 `setup()` 里赋给 `platterGlassView.cornerRadius`（同文件 `:88`）。
   - macOS 26 以前：`PrimaryRoundedView.updateLayer()` 里 `baseLayer.cornerRadius = 10`
     （`Sources/UIFoundationAppKit/QuickActionBar/Internal/Util/QuickActionBar+PrimaryRoundedView.swift:90`）。

   宿主想让操作栏和自己窗口的圆角一致（比如做成 Xcode「Open Quickly」那样的小圆角），只能改库。
2. **`present` 参数太多。** `present(parentWindow:placeholderText:searchImage:initialSearchText:width:height:showKeyboardShortcuts:canBecomeMainWindow:didClose:)`
   已有九个参数（`Sources/UIFoundationAppKit/QuickActionBar/QuickActionBar.swift:110`），再追加
   `cornerRadius` 就是十个。其中七个是「这个 bar 长什么样」，每次打开都不变，却每次都要重新传：
   示例 App 与三个下游 App 的调用点都在重复同一组值。
3. **设置散在两处。** 同属行为设置的 `requiredClickCount` 是实例属性（`QuickActionBar.swift:44`），
   `showKeyboardShortcuts`、`canBecomeMainWindow` 却是 `present` 参数，宿主得记住哪个在哪。
4. **`height` 名不副实。** 文档注释说它是「the height of the quick action bar」，实际是结果列表的高度：
   `ResultsView` 拿它定滚动视图高度（`QuickActionBar+ResultsView.swift:76`），`calculateWindowFrame`
   只在显示结果时把它加进窗口高度（`QuickActionBar+Window.swift:409`）。示例 App 的滑块也叫
   `resultsHeightSlider`。

## 前期调研

- **现状代码怎么走的**
  - `present(…)` 把参数写进 bar 的三个内部存储 `width`、`height`、`searchImage`
    （`QuickActionBar.swift:79-81`），其余直接设到 `QuickActionBar.Window`：
    `showKeyboardShortcuts`、`currentCanBecomeMainWindow`、`placeholderText`
    （`QuickActionBar.swift:149,164,165`）。
  - `width` 与 `height` 的默认值是调用那一刻主屏宽、高的四分之一（`QuickActionBar.swift:115-116`），
    不是 `DefaultWidth` / `DefaultHeight`——后两者只在没有主屏时兜底。
  - `searchImage` 为 `nil` 时用 `QuickActionBar.DefaultImage`；自定义图会按比例缩到 64 pt 并保留
    `isTemplate`（`QuickActionBar.swift:123-131`）。缩放失败时 `searchImage` 为 `nil`，搜索行就不放图
    （`QuickActionBar+Window.swift:116`）。
  - `requiredClickCount` 在点击时才读（`QuickActionBar+ResultsView.swift:209`），所以现在打开期间改它会立即生效。
  - `rowHeight` 只在 `if #available(macOS 10.13, *) … else { tableView.rowHeight = quickActionBar.rowHeight }`
    的 `else` 分支里读（`QuickActionBar+ResultsView.swift:93-97`）。本库最低 macOS 14，这条分支永远不走，
    **`rowHeight` 早已不起任何作用**。
  - macOS 26+ 的底板是 `GlassPlatterView` 里的 `platterGlassView: NSGlassEffectView`，圆角就是它的
    `cornerRadius`；浏览按钮的圆是另外的 `NSGlassEffectView`，半径按直径的一半逐帧设置（同文件 `:254`），
    与底板圆角无关。`PrimaryRoundedView` 在 macOS 26+ 上故意不设图层圆角：27.2 上图层圆角会打开
    `clipsToBounds`，裁掉越过底板右缘的浏览按钮（指南 §8.5 末条）。
  - macOS 26 以前，`PrimaryRoundedView` 自己的图层同时是模糊视图的 mask（`blurView.layer?.mask = self.layer`，
    同文件 `:75`），所以改它的 `cornerRadius` 就同时改了背景和模糊的形状。
- **仓库里的先例**
  - `SpotlightPanel.Configuration`（`Sources/UIFoundationAppleInternal/SpotlightPanel/SpotlightPanel+Configuration.swift`）：
    `public struct`，全部 `var`，带默认值的 memberwise `init`；`SpotlightPanel` 持有
    `public var configuration`，`init(configuration:)`，`present(on:initialSearchTerm:)` 只收每次打开才变的参数。
  - `SettingsWindowController.Configuration`（[0006](0006-settings-window-configuration.md)）：同样的收拢，
    把运行时状态（`navigator`）与内容（页面 builder）留在 Configuration 外。本提案按同一条线把
    `browseItems`（打开期间可改、带动画的内容）留在外面。
- **下游怎么调用的**（`grep` 三个启用了 `QuickActionBar` trait 的仓库）
  - XCOrganizer `XCOrganizer/QuickOpen/QuickOpenPresenter.swift:58`：`present(parentWindow:placeholderText:width:height:)`
  - StarLight `StarLight/Main/MainActionBarController.swift:133`：`present(placeholderText:width:height:) { … }`
  - RuntimeViewer `RuntimeViewerUsingAppKit/…/SidebarRuntimeObjectListViewController.swift:73`：
    九个参数里的七个加尾随闭包。

  三处都传了新 `present` 没有的参数，所以重载决议只会落到旧方法上，照常编译。
- **尚未验证、实现时实测**
  - 推测：`@_disfavoredOverload` 能让 `present()`、`present(parentWindow:)`、`present { }` 这类两个重载
    都能匹配的调用落到新方法。落地步骤 2 用测试钉住（见该步骤的行为清单）。
  - 推测：`NSGlassEffectView.cornerRadius` 超过底板高度一半时的表现（是否被截到胶囊形）。不影响 API，
    实现时在示例 App 里看一眼并写进指南。

## 提议方案

1. 新增 `QuickActionBar.Configuration`（`public struct`），八个字段：`placeholderText`、`searchImage`、
   `width`、`resultsHeight`、`cornerRadius`、`showsKeyboardShortcuts`、`canBecomeMainWindow`、
   `requiredClickCount`。默认值逐项等于现在 `present` 的默认值；`cornerRadius` 的默认值由
   `Configuration.defaultCornerRadius` 按系统给出（macOS 26+ 为 28，更早为 10）。
2. `QuickActionBar` 持有 `public var configuration`，`init()` 改为 `init(configuration: Configuration = Configuration())`，
   `QuickActionBar()` 的写法不变。
3. 新增 `present(parentWindow:initialSearchText:didClose:)`。它在调用时把 `configuration` 拷一份快照，
   这次打开的整个生命周期只读快照：**打开期间改 `configuration`，下次打开才生效**，八个字段一个规则。
4. 圆角经 `Window.setup` → `PrimaryRoundedView(cornerRadius:)` 一路传下去：macOS 26+ 设给
   `platterGlassView.cornerRadius`，更早的系统设给 `PrimaryRoundedView` 的图层。删掉
   `GlassPlatterView.platterCornerRadius` 与写死的 10。
5. 旧 API 保留并标废弃：
   - 九参数 `present`：`@available(*, deprecated, message:)` + `@_disfavoredOverload`，把七个外观参数写进
     `configuration`，再调新 `present`。
   - `requiredClickCount`：转发到 `configuration.requiredClickCount`。
   - `rowHeight`：标废弃、注明不起作用，存储照旧保留，不接进任何地方。
6. 示例 App、测试、指南、README 改用新 API；示例 App 的 Quick Action Bar 演示页加一个圆角滑块。

### 非目标

- **不把 `browseItems` 收进来**：它在 bar 打开期间可改，改了会带动画收回再长出，是内容不是配置。
- **不改三个下游 App 的调用点**：它们只多废弃警告。迁移各自在自己的仓库里另做。
- **不改别的写死值**：搜索防抖 0.2 s、`animationPadding` 40、搜索行 56 pt 高度、窗口层级都不动。
- **不动 `DefaultWidth` / `DefaultHeight` / `DefaultPlaceholderString` / `DefaultImage`**：大写开头的静态名
  沿用上游写法，改名不在本次范围。
- **不给 Configuration 加 `Equatable` / `Sendable`**：`NSImage` 字段让这两项都要另外论证，目前没有调用方需要。
- **不做圆角以外的新外观项**（边框、背景色、阴影）：没有需求。
- **不保留 `requiredClickCount` 的「打开期间改立即生效」**：统一成快照规则；示例 App 和下游都是打开前设置。

## 改动地图

| 文件 / 类型 | 动作 | 改什么 | 为什么 | 步骤 |
|---|---|---|---|---|
| `Sources/UIFoundationAppKit/QuickActionBar/QuickActionBar+Configuration.swift` · `QuickActionBar.Configuration` | 新增 | 八个字段、带默认值的 `init`、`static var defaultCornerRadius` | 外观与行为设置的唯一入口 | 1 |
| `Sources/UIFoundationAppKit/QuickActionBar/QuickActionBar.swift` · `QuickActionBar` | 修改 | 加 `configuration`、`init(configuration:)`、内部快照 `presentedConfiguration`；`requiredClickCount` 改为废弃的转发属性；`rowHeight` 标废弃 | 配置存在 bar 上 | 1 |
| `Sources/UIFoundationAppKit/QuickActionBar/QuickActionBar.swift` · `present(parentWindow:initialSearchText:didClose:)` | 新增 | 拍快照，由快照解出 `width` / `height` / `searchImage`，其余流程照旧 | 新的打开入口 | 2 |
| `Sources/UIFoundationAppKit/QuickActionBar/QuickActionBar.swift` · 九参数 `present` | 修改 | 标 `deprecated` + `@_disfavoredOverload`，写进 `configuration` 后调新 `present` | 下游不改照常编译 | 2 |
| `Sources/UIFoundationAppKit/QuickActionBar/Internal/QuickActionBar+ResultsView.swift` · `ResultsView` | 修改 | 点击判断改读 `presentedConfiguration.requiredClickCount` | 快照规则 | 2 |
| `Sources/UIFoundationAppKit/QuickActionBar/Internal/QuickActionBar+Window.swift` · `Window.setup` | 修改 | 加 `cornerRadius:` 参数，传给 `PrimaryRoundedView` | 圆角往下传 | 3 |
| `Sources/UIFoundationAppKit/QuickActionBar/Internal/Util/QuickActionBar+PrimaryRoundedView.swift` · `PrimaryRoundedView` | 修改 | `init(cornerRadius:)`；26 以前的 `updateLayer()` 用它代替 10；26+ 传给 `GlassPlatterView` | 两条系统路径都可配 | 3 |
| `Sources/UIFoundationAppKit/QuickActionBar/Internal/QuickActionBar+GlassPlatterView.swift` · `GlassPlatterView` | 修改 | `init(platterContentView:cornerRadius:)`；删 `static let platterCornerRadius` | 去掉写死的 28 | 3 |
| `Tests/UIFoundationTests/QuickActionBarConfigurationTests.swift` | 新增 | 默认值、快照、旧 `present` 转发、重载决议、圆角到达底板 | 钉住新契约 | 1–3 |
| `Tests/UIFoundationTests/QuickActionBarPresentationTests.swift`、`QuickActionBarBrowseButtonTests.swift`、`QuickActionBarEscapeTests.swift` | 修改 | `present(width:height:)` 等改为先设 `configuration` | 测试不调废弃 API | 2 |
| `UIFoundationExample-macOS/…/Demos/QuickActionBarDemoViewController.swift` | 修改 | 改用 `configuration`；加「Corner radius」滑块 | 演示新能力，也是可运行的调用示例 | 4 |
| `UIFoundationExample-macOS/…/Demos/QuickActionBarBrowseButtons/QuickActionBarBrowseButtonsDemo+Launcher.swift`、`+Notes.swift`、`+Tags.swift` | 修改 | 改用 `configuration` | 示例不留废弃警告 | 4 |
| `Documentations/QuickActionBar.md` | 修改 | §1 示例、§2 表格加 Configuration 与新旧 `present`、新增「配置」小节（快照规则、圆角默认值的来历、两条系统路径）、§7 提圆角滑块 | 指南与行为同批 | 4 |
| `README.md` · Quick Action Bar 一节 | 修改 | 示例改用 `configuration`，提一句 `cornerRadius` | 对外文档 | 4 |
| `Documentations/Evolutions/README.md` | 修改 | 登记本提案；落地时改编号与状态 | 索引 | 0、4 |

## 架构图

公开 API 的变化：

```text
QuickActionBar
+ ├── var configuration: Configuration                    read once per present()
+ ├── init(configuration: Configuration = Configuration())
+ ├── present(parentWindow:initialSearchText:didClose:)
~ ├── present(parentWindow:placeholderText:searchImage:   deprecated, @_disfavoredOverload
~ │           initialSearchText:width:height:               → writes configuration
~ │           showKeyboardShortcuts:canBecomeMainWindow:    → calls the new present
~ │           didClose:)
~ ├── var requiredClickCount                              deprecated → configuration.requiredClickCount
~ ├── var rowHeight                                       deprecated, no effect (unchanged storage)
  └── var browseItems                                     unchanged: content, live-updated

+ QuickActionBar.Configuration
+   placeholderText · searchImage · width? · resultsHeight?
+   cornerRadius (default: defaultCornerRadius = 28 on macOS 26+, 10 before)
+   showsKeyboardShortcuts · canBecomeMainWindow · requiredClickCount
```

圆角从配置到屏幕的路径：

```text
present(parentWindow:initialSearchText:didClose:)
+ ├── presentedConfiguration = configuration              snapshot
~ ├── width / height / searchImage                        resolved from the snapshot
~ └── Window.setup(parentWindow:initialSearchText:cornerRadius:)
~       └── PrimaryRoundedView(cornerRadius:)
~             ├── macOS 26+   GlassPlatterView(platterContentView:cornerRadius:)
~             │                 └── platterGlassView.cornerRadius = cornerRadius
-             │                     (was static platterCornerRadius = 28)
~             └── before 26   updateLayer(): layer.cornerRadius = cornerRadius
-                               (was 10)

ResultsView row click
~ └── presentedConfiguration.requiredClickCount           (was quickActionBar.requiredClickCount)
```

## 详细设计

### `QuickActionBar.Configuration`

```swift
#if QuickActionBar && os(macOS)

import AppKit

extension QuickActionBar {
    /// Everything a host can set about how the bar looks and behaves.
    ///
    /// The bar reads it when ``QuickActionBar/present(parentWindow:initialSearchText:didClose:)``
    /// is called and keeps that copy until it closes: a change made while the bar is open applies
    /// to the next presentation.
    public struct Configuration {
        /// The placeholder shown in the empty search field.
        public var placeholderText: String

        /// The image at the leading edge of the search field. An image other than
        /// ``QuickActionBar/DefaultImage`` is scaled proportionally to fit 64 points.
        public var searchImage: NSImage

        /// The width of the bar. `nil` takes a quarter of the main screen's width, measured when
        /// the bar is presented.
        public var width: CGFloat?

        /// The height of the results list below the search field. `nil` takes a quarter of the
        /// main screen's height, measured when the bar is presented.
        public var resultsHeight: CGFloat?

        /// The corner radius of the bar's platter, kept as results make it taller. The browse
        /// buttons stay circles whatever it is.
        public var cornerRadius: CGFloat

        /// Whether the first ten rows show their keyboard shortcuts (↩ and ⌘1–⌘9).
        public var showsKeyboardShortcuts: Bool

        /// Whether the bar's panel can become the main window.
        public var canBecomeMainWindow: Bool

        /// The number of clicks that activates a row in the results.
        public var requiredClickCount: RequiredClickCount

        public init(
            placeholderText: String = QuickActionBar.DefaultPlaceholderString,
            searchImage: NSImage = QuickActionBar.DefaultImage,
            width: CGFloat? = nil,
            resultsHeight: CGFloat? = nil,
            cornerRadius: CGFloat = Configuration.defaultCornerRadius,
            showsKeyboardShortcuts: Bool = false,
            canBecomeMainWindow: Bool = true,
            requiredClickCount: RequiredClickCount = .double
        ) {
            self.placeholderText = placeholderText
            self.searchImage = searchImage
            self.width = width
            self.resultsHeight = resultsHeight
            self.cornerRadius = cornerRadius
            self.showsKeyboardShortcuts = showsKeyboardShortcuts
            self.canBecomeMainWindow = canBecomeMainWindow
            self.requiredClickCount = requiredClickCount
        }

        /// The platter's corner radius when none is set: 28 points on macOS 26 and later — half of
        /// the collapsed bar's 56-point height, as Spotlight's — and 10 points before.
        public static var defaultCornerRadius: CGFloat {
            if #available(macOS 26.0, *) {
                28
            } else {
                10
            }
        }
    }
}

#endif
```

字段命名的取舍：

- `showsKeyboardShortcuts`：布尔属性读成对接收者的断言，照 AppKit 的 `showsResizeIndicator`、
  `showsToolbarButton`；旧参数名 `showKeyboardShortcuts` 只留在废弃的 `present` 上。
- `resultsHeight`：旧参数 `height` 实为结果列表高度（见动机 4），换名说清楚。
- `canBecomeMainWindow`：沿用旧名，它对应 `NSWindow.canBecomeMain`，读起来已是断言。
- `searchImage` 不做 Optional：现在 `nil` 的唯一含义是「用默认图」，直接把默认图写成默认值，`nil` 就不必背一层含义。
- `width` / `resultsHeight` 做 Optional：`nil` 表示「打开那一刻按主屏的四分之一算」，这是现在的默认行为，
  放在构造时算会在换屏后过时。
- `cornerRadius` 不做 Optional：默认值按系统不同，用 `defaultCornerRadius` 把它写在明处，调用方能读到
  也能在它基础上加减。

### `QuickActionBar` 上的变化

```swift
public final class QuickActionBar {
    /// How the bar looks and behaves. Read when the bar is presented.
    public var configuration: Configuration

    /// Create a `QuickActionBar` instance.
    public init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
        self.presentedConfiguration = configuration
    }

    /// The configuration of the current, or last, presentation.
    internal private(set) var presentedConfiguration: Configuration

    @available(*, deprecated, message: "Set configuration.requiredClickCount instead.")
    public var requiredClickCount: RequiredClickCount {
        get { configuration.requiredClickCount }
        set { configuration.requiredClickCount = newValue }
    }

    @available(*, deprecated, message: "Has no effect: result rows size themselves automatically.")
    public var rowHeight: CGFloat = 36

    // internal var width / height / searchImage stay: they hold the values resolved at present().
}

public extension QuickActionBar {
    /// Present a `QuickActionBar` with the current ``configuration``.
    ///
    /// - Parameters:
    ///   - parentWindow: the window to center the quick action bar in, or nil to center on screen
    ///   - initialSearchText: the text to initially populate the search field with
    ///   - didClose: called once the quick action bar has closed
    func present(
        parentWindow: NSWindow? = nil,
        initialSearchText: String? = nil,
        didClose: (() -> Void)? = nil
    )

    @available(*, deprecated, message: "Set the appearance on configuration, then call present(parentWindow:initialSearchText:didClose:).")
    @_disfavoredOverload
    func present(
        parentWindow: NSWindow? = nil,
        placeholderText: String? = QuickActionBar.DefaultPlaceholderString,
        searchImage: NSImage? = nil,
        initialSearchText: String? = nil,
        width: CGFloat = (NSScreen.main?.frame.width ?? (QuickActionBar.DefaultWidth * 4)) / 4.0,
        height: CGFloat = (NSScreen.main?.frame.height ?? (QuickActionBar.DefaultHeight * 4)) / 4.0,
        showKeyboardShortcuts: Bool = false,
        canBecomeMainWindow: Bool = true,
        didClose: (() -> Void)? = nil
    ) {
        configuration.placeholderText = placeholderText ?? ""
        configuration.searchImage = searchImage ?? QuickActionBar.DefaultImage
        configuration.width = width
        configuration.resultsHeight = height
        configuration.showsKeyboardShortcuts = showKeyboardShortcuts
        configuration.canBecomeMainWindow = canBecomeMainWindow
        present(parentWindow: parentWindow, initialSearchText: initialSearchText, didClose: didClose)
    }
}
```

新 `present` 的开头（其余与现在相同）：

```swift
presentedConfiguration = configuration
let screenFrame = NSScreen.main?.frame
self.width = presentedConfiguration.width
    ?? (screenFrame?.width ?? QuickActionBar.DefaultWidth * 4) / 4
self.height = presentedConfiguration.resultsHeight
    ?? (screenFrame?.height ?? QuickActionBar.DefaultHeight * 4) / 4
self.searchImage = {
    let configuredImage = presentedConfiguration.searchImage
    guard configuredImage !== QuickActionBar.DefaultImage else { return configuredImage }
    let scaledImage = QuickActionBar.scaleImageProportionally(configuredImage, to: 64)
    scaledImage?.isTemplate = configuredImage.isTemplate
    return scaledImage
}()
// …
quickBarWindow.showKeyboardShortcuts = presentedConfiguration.showsKeyboardShortcuts
quickBarWindow.setup(
    parentWindow: parentWindow,
    initialSearchText: initialSearchText,
    cornerRadius: presentedConfiguration.cornerRadius
)
// …
quickBarWindow.currentCanBecomeMainWindow = presentedConfiguration.canBecomeMainWindow
quickBarWindow.placeholderText = presentedConfiguration.placeholderText
```

- 旧 `present` 会**改写** `configuration` 里它覆盖的六个字段（`placeholderText`、`searchImage`、`width`、
  `resultsHeight`、`showsKeyboardShortcuts`、`canBecomeMainWindow`），`cornerRadius` 与
  `requiredClickCount` 不动。旧调用方每次都传全套，行为与现在相同；新旧混用的宿主以最后一次旧调用为准，
  在废弃消息与指南里写明。
- 旧 `present` 的 `width` / `height` 默认值仍在调用处求值，与现在一样，写进配置时已是具体数字。

### 内部视图

```swift
// QuickActionBar+Window.swift
internal func setup(parentWindow: NSWindow? = nil, initialSearchText: String?, cornerRadius: CGFloat)
//   let content = QuickActionBar.PrimaryRoundedView(cornerRadius: cornerRadius)

// QuickActionBar+PrimaryRoundedView.swift
internal final class PrimaryRoundedView: NSView {
    let cornerRadius: CGFloat
    init(cornerRadius: CGFloat)               // replaces init(frame:); init?(coder:) becomes unavailable
    // macOS 26+: GlassPlatterView(platterContentView: contentView, cornerRadius: cornerRadius)
    // before 26: updateLayer() sets baseLayer.cornerRadius = cornerRadius
}

// QuickActionBar+GlassPlatterView.swift
init(platterContentView: NSView, cornerRadius: CGFloat)
//   platterGlassView.cornerRadius = cornerRadius   (static platterCornerRadius removed)
```

`PrimaryRoundedView` 只在 `Window.setup` 里用代码创建，`init(frame:)` / `init?(coder:)` 没有别的调用方；
换成 `init(cornerRadius:)` 后把 `init?(coder:)` 标 `unavailable`，与同目录的 `GlassPlatterView` 一致。
macOS 26+ 上 `PrimaryRoundedView` 仍不设图层圆角（理由见调研里的 `clipsToBounds`），这条不变。

## 替代方案考量

- **每次把 Configuration 传进 `present(configuration:…)`**：用户否决。bar 本身是长寿对象，外观每次打开都一样，
  存在 bar 上与 `SpotlightPanel` 一致，调用点也最短。
- **只给旧 `present` 加 `cornerRadius:` 参数**：解决眼前需求，但参数涨到十个，正是这次要结束的问题。
- **直接删掉九参数 `present`**：用户否决。那是破坏性 API 改动，三个下游 App 都要同批改，按提案制要升到完整档；
  废弃保留零成本过渡。
- **`cornerRadius: CGFloat?`，`nil` 表示按系统取默认**：能表达，但调用方读不到默认值是多少，想「在默认基础上
  小一点」无从下手。`defaultCornerRadius` 把它公开出来更直白。
- **用枚举 `CornerStyle { case automatic, capsule, fixed(CGFloat) }`**（仿 `UIButton.Configuration.cornerStyle`）：
  底板展开后高度在变，「capsule」在展开态没有确定含义；目前只有「给个数」一种需求，等真有第二种再扩展。
- **把 `browseItems` 也收进 Configuration**：它打开期间可改并带动画，放进快照规则就失去这个能力。
- **保留 `requiredClickCount` 打开期间立即生效**：要让一个字段例外于快照规则，规则就得写成「除了……」，
  没有调用方依赖这个时机。
- **把 `rowHeight` 接回去生效**：行高由 `usesAutomaticRowHeights` 按内容决定，强设固定行高会改变现有外观；
  没有需求，标废弃说明它不起作用更诚实。

## 影响

### 源码兼容性（source compatibility）

**纯新增 + 废弃**，不破坏现有调用点：

- `QuickActionBar()` 仍可用（`init(configuration:)` 带默认参数）。
- 九参数 `present` 照旧可调：传了新 `present` 没有的参数（`placeholderText`、`width` 等）的调用只有旧方法匹配。
- 两者都能匹配的调用（`present()`、`present(parentWindow:)`、`present { }`）由 `@_disfavoredOverload`
  交给新方法。这一点必须成立：宿主先设了 `configuration.placeholderText` 等再调 `present()`，若落到旧方法，
  它会用自己的默认参数把这些字段写回默认值。落地步骤 2 用测试钉住。
- `requiredClickCount`、`rowHeight` 读写照旧，多一条废弃警告。

改前 / 改后：

```swift
// Before
actionBar.requiredClickCount = .single
actionBar.present(parentWindow: window, placeholderText: "Open Quickly", width: 640, height: 320)

// After
actionBar.configuration.requiredClickCount = .single
actionBar.configuration.placeholderText = "Open Quickly"
actionBar.configuration.width = 640
actionBar.configuration.resultsHeight = 320
actionBar.configuration.cornerRadius = 12
actionBar.present(parentWindow: window)
```

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- **本仓库**：只动 `UIFoundationAppKit` 的 QuickActionBar 目录（trait 关闭时编译为空）、它的测试与示例 App。
  `SpotlightPanel` 是独立实现，不受影响。
- **XCOrganizer**（`QuickOpenPresenter.swift:58`）、**StarLight**（`MainActionBarController.swift:133`）、
  **RuntimeViewer**（`SidebarRuntimeObjectListViewController.swift:73`）：照常编译，各多一条废弃警告，
  行为不变。迁移另做。
- **MachOKitUI / PrivateSymbols**：未启用 `QuickActionBar` trait，不受影响。

### 文档与示例

- `Documentations/QuickActionBar.md`：§1、§2、新增「配置」小节、§7；§8.5 末条（26+ 不设图层圆角）不变。
- `README.md` 的 Quick Action Bar 示例。
- 示例 App 四个文件（见改动地图）。
- 根目录 `CLAUDE.md` 的 QuickActionBar 索引行只写测试陷阱，不受影响。
- `AgentPlugins/uifoundation/skills/` 两个 skill 都没有写 QuickActionBar，不改、不升版本号。

## API 演进与废弃策略

- 九参数 `present` 与 `requiredClickCount`：`@available(*, deprecated, message:)` 保留并转发。用 `message:`
  而不是 `renamed:`：新写法要拆成「设配置 + 调 present」两步，fix-it 无法自动改写。
- `rowHeight`：`deprecated`，消息写明不起作用。
- 移除时机：三个下游 App 迁完之后的某个 minor 版本，不预定版本号；本库仍是 0.x，移除时按破坏性改动单独走提案。
- 版本号：本次是新增 + 废弃，发 minor。

## 落地步骤

0. **提案入库** —— `Documentations/Evolutions/README.md` 登记一行 `draft`。

1. **Configuration 与存储**（已完成）—— 改动地图第 1、2 行，测试文件的默认值部分
   - 行为：`defaultConfigurationKeepsPresentDefaults`（占位文字 "Quick Actions"、默认图、宽高为 nil、
     不显示快捷键、能成为主窗口、双击激活）
   - 行为：`defaultCornerRadiusIs28PointsOnMacOS26`
   - 行为：`initializerStoresTheGivenConfiguration`
   - 行为：`deprecatedRequiredClickCountForwardsToConfiguration`

2. **新 `present` 与旧 `present` 的转发**（已完成）—— 第 3、4、5、10 行
   - 行为：`presentWithoutArgumentsUsesTheConfiguredPlaceholder`（先设 `configuration.placeholderText`，
     再调 `present()`，窗口显示的是设的值——证明新方法胜出）
   - 行为：`deprecatedPresentWritesItsArgumentsIntoTheConfiguration`
   - 行为：`deprecatedPresentLeavesCornerRadiusAlone`
   - 行为：`configurationChangedWhilePresentedAppliesToTheNextPresentation`
   - 行为：`configuredWidthSizesTheBar`（512 → 窗口宽 592，含两侧各 40 pt 动画余量；不依赖 macOS 26 的玻璃底板，各系统都能测）
   - 行为：`rowClickUsesThePresentedClickCount`（用 `sendAction` 或单元格的跟踪方法，不发真实点击）
   - 现有三个测试文件改用 `configuration`；调废弃 API 的测试函数标 `@available(*, deprecated)` 以免警告。

3. **圆角接通**（已完成）—— 第 6、7、8 行
   - 行为：`defaultCornerRadiusReachesThePlatterGlass`（26+：`platterGlass.cornerRadius == 28`）
   - 行为：`configuredCornerRadiusReachesThePlatterGlass`（26+：设 12 → 12）
   - 行为：`browseButtonsStayCirclesWithACustomCornerRadius`（设 12、四个按钮，玻璃圆半径仍是直径一半）
   - macOS 26 以前的路径本机（27.2）测不到，只能读代码确认；在决策日志里记一笔。

4. **示例、文档、收尾** —— 第 11–15 行
   - 示例 App 加圆角滑块（0–40，初值 `defaultCornerRadius`），构建示例 App。
   - 全 trait 构建；`swift test --traits QuickActionBar`，按原始退出码判断，并确认输出以 `Test run with … tests` 结尾。
   - 在示例 App 里看一眼圆角大于 28 时的表现，写进指南（调研里的第二条推测）。

**收尾时必须判断两件事**（判断结果写进决策日志，不允许沉默跳过）：

- **要不要配套专题文章** —— 预计不需要新文章：契约写进现有 `QuickActionBar.md` 的新小节。
- **有没有引入新术语** —— 预计没有。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-11-28 | Created as Draft | QuickActionBar 底板圆角在两条系统路径上都写死，宿主无法自定义；`present` 已有九个参数，不宜再加。 |
| 2026-11-28 | 配置存在 bar 上 | 用户批准：照 `SpotlightPanel` 的形状，`configuration` 属性 + `init(configuration:)`，`present` 只留每次打开才变的参数。 |
| 2026-11-28 | 旧 `present` 标废弃保留 | 用户批准：不破坏三个下游 App，按轻量档走；删除留到下游迁完以后。 |
| 2026-11-28 | Accepted | 用户批准，开始实现。 |
| 2026-11-28 | In Progress：第 1 步完成 | `ResultsView` 里 `#available(macOS 10.13, *)` 的 `else` 分支（唯一读 `rowHeight` 的地方）随 `rowHeight` 废弃一并删掉：本库最低 macOS 14，它从不执行。点击判断这一步先改读 `configuration`，第 2 步换成快照。 |
| 2026-11-28 | 第 2 步完成 | 宽度测试改为断言窗口宽度（512 + 2 × 40），不再断言玻璃底板宽度，各系统通用。点击数测试用 `Bool` 参数而非 `RequiredClickCount`：后者不是 `Sendable`，作测试参数会报隔离警告，不为测试给公开类型加遵循。结果表没有 target，测试把单击 action 直接发给 `ResultsView`（窗口在测试进程里不会成为 key，nil target 走不到它）。变异检查：`ResultsView` 改读实时配置时，点击数测试的两个参数都失败。 |
| 2026-11-28 | `@_disfavoredOverload` 实测不是必需 | 临时去掉它，`present()` 仍落到新方法、不报歧义（编译器本就偏向用到默认参数更少的重载）。保留它作为保险，指南不再说它是新方法胜出的原因。 |
| 2026-11-28 | 第 3 步完成，第 4 步的示例与文档同批 | 项目要求指南与行为同一个提交，圆角接通与示例、指南、README 一起提交。圆角大于 28 时的观感没有在示例 App 里看：那需要交互式查看界面，用户没有要求；指南只写「值原样交给玻璃与图层，不做截断」。 |
