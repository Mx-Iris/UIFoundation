# 0025 - NSGlassEffectView_Private.h：给七个私有玻璃设置换上逆向出来的类型

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-09-26
- **最后更新**: 2026-09-26
- **所属愿景**: 无
- **关联提案**: [`0022`](0022-glass-effect-replica-view.md) —— 这个私有头是它引入的；本提案只给私有设置补上类型，不改它的任何结论
- **实现分支 / PR**: `main`（直接落地）
- **配套文档**: 逆向报告 [`Researchs/AppKit-NSGlassEffectView-PrivateConfiguration.md`](../../Researchs/AppKit-NSGlassEffectView-PrivateConfiguration.md)（新写，原分栏报告第 6 节并入其中）；[`GlassEffectReplica.md`](../GlassEffectReplica.md) 的「已知偏离」同步更新

## 摘要

`NSGlassEffectView`（macOS 26+）有七个决定玻璃怎么渲染的私有设置：`_variant`、`_subvariant`、`_interactionState`、`_subduedState`、`_scrimState`、`_contentLensing`、`_adaptiveAppearance`。AppKit 自己的 Swift 代码把它们声明成同名的 C 类型（`__C._NSGlassEffectViewVariant` 等），但 SDK 里一个都没有，而 C 枚举的常量名和字符串常量都不进二进制。本库的私有头原先只声明了其中三个，而且全是裸 `NSInteger` / `NSString`，调用方只能写魔数。本提案按逆向结果把七个都声明成具体类型：六个 `NS_ENUM`，加一个 `NS_TYPED_EXTENSIBLE_ENUM` 字符串类型。常量名取自 AppKit 对每个值的实际处理 —— 多数是它为该值调用的 DesignLibrary API，`_adaptiveAppearance` 的三个名字则是 AppKit 自己的调试输出打印的原名。

## 方案

- **依据**：`NSGlassEffectView` 是 Swift 实现的，一个配置构建函数把每个设置翻译成 `DesignLibrary.GlassMaterialProvider.Configuration`（27.0 `0x185DDA3D4`、26.6 `0x184E1852C`）。七张取值表在 26.6 与 27.0 上逐项一致。完整表格、地址、谁在用哪个值、以及还没弄清的部分，都在逆向报告里。
- **头文件**：
  - 新增 `_NSGlassEffectViewInteractionState`（idle / pressed / rollover）、`_NSGlassEffectViewSubduedState`、`_NSGlassEffectViewScrimState`（各自只有 0 和 1）、`_NSGlassEffectViewContentLensing`、`_NSGlassEffectViewAdaptiveAppearance`（automatic / off / on）五个 `NS_ENUM`，以及字符串类型 `_NSGlassEffectViewSubvariant`。
  - `_variant`、`_subvariant`、`_adaptiveAppearance` 改用新类型；补声明另外四个属性。
  - 改正 `_adaptiveAppearance` 的注释：它管的是按背景明暗切换浅色 / 深色，与窗口 key 状态无关。
- **subvariant 常量由本库自己定义**：AppKit 没有导出任何 subvariant 常量，它的 ObjC 代码直接写字面量。所以头文件声明、ObjC target 里新增的 `NSGlassEffectView_Private.m` 定义。
  - 覆盖 DesignLibrary 在 26.6 与 27.0 上都接受的 31 个名字，含 AppKit 自己用的 `tab` / `menu`；只有一个版本接受的名字不给常量。
  - ObjC 与 Swift（`.tab`、`.sheet` …）都能用。
  - 头文件和 `.m` 里都注明 Apple 的实现没有这种常量。
- **源码兼容性**：
  - Swift 里 `_variant`、`_adaptiveAppearance` 从 `Int` 变成枚举，`_subvariant` 从 `String?` 变成 `_NSGlassEffectViewSubvariant?`。写字面量的地方会编不过。
  - 这个头在 `AppleInternal` trait 下经伞模块导出，所以对下游算源码不兼容。逐个查过 RuntimeViewer、MachOKitUI、PrivateSymbols，都没有直接用这七个属性。
  - 本库内受影响的只有 `GlassEffectReplicaViewTests` 里的字面量。`matchGlassConfiguration(of:)` 只做原样拷贝，不受影响；`TabBar+SystemDecoration.swift` 走的是动态 selector 调用，也不受影响。
  - ABI：不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。
- **测试**：`GlassEffectViewPrivateConfigurationTests` 在当前系统上核对从视图外能观察到的部分：
  - 七个设置的初始值；
  - 公开 `style` 与 `_variant` 的对应；
  - `_adaptiveAppearance` 三个值被 AppKit 调试输出打印成的名字。

  其余取值在视图外观察不到，只能靠逆向保证；这些一旦对不上，就说明整个头要在这个系统上重读。
- **没有问、自己定的假设**：
  - `_variant` 的 0 叫 `Default`：二进制里没有它的名字，只知道它是初始值、渲染效果同 regular。
  - 大小写按 Objective-C 习惯写成 `AVPlayer`、`FaceTime`（Swift 里是 `.avPlayer`、`.faceTime`），DesignLibrary 的原拼写记在注释里。
  - subdued / scrim / lensing 的 0 统一叫 `Automatic`，仿照 AppKit 给 `_adaptiveAppearance` 的 0 起的名字。
  - lensing 的 0 和 1 行为完全相同，名字只是按同样的形状推的，注释里写明了。
  - subdued / scrim 不声明 2：没有任何代码区分它和 0，也没有任何代码写它。
  - 用 `NS_ENUM` 而不是纯 C `enum`，和同目录 `NSView_Private.h` 一致。
  - 不加 `API_AVAILABLE`：整个头已经被 `__MAC_26_0` 包住。
  - 编号都不是契约。`GlassEffectReplicaView` 照旧从活的外层玻璃拷贝，枚举只是让读代码的人看得懂。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-26 | Created as Draft | 用户要求逆向 `_NSGlassEffectViewVariant` 的常量名，并用在 `NSGlassEffectView_Private.h` 里 |
| 2026-09-26 | Accepted | 用户在对话中确认了方案：头文件改用枚举，研究报告一起补 |
| 2026-09-26 | 常量名取 DesignLibrary 配置名，而不是去猜 Apple 的原拼写 | 原拼写不在任何二进制里；配置名是每个值唯一有据可查的名字 |
| 2026-09-26 | In Progress | 开始实现 |
| 2026-09-26 | Implemented（仅 `_variant`） | `swift test --traits AppleInternal --filter GlassEffect` 10 个测试通过，打开全部 trait 的 `swift build` 通过 |
| 2026-09-26 | 范围扩大到全部七个私有设置，状态回到 In Progress；文件由 `draft-glass-effect-view-variant-enum.md` 改名 | 用户要求用子 agent 逆向另外六个类型并一并写进头文件，同时写一份调查报告。仍未提交，按「一次改动 = 一份提案」原地扩写 |
| 2026-09-26 | subvariant 用 `NS_TYPED_EXTENSIBLE_ENUM`，常量只在 Swift 侧补 `tab` / `menu` | 二进制分不出 Apple 用的是 `NS_TYPED_ENUM` 还是 extensible 版本；合法取值随系统版本变化、任何字符串都能传，extensible 更符合实际。AppKit 没有导出常量，头文件里写 `extern` 会链接不上 |
| 2026-09-26 | 逆向依据单独成篇，分栏报告第 6 节改为指向它 | 七个设置放在「分栏玻璃」那篇里不合适；同一张表只保留一份 |
| 2026-09-26 | Implemented | `swift test --traits AppleInternal --filter GlassEffect` 12 个测试（14 个用例）全部通过，原始退出码 0；打开全部 trait 的 `swift build` 通过。配套文档：新写逆向报告，不需要新的指南或实现说明；`GlassEffectReplica.md` 与 `AGENTS.md` 同步更正。术语表：没有新术语 |
| 2026-09-26 | subvariant 常量改由本库在 ObjC 层定义（`NSGlassEffectView_Private.m`），删掉只有 Swift 能用的 `NSGlassEffectView+Subvariant.swift` | 用户要求自己定义常量，让 ObjC 和 Swift 都能用，并注明 Apple 的实现里没有这种东西。符号在本库里，AppKit 是动态库，不会和它冲突 |
| 2026-09-26 | Implemented | 13 个测试（15 个用例）全部通过，原始退出码 0，新增的一条核对两个常量的拼写与 AppKit 写入的字面量一致；打开全部 trait 的 `swift build` 通过 |
| 2026-09-26 | 常量扩充到 26.6 与 27.0 都接受的 31 个名字，状态回到 In Progress | 用户要求补齐，但只补两个系统都存在的。名单取两版 `Subvariant.Kind` 元数据的交集（与子 agent 反汇编两版初始化函数得到的结果一致）；只存在于一个版本的名字（27.0 的 `dock` 等 17 个、26.6 的 `track` / `iOSNotificationCenter`）不给常量 |
| 2026-09-26 | Implemented | `swift test --traits AppleInternal --filter GlassEffect` 13 个测试、45 个用例全部通过，原始退出码 0；其中参数化测试逐个核对 31 个常量的拼写，期望值取自 DesignLibrary 元数据而非照抄 `.m`。打开全部 trait 的 `swift build` 通过，无错误无警告 |
