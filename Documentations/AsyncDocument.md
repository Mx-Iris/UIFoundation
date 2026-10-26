# AsyncDocument —— 读写都是 async 的 NSDocument

`UIFoundationAppKit` 里的 `AsyncDocument<Snapshot: Sendable>`（源码在 `Sources/UIFoundationAppKit/Document/`），不挂 trait。它是 NSDocument 的子类，读盘、写盘都写成
`async` 方法，在后台执行器上运行。主线程上只做两件同步的事：保存时把要写的内容复制成一个值（快照），打开和
恢复时把读到的快照填回文档。另附 `NSDocument.box` 上 9 个 async 方法（在 `Sources/UIFoundationToolbox/AppKit/NSDocument+.swift`），把 `canClose`、带面板的保存这类回调式
操作改成可以 `await`。

决策记录见 [`Evolutions/0030-async-document.md`](Evolutions/0030-async-document.md)，逆向与实测依据见
[`Researchs/AppKit-NSDocument-AsyncReadingAndWriting-Internals.md`](../Researchs/AppKit-NSDocument-AsyncReadingAndWriting-Internals.md)。

## 什么时候用它

- 读写代码想用 `async` / `await` 写，比如调用 async 的解码、压缩、网络或数据库 API。
- 文件大，不想让用户在保存时等。前提是打开 `autosavesInPlace`，见契约 3。
- 打开文件时不想卡住界面。默认在后台读盘，见契约 4。

## 用法

子类实现四个方法：

```swift
final class NoteDocument: AsyncDocument<String> {
    var text = ""

    override class var autosavesInPlace: Bool { true }

    // 保存：主线程同步，只复制
    override func snapshot(ofType typeName: String, for saveOperation: SaveOperationType) throws -> String {
        text
    }

    // 保存：后台 async，负责编码和写盘
    nonisolated override func write(_ snapshot: String, to url: URL, context: WriteContext) async throws {
        try Data(snapshot.utf8).write(to: url)
    }

    // 打开、恢复：后台 async，负责读盘和解码
    nonisolated override func readSnapshot(from url: URL, ofType typeName: String) async throws -> String {
        String(decoding: try Data(contentsOf: url), as: UTF8.self)
    }

    // 打开、恢复：主线程同步，把值填回文档
    override func apply(_ snapshot: String, ofType typeName: String) throws {
        text = snapshot
    }
}
```

- 四个方法都可以抛错。
  - `snapshot` 或 `write` 抛错，保存失败，NSDocument 照常弹出错误。
  - `readSnapshot` 或 `apply` 抛错，打开或恢复失败。
  - 和 SwiftUI 的 `DocumentGroup` 不同，这里的错误都会传到 NSDocument，不会被吞掉。
- `WriteContext` 带三样东西：
  - `typeName`
  - `saveOperation`
  - `originalContentsURL`：文档当前内容所在的位置，包格式文档可以从这里复用没改的部分。

## `NSDocument.box` 上的 async 操作

任何 NSDocument 都能用，不限于 `AsyncDocument`。

```swift
if await document.box.canClose() {
    document.close()
}
```

| 方法 | 包装的是 | 返回 `true` 表示 |
|---|---|---|
| `canClose()` | `canClose(withDelegate:shouldClose:contextInfo:)` | 可以关闭 |
| `shouldCloseWindowController(_:)` | `shouldCloseWindowController(_:delegate:shouldClose:contextInfo:)` | 这个窗口控制器可以关闭 |
| `save()` | `save(withDelegate:didSave:contextInfo:)`（文件 > 存储） | 存好了 |
| `runModalSavePanel(for:)` | `runModalSavePanel(for:delegate:didSave:contextInfo:)` | 存好了；用户取消面板时为 `false` |
| `duplicate()` | `duplicate(withDelegate:didDuplicate:contextInfo:)`（文件 > 复制） | 复制了一份 |
| `runModalPageLayout(with:)` | `runModalPageLayout(with:delegate:didRun:contextInfo:)` | 用户确认了页面设置 |
| `print(withSettings:showPrintPanel:)` | `print(withSettings:showPrintPanel:delegate:didPrint:contextInfo:)` | 打印了 |
| `runModalPrintOperation(_:)` | `runModalPrintOperation(_:delegate:didRun:contextInfo:)` | 打印了 |
| `presentError(_:modalFor:)` | `presentError(_:modalFor:delegate:didPresent:contextInfo:)` | 错误恢复成功 |

- 它们都在主线程上执行，弹出的面板、sheet、警告框和原方法完全一样。
- 名字就是原方法去掉 delegate、selector、contextInfo 三个参数。
- 带 completion handler 的操作不在表里，Swift 已经把它们导入成 async，例如 `save(to:ofType:for:)`、
  `autosave(withImplicitCancellability:)`、`move(to:)`。

## 子类必须遵守的契约

1. **`write` 和 `readSnapshot` 绝不能跳回主线程。**
   - 包括这几种写法：`await MainActor.run`、调用 `@MainActor` 方法、`DispatchQueue.main.sync`。
   - NSDocument 有好几条路径是主线程在等它们：恢复版本、复制文档、不开 `autosavesInPlace` 的保存、等待文件访问。
     这时跳回主线程的那一步永远排不上，程序卡死，也不会报错。
   - 读写需要的东西，要么放进快照，要么在 `readSnapshot` 里算好、交给 `apply`。
2. **`snapshot` 要同步，而且要快。**
   - 它在 NSDocument 锁住用户输入期间执行，只做复制，编码留给 `write`。
   - 它不能是 `async` 的：在这段时间里挂起，就会出现 SwiftUI 那样的死锁，见调研报告第 9 节。
3. **不开 `autosavesInPlace`，就是同步写盘。**
   - `autosavesInPlace` 为 `false` 的文档在保存时拿不到 change-count token，保存完成时 NSDocument 会把写盘期间
     的编辑一并标成已保存。
   - 所以对这类文档，基类在 `canAsynchronouslyWrite` 里回答 `false`。`write` 仍在后台执行器上跑，但主线程会
     等它写完，这和普通 NSDocument 一样。
   - 想让用户保存时不用等，就覆写 `autosavesInPlace` 返回 `true`。代价是保存体验跟着变：关窗不再询问是否保存，
     并且有版本浏览。
4. **后台打开时，`init` 不在主线程上执行。**
   - `canConcurrentlyReadDocuments(ofType:)` 默认返回 `true`。`NSDocumentController` 在它的
     "NSDocumentController Opening" 队列上依次调用 `-init` 和读盘，只有 `apply` 回到主线程执行。
   - 所以 `init` 里只能初始化自己的存储属性。界面、只能在主线程上用的对象，放到 `makeWindowControllers()` 或
     懒加载里。
   - **Swift 6 模式下这一条尤其要紧。**
     - NSDocument 的 `init()` 在 Swift 里是主线程隔离的，子类继承了这个隔离后，编译器会在它的 Objective-C
       入口插一个主线程断言，后台打开时就会崩。写出来的 `init` 和编译器合成的 `init` 都一样，已用 SILGen 核实。
     - 基类把 `init()` 声明成了 `nonisolated`，子类的 `init`（写出来的或合成的）都继承 `nonisolated`，不会被插这个断言。
     - 遗留的坑是存储属性的默认值。像 `let accessory = NSView()` 这种需要主线程的默认值，编译器不报错，但会在
       后台线程上执行。
   - `init` 确实离不开主线程时，覆写 `canConcurrentlyReadDocuments(ofType:)` 返回 `false`。这时整个打开过程在
     主线程上进行，读盘期间界面要等。
5. **`Snapshot` 必须是 `Sendable`。**
   - `FileWrapper` 不是 `Sendable`。包格式文档应该把模型复制成值类型（比如成员名到 `Data` 的字典），
     再在 `write` 里生成 `FileWrapper` 写盘。
6. **`apply` 要么全部生效，要么完全不生效。**
   - 它抛错时，恢复会失败，NSDocument 不会把文档标成未修改，也不会清空撤销记录。
   - 如果 `apply` 已经改了一半，文档就停在那一半。所以先把要用的东西全部算好，再动文档。
7. **NSDocument 原有的读写方法被封住了。**
   - 以下 5 个方法标了 `final`，基类从不调用它们：
     - `data(ofType:)`
     - `fileWrapper(ofType:)`
     - `read(from:ofType:)` 的 `Data` 版和 `FileWrapper` 版
     - `write(to:ofType:)`
   - 从普通 NSDocument 子类迁移过来时，编译器会在这几处报错，把逻辑分别挪进上面的四个方法。
   - 三个接法本身也是 `final`：`canAsynchronouslyWrite(to:ofType:for:)`、`write(to:ofType:for:originalContentsURL:)`、
     URL 版 `read(from:ofType:)`。
   - `canConcurrentlyReadDocuments(ofType:)` 有意保持 `open`：读盘在哪个线程上都能工作，而覆写它返回 `false` 正是
     后文「版本浏览器可能卡住」的绕过办法。

## 和 SwiftUI `DocumentGroup` 的差别

macOS 27 SwiftUI 的 `Document` 协议在 API 上也是快照模型。它接到 NSDocument 上的方式（`URLPlatformDocument`）
有三处实测问题，本实现的接法都相反：

| | SwiftUI（macOS 27.2 实测） | `AsyncDocument` |
|---|---|---|
| 写盘出错 | 写了一半再出错时报成功，原文件被半截内容替换 | 保存失败，原文件不变 |
| `apply` 出错 | 打开照样成功 | 打开失败 |
| 取快照的时机 | 放开主线程之后，async 跳回主线程去取；主线程若在等文件访问就死锁 | 放开主线程之前，同步取完 |
| 恢复版本 | `revertToContentsOfURL:` 在 `apply` 之前就返回 | `apply` 完成后才返回 |

## 已知限制

- **版本浏览器可能卡住（静态分析，没有实测）。**
  - 版本浏览器会在后台预加载旧版本。主线程如果在预加载还没完成时同步等同一个版本（`waitUntilFinished`），
    后台读盘回主线程执行 `apply` 的那一步就排不上。
  - 这个等待不处理 `continueAsynchronousWorkOnMainThread(_:)`，所以会卡住。
  - 遇到时可以覆写 `canConcurrentlyReadDocuments(ofType:)` 返回 `false`，版本浏览器就改在调用线程上加载。
    详见调研报告第 4.3 节。
- **被中途放弃的保存会留下一份快照。**
  - NSDocument 偶尔在问过 `canAsynchronouslyWrite` 之后不再写盘，例如保留旧版本失败时。
  - 那份快照会留在内存里，直到下一次保存把它换掉。它不会被写进文件：在主线程上的写盘会丢掉它重新取，在后台的
    写盘之前一定会先有一次新的询问。
- **本模块的构建有一条警告，压不掉。**
  - 位置是 `AsyncDocument.init()` 里的 `super.init()`，内容是 "call to main actor-isolated initializer"。
  - 这是契约 4 的代价。`@preconcurrency` 和 Swift 6.4 的 `@diagnose`（SE-0522）都试过，都压不住它，原因见调研报告第 8 节。
- **相关的 AppKit 陷阱：`performSynchronousFileAccess(_:)` 不能从 Swift 直接调用。**
  - 它在需要等待时会留住传进去的 block，违反头文件里的 `NS_NOESCAPE` 标注。
  - Swift 检查到后会直接 trap："closure argument passed as @noescape to Objective-C has escaped"，macOS 27.2 实测。
  - 需要时改发 Objective-C 消息，`AsyncDocumentTests` 就是这样调用的：

    ```swift
    let block: @convention(block) () -> Void = { /* … */ }
    document.perform(#selector(NSDocument.performSynchronousFileAccess(_:)), with: block)
    ```

## 实现说明

写给维护者。下面几处看起来都能简化，其实都不能。结论都在 macOS 27.2 上实测过，或者是从 macOS 27.0 的 AppKit 二进制里读出来的。

- **快照在 `canAsynchronouslyWrite(to:ofType:for:)` 里取，不在写盘方法里取。**
  - 这是唯一合适的时刻：NSDocument 已经拿到 change-count token，又还没有用 `NSConditionLock` 把主线程挡住。
    挡住之后，主队列上的 block 和 `@MainActor` 任务都不会再执行。
  - SwiftUI 的 `URLPlatformDocument` 改在写盘方法里取快照，主线程恰好在等文件访问时就会死锁（见上文对比表）。
- **`canAsynchronouslyWrite` 只在 `autosavesInPlace` 为 `true` 时回答 `true`，不要改成无条件回答 `true`。**
  原因见契约 3：没有 token，保存完成时写盘期间的编辑会被标成已保存。
- **回主线程只走 `continueAsynchronousWorkOnMainThread(_:)`，绝不用 `DispatchQueue.main` 或 `MainActor`，也不设超时。**
  - NSDocument 在它自己的同步等待里只处理这一条通道。
  - 原型里的 5 秒超时只是测量用的；放进正式代码，主线程一忙，打开文件就会失败。
- **`init()` 上的 `nonisolated` 不能删。** 删掉之后 `AsyncDocumentTests` 就编译不过，它就是这条的守卫（原因见契约 4）。
