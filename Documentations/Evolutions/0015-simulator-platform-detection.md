# 0015 - 进程平台识别与模拟器标记

- **状态**: Withdrawn
- **作者**: JH
- **创建日期**: 2026-08-24
- **最后更新**: 2026-09-05
- **所属愿景**: 无
- **关联提案**: [0016 - 选择器呈现样式（表格与列表）](0016-picker-presentation-styles.md) —— 重新裁决了本提案引入的 Platform 列的呈现方式
- **实现分支 / PR**: main
- **配套文档**: 实现说明 `Documentations/Internal/PlatformDetection.md` 已随撤销一并删除


> **本提案已于 2026-09-05 撤销**，随 [0014](0014-running-application-merge.md) 把
> RunningApplication 整体移出本库 —— 撤销的范围与理由记在 0014 的「撤销」一节。
> 本提案的成果（`Platform` 枚举、`MachOPlatform`、模拟器标记）已不在代码库中。
> 状态之外正文一字未改。原始实现仍存于独立仓库
> [`Mx-Iris/RunningApplicationKit`](https://github.com/Mx-Iris/RunningApplicationKit)，
> 本提案在那里的编号是 `0001`。

> **移植说明。** 本提案原属独立仓库
> [`Mx-Iris/RunningApplicationKit`](https://github.com/Mx-Iris/RunningApplicationKit)，
> 编号 `0001`，随该库整体并入 UIFoundation 时重编号为 `0015`（见
> [0014 - RunningApplication：把 RunningApplicationKit 整体并入本库](0014-running-application-merge.md)）。
>
> **以下正文保持原貌，一字未改** —— 提案是决策快照，落地后不随实现改写。因此文中的路径
> `Sources/RunningApplicationKit/…` 指的是原仓库的位置，在本库中对应
> `Sources/UIFoundationRunningApplication/…`；文中提到的「本库」「本项目」均指原
> RunningApplicationKit。并入过程本身带来的差异（接入本库基类、删除弃用别名等）记在
> 0014 号提案里，不在此处。

## 摘要

给 `RunningItem` 增加一个 `platform` 属性，通过读取进程可执行文件的 Mach-O `LC_BUILD_VERSION`
判定它属于哪个平台（macOS、iOS Simulator、Mac Catalyst、DriverKit 等），并在 Processes 标签页
新增一列 Platform 展示。模拟器里运行的进程因此能被一眼认出，并可通过搜索框一键筛出。

## 动机

**在装有 Xcode 的机器上，进程列表被模拟器进程淹没。** 实测（macOS 26.5，运行一个 iOS 18.5
模拟器）：系统共 1708 个进程，其中 226 个是模拟器沙盒里运行的 guest 进程 —— SpringBoard、
被调试的 app，以及 iOS 自己的全套 daemon（`logd`、`runningboardd`、`cfprefsd`、`trustd` …）。
这些进程与宿主进程在现有 UI 里完全无从区分：

- **名字不区分** —— 模拟器里的 `logd`、`cfprefsd`、`securityd` 与 macOS 自己的同名进程重名。
- **架构不区分** —— 实测模拟器 guest 进程的 `PROC_PIDARCHINFO` 返回 `CPU_TYPE_ARM64`，与宿主
  进程完全一致（Apple Silicon 上 iOS 模拟器跑的是原生 arm64 代码，不经翻译）。现有的 Arch 列
  对它们全部显示 `arm64`。
- **路径要横向滚动才看得到** —— Path 列虽然含 `CoreSimulator`，但那是一条 160 余字符的长路径，
  前缀被截断，实际看到的是 `…/RuntimeRoot/usr/libexec/logd`，需要悬停 tooltip 才能确认。

结果是：想在 Processes 标签页里找到模拟器中正在调试的那个进程，只能靠肉眼逐行辨认路径。

本次改动的直接用途是**快速定位模拟器里的调试目标**（而非把模拟器进程当噪音隐藏掉）——
这一点决定了后文若干取舍：列里显示的是平台名而非「是/否」图标、排序采用模拟器优先而非字母序、
以及搜索框扩展为可匹配平台名。

## 前期调研

### 现状代码怎么走的

- `Sources/RunningApplicationKit/RunningItem.swift:3` —— `public protocol RunningItem`，现有
  requirement 为 `processIdentifier` / `name` / `icon` / `architecture` / `isSandboxed`。
- `Sources/RunningApplicationKit/BSDProcess.swift:51` —— `BSDProcess.architecture(for:)`，用
  `proc_pidinfo(pid, PROC_PIDARCHINFO, …)` 取内核记录的运行架构。
- `Sources/RunningApplicationKit/RunningProcess.swift:63` —— `RunningProcessEnumerator.makeProcess(for:)`，
  逐 PID 组装 `RunningProcess`；架构与沙盒状态各自按 `executablePath` 走一层 `ThreadSafeCache`。
- `Sources/RunningApplicationKit/RunningItemPickerViewController.swift:72` —— `filterItems(_:searchText:)`，
  目前只做 `name.localizedCaseInsensitiveContains(searchText)`。
- `Sources/RunningApplicationKit/RunningItemPickerViewController.swift:400` / `:439` ——
  `makeSharedCellView(columnIdentifier:item:)` 与 `compareSharedItems(_:_:columnIdentifier:)`，
  两个 picker 共享的列渲染与排序分派。
- `Sources/RunningApplicationKit/RunningPickerTabViewController.swift:116` —— `public enum ProcessColumn`，
  `allCases` 即 `ProcessConfiguration.allowsColumns` 的默认值。

### 内核没有可用的 platform 接口 —— 已证伪

最初的假设是内核会像暴露架构那样暴露 platform（XNU 内部确有 `struct proc_platforminfo`）。
**该假设被实测证伪**：

- macOS 26.5 SDK 的 `sys/proc_info.h` 只公开到 `PROC_PIDARCHINFO`（19），没有 platform flavor。
- 用自身 PID 与一个模拟器 guest 进程（SpringBoard）逐一扫过 `proc_pidinfo` 的 flavor 1–64、
  缓冲区 8 字节，只有 flavor 1 / 6 / 19 / 28 / 32 / 34 有返回，无一是 `{platform, sdk_version}`
  结构；其中 flavor 19 对宿主与 guest 均返回 `16777228`（`CPU_TYPE_ARM64`），再次印证架构不可用于区分。

### Mach-O `LC_BUILD_VERSION` 是权威依据 —— 已实测

`vtool -show-build` 对照验证：

| 二进制 | platform |
|---|---|
| `…/iOS 18.5.simruntime/…/RuntimeRoot/System/Library/CoreServices/SpringBoard.app/SpringBoard` | `IOSSIMULATOR` |
| `/Applications/Xcode.app/…/Simulator.app/Contents/MacOS/Simulator` | `MACOS` |

平台常量取自 `mach-o/loader.h:1323-1350`（SDK 26.5）：`PLATFORM_MACOS` 1 … `PLATFORM_VISIONOSSIMULATOR` 12，
其后 13–24 为 `PLATFORM_FIRMWARE`、`PLATFORM_SEPOS` 及五个系统各自的 `EXCLAVECORE` / `EXCLAVEKIT`。
该表逐年增长，是后文 `unknown` 携带原始数值的理由。

### 原型实测：覆盖率与开销

已写出可运行原型（遍历全部 PID → `proc_pidpath` → 打开文件 → 处理 fat → 遍历 load commands），
在本机的结果：

- **1708 个进程，27.6 ms 判完**，1026 条不同路径，606 次命中按路径的缓存。
- 判定结果：macOS 1384、**iOSSimulator 226**、macCatalyst 14、DriverKit 5。
- **判不出的 79 个（4.6%）**：76 个 `proc_pidpath` 拿不到路径（受保护的系统进程 —— 与现有 Arch 列
  判不出的是同一批），3 个 `open` 返回 `EACCES`。
- 无一进程走 legacy `LC_VERSION_MIN_*` 路径；本机全部二进制都带 `LC_BUILD_VERSION`。

作为对照，现有的 `isSandboxed` 走 `SecCodeCopySigningInformation`，开销比这高约两个数量级 ——
这是本提案不为 platform 解析设置延迟开关的依据。

### 胖二进制的 slice 选择 —— 一个实测踩到的坑

原型第一版对 391 个进程报「找不到匹配 slice」。原因不是解析错误，而是
**`PROC_PIDARCHINFO` 本身对 279 个进程不可用**（同样是权限问题），拿不到运行架构就无法在
fat binary 里挑片。修正为「运行架构 → 宿主架构（`sysctlbyname("hw.cputype")`）→ 第一个 slice」
三级回退后，判不出的降至 79 个。**若不做这级回退，实际漏判率会从 4.6% 升到 23%。**

### Applications 标签页的实际分布

同批实测：234 个 `NSRunningApplication` 中 232 个是 macOS，仅 `UIKitSystem` 与 `WeatherMenu`
两个是 macCatalyst；**模拟器 guest 进程一个都不出现在这一页**（它们不是 `NSRunningApplication`）。
这是应用页不加此列的依据。

## 提议方案

1. 新增 `public enum Platform`，忠实映射 Mach-O 的 24 个 platform 常量，另加
   `case unknown(UInt32)` 承载未来新值；提供 `isSimulator` 派生属性与完整措辞的 `description`。
2. 新增内部类型负责从可执行文件读出 platform：打开文件 → 处理 fat header 与 slice 选择 →
   遍历 load commands 找 `LC_BUILD_VERSION`。结果按 `executablePath` 缓存，复用现有
   `ThreadSafeCache` 模式。
3. `RunningItem` 增加 `var platform: Platform? { get }` requirement，并在协议扩展里给默认实现
   `nil`，使外部实现者无需改动即可继续编译。
4. `RunningProcess` 与 `RunningApplication` 各自提供真值；后者在现有 init 内同步解析，不新增参数。
5. `ProcessColumn` 增加 `case platform`，默认显示，宽 130pt，显示完整平台名；排序采用模拟器优先。
6. `filterItems` 扩展为同时匹配平台的显示文本与枚举 case 名。

### 非目标

- **不标宿主侧的 CoreSimulator 支撑进程**（`CoreSimulatorService`、`SimRenderServer`、
  `SimMetalHost`、`SimulatorTrampoline` 等，本机 15 个）。它们的 Mach-O platform 就是 `MACOS`，
  按平台判定本就该显示 macOS；要把它们也归入「模拟器」只能靠路径含 `CoreSimulator` 的字符串约定，
  与本提案的判定依据不同源。
- **不识别第三方模拟器与虚拟机**（Android emulator 的 `qemu-system-*`、UTM、Parallels）。它们是
  普通 macOS 进程，Mach-O 里没有任何可供区分的字段，只能靠进程名黑名单，必然有漏网且需长期维护。
- **不提供隐藏 / 过滤模拟器进程的开关**。本次用途是正向定位，不是排噪音。
- **不在 Applications 标签页增加 Platform 列**（属性仍可从 API 读到）。
- **不改变进程枚举范围** —— `listProcesses(excludingApplications:)` 的语义不动。

## 详细设计

### Platform

```swift
public enum Platform: Hashable, Sendable, CustomStringConvertible {
    case macOS
    case iOS
    case tvOS
    case watchOS
    case bridgeOS
    case macCatalyst
    case iOSSimulator
    case tvOSSimulator
    case watchOSSimulator
    case driverKit
    case visionOS
    case visionOSSimulator
    case firmware
    case securityEnclaveOS
    case macOSExclaveCore
    case macOSExclaveKit
    case iOSExclaveCore
    case iOSExclaveKit
    case tvOSExclaveCore
    case tvOSExclaveKit
    case watchOSExclaveCore
    case watchOSExclaveKit
    case visionOSExclaveCore
    case visionOSExclaveKit
    /// A platform constant this version of the library does not know about.
    /// Carries the raw Mach-O value so future platforms stay diagnosable.
    case unknown(UInt32)

    /// Whether the binary was built for a simulator runtime rather than real hardware.
    public var isSimulator: Bool { get }

    /// Full display wording, e.g. "iOS Simulator", "Mac Catalyst", "DriverKit".
    public var description: String { get }
}
```

`case sepOS` 写作 `securityEnclaveOS`：项目规则禁止缩写，`sepOS` 中的 `sep` 是
Secure Enclave Processor 的首字母缩写。其 `description` 仍为 Apple 的官方写法 `"sepOS"`。

`unknown` 携带原始值意味着 `Platform` 不能自动合成 `RawRepresentable`；从数值到 case 的转换写成
一个 `init(machOPlatform: UInt32)`，反向转换写成 `machOPlatformValue` 属性。这与现有
`Architecture`（无 associated value）不对称，理由是平台常量表逐年增长而 CPU 类型表不会。

### 判定实现

```swift
enum MachOPlatform {
    /// Read the Mach-O `LC_BUILD_VERSION` platform of the executable at `path`.
    /// - Parameter runningArchitecture: the process's actual running architecture, used to pick
    ///   the right slice out of a fat binary. Pass nil when unavailable — the host architecture
    ///   is then used, falling back to the first slice.
    static func platform(atPath path: String, runningArchitecture: (cpu_type_t, cpu_subtype_t)?) -> Platform?
}
```

流程：

1. `open(path, O_RDONLY)`；失败返回 `nil`。
2. `pread` 头部 4 KB，读 magic。若为 `FAT_CIGAM` / `FAT_CIGAM_64`（fat header 固定大端序），
   遍历 `fat_arch` 条目按下述三级回退选出 slice 偏移；否则偏移为 0。
3. `pread` 出 `mach_header_64`，取 `ncmds` / `sizeofcmds`，再 `pread` 出整块 load commands。
4. 顺序遍历，命中 `LC_BUILD_VERSION` 即读其 `platform` 字段返回；命中 legacy 的
   `LC_VERSION_MIN_MACOSX` / `_IPHONEOS` / `_TVOS` / `_WATCHOS` 则记下作为兜底（本机实测未触发，
   但 iOS 12 以前 SDK 构建的二进制只有这组 load command）。

**slice 选择的三级回退**（前期调研中实测必需）：

1. `cputype` 与 `cpusubtype` 低 24 位都匹配进程运行架构 → 取之；
2. 否则取第一个 `cputype` 匹配**宿主架构**（`sysctlbyname("hw.cputype")`）的 slice；
3. 再否则取第一个 slice。

所有 `pread` 长度与 load command 的 `cmdsize` 都做边界校验，`sizeofcmds` 上限 1 MB，
避免畸形文件导致越界读或巨量分配。

### 缓存与接入

`RunningProcessEnumerator` 增加一个 `ThreadSafeCache<String, Platform?>`，键为 `executablePath`，
与现有 `architectureCache` / `sandboxCache` 完全同构（外层 `nil` 表示未缓存，内层 `nil` 表示
判不出）。`makeProcess(for:)` 中按同样的模式填充。

`RunningApplication.init(from:resolveSandbox:)` 内用 `app.executableURL?.path` 走同一入口，
签名不变。

### RunningItem

```swift
public protocol RunningItem: Hashable, Sendable {
    var processIdentifier: pid_t { get }
    var name: String { get }
    var icon: NSImage? { get }
    var architecture: Architecture? { get }
    var isSandboxed: Bool { get }
    var platform: Platform? { get }
}

public extension RunningItem {
    var platform: Platform? { nil }
}
```

### UI

- `ProcessColumn` 增加 `case platform`，位置在 `architecture` 与 `sandboxed` 之间；
  `title` 为 `"Platform"`，`preferredWidth` / `minWidth` / `maxWidth` 均为 130；
  `headerAlignment` 保持默认（左对齐，与 Arch 列一致）。
- 新增 `PlatformTableCellView: LabelTableCellView`，供 `NSTableView.makeView(ofClass:)` 按类身份复用。
- `makeSharedCellView` 增加 `"platform"` 分支：`$0.string = item.platform?.description`。
  `platform` 为 `nil` 时留空（与 Arch 列判不出时的表现一致）；`.unknown(let value)` 的
  `description` 为 `"Platform \(value)"`，即「读到了但不认识」与「没读到」在视觉上可区分。
- `compareSharedItems` 增加 `"platform"` 分支，按 `sortOrder` 比较：模拟器平台 0–3，
  其余已知平台其后，`.unknown` 再后，`platform == nil` 最后。升序即把模拟器进程顶到表头。

`description` 最长的是 `"visionOS ExclaveCore"`（20 字符），略超 130pt；`LabelTableCellView`
已配置 `.byTruncatingTail` 并在 `string` 的 `didSet` 里同步 `toolTip`，截断后仍可悬停查看。
实际会出现的最长值是 `"visionOS Simulator"`（18 字符，约 125pt），在 130pt 内完整显示。

### 搜索

```swift
override func filterItems(_ items: [Item], searchText: String) -> [Item] {
    guard !searchText.isEmpty else { return items }
    return items.filter { item in
        item.name.localizedCaseInsensitiveContains(searchText)
            || item.platform?.matches(searchText: searchText) == true
    }
}
```

`Platform.matches(searchText:)` 对 `description` 与 case 名（如 `"iOSSimulator"`）各做一次
`localizedCaseInsensitiveContains`。因此 `sim`、`simulator`、`ios`、`catalyst` 均可命中。

**已知副作用**：名字里含 `sim` 的宿主进程（`simdiskimaged`、`SimRenderServer` 等）会因 name
匹配一并出现在结果里。这是 `name` 与 `platform` 取并集的必然结果，视为可接受 —— 它们确实
与模拟器相关。

## 替代方案考量

**按可执行路径前缀判定。** 检查路径是否落在 `/Library/Developer/CoreSimulator/` 或
`~/Library/Developer/CoreSimulator/Devices/` 下。零文件 IO，且能顺带覆盖宿主侧支撑进程。
否决理由：它靠的是 Apple 的目录约定而非 ABI 字段，路径一改即失效；更关键的是它只能回答
「是不是模拟器」，给不出 Mac Catalyst、DriverKit、iPad app on Mac 这些取值，而公开 API 定为
通用 `Platform` 枚举后，这条路已不足以支撑。

**只加 `isSimulated: Bool`。** 改动最小。否决理由：同一次 Mach-O 读取已经拿到了完整 platform，
压成一个 Bool 是主动丢弃信息；且日后想区分 tvOS/watchOS 模拟器、或标出 Catalyst 应用，都得再动
一次公开 API。

**嵌套枚举 `.simulator(…)` / `.native(…)`。** 把「是否模拟器」提升到类型层面，调用方不可能忘记判。
否决理由：与现有扁平的 `Architecture` 风格不一致，且每处 `switch` 都要多一层模式匹配。
`isSimulator` 派生属性能以低得多的成本达到同样效果。

**只收实际出现的 4 种 platform。** 否决理由：`tvOS Simulator`、`watchOS Simulator`、
`visionOS Simulator` 恰恰是本功能要标的东西，只是本机当前没跑而已；落进 `unknown` 等于功能在
那些环境下失效。

**对勾 / 叉图标列（与 Sandbox 列同构）。** 视觉语言最统一。否决理由：1400 余行红叉是强噪音，
且白白丢弃已经读到的 platform 信息。

**在 Name 列加徽标 / 图标列加角标 / 整行背景色。** 均否决：徽标会被长进程名挤掉且不好排序；
20pt 见方的角标可读性差；行背景色与选中态、隔行底色打架。

**显式筛选控件（全部 / 仅模拟器 / 仅本机）。** 可发现性最好。否决理由：需要新 UI 元素、新配置
API 并占用头部空间；扩展搜索匹配已能达成「快速定位」，成本低得多。

**为 platform 解析加 `resolvePlatform` 开关**（与现有 `resolveSandbox` 对称）。否决理由：
实测开销比 sandbox 小两个数量级，不值得为此扩大公开 init 的表面积。

**协议 requirement 不给默认实现。** 语义更严（每个 `RunningItem` 都必须回答自己的平台）。
否决理由：`RunningItem` 是 public 协议，外部可能已有实现；给默认实现可让破坏面归零，代价仅是
外部类型静默得到 `nil`。

**按显示文本字母序排序。** 与现有 Arch 列做法一致。否决理由：`iOS Simulator` 会排在 `DriverKit`
之后、`macOS` 之前，模拟器进程不在表头，与「快速定位」的用途相悖。

## 影响

### 源码兼容性（source compatibility）

**基本为纯新增，一处需注意：**

- **纯新增**：`Platform` 枚举、`RunningProcess.platform`、`RunningApplication.platform`、
  `ProcessColumn.platform`。现有调用点无需改动。
- **`RunningItem` 增加 requirement** —— 本应是源码破坏性变更，但协议扩展提供了默认实现
  `{ nil }`，因此**外部实现该协议的类型无需修改即可继续编译**，只是会静默得到 `nil`。
  已知本仓库内的实现者只有 `RunningApplication` 与 `RunningProcess`，两者都提供真值。
- **`ProcessColumn.allCases` 多出一个 case** —— 使用默认 `ProcessConfiguration()` 的调用方，
  Processes 标签页会**多出一列 Platform**（宽 130pt）。这不是 API 破坏（不影响编译），但是
  可见的行为变化。显式传入 `allowsColumns` 的调用方不受影响。
- 对 `ProcessColumn` 做穷尽 `switch` 的外部代码会因新 case 报错 —— 但该枚举的 `title` 等成员
  均为 internal，外部实际上无从穷尽匹配。

无需 `@available(*, deprecated)` 过渡：没有任何 API 被替换或移除。

### ABI 兼容性

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。`Package.swift` 未开启
`-enable-library-evolution`，也不以 `binaryTarget` 分发。

### 下游影响

- 本仓库内受影响的 target：`RunningApplicationKit`（唯一的 library target）；新增测试 target。
- `Example/` 示例应用使用默认配置，会自动显示新列 —— 正好作为人工验证入口。
- 跨仓库：本库以 `https://github.com/Mx-Iris/RunningApplicationKit.git` 公开分发，下游消费者
  未知。上述「多一列」的行为变化需要写进 release notes。

### 文档与示例

- `README.md`：功能列表与 `ProcessColumn` 说明需补充 Platform 列（README 为面向公众文档，用英文）。
- `CLAUDE.md`：「There are no tests in this project」一句在测试 target 落地后需要改写。
- 落地时判断是否需要一篇实现说明，见「落地步骤」。

## API 演进与废弃策略

- 无 API 被替代或废弃，不需要废弃期。
- **不需要 semver major 跃迁**：唯一的破坏性面（协议新 requirement）已由默认实现消解。
  建议按 minor 发布，并在 release notes 中点名「使用默认 `ProcessConfiguration` 的调用方会
  多出一列 Platform」。
- **`Platform` 的未来扩展**：Apple 新增平台常量时，只需增加 case 并从 `unknown(UInt32)` 里
  「毕业」。这对穷尽 `switch` 的调用方是源码破坏 —— 但 `unknown` 的存在意味着调用方本就必须
  写 `default` 分支，实际破坏面为零。

## 落地步骤

1. **`Platform` 枚举** —— 24 个 case + `unknown(UInt32)`，`init(machOPlatform:)`、
   `machOPlatformValue`、`isSimulator`、`description`、`sortOrder`、`matches(searchText:)`。
   可独立编译。
2. **`MachOPlatform` 解析器** —— fat header 处理、三级 slice 回退、load command 遍历、边界校验。
   可独立编译。
3. **测试 target** —— 新建 `Tests/RunningApplicationKitTests/`，用手工构造的字节数组覆盖：
   fat header 大端解析、三级 slice 回退（含运行架构不可用的路径）、load command 遍历边界
   （`cmdsize` 为 0 / 超界 / `ncmds` 与 `sizeofcmds` 不自洽）、`LC_BUILD_VERSION` 与 legacy
   `LC_VERSION_MIN_*` 的取值、平台数值到枚举的往返映射。**不触碰真实进程枚举**，因此不依赖
   本机是否装有模拟器，CI 可跑。
4. **接入数据层** —— `RunningItem` 加 requirement 与默认实现；`RunningProcessEnumerator` 加
   platform 缓存并在 `makeProcess(for:)` 里填充；`RunningApplication.init` 内解析。
5. **接入 UI** —— `ProcessColumn.platform`、`PlatformTableCellView`、`makeSharedCellView` 与
   `compareSharedItems` 的新分支。
6. **搜索** —— `filterItems` 扩展为并集匹配。
7. **文档与示例** —— README、CLAUDE.md 的测试一句、示例应用人工验证。

**收尾时必须判断两件事**（判断结果写进决策日志，不允许沉默跳过）：

- **要不要配套专题文章** —— 候选是一篇实现说明：Mach-O slice 选择的三级回退在代码里看不出
  为什么必要（实测数据在提案里，不在代码里），且「内核为什么不能直接问 platform」是一条会被
  重复走一遍的死路。
- **有没有引入新术语** —— `guest 进程`、`slice`、`ExclaveKit` 三个候选待评估。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-08-24 | Created as Draft | 用户原话：「加一个功能，如果进程是模拟器进程则标出来」。经五轮澄清提问后成文。 |
| 2026-08-24 | 定范围：只标 guest 进程 | 否决「guest + 宿主支撑进程同一标记」（判定依据不同源）、「分两级标记」（UI 与 API 都要表达两个状态）、「含第三方模拟器/虚拟机」（只能靠进程名黑名单，必然漏网且需长期维护）。 |
| 2026-08-24 | 定用途：快速定位调试目标 | 否决「当噪音隐藏」与「纯信息完整性」。此决定下游影响：列显示平台名而非勾叉、排序模拟器优先、扩展搜索而非加隐藏开关。 |
| 2026-08-24 | 定 UI：新增一列 | 否决「Name 列加徽标」「图标列角标」「整行背景色」。 |
| 2026-08-24 | 定 API：通用 `Platform` 枚举进协议 | 否决「只加 `isSimulated: Bool`」「只加到 `RunningProcess` 不进协议」。 |
| 2026-08-24 | 定枚举形状：扁平 + `isSimulator` | 否决「嵌套 `.simulator`/`.native`」（与 `Architecture` 风格不一致）、「只收实测出现的四种」（tvOS/watchOS/visionOS 模拟器恰是要标的对象）。 |
| 2026-08-24 | 定列内容：完整措辞平台名 | 否决「仅模拟器行显示标记」「勾叉图标」「仅非 macOS 显示文字」。用户选择完整措辞而非提议的极短措辞，列宽因此由 80pt 调整为 130pt。 |
| 2026-08-24 | 定应用页：不加列 | 依据实测 234 个应用中 232 个为 macOS。否决「加列默认关闭」「加列默认开」。 |
| 2026-08-24 | 定筛选：扩展搜索匹配 | 否决「显式筛选控件」「只靠列头排序」「公开过滤闭包给调用方」。 |
| 2026-08-24 | 定判不出时的表现 | 没读到留空、读到但不认识显示 `Unknown`。否决「两者都显示 Unknown」「用破折号」「留空但靠 tooltip 说明」。 |
| 2026-08-24 | 定搜索匹配对象 | 显示文本 + 枚举 case 名。否决「只匹配显示文本」（选了完整措辞后搜 `sim` 仍可中，但仍不如兼取 case 名稳）、「维护别名表」（需长期维护）、「`platform:` 前缀语法」（需先知道语法）。 |
| 2026-08-24 | 定文档位置 | 新建 `Documentations/Evolutions/`，`docs/plans/` 下 2026-03-08 的两份旧文件保持不动。否决「沿用 docs/plans 只写一份」「迁移合并旧文档」「沿旧惯例仍写两份」。 |
| 2026-08-24 | 定协议兼容策略 | 加 requirement + 默认实现 `nil`。否决「不给默认实现、当作破坏性变更」。 |
| 2026-08-24 | 定排序：模拟器优先 | 否决「显示文本字母序」（与现有 Arch 列一致但模拟器不在表头）、「枚举声明顺序」（对用户不透明）。 |
| 2026-08-24 | 定列宽与默认：130pt、默认显示 | 否决「100pt 允许截断」「加进枚举但默认不显示」。 |
| 2026-08-24 | 定应用侧解析：同步、无开关 | 否决「与 sandbox 对称加 `resolvePlatform` 开关」「应用侧恒为 nil」。依据：实测开销比 sandbox 小两个数量级。 |
| 2026-08-24 | 定测试范围：只测纯函数 | 否决「不加测试」「加真实二进制集成测试」（结果取决于跑它的机器装了什么）。 |
| 2026-08-24 | 修正事实：platform 常量有 24 个而非 12 个 | 核对 `mach-o/loader.h` 时发现 SDK 26.5 已定义到 24（firmware、sepOS、五套 ExclaveCore/ExclaveKit）。据此重新裁决枚举覆盖范围：收全 24 个，`unknown` 携带原始数值。否决「收全但 unknown 不带值」「只收 1-12」「只收实测 4 种 + 各类模拟器」。 |
| 2026-08-24 | Draft → Accepted | 用户审阅后批准（原话「开工」），实现开始。 |
| 2026-08-24 | Accepted → Implemented | 七个落地步骤全部完成。库与 Example 均构建通过，34 个单元测试通过（以 `swift test` 退出码为准）。真实二进制验证：两个 iOS runtime 的 SpringBoard / launchd_sim / logd 均判为 iOS Simulator，Simulator.app 与 CoreSimulatorService 判为 macOS，Home.app 判为 Mac Catalyst，HID dext 判为 DriverKit。 |
| 2026-08-24 | 收尾判断一：写配套实现说明 | 判定**需要**。三条「代码本身看不出来」的信息：内核没有 platform flavor 这条已证伪的死路、slice 四级回退的实测依据（漏判率 23% → 4.6%）、以及变异测试暴露的两处测试缺陷及其修法。已写入 `Documentations/Internal/PlatformDetection.md` 并登记到本提案头部。 |
| 2026-08-24 | 收尾判断二：登记新术语 | 判定**需要**。项目级 `Documentations/Glossary.md` 新建并收录 `guest 进程`、`platform`（与 `architecture` 的区别）、`ExclaveCore / ExclaveKit`；跨项目通用的 `slice（架构分片）` 登记到全局术语表。 |
| 2026-08-24 | 实现细化四处，差异记在实现说明 | slice 回退由三级细化为四级（多一级应对 Rosetta 进程）；搜索匹配落在泛型基类因而两个标签页都生效；`ThreadSafeCache` 由 private 提取为共享 internal 类型；性能数字实测更精确（冷 14.8 ms / 热 2.6 ms）。按规矩提案保持历史原貌，逐条差异写在实现说明的「与提案的差异」一节。 |
| 2026-08-25 | 分配编号 0001 | 落地 commit 中取号：fetch 全部共享分支后，`Documentations/Evolutions/` 下无任何已编号提案，故取全局最大值 + 1 = 0001，由 `draft-simulator-platform-detection.md` 改名而来。 |
| 2026-09-05 | Implemented → Withdrawn | 随 [0014](0014-running-application-merge.md) 把 RunningApplication 整体移出本库。配套实现说明 `Internal/PlatformDetection.md` 一并删除，术语表里本提案登记的 `guest 进程` / `platform` / `ExclaveCore / ExclaveKit` 三条随之移除。原始实现仍在独立仓库 RunningApplicationKit 中。 |
