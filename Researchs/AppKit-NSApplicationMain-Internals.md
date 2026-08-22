# AppKit `NSApplicationMain` 与 `-[NSApplication run]` 启动路径分析

> 调研对象：AppKit 的 `NSApplicationMain` 与 `-[NSApplication run]`（IDA 反编译，macOS 26 时期的 AppKit）
> 调研动机：Evolution 0009 把示例 App 改成纯代码启动（删除仅装主菜单的 storyboard）后，
> `@main` 挂在 `NSApplicationDelegate` 上界面起不来；需要确证手写入口相对 `NSApplicationMain`
> 到底丢了什么、哪些不用补。
> 结论摘要：**功能性差异只有 delegate / UI 装载与 `NSPrincipalClass` 支持**，其余（池、
> update cycle 初始化、系统集成）`run()` 自己都会做。手写入口只需强持有 delegate、
> 用 `autoreleasepool` 盖住 `run()` 之前的准备段。
> 状态：调研完成，结论已落地（示例 App `App.main()` + `Documentations/MainMenu.md` 入口契约）。

---

## 1. `NSApplicationMain` 的三条路径

反编译骨架（省略错误分支）：

```c
int NSApplicationMain(int argc, const char **argv) {
    pool = NSPushAutoreleasePool(0);
    resolveUpdateCycleEnabledOnce(0);
    CGInitializeImageIO(0);

    info = qword_1EA5D5FF8 ?: [[NSBundle mainBundle] infoDictionary];   // ← 静态覆盖槽
    principalClassName = info[@"NSPrincipalClass"];    // 缺省回落 NSApplication（见 §1.1）
    mainNibName        = info[@"NSMainNibFile"];
    mainStoryboardName = info[@"NSMainStoryboardFile"];
    delegateClassName  = info[@"NSDelegateClass"];     // ← 只在 storyboard 分支被消费（见 §2）

    [NSClassFromString(principalClassName) sharedApplication];
    byte_1EA5D5E96 = 1;                                // 「走过 NSApplicationMain」内部标志

    if ([NSApp _shouldLoadMainStoryboardNamed:mainStoryboardName]
        && (storyboard = [NSStoryboard mainStoryboard])) {
        // —— storyboard 分支，见 §2
    } else {
        if ([NSApp _shouldLoadMainNibNamed:mainNibName])
            [NSBundle loadNibNamed:mainNibName owner:NSApp];   // File's Owner = NSApp
        NSPopAutoreleasePool(pool);
        [NSApp run];
        exit(0);
    }
}
```

三条路径：storyboard、nib（owner 是 `NSApp`，xib 里的 delegate outlet 连接由此生效）、
两者皆无时**直接 `run()`**。最后一条说明：没有 storyboard / nib 时，`NSApplicationMain`
本身就退化成 `sharedApplication` + `run()` —— 与手写入口同构。

### 1.1 `NSPrincipalClass` 与静态覆盖槽

- `NSPrincipalClass` 缺失时，链接于新 SDK 的可执行文件（`_CFExecutableLinkedOnOrAfter(16)`）
  回落到 `NSApplication`，否则直接报错退出。手写 `NSApplication.shared` 等于硬编码主类；
  用自定义 `NSApplication` 子类时要自己写 `MyApplication.shared`。
- `qword_1EA5D5FF8` 是一个可以整体替换 infoDictionary 的静态槽。**推测**（未验证）：这是
  Swift `@main`（`NSApplicationDelegate` 协议扩展的 `main()`）注入 `NSDelegateClass` 的
  通道 —— 它解释了 `@main` 挂 delegate 在有 storyboard 时为何能拿到 delegate 实例。

## 2. 关键发现：`NSDelegateClass` 只在 storyboard 分支被消费

storyboard 分支全文：

```c
delegate = objc_alloc_init(NSClassFromString(delegateClassName));   // 从不 release ⇒ 强持有
if (delegate)
    [[principalClass sharedApplication] setDelegate:delegate];
[storyboard _instantiateMainMenu:[principalClass sharedApplication]];
if ([storyboard _hasInitialController]) {
    controller = [storyboard instantiateInitialController];
    // NSWindowController → showWindow:
    // NSViewController   → +[NSWindowController windowControllerWithContentViewController:] → showWindow:
    // 其它               → NSInternalInconsistencyException
    if ([delegate respondsToSelector:@selector(setWindowController:)])
        [delegate setWindowController:controller];
}
[NSApp run]; exit(0);
```

三个要点：

1. **delegate 的实例化代码只存在于这个分支。** nib 分支靠 xib 连接，裸 `run()` 分支什么都
   不做。所以删掉 storyboard 后 `@main` 挂在 `NSApplicationDelegate` 上时，delegate 永远
   不会被创建 —— 进程在跑、`applicationDidFinishLaunching` 不触发、窗口不出现。这就是
   Evolution 0009 落地时实测到的现象的精确位置。
2. **`NSApplication.delegate` 是 weak / assign**；`NSApplicationMain` 靠对 `alloc_init` 出的
   实例从不 release 来保活。手写入口必须自己强持有（示例 App 用 `static let shared`）。
3. `_instantiateMainMenu:` 负责主菜单实例化与 systemMenu 接线 —— 即 `MainMenu.ItemIdentifier`
   在代码侧补掉的那部分；initial controller 的展示与 `setWindowController:` 交接也在这里。

## 3. `-[NSApplication run]` 自己兜住的事

反编译显示 `run()` 在事件循环前做了一整段初始化，**与启动路径无关**：

```c
- (void)run {
    pool = NSPushAutoreleasePool(0);
    if (!run_updateCycleInitializeCalled) { run_updateCycleInitializeCalled = 1; NSUpdateCycleInitialize(); }
    _NSApplicationBeginRunning(self);
    _HIEnableSuddenTerminationIfRequestedByPlist();
    [_NSTrackingAreaManager appKitWillManageEventLoop];
    [self _checkForAutomaticTerminationSupportPossiblyEnablingIt];
    [NSUndoManager _setEndsTopLevelGroupingsAfterRunLoopIterations:0];
    NSPopAutoreleasePool(pool);
    [self _installMemoryStatusDispatchSources];
    [self _installMemoryPressureDispatchSources];
    _CFUserNotificationSetWarningThread(pthread_self());
    // _running 断言（_NSApplicationBeginRunning 置 1，stop: 置 0）
    [self setWindowsNeedUpdate:YES];
    while (self->_running) {
        pool = [NSAutoreleasePool new];
        [self nextEventMatchingMask:-1 untilDate:distantFuture inMode:[self _outerRunLoopMode] dequeue:YES];
        [self _handleEvent:self->_currentEvent];
        [pool drain];
    }
}
```

- **池**：入口 push 一个盖住这段准备、进循环前 pop；此后**每轮事件一个新池**、处理完 drain。
  事件期内存行为与启动方式无关。
- **update cycle 初始化**：`run_updateCycleInitializeCalled` 一次性守卫兜住了
  `NSApplicationMain` 里 `resolveUpdateCycleEnabledOnce` 的那次预热。
- **系统集成**全部在此：sudden termination（按 plist）、tracking area 管理、automatic
  termination 检查、memory status / pressure dispatch source、CFUserNotification 警告线程。
- `run()` 在 `_running` 归零（`stop:`）时返回；`NSApplicationMain` 随即 `exit(0)`，
  手写 `main()` 正常返回效果等价（`terminate:` 反正自己 exit）。

## 4. 差异清单与结论

| 差异 | 性质 | 手写入口的处置 |
|------|------|----------------|
| delegate 实例化与强持有 | **功能性** | 自己创建并强持有（`static let shared`），`run()` 前赋给 `delegate` |
| 主菜单 / 初始窗口装载 | **功能性** | `MainMenu.standard()` + 自己的 window controller |
| `NSPrincipalClass` 支持 | 功能性（仅自定义子类需要） | 需要时显式 `MyApplication.shared` |
| `run()` 前的 autorelease pool | 内存卫生 | `autoreleasepool` 盖住准备段（`run()` 的池从进入 `run()` 才开始，盖不到之前；Swift 手写 `main()` 里那段没有任何池，runtime 对无池 autorelease 只是容忍、永不排水） |
| `CGInitializeImageIO` 预热、启动 signpost（`kdebug_trace`） | 非功能 | 不复刻；只影响 Instruments 启动分析点 |
| `byte_1EA5D5E96` 内部标志 | 未知 | 读者未查（见 §5），未见影响 |

**结论**：手写入口 + 上述处置后，两条启动路径等价。示例 App 的 `App.main()` 即参考实现：

```swift
@main
enum App {
    static func main() {
        let app = autoreleasepool {
            let app = NSApplication.shared
            app.delegate = AppDelegate.shared
            app.setActivationPolicy(.regular)
            app.mainMenu = MainMenu.standard()
            return app
        }
        app.run()
    }
}
```

## 5. 未尽事项

- `byte_1EA5D5E96`（「走过 `NSApplicationMain`」标志）的读者未做交叉引用排查。
- `qword_1EA5D5FF8` 覆盖槽的写入方（Swift `@main` overlay 注入 `NSDelegateClass` 的推测）
  未验证。
- 两者都不影响本次结论；若将来发现某 AppKit 行为只在 `NSApplicationMain` 启动下出现，
  先查这个标志。
