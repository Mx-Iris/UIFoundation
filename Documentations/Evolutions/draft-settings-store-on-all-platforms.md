# Draft - 设置存储在所有平台上可用

- **状态**: In Progress
- **作者**: JH
- **创建日期**: 2026-11-20
- **最后更新**: 2026-11-20
- **所属愿景**: 无（下游 RuntimeViewer 的愿景《iOS 版功能对齐》第二步要用到它）
- **关联提案**: [0002-reusable-settings-window](0002-reusable-settings-window.md)（设置窗口与 `UIFoundationSettings` 的来历）；下游 RuntimeViewer 的 `draft-settings-storage-on-ios`
- **实现分支 / PR**: `feature/settings-store-on-all-platforms`
- **配套文档**: 无单独文档——改的是现有指南 [`SettingsWindow.md`](../SettingsWindow.md) 的平台说明与「读写设置」一节
- **网页版**: 同目录同名的 `.html`

## 摘要

`UIFoundationSettings`（设置的数据层：`SettingsModel`、`PersistentSettings`、`SettingsStore`、`SettingsStorage`、
`FileSystemSettingsStorage`）只用 Foundation 与 Observation，却整个包在 `#if Settings && os(macOS)` 里。本提案把条件
改成 `#if Settings`，`@available` 补上 Observation 可用的各平台版本，让 iOS、Mac Catalyst、tvOS、watchOS、visionOS
也能用同一个存储；另给 `SettingsStore` 加一个同步的 `load()`，与已有的同步 `save()` 成对，供必须在启动回调里读完设置
的宿主使用。`UIFoundationSettingsUI`（设置窗口，依赖 AppKit）不动，仍只在 macOS 上。纯新增，macOS 上行为不变。

## 动机

- **数据层被窗口层的平台限定连带挡住了**。三个源文件的 import 只有 `Foundation` 与 `Observation`
  （`Sources/UIFoundationSettings/PersistentSettings.swift:3-4`、`SettingsStorage.swift:3`、`SettingsStore.swift:3-4`），
  没有一处 AppKit 调用；`os(macOS)` 是 [0002](0002-reusable-settings-window.md) 抽取时与窗口层一起加的。
- **下游要在 iOS 上存设置**。RuntimeViewer 的设置模型在 macOS 之外只能放在内存里，`load()` / `flushSynchronously()`
  是空操作（RuntimeViewer `RuntimeViewerPackages/Sources/RuntimeViewerSettings/Settings.swift:116-122`、`:134-174`）；
  它的愿景《iOS 版功能对齐》第二步要求 iOS 上真正读写同一份设置，并选定「改上游放开平台限定」而不是在 RuntimeViewer
  里另写一套持久化。
- **iOS 宿主没有地方等一个异步的读取**。`SettingsStore.load()` 只有 `async` 版本（`SettingsStore.swift:90-112`）。
  macOS 宿主在 `applicationDidFinishLaunching` 里开一个 `Task` 去读；iOS 上 `application(_:didFinishLaunchingWithOptions:)`
  返回之后紧接着连接第一个 scene，scene 里的界面可能在那个 `Task` 执行之前就读了设置，拿到的是默认值（**推测**：
  未在设备上实测 `Task` 与 scene 连接的先后，但这个顺序不受宿主控制）。`SettingsStorage` 早已要求实现同步的
  `load() throws -> Data`（`SettingsStorage.swift:23`），只是 store 没有对应的同步入口。

## 前期调研

- **数据层没有平台相关的调用**：`FileSystemSettingsStorage` 用 `FileManager.urls(for:in:)` 取 `.applicationSupportDirectory`
  （`SettingsStorage.swift:49-57`），iOS 上返回 App 容器里的 `Library/Application Support`，同样非空。注释「Guaranteed
  non-empty on macOS」（`:51`）需要改成不限平台的说法。
- **Observation 的最低版本**：`Observation` 模块在 macOS 14、iOS 17、Mac Catalyst 17、tvOS 17、watchOS 10、visionOS 1
  起可用；`SettingsModel` 继承 `Observable`、`SettingsStore` 是 `@Observable`，所以 `@available` 取这一组版本。包的部署
  下限是 iOS 13 / Catalyst 13 / tvOS 13 / watchOS 6 / visionOS 1（`Package.swift:57-60`），比 Observation 低，
  因此必须写全 `@available`，不能只删 `os(macOS)`。
- **`SettingsStorage` 与 `FileSystemSettingsStorage` 没有 `@available`**（`SettingsStorage.swift:19`、`:31`）：它们只用
  Foundation，在包的部署下限上就能用，放开后仍不需要标注。
- **同步与异步重载并存的先例就在这个类型里**：`save() async throws` 与 `save() throws`（`SettingsStore.swift:116-131`）
  靠调用上下文选择（SE-0296：同步上下文只能选同步重载），`SettingsStorage` 的两对方法也是这样。同步 `load()` 照抄这个形状。
- **测试**：`Tests/UIFoundationTests/Settings/SettingsStoreTests.swift` 与 `AppSettingsTests.swift` 都包在
  `#if Settings && os(macOS)` 里。前者只测数据层，可以改成 `#if Settings`；后者测 `AppSettings`（UI 层），保持原样。
  测试只在 macOS 上用 `swift test` 跑，其他平台靠编译验证。
- **使用方**：除 RuntimeViewer 外，`ReverseEngineeringToolbox`、`MacKedUpdater`、`XCOrganizer` 的包也依赖
  `UIFoundationSettings`，三者都是 macOS App，只在 macOS 上用到它。

## 提议方案

1. **放开平台限定**：`UIFoundationSettings` 的三个源文件把 `#if Settings && os(macOS)` 改为 `#if Settings`；
   `SettingsModel`、`PersistentSettings`（及其扩展）、`SettingsStore` 的 `@available(macOS 14.0, *)` 改为
   `@available(macOS 14.0, iOS 17.0, macCatalyst 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)`。
2. **同步读取**：`SettingsStore` 新增 `@discardableResult public func load() -> LoadOutcome`，语义与异步版本相同（没有
   存储时返回 `.noStoredData`，读不出或解不开时返回 `.failed`、保留默认值、不碰存储里的数据，读到后重新挂上持久化观察）。
   两个版本共用一个私有的「把读到的数据变成结果」的方法，免得两份逻辑漂移。
3. **测试**：`SettingsStoreTests` 改成 `#if Settings`，补同步读取的用例；放开平台后在 iOS 模拟器、Mac Catalyst、
   tvOS、watchOS、visionOS 上各编一次这个模块。
4. **文档**：`SettingsWindow.md` 开头的平台说明改为「数据层各平台可用，窗口层只在 macOS」，「读写设置」一节写明同步
   `load()` 的用途；`AGENTS.md` 项目地图里 `UIFoundationSettings` 那一行改成各平台的版本。

### 非目标

- **`UIFoundationSettingsUI` 不动**：设置窗口、`SettingsScene`、`AppSettings` 等仍只在 macOS 上；iOS 上的设置界面由
  宿主自己做，或另起一篇。
- **不把设置模块并进 `UIFoundation` 伞模块**：`SettingsWindow.md` 记着不并进去的原因，这次不改。
- **不改存储格式、文件位置或自动保存的节奏**。
- **不给 iOS 加生命周期钩子**：什么时候写盘（进入后台、即将终止）由宿主决定，库只提供同步的 `save()` / `load()`。

## 改动地图

| 文件 / 类型 | 动作 | 改什么 | 为什么 | 步骤 |
|---|---|---|---|---|
| `Sources/UIFoundationSettings/PersistentSettings.swift` · `SettingsModel`、`PersistentSettings` 及扩展 | 修改 | 条件改 `#if Settings`；三处 `@available` 补齐各平台 | 数据层不依赖 AppKit | 1 |
| `Sources/UIFoundationSettings/SettingsStorage.swift` · `SettingsStorage`、`FileSystemSettingsStorage` | 修改 | 条件改 `#if Settings`；`init` 里「Guaranteed non-empty on macOS」与类型注释里的 `~/Library/...` 路径改成不限平台的说法 | 同上；iOS 的位置在 App 容器里 | 1 |
| `Sources/UIFoundationSettings/SettingsStore.swift` · `SettingsStore` | 修改 | 条件改 `#if Settings`；`@available` 补齐；新增同步 `load()`；抽出私有的 `adopt(_:)`（数据 → `LoadOutcome`）供两个版本共用 | 启动回调里必须读完设置的宿主 | 1、2 |
| `Tests/UIFoundationTests/Settings/SettingsStoreTests.swift` | 修改 | 条件改 `#if Settings`；新增同步读取的用例 | 覆盖新入口；数据层测试不该挂在 macOS 上 | 2 |
| `Documentations/SettingsWindow.md` | 修改 | 开头的平台说明；「读写设置」一节加同步 `load()` 与非 macOS 宿主何时写盘的建议 | 指南是对外契约，契约变了要同批改 | 3 |
| `AGENTS.md` · 项目地图 | 修改 | `UIFoundationSettings` 一行写各平台版本 | 让 agent 知道它不再只在 macOS | 3 |
| `Documentations/Evolutions/README.md` | 修改 | 登记本提案 | 索引 | 3 |

## 架构图

```text
UIFoundationSettings  (trait Settings)
- #if Settings && os(macOS)            + #if Settings
  SettingsModel        @available(macOS 14)   + iOS 17, macCatalyst 17, tvOS 17, watchOS 10, visionOS 1
  PersistentSettings   @available(macOS 14)   + (same)
  SettingsStore        @available(macOS 14)   + (same)
    load() async -> LoadOutcome
  + load()       -> LoadOutcome          (new, synchronous; same result as the async one)
    save() async throws
    save()       throws
  SettingsStorage / FileSystemSettingsStorage   (no @available; package floor)

UIFoundationSettingsUI  (unchanged: #if Settings && os(macOS))
```

```text
Host launch, before and after
  macOS (unchanged)   applicationDidFinishLaunching ── Task { await store.load() }
  iOS (new)           didFinishLaunchingWithOptions ── store.load()        // returns with the settings read
                      scene willConnectTo ─────────── reads Settings.current  // already the stored value
                      didEnterBackground ─────────── try store.save()     // host's choice
```

## 详细设计

```swift
@available(macOS 14.0, iOS 17.0, macCatalyst 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *)
@MainActor
@Observable
public final class SettingsStore<Value: SettingsModel> {
    /// Reads stored settings and adopts them, keeping the default value if
    /// there is nothing to read.
    @discardableResult
    public func load() async -> LoadOutcome {
        let data: Data
        do {
            data = try await storage.load()
        } catch {
            return Self.outcome(ofFailedLoad: error)
        }
        return adopt(data)
    }

    /// Synchronous counterpart of ``load()`` — the same read, finished
    /// before the call returns. The compiler picks this overload in
    /// synchronous contexts.
    ///
    /// For a host that must have the stored settings in place before it
    /// returns from a launch callback: on iOS, the first scene connects right
    /// after `application(_:didFinishLaunchingWithOptions:)` returns, which
    /// can be before a task started there has run.
    @discardableResult
    public func load() -> LoadOutcome {
        let data: Data
        do {
            data = try storage.load()
        } catch {
            return Self.outcome(ofFailedLoad: error)
        }
        return adopt(data)
    }

    private static func outcome(ofFailedLoad error: any Error) -> LoadOutcome {
        if case FileSystemSettingsStorage.LoadError.noStoredData = error {
            return .noStoredData
        }
        return .failed(error)
    }

    private func adopt(_ data: Data) -> LoadOutcome {
        do {
            value = try JSONDecoder().decode(Value.self, from: data)
            armPersistenceObservation()
            return .loaded
        } catch {
            return .failed(error)
        }
    }
}
```

`outcome(ofFailedLoad:)` 保留现有的判别：只有 `FileSystemSettingsStorage.LoadError.noStoredData` 算「没有存储」，其他
错误一律 `.failed`。异步版本只是把现有代码拆进两个私有方法，行为不变。

## 替代方案考量

- **只删 `os(macOS)`、不补 `@available`**：包的 iOS 下限是 13，Observation 要 17，编不过。
- **不加同步 `load()`，让 iOS 宿主自己处理先后**：宿主只能让第一个 scene 等一个异步读取，或者先用默认值、读完后
  再全部刷新——前者要改 scene 的启动流程，后者在读完之前改动设置会写回默认值。`SettingsStorage` 已经要求同步读取，
  store 补一个入口代价最小。
- **改名为 `loadSynchronously()`**：类型里已有 `save()` 的同名同步重载，另起名字反而不一致。

## 影响

### 源码兼容性（source compatibility）

**纯新增**。macOS 上的声明与行为不变；新增的同步 `load()` 与异步版本同名，现有调用点都在 `await` 里，仍选异步重载。
一个边角情况：在同步上下文里写 `store.load()` 而以前因为没有同步重载会报错的代码，现在会编过并选同步版本——以前编不过，
所以不存在被悄悄改变行为的现有代码。

### ABI 兼容性（条件项）

不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。

### 下游影响

- 本仓库：只有 `UIFoundationSettings` 与 `UIFoundationTests`。`UIFoundationSettingsUI` 不变。
- **RuntimeViewer**：在 iOS 上改用这个存储（它自己的提案 `draft-settings-storage-on-ios`），版本下限抬到本次发版。
- **ReverseEngineeringToolbox、MacKedUpdater、XCOrganizer**：只在 macOS 上用，无需改动。

### 文档与示例

`SettingsWindow.md` 的平台说明与「读写设置」一节；`AGENTS.md` 的项目地图。示例 App 不变（iOS 示例不演示设置）。

## API 演进与废弃策略

- 没有被替代的 API，不废弃任何东西。
- 不需要 semver major 跃迁；按本库惯例发一个次版本（0.48.0）。

## 落地步骤

1. **放开平台限定**（已完成）—— 改动地图前三行的条件与 `@available`
   - 行为：`settingsModuleBuildsForIOSCatalystTVOSWatchOSAndVisionOS`（各平台 `xcodebuild` 编过 `UIFoundationSettings`，开 `Settings` trait）
   - 行为：`existingSettingsStoreTestsPassUnchanged`（macOS 上原有用例照过）
2. **同步读取**（已完成）—— `SettingsStore` 与测试
   - 行为：`synchronousLoadAdoptsStoredSettings`
   - 行为：`synchronousLoadKeepsDefaultValueWhenNothingIsStored`
   - 行为：`synchronousLoadReportsUndecodableDataAndKeepsStoredBytes`
   - 行为：`synchronousLoadDoesNotWriteTheSettingsStraightBack`
   - 行为：`editAfterSynchronousLoadIsSaved`（读完重新挂上了持久化观察）
3. **文档与发版**（文档已完成）—— 指南、`AGENTS.md`、索引；合进 `main` 后打 `0.48.0`
   - 行为：`guideDescribesDataLayerAsCrossPlatform`

**收尾时必须判断两件事**（判断结果写进决策日志，不允许沉默跳过）：

- **要不要配套专题文章** —— 预计不需要：契约变化写进现有的 `SettingsWindow.md`。
- **有没有引入新术语** —— 预计没有。

## 决策日志

| 日期 | 变更 | 说明 |
|------|------|------|
| 2026-11-20 | Created as Draft | RuntimeViewer 要在 iOS 上存设置；数据层只用 Foundation 与 Observation，却被 `os(macOS)` 挡着 |
| 2026-11-20 | 自定：加同步 `load()` | iOS 宿主要在启动回调返回前读完设置；照 `save()` 已有的同步 / 异步重载成对 |
| 2026-11-20 | 自定：`UIFoundationSettingsUI` 不在本篇 | 用户定了 RuntimeViewer 这一步只做存储，iOS 设置界面留到之后 |
| 2026-11-20 | 用户批准，开始实现 | 与 RuntimeViewer 的 `draft-settings-storage-on-ios` 一起批准；本篇先落地并发 0.48.0，RuntimeViewer 再抬下限 |
| 2026-11-20 | 实现中的调整 | 一、`SettingsStoreTests` 里 15 处 `#available(macOS 14.0, *)` 一并补齐各平台版本，否则测试 target 一旦为其他平台编译就会报可用性错误。二、同步读取的五个用例里，同步测试直接写 `store.load()`，异步测试照同步 `save()` 用例的写法绑定一个同步函数值，免得选到异步重载；变异检查（让同步 `load()` 不读就返回）使其中 4 处断言变红。三、各平台验证：iOS 真机、iOS 模拟器、Mac Catalyst、visionOS 模拟器用 `swift build --target UIFoundationSettings --triple … --sdk …` 交叉编译通过，产物里同步、异步两个 `load()` 都在；tvOS 与 watchOS 上整包编不了——包声明的 tvOS 13 / watchOS 6 低于 Xcode 27 支持的 15 / 9，基线上同样如此，与本篇无关——改用 `swiftc -typecheck -D Settings` 以 tvOS 15、watchOS 9 为目标检查三个源文件，通过。 |
