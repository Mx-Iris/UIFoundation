# 0030 - AsyncDocument：读写都是 async 的 NSDocument 子类

- **状态**: Implemented
- **创建日期**: 2026-10-17
- **最后更新**: 2026-10-17
- **配套文档**: 使用指南 [`AsyncDocument.md`](../AsyncDocument.md)；逆向与实测依据 [`Researchs/AppKit-NSDocument-AsyncReadingAndWriting-Internals.md`](../../Researchs/AppKit-NSDocument-AsyncReadingAndWriting-Internals.md)

## 摘要

在 `UIFoundationAppKit` 新增 `AsyncDocument<Snapshot>`，不挂 trait。它是 NSDocument 的子类，子类实现四个方法：

| 步骤 | 方法 | 在哪里执行 |
|---|---|---|
| 保存时把要写的内容复制成一个值 | `snapshot(ofType:for:)` | 主线程，同步 |
| 把这个值写进文件 | `write(_:to:context:)` | 后台，`async` |
| 从文件读出一个值 | `readSnapshot(from:ofType:)` | 后台，`async` |
| 把读到的值填回文档 | `apply(_:ofType:)` | 主线程，同步 |

这个值就是「快照」，这种拆法叫快照模型。

另外在 `NSDocument.box` 上新增 9 个 async 方法。NSDocument 有一类操作通过「delegate + selector + contextInfo」回调结果，例如 `canClose`、带保存面板的保存；这 9 个方法把它们改成可以 `await`。

纯新增。不改动任何既有 API 和行为，现有使用方零影响。

## 方案

### 为什么选快照模型

动手前做了两个原型，用同一份示例文档跑了 14 个对比测试。两个原型都没提交，结论见决策日志。

- **快照模型**：就是本提案的做法。
- **原钩子改 async**：把 NSDocument 原有的 `data(ofType:)`、`read(from:ofType:)` 等方法直接改成 `async`，整段读写逻辑在主线程上执行。

原钩子模型有三类问题，基类无法替子类兜住：

- 用户在写盘期间编辑时，文件被写成一半旧、一半新。
- 不开 `autosavesInPlace` 的文档会丢编辑：写盘期间的按键被标成已保存，实际不在文件里。
- 两种情况下会卡死：保存进行中主线程去等文件访问；从 Swift 的 `@MainActor` 代码触发主线程上的读盘。

同样的场景，快照模型全部正常。

macOS 27 SwiftUI 的 `Document` 协议在 API 上也是这种拆法。我们实测了它接到 NSDocument 上的 `URLPlatformDocument`，发现以下问题：

- 写盘错误被吞掉：写了一半再出错时，保存报成功，原文件被半截内容替换。
- `apply` 的错误被丢掉。
- 取快照时 async 挂起，主线程若在等这个文档的文件访问，就会死锁。

本实现在这三处的接法都与它相反，并有测试覆盖。

### 关键接法（都有实测依据，见调研报告）

- **快照在 `canAsynchronouslyWrite(to:ofType:for:)` 里取。**
  - 这个方法只有 NSDocument 的保存流程会调用，在主线程上执行。
  - 调用时机在拿到 change-count token 之后，NSDocument 锁住主线程之前。
  - 所以保存期间的编辑既不会进文件，也不会被标成已保存。
- **不开 `autosavesInPlace` 的文档同步写盘。**
  - 这类文档没有 change-count token。保存完成时，NSDocument 会把写盘期间的编辑一并标成已保存。
  - 所以对这类文档，`canAsynchronouslyWrite` 回答 `false`。
  - 写方法仍在后台执行器上跑，但主线程会等它写完，这和普通 NSDocument 一样。
- **读盘在后台进行，`apply` 一定在主线程。**
  - 后台打开时，经 `continueAsynchronousWorkOnMainThread(_:)` 回到主线程执行 `apply`，并等它完成。NSDocument 在自己的同步等待里只处理这个通道。
  - `apply` 抛出的错误会让打开或恢复失败。
- **`init()` 声明为 `nonisolated`。**
  - 后台打开时，AppKit 在 "NSDocumentController Opening" 队列上调用 `-init`。
  - NSDocument 的 `init()` 在 Swift 里是主线程隔离的，Swift 6 模式的子类因此会在 Objective-C 入口处插入主线程断言（已用 SILGen 核实），后台打开时就会触发。
  - 基类声明 `nonisolated init()` 之后，子类不管是自己写 `init` 还是用编译器合成的，都继承 `nonisolated`，入口处不再有断言。
  - 代价：本模块里 `super.init()` 这一行会产生一条警告，而且压不掉，原因见决策日志。

### 哪些方法是 `final`

用户要求不让子类覆写的方法标 `final`。判据是：覆写了会让上面的接法失效，或者覆写了也永远不会被调用。

- **接法本身，3 个**：
  - `canAsynchronouslyWrite(to:ofType:for:)`：快照在这里取。
  - `write(to:ofType:for:originalContentsURL:)`：写盘的桥接。
  - `read(from:ofType:)`（URL 版）：读盘的桥接。
- **基类永远不调用的 5 个**：
  - `read(from:ofType:)` 的 `Data` 版和 `FileWrapper` 版
  - `data(ofType:)`
  - `fileWrapper(ofType:)`
  - `write(to:ofType:)`

  它们实现成抛出 `CocoaError(.featureUnsupported)`。标 `final` 是为了让从普通 NSDocument 迁移过来的子类在这几处编译失败，免得留下永远不会执行的覆写。

**保持 `open` 的是策略开关 `canConcurrentlyReadDocuments(ofType:)`**，默认 `true`。

- 覆写它不会破坏接法：在主线程读和在后台读，桥接都能处理。
- 子类需要关掉它的情况有两种：
  - `init` 不能在后台执行。
  - 想避开版本浏览器的已知风险（见使用指南）。

### `NSDocument.box` 上的 9 个 async 方法

放在 `UIFoundationToolbox/AppKit/NSDocument+.swift`，遵循本库「框架类型的扩展一律走 `.box`」的约定。这样任何 NSDocument 都能用，而且将来 Apple 加了同名 async 方法也不会撞名。

| 方法 | 包装的是 |
|---|---|
| `canClose()` | `canClose(withDelegate:shouldClose:contextInfo:)` |
| `shouldCloseWindowController(_:)` | `shouldCloseWindowController(_:delegate:shouldClose:contextInfo:)` |
| `save()` | `save(withDelegate:didSave:contextInfo:)` |
| `runModalSavePanel(for:)` | `runModalSavePanel(for:delegate:didSave:contextInfo:)` |
| `duplicate()` | `duplicate(withDelegate:didDuplicate:contextInfo:)` |
| `runModalPageLayout(with:)` | `runModalPageLayout(with:delegate:didRun:contextInfo:)` |
| `print(withSettings:showPrintPanel:)` | `print(withSettings:showPrintPanel:delegate:didPrint:contextInfo:)` |
| `runModalPrintOperation(_:)` | `runModalPrintOperation(_:delegate:didRun:contextInfo:)` |
| `presentError(_:modalFor:)` | `presentError(_:modalFor:delegate:didPresent:contextInfo:)` |

- 名字就是原方法去掉 delegate、selector、contextInfo 三个参数。
- 返回值是 NSDocument 传给回调的那个 `Bool`。

不在表里的有两类：

- **已经能 `await` 的**：带 completion handler 的方法 Swift 已自动导入成 async，例如 `save(to:ofType:for:)`、`autosave(withImplicitCancellability:)`、`move(to:)`。
- **不该由应用调用的**：`autosaveDocument(withDelegate:…)`。头文件说明它只由 AppKit 的定时自动保存调用。

### 没做的

- **写盘时传入「上一次写入的快照」**，方便包格式文档只写改动的部分。
  - 这个快照必须和 `originalContentsURL` 指向的文件对应。
  - 文档另有自动保存副本（`autosavedContentsFileURL`）时，这两者可能不对应。对应关系定不清，传错了会写坏文件。
- **读写进度**：NSDocument 没有公开的进度属性，做了也没有地方显示。
- **NSDocumentController 的回调式方法**（`closeAllDocuments`、`reviewUnsavedDocuments`）：本次只覆盖文档本身的操作。

### 采用的假设（没有询问）

- 类名用用户原话里的 `AsyncDocument`，泛型参数 `Snapshot` 要求 `Sendable`。
  - `FileWrapper` 不是 `Sendable`，包格式文档应把模型复制成值类型，在 `write` 里再生成 `FileWrapper`。
- `autosavesInPlace` 保持 NSDocument 的默认值 `false`，不替子类打开。
  - 打开它会改变保存体验：关窗不再询问、出现版本浏览，这应由应用决定。
  - 使用指南会说明：不打开就是同步写盘。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-10-16 | 用户要求「封装一个 AsyncDocument 继承 NSDocument，把读取和写入等等操作全部换成 async」 | 原始需求 |
| 2026-10-16 | 快照模型和原钩子模型各做一个原型，跑 14 个对比测试；原型不提交 | 用户要求两个都做出来对比。结论见「为什么选快照模型」 |
| 2026-10-17 | 写最小的 SwiftUI `DocumentGroup` 探针 app 实测 `URLPlatformDocument`（macOS 27.2） | 用户批准。坐实写盘错误被吞、`apply` 错误被丢、async 取快照与文件访问死锁三条。推翻了静态分析的一条：主线程上恢复版本不会卡死，但 `revertToContentsOfURL:` 在 `apply` 之前就返回 |
| 2026-10-17 | 选定快照模型，原钩子模型的原型删除；状态 Draft → Accepted → In Progress | 用户选定 |
| 2026-10-17 | 子类不该覆写的方法标 `final`：接法本身 3 个，基类不调用的 5 个；`canConcurrentlyReadDocuments` 保持 `open` | 用户要求标 `final`；判据见「哪些方法是 final」 |
| 2026-10-17 | `init()` 声明为 `nonisolated`，接受 `super.init()` 处的一条警告 | Swift 6 子类在后台打开时会撞上 Objective-C 入口的主线程断言；这是唯一的解法。三种消除警告的写法都试过，均无效：`@preconcurrency import AppKit`、给 init 加 `@preconcurrency`、Swift 6.4 的 `@diagnose(ActorIsolatedCall, as: ignored)`（SE-0522）。原因是这条在 Swift 5 模式下是降级成警告的错误，SE-0522 明确不管错误 |
| 2026-10-17 | 原型桥接里等待主线程的 5 秒超时不进正式实现 | 那是为了让对比测试能观察到卡死而加的测量手段；正式实现若超时放弃，只会把主线程忙时的正常打开变成假错误 |
| 2026-10-17 | 回调式操作的 async 版放进 `NSDocument.box`，不做成 `AsyncDocument` 的方法 | 与文档模型无关，任何 NSDocument 都适用；遵循本库 `.box` 约定，避免与 Apple 将来的同名 API 冲突 |
| 2026-10-17 | 状态改为 Implemented，编号 0030，直接提交到 `main` | 维护者要求提交推送。编号取 `origin` 各分支上的最大编号 0029 加一。配套文档（指南 `AsyncDocument.md`、调研报告 `AppKit-NSDocument-AsyncReadingAndWriting-Internals.md`）已登记在文首。术语表新增「快照模型」。agent 插件不改：`uifoundation-widgets` 只讲 AppKit 界面，`.box` 辅助方法按目录指过去而不逐个列举；`uifoundation-settings-layer` 与此无关 |
