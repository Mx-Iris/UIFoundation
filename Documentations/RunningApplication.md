# RunningApplication —— 运行中的应用与进程

正在运行的应用和 BSD 进程：值类型模型（带架构、平台、沙盒判定）、两个观察者，以及一个开箱即用的
选择器 UI。移植自独立仓库
[`Mx-Iris/RunningApplicationKit`](https://github.com/Mx-Iris/RunningApplicationKit)，
决策记录是 [0014](Evolutions/0014-running-application-merge.md)。

**这一篇是给调用方看的**：怎么用、宿主必须遵守什么契约、有哪些已知降级。
实现细节在两篇实现说明里：[平台识别](Internal/PlatformDetection.md)、
[呈现样式](Internal/PresentationStyles.md)。

## 接入

opt-in SPM trait `RunningApplication`（默认关闭），仅 macOS 11+。

```swift
.package(url: "…/UIFoundation", traits: ["RunningApplication"])
```

```bash
swift build --traits RunningApplication
swift test  --traits RunningApplication
```

**它不在 `UIFoundation` 伞包里**，要单独依赖 product 并单独 import：

```swift
.product(name: "UIFoundationRunningApplication", package: "UIFoundation")
```

```swift
import UIFoundationRunningApplication   // 不是 import UIFoundation
```

分出来的原因只有一个：它的平台下限是 macOS 11，而伞包是 10.15。进伞包等于替所有使用方抬地板。
`UIFoundationSettings` 分出来也是同一个理由。

## 选择器

```swift
let picker = RunningPickerTabViewController()
picker.delegate = self
NSWindow(contentViewController: picker).makeKeyAndOrderFront(nil)
```

两个标签页（应用 / 进程），各自独立配置：

```swift
let picker = RunningPickerTabViewController(
    applicationConfiguration: .init(
        title: "Choose an App",
        allowsFields: [.icon, .name, .bundleIdentifier, .architecture]
    ),
    processConfiguration: .init(
        style: .list,
        allowsFields: [.icon, .name, .pid, .executablePath],
        refreshInterval: 3.0
    )
)
```

选择结果走 delegate：

```swift
extension MyController: RunningPickerTabViewController.Delegate {
    func runningPickerTabViewController(
        _ viewController: RunningPickerTabViewController,
        didConfirmApplication application: RunningApplication
    ) { … }

    func runningPickerTabViewController(
        _ viewController: RunningPickerTabViewController,
        didConfirmProcess process: RunningProcess
    ) { … }

    func runningPickerTabViewControllerWasCancelled(
        _ viewController: RunningPickerTabViewController
    ) { … }
}
```

### 两种呈现样式

每个标签页各自持有一个 `style`，取值 `.table`（默认）或 `.list`。运行时可切，选中项、搜索文本
和排序都会保留：

```swift
picker.processStyle = .list
picker.setStyle(.table)          // 两个标签页一起切
```

两种样式读同一份 `allowsFields`，但渲染方式不同：

| | `.table` | `.list` |
|---|---|---|
| 布局 | 一个字段一列 | 图标、标题、行内徽章、副标题 |
| 排序 | 点列头 | 搜索框旁的下拉 |
| `platform` | 每行都有徽章，宿主平台用暗色 | 徽章，宿主平台**整个省略** |
| `architecture` | 按架构着色的徽章 | 副标题里的纯文本 |
| `pid` | 等宽数字，暗色 | 副标题里的纯文本 |
| `isSandboxed` | 每行一个对勾或叉 | `Sandboxed` 徽章，非沙盒时省略 |
| 长路径 | 列内尾部截断 | 整行宽度，中部截断 |

**两种样式对「不值一提的值」的处理刚好相反，这是刻意的**：列表省略它，表格用暗色打印它 ——
一列空白读起来像坏了。实测一台开着 iOS 模拟器的机器上，400 个进程里 391 个报 `macOS`、
只有 22 个在沙盒里，这两个字段作为列几乎每行都在重复同一件事，这正是列表样式存在的理由。

### 契约一：行高等默认值随样式走，除非你显式设过

`rowHeight` / `cellSpacing` / `iconSize` 三个属性**没有存储的默认值**，读取时回落到当前样式的
默认（表格 28pt 行 + 20pt 图标，列表 44pt 行 + 28pt 图标）。一旦显式赋值，就锁定在你给的值上，
不再随样式变：

```swift
var configuration = RunningPickerTabViewController.ProcessConfiguration(style: .list)
configuration.rowHeight        // 44，来自样式
configuration.rowHeight = 52   // 从此固定 52，切到 .table 也是 52
```

踩法：为表格样式调好一个行高，之后切到列表，列表会用你那个为表格调的值，看起来过于紧凑。

### 契约二：`allowsFields` 里的 `.icon` 没有标题，因而不可排序

列表样式的排序下拉只列有标题的字段。`.icon` 的标题是空串，不会出现在下拉里 —— 这不是漏判，
是不给它一个空白菜单项。

## 数据模型

`RunningApplication` 是 `NSRunningApplication` 的值类型包装，`RunningProcess` 是一个 BSD 进程。
两者都遵循 `RunningItem`（`processIdentifier` / `name` / `icon` / `architecture` /
`isSandboxed` / `platform`）。

```swift
let processes = RunningProcessEnumerator.listProcesses()          // 默认排除 GUI 应用
let one = RunningProcessEnumerator.makeProcess(for: 1234)
let simulated = processes.filter { $0.platform?.isSimulator == true }
```

### 契约三：`platform` 与 `architecture` 都可能是 `nil`，且是同一批进程

| | 回答什么 | 数据来源 | 能区分模拟器吗 |
|---|---|---|---|
| `architecture` | 内核**实际以什么架构运行**这个进程 | `proc_pidinfo` + `PROC_PIDARCHINFO` | **不能** |
| `platform` | 二进制**被编译成给哪个平台** | 可执行文件的 Mach-O 头 | 能 |

Apple Silicon 上模拟器里的进程跑的是原生 arm64，与宿主进程的架构完全一致 —— 这正是必须引入
`platform` 的原因，也是「架构判不出模拟器」这句话的含义。

**`platform` 为 `nil` 的情形是受保护的系统进程**：`proc_pidpath` 不肯报出路径，因而读不到
它的 Mach-O 头。开发机上实测约占全部进程的 5%，且与 `architecture` 读不到的是同一批。
**不要把 `nil` 当成「不是模拟器」** —— 它的含义是「不知道」。

术语的完整定义见[术语表](Glossary.md)（platform 与 architecture 之别、guest 进程、
ExclaveCore / ExclaveKit）。

### 契约四：只有 guest 进程会被标为模拟器

被标记的是跑在**模拟器沙盒内部**的进程（SpringBoard、被调试的 app、模拟器里那套 iOS 自己的
daemon）。宿主侧的支撑进程 —— `CoreSimulatorService`、`SimRenderServer`、`Simulator.app` ——
本身是货真价实的 macOS 进程，平台就是 `macOS`，因此不会被标记。**这是有意的，不是漏判。**

## 观察者

两个都是 `actor`，所以调用点都要 `await`。

```swift
let observer = RunningApplicationObserver(observeApplicationBundleID: "com.apple.Safari")
await observer.onLaunch { print("launched") }
await observer.onTerminate { print("terminated") }
await observer.start()
// …
await observer.stop()
```

```swift
let observer = RunningProcessObserver(target: .name("nginx"), pollingInterval: 2.0)
```

两者的机制不同，代价也不同：`RunningApplicationObserver` 走 KVO，事件是**推**过来的；
`RunningProcessObserver` 没有等价的内核通知，只能**轮询**，所以 `pollingInterval` 直接决定
它的延迟上限和它烧掉的 CPU。默认 2 秒。

## 已知降级

- **进程枚举与选择器的高层行为没有测试。** 测试它们需要真实进程环境，与本套测试
  「确定性、与环境无关」的原则冲突 —— 现有 1200 余行测试没有一行读真实进程、真实二进制或
  本机任何状态。这是从原库继承过来的缺口，并入时未补。
- **约 5% 的进程读不到路径**，因而 `platform` 与 `architecture` 均为 `nil`（见契约三）。
- **`Platform` 枚举里的 ExclaveCore / ExclaveKit 一族实测从未出现**在进程列表里 ——
  它们不是普通 BSD 进程。枚举收录它们是为了对 Mach-O ABI 忠实。

## 与原库的差异

并入本库时的改动（详见 [0014](Evolutions/0014-running-application-merge.md)）：

- **模块名与 import 变了**：`import RunningApplicationKit` → `import UIFoundationRunningApplication`。
  **类型名一个都没改。**
- **弃用别名全部删除**：`allowsColumns`、`ProcessColumn`、`ApplicationColumn` 以及各
  configuration 上那个接收 `allowsColumns` 的初始化器。原库标注的是「下一个 minor 移除」，
  搬家时一并清掉 —— 下游本来就要改依赖与 import。
- **内部实现接入了本库基座**：cell 改用本库的 `TableCellView`、`.box.makeView(ofClass:)`、
  `makeConstraints`、`HStackView` / `VStackView`、`XiblessViewController`。
  **几何与运行时行为未变**，由扩充后的布局测试保证。
