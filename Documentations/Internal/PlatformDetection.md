# 平台识别：实现说明

> 配套提案见 [进程平台识别与模拟器标记](../Evolutions/0015-simulator-platform-detection.md)。
> 本文记录**实际落地的实现**、与提案的差异，以及当前覆盖范围与已知降级。面向维护者。


> **本文描述的代码已随 RunningApplicationKit 整体并入本库**（见
> [0014 - RunningApplication：把 RunningApplicationKit 整体并入本库](../Evolutions/0014-running-application-merge.md)），
> 路径与提案编号已同步更新到并入后的位置。并入时接入了本库的基类与 `.box` 扩展，
> 因此本文提到的布局代码有一部分改用了 `makeConstraints` / `HStackView` / `XiblessViewController`；
> 几何与行为未变，具体清单见 0014。

## 背景与目标

判断一个进程属于哪个平台，核心用途是把模拟器里运行的进程从宿主进程里分辨出来。完整动机见提案。

这里只需要记住一件事：**架构判不出模拟器**。Apple Silicon 上 iOS 模拟器里的进程跑的是原生
arm64 代码，`PROC_PIDARCHINFO` 返回的 `CPU_TYPE_ARM64` 与宿主进程一模一样。

## 关键设计决策

### 内核问不到平台 —— 这条路已证伪，不要再走一遍

XNU 内部确有 `struct proc_platforminfo`，很容易让人以为 `proc_pidinfo` 能像返回架构那样返回平台。
**它不能**：

- macOS 26.5 SDK 的 `sys/proc_info.h` 公开的 flavor 到 `PROC_PIDARCHINFO`（19）为止，没有 platform。
- 拿自身进程与一个模拟器 guest 进程，把 flavor 1–64 全部扫过一遍（缓冲区 8 字节），只有
  1 / 6 / 19 / 28 / 32 / 34 有返回，没有一个是 `{platform, sdk_version}` 结构。

所以平台只能从**可执行文件本身**读，即 Mach-O 的 `LC_BUILD_VERSION` 载荷命令。

### 不按路径前缀判定

模拟器 guest 进程的可执行文件都在 `/Library/Developer/CoreSimulator/…/RuntimeRoot/` 之下，
按前缀匹配零文件 IO，看上去更省。否掉的理由有两条，第二条是决定性的：

1. 它依赖 Apple 的目录约定而非 ABI 字段，路径一改即失效。
2. **它只能回答「是不是模拟器」**，给不出 Mac Catalyst、DriverKit、iPad app on Mac。公开 API
   定为通用的 `Platform` 枚举之后，路径判定已经不足以支撑。

### 胖二进制的 slice 选择需要四级回退，不是两级

这是实现里唯一一处**不实测就一定会写错**的地方。

第一版只有「按进程运行架构匹配，否则失败」，结果 1708 个进程里有 **391 个** 报「找不到匹配
slice」。根因不是解析错误，而是 **`PROC_PIDARCHINFO` 本身对 279 个进程不可用**（权限），
拿不到运行架构就无法在多架构文件里挑片。

补上宿主架构与第一片两级回退后，判不出的从 391 降到 79。**漏判率从 23% 降到 4.6%**。

最终四级，见 `MachOPlatform.sliceOffset(in:runningArchitecture:)`：

1. 运行架构的 cputype 与 cpusubtype（掩掉高位能力位）都匹配
2. 运行架构的 cputype 匹配，subtype 不匹配
3. **宿主架构**的 cputype 匹配 ← 救回 279 个进程的那一级
4. 第一片

第 2 级单独存在是为了 Rosetta 翻译的进程：它的运行架构是 x86_64 而宿主是 arm64，两者的
cputype 不同，只靠第 3 级会挑错片。

### `unknown` 携带原始数值，与 `Architecture` 不对称

`Architecture.unknown` 不带值，`Platform.unknown` 带。这个不对称是有意的：

CPU 类型表几十年不变，而 **Mach-O 的 platform 表几乎每年增长**。写这段代码时 SDK 26.5 已经定义
到 24（1–12 是常见平台，13–24 是 firmware、sepOS 和五个系统各自的 ExclaveCore / ExclaveKit）。
带上原始值，遇到第 25 个平台时至少还能显示成 `Platform 25` 而不是一片空白。

代价：`Platform` 不能自动合成 `RawRepresentable`，双向转换靠手写的
`init(machOPlatformValue:)` 与 `machOPlatformValue`。

### 缓存放在 `MachOPlatform`，不放在 `RunningProcessEnumerator`

`RunningApplication` 与 `RunningProcess` 都要读平台，缓存放进程枚举器里的话应用侧就用不上 ——
而 `RunningApplication` 会随 KVO 频繁重建。放在 `MachOPlatform` 里两边共用，键是可执行文件路径。

`cachedPlatform(atPath:runningArchitecture:)` 的 `runningArchitecture` 参数声明为
`@autoclosure`，**缓存命中时那次 `proc_pidinfo` 系统调用根本不会发生**。

纯解析函数 `platform(in:runningArchitecture:)` 保持无状态，测试打的是它。

### 协议 requirement 给默认实现

`RunningItem` 是 public 协议，加 requirement 本是源码破坏性变更。在协议扩展里给
`var platform: Platform? { nil }`，把破坏面降到零；库自己的两个类型都提供真值。

代价是库外的实现者会静默拿到 `nil`，编译器不会提醒他们去实现。这是刻意换来的兼容性。

## 模块结构

```
Sources/UIFoundationRunningApplication/
├── Platform.swift          # 枚举：24 个 Mach-O 平台 + unknown(UInt32)，及其显示、排序、搜索事实
├── MachOPlatform.swift     # 解析器：字节源抽象、fat slice 选择、load command 遍历、按路径缓存
├── ThreadSafeCache.swift   # 从 RunningProcess.swift 提出来的共享缓存类型
└── BSDProcess.swift        # machOArchitecture(for:) 新增，供 slice 选择复用同一次系统调用
```

`Platform` 的四个静态事实（Mach-O 常量、显示文本、case 名、排序序号）由**一个** switch
统一给出（`Platform.facts`），这样新增 case 时编译器会强制你把四个事实一次性补齐，而不是漏掉某个
属性后静默走 fallback。

## 核心算法与数据流

```
makeProcess(for: pid)
  ├─ BSDProcess.executablePath(for:)        // 拿不到 → platform 为 nil，到此为止
  ├─ runningArchitecture()                   // 局部记忆化：一次 proc_pidinfo，架构与平台共用
  └─ MachOPlatform.cachedPlatform(atPath:runningArchitecture:)
       ├─ 命中缓存 → 直接返回（autoclosure 未求值，无系统调用）
       └─ 未命中 → platform(atPath:)
            ├─ open + pread magic
            ├─ fat？→ sliceOffset(...) 四级回退挑片
            └─ platformOfSlice(...) 读 header → 读整块 load commands → 找 LC_BUILD_VERSION
                 └─ 没有 → 回退到 legacy LC_VERSION_MIN_* 命令的类型
```

`LC_BUILD_VERSION` 一旦命中立即返回；legacy 命令只作兜底记录、遍历结束才用 —— 因为同时带两者的
二进制应当以 `LC_BUILD_VERSION` 为准。

## 与提案的差异

| 差异 | 说明 |
|---|---|
| slice 回退从三级细化为**四级** | 提案写的是「运行架构精确匹配 → 宿主架构 → 第一片」。实现多了一级「运行架构 cputype 匹配但 subtype 不匹配」，插在最前两级之间。理由见上文，针对 Rosetta 翻译进程。 |
| 搜索匹配在**两个标签页**都生效 | 提案只讨论了 Processes 页。`filterItems` 是泛型基类的默认实现，`platform` 又是协议属性，因此应用页搜 `catalyst` 也能筛出 Catalyst 应用。判断为净收益：应用页虽不显示该列，但结果本身是对的、有用的。 |
| 提取了 `ThreadSafeCache` | 它原本是 `RunningProcess.swift` 里的 `private` 类型，为了让 `MachOPlatform` 复用而移到独立文件并改为 internal。行为未变。 |
| 性能数字更精确 | 提案写「1708 个进程 27.6 ms」。落地后实测：1398 个进程 / 776 个不同可执行文件，**冷解析 14.8 ms（0.019 ms 每个），全部命中缓存的热路径 2.6 ms**。同一量级，结论不变。 |

## 验证

**单元测试**：`Tests/UIFoundationTests/RunningApplication/`，34 个，全部是纯函数测试，用手工构造的字节数组
驱动，不依赖测试机装了什么。

- `PlatformTests` —— 24 个常量的双向映射、`unknown` 的保值、恰好四个平台是模拟器、
  排序序号唯一且模拟器领先、显示措辞、搜索命中与不命中。
- `MachOPlatformTests` —— thin / fat / fat64 布局，四级回退**逐级**验证（每级都构造成只有该级
  能解释命中），legacy 命令，以及畸形输入：cmdsize 为 0 / 过小 / 越界、ncmds 虚高、
  sizeofcmds 超 1 MB 上限或大于文件本身、slice 表截断、slice 偏移越界。

**跑测试只认 `swift test` 的退出码。** xcsift 会把失败的 swift-testing 测试报成 success。

**变异测试**（一次性验证，不在套件里）：故意破坏实现看测试是否变红。结论值得记下来：

| 变异 | 结果 |
|---|---|
| 去掉宿主架构回退 | 红 ✅ |
| fat header 按主机字节序读 | 红 ✅ |
| 不掩 subtype 能力位 | **初版绿** ❌ → 测试有缺陷，已修 |
| 32 位 header 用错 header 大小 | 红 ✅ |
| legacy 命令立即返回 | 红 ✅ |
| 去掉 build_version 长度校验 | **初版绿** ❌ → 测试有缺陷，已修 |
| 去掉 cmdsize 下界校验 | 绿 —— **等价变异**，其余校验已完全覆盖，非测试缺陷 |
| 去掉 slice 数量上限 | 绿 —— **等价变异**，`readBytes` 失败即中断循环 |

两处初版绿暴露的是同一类错误：**fixture 构造得太宽松，让别的分支替被测分支兜了底**。修法都是
让 fixture 变窄到只有目标分支能解释结果（例如两片同 cputype 不同 subtype，使 cputype 级回退
无法救场）。以后往这里加测试时先做一次变异验证，不要只看绿。

后两行的「等价变异」不是缺陷：那两处校验是防御性的，去掉不改变任何可观察行为。保留是因为意图明确。

**真实二进制验证**（一次性，`swiftc` 把产品源码直接编进一个验证程序跑）：

| 二进制 | 结果 |
|---|---|
| `/bin/ls`、`/usr/bin/vtool` | macOS |
| `Simulator.app`、`CoreSimulatorService` | macOS ← 符合「只标 guest」的范围决定 |
| iOS 15.5 与 18.5 两个 runtime 的 SpringBoard / launchd_sim / logd | iOS Simulator, `isSimulator == true` |
| `Home.app` | Mac Catalyst |
| `com.apple.AppleUserHIDDrivers.dext` | DriverKit |

**未验证**：tvOS / watchOS / visionOS 模拟器 —— 开发机上没有装。平台常量取自 Mach-O ABI，
判定路径与 iOS 模拟器完全相同，但确实没有实机跑过。

**未做**：模拟器运行中的端到端 UI 验证。落地时机器上的模拟器已全部关闭，而启动模拟器需要单独授权。

## 已知降级

- **约 4.6% 的进程判不出平台**，`platform` 为 `nil`，列里留空。其中绝大多数是
  `proc_pidpath` 不肯报路径的受保护系统进程 —— 与 `architecture` 判不出的是同一批。
- **字节序反转的 Mach-O 不支持**（大端二进制在小端主机上）。`platformOfSlice` 只接受
  `MH_MAGIC` / `MH_MAGIC_64`，遇到 `MH_CIGAM*` 返回 `nil`。本库支持的平台上不存在这种可执行文件。
- **ExclaveCore / ExclaveKit 的显示措辞会被截断**。列宽 130pt 是按实际会出现的最长值
  `"visionOS Simulator"`（约 125pt）定的；`"visionOS ExclaveCore"` 更长。`LabelTableCellView`
  自带尾部截断并把完整文本放进 `toolTip`，悬停仍可读。
- **平台不随进程变化更新**。缓存键是可执行文件路径，一个正在运行的可执行文件其平台不会改变；
  但若文件在原地被替换，缓存不会失效。进程列表刷新不会重读。

## 后续工作

- 若日后要标宿主侧的 CoreSimulator 支撑进程（`CoreSimulatorService`、`SimRenderServer` 等），
  那是**另一个判定维度**，不能塞进 `Platform` —— 它们的平台确实就是 macOS。应另起一个属性。
- `Platform` 已为新平台常量预留 `unknown(UInt32)`，Apple 加新值时把 case 从 `unknown` 里
  「毕业」即可，调用方本就必须写 `default` 分支，不构成破坏。

## 延伸阅读

- 配套提案：[进程平台识别与模拟器标记](../Evolutions/0015-simulator-platform-detection.md)
- 术语：[guest 进程、slice、platform](../Glossary.md)
