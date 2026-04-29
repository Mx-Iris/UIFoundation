# UIEvent / UIGestureRecognizer 在 macOS 上的事件桥接

> 反向工程目标：UIKitCore + UIKitMacHelper + AppKit (macOS 26.4 dyld_shared_cache)
> 对应 IDA database: `UIKitCore+UIKitMacHelper+AppKit.i64`

逆向了 NSEvent 怎么变成 UIEvent / UITouch / UIPress / UIScrollEvent / UIHoverEvent / UITransformEvent，以及 UIGestureRecognizer 在 Mac 上是不是纯 UIKit 实现。本文是 [UIKit-Public-Views-AppKit-Bridging.md](./UIKit-Public-Views-AppKit-Bridging.md) 的姊妹篇 — 那篇看的是 View 层的桥接，这篇看的是 Event/Gesture 层的桥接。

---

## 0. 核心结论（先看这一段）

| 问题 | 答案 |
|------|------|
| Mac 上 UIKit 收到什么样的事件？ | **IOHIDEvent**（不是 NSEvent！）|
| NSEvent 怎么变成 IOHIDEvent？ | UIKitMacHelper 反向合成，把自己伪装成 BackBoardd |
| 谁负责拦截 NSEvent？ | **`UINSInputView`**（NSView 子类，实现完整 NSResponder 事件方法集）|
| 谁负责把 NSEvent 转成 IOHIDEvent？ | **`UINSMouseEventTranslator`** / `UINSGameEventTranslator`（不是 `UINSEventTranslator`，那个基类的方法都是空 stub）|
| IOHIDEvent 注入哪里？ | **`UINSHidManager.sharedHidManager`** 的队列；UIEventFetcher 通过 `pullNextEventFromQueue` 从这里拉 |
| UIEvent 怎么从 IOHIDEvent 合成？ | `UIEventEnvironment.UIKitEventForHIDEvent:` — 跟 iOS 完全相同的类型分发表 |
| UIGestureRecognizer 跟 NSGestureRecognizer 有桥吗？ | **没有**。UIGestureRecognizer 在 Mac 上 100% 纯 UIKit，跟 iOS 一致 |
| 唯一的反向桥（UIView→NSView）是什么？ | `_UINSViewGestureRecognizer` — 给 `_UINSView`（UIView 包装 NSView）把 UIEvent 反向 drain 回 NSEvent 路径 |

整体架构可以一句话概括：**UIKitMacHelper 把 NSEvent 反向合成 IOHIDEvent 注入到 UIKitCore 期待的 HID 输入源里，让 UIKit 在 Mac 上跟在 iOS 上一样地工作**。AppKit 的 NSResponder 路径只在 `UINSInputView` 这一层被拦截，下游的 UIEvent / UIGestureRecognizer 全是 iOS 原生路径。

---

## 1. 总览：UIKitMacHelper 把自己伪装成 BackBoardd

iOS 上 UIKit 的输入路径：

```
HID 设备 → BackBoardd (系统进程) → IOSurface/IPC → app 进程
       → UIEventFetcher._receiveHIDEvent: → UIEventDispatcher
       → UIEventEnvironment.UIKitEventForHIDEvent: → UIWindow.sendEvent:
       → UIView hit test → UIGestureRecognizer
```

Mac 上没有 BackBoardd，只有 AppKit 的 NSEvent 体系。但 UIKit 不想为 mac 写一套全新的事件系统 —— 所以 UIKitMacHelper 在中间插了一段反向转换：

```
NSEvent (AppKit) → UINSInputView (NSResponder)
       → UINSMouseEventTranslator → UINSCopyHIDMouseEvent (NSEvent → IOHIDEvent)
       → UINSHidManager.enqueueHidEvent:forSceneView:
       → ⚡ pingHandler 通知
       → UIEventFetcher._pullHIDEvents → [hidManager pullNextEventFromQueue]
       → UIEventDispatcher → UIEventEnvironment.UIKitEventForHIDEvent:
       → UIWindow.sendEvent: → UIView hit test → UIGestureRecognizer
            (从这里开始跟 iOS 完全一致)
```

UIKitMacHelper 实际上**模拟了 BackBoardd**：UIEventFetcher 不需要修改，只是把"从 BackBoardd 拉事件"改成"从 UINSHidManager 拉事件"。

---

## 2. NSEvent → IOHIDEvent 转换层

### 2.1 入口：`UINSInputView`（NSView 子类）

每个 UIScene 在 mac 上托管在 `UINSWindow`（NSWindow 子类）里，content view 之上挂 `UINSSceneView`（NSView 子类，宿主 USSLayerHost 拿到 IOSurface），但 NSEvent **不直接** 给 UINSSceneView — 而是给 `UINSInputView`（同样是 NSView，专门 override 全部 NSResponder 事件方法）。

`UINSInputView` 关键 ivar 布局（`offset` 来自 dump）：

```objc
@interface UINSInputView : NSView <NSTextInputClient,
                                   NSServicesMenuRequestor,
                                   UINSKeyboardEventHandler> {
    NSTrackingArea            *_mouseTrackingArea;        // 536
    UINSEventTranslator       *_eventTranslator;          // 544 (weak slot,
                                                          //      实际多态指向子类)
    UINSMouseEventTranslator  *_mouseEventTranslator;     // 552
    UINSGameEventTranslator   *_gameEventTranslator;      // 560
    BOOL                       _trackingDragLocally;       // 568
    BOOL                       _gameControllerInputAlternativeActive; // 569
    NSMutableSet              *_currentlyHeldModifierKeyCodes;
    id                         _keyUpEventMonitor;
    id                         _keyFocusEventMonitor;
    NSEvent                   *_resentEvent;
    id                         _resignedKeyObserver;
    BOOL                       _performingKeyEquivalent;
    BOOL                       _waitingForMaybeDidBecomeFirstResponder;
    NSView                    *_fallbackKeyViewIfNotHandledByFocusSystem;
    NSEvent                   *_lastSeenEventInChooseNewKeyViewWithDirection;
}
```

UINSInputView 实现了完整的 NSResponder 事件方法（**全部**都做转发），决斗对象是 `_eventTranslator`：

```objc
- (void)mouseDown:(NSEvent *)event {                                  // 0x19E8C4CD8
    NSTextInputContext *ctx = [self inputContext];
    if ([ctx hasMarkedText] && [ctx handleEvent:event]) {
        [self _consumeMouseEventsUntilMouseUp];
    } else {
        [NSEvent setMouseCoalescingEnabled:NO];
        UINSEventTranslator *t = objc_loadWeakRetained(&_eventTranslator);
        [t mouseDown:event];
    }
}

// mouseDragged:/mouseUp:/scrollWheel:/touchesBeganWithEvent: 等都是简洁的
//   id t = objc_loadWeakRetained(&_eventTranslator);
//   [t <相同 selector>:event];
```

被 override 的全部方法（IDA 符号表确认）：

```
mouseDown / mouseUp / mouseDragged / mouseMoved / mouseEntered / mouseExited
rightMouseDown / rightMouseUp / rightMouseDragged    (但都走 _eventTranslator)
scrollWheel / magnifyWithEvent / rotateWithEvent
touchesBeganWithEvent / touchesMovedWithEvent / touchesEndedWithEvent / touchesCancelledWithEvent
keyDown / keyUp / flagsChanged
tabletPoint
```

### 2.2 `_eventTranslator` 是多态槽位 — 基类是空 stub

最容易被诱导上当的地方：`UINSEventTranslator` 类在 dump 头里看似实现了所有事件方法，但反编译可见这些 IMP **几乎全部是 4 字节空 stub**：

```objc
@interface UINSEventTranslator : NSObject
- (void)mouseDown:(NSEvent *)e;        // 0x19E93C0B0  ← 空函数 (ret)
- (void)mouseUp:(NSEvent *)e;          // 0x19E93C0B8  ← 空函数
- (void)keyDown:(NSEvent *)e;          // 0x19E93C0A0  ← 空函数
- (void)scrollWheel:(NSEvent *)e;      // 0x19E93C0CC  ← 空函数
- (void)touchesBeganWithEvent:(id)e;   // 0x19E93C0FC  ← 空函数
// ... 全部空 stub
@end
```

观察：相邻方法 IMP 地址只差 4 字节（一条 `ret` 指令），是占位符。

实际工作的是 **子类**：

| 子类 | 用途 |
|------|------|
| `UINSMouseEventTranslator` | 鼠标 / 触控板 / 触摸 / 滚轮 / pinch / rotate / 平板触控笔 |
| `UINSGameEventTranslator` | 游戏控制器 keyDown/keyUp 等键盘按键模拟 |

UINSInputView 的 `_eventTranslator` ivar slot 在 setup 时被装填子类实例（最常见的是 UINSMouseEventTranslator），**靠 ObjC 多态 dispatch** 到子类的实际实现 — 这是为什么基类要保留空 stub：避免 `[t methodNotImplemented]` 直接抛 unrecognized selector，子类没 override 时静默吞掉。

### 2.3 `UINSMouseEventTranslator` — 鼠标 / 触控板 / 触摸

完整 ivar：

```objc
@interface UINSMouseEventTranslator : UINSEventTranslator {
    id                  _changeModeMonitor;
    UINSScrollState    *_scrollState;
    struct __IOHIDEvent *_lastPressureEvent;
    unsigned int        _mouseContextId;     // 用于点击事件
    unsigned int        _gestureContextId;   // 用于 pinch/rotate
    unsigned int        _hoverContextId;     // 用于 hover
    unsigned int        _dragContextId;      // 用于 drag and drop
    BOOL                _mouseIsInside;
    BOOL                _needMouseExitOnUp;
    unsigned long long  _lastButtonMask;
    BOOL                _lastClickCount;
    unsigned long long  _lastModifiers;
    CGPoint             _lastSceneLoc;
    BOOL                _dragAndDropDragging;
    unsigned long long  _gesturePhase;
    unsigned long long  _lastSeenTouchSenderID;
}
```

`mouseDown:` 实现（地址 0x19E8CA0E0）：

```objc
- (void)mouseDown:(NSEvent *)event {
    if (!_mouseContextId) {
        // hit-test：鼠标按下时锁定一个 contextId，整个 down/drag/up 序列共用
        CGPoint p = [event locationInWindow];
        _mouseContextId = [self contextIdAtWindowLocation:p];
    }
    [self _handleMouseEvent:event contextId:_mouseContextId];
}
```

`_handleMouseEvent:contextId:`（0x19E89FA7C）摘要：

```c
- (void)_handleMouseEvent:(NSEvent *)e contextId:(unsigned int)cid {
    CGPoint sceneLoc = [self convertWindowLocationToSceneCoordinates:[e locationInWindow]];
    CGEventRef cg = [e CGEvent];
    int subtype = (cg && CGEventGetType(cg) != kCGEventMouseMoved)
                  ? CGEventGetIntegerValueField(cg, ...)
                  : 0;
    UInt8 clickCount = (1ULL << [e type]) & 0xE0000DELL ? [e clickCount] : 0;

    // 关键：如果是 forceTouch 派生（associatedEventsMask 包含 0x400000000）
    //   等待或合并 pressure 事件
    if (subtype & 1 && [e associatedEventsMask] & 0x400000000) {
        IOHIDEventRef pressure = [self _copyCoalescedPressureEventUntilDate:...];
        ...
    }
    // tablet 子事件
    if (![event subtype] == 1) {
        IOHIDEventRef tablet = UINSCreateHIDTabletEvent(time, sceneLoc, ...);
    }

    // ★ 真正的合成：NSEvent → IOHIDEvent
    [self _handleMouseEventAtSceneLocation:sceneLoc
                                      type:[e type]
                                buttonMask:btnMask
                                clickCount:clickCount
                             modifierFlags:[e modifierFlags]
                                childEvent:childEvent
                                 contextId:cid];
}
```

`_handleMouseEventAtSceneLocation:...` （0x19E8CAB6C，**核心**）：

```c
{
    uint64_t now = mach_absolute_time();
    BOOL active = btnMask || _mouseIsInside;

    // ★★★ 合成 IOHIDEvent
    IOHIDEventRef hid = UINSCopyHIDMouseEvent(cid, now, type, btnMask, clickCount,
                                              modifiers, 0, 0, sceneLoc, active);
    _lastButtonMask = btnMask;
    _lastClickCount = clickCount;
    _lastModifiers  = modifiers;
    _lastSceneLoc   = sceneLoc;
    if (childEvent) IOHIDEventAppendEvent(hid, childEvent, 0);

    // ★★★ 入队
    [[UINSHidManager sharedHidManager] enqueueHidEvent:hid forSceneView:[self sceneView]];

    if (!btnMask) _mouseContextId = 0;
    if (hid) CFRelease(hid);
}
```

NSEvent → IOHIDEvent 的合成函数有一组：

| 函数 | 用途 |
|------|------|
| `UINSCopyHIDMouseEvent` | 鼠标 / 触摸 (digitizer event, type 11) |
| `UINSCopyHIDScrollEventCollection` | 滚轮 / 滚动手势 |
| `UINSCreateHIDTabletEvent` | 数位板 / 触控笔（pressure/tilt/rotation） |
| `_UINSHIDCreateForceCGEventFromHIDEvent` | Force Touch 压力事件 |
| `UINSHIDEventAppendLocation` | 给 IOHIDEvent 附加位置/修饰键 |
| `UINSHIDEventAppendContextId` | 附加 contextId（用于 routing） |
| `_UINSHIDGetChildPointerEvent` | 反向：从 IOHIDEvent 取 pointer 子事件 |
| `_UINSHIDGetChildForceEvent`   | 反向：取 force 子事件 |
| `UINSMouseAddendumFromHIDEvent` | 反向：从 HID 拿 button mask 等 mac 特定字段 |

注意还有反向方向的函数 — 因为 `_UINSViewGestureRecognizer.drainEventQueue` 需要把 IOHIDEvent 反着送回 NSEvent 路径（见 §5.4）。

### 2.4 触控板手势 / 滚轮（多分支）

`scrollWheel:` 实现（0x19E8CA690）：

```objc
- (void)scrollWheel:(NSEvent *)e {
    // 关键：通知 NSApp 我们消费了 trackpad gesture event
    if (!([NSApp gestureEventMask] & 0x400000)) {
        [NSApp setGestureEventMask:[NSApp gestureEventMask] | 0x400000];
    }
    [self _handleScrollWheelEvent:e];
}
```

`_handleScrollWheelEvent:` 三分支（0x19E8CACFC）：

```objc
- (void)_handleScrollWheelEvent:(NSEvent *)e {
    if (([_scrollState momentumPhase] & 0x18) == 0 && ![e momentumPhase]) {
        [_scrollState setMomentumPhase:16];
    }
    if ([e momentumPhase]) {
        [self _handleMomentumScrollEvent:e];      // 惯性
    } else if ([e phase]) {
        [self _handleGestureScrollEvent:e];       // 触控板手势 (began/changed/ended)
    } else if ([_scrollState gesturePhase] & 0x18) {
        [self _handleRelativeScrollEvent:e];      // 鼠标滚轮 / 简单滚动
    }
}
```

`_handlePinchEvent:`（0x19E8CC1E0）— 把 pinch 当作 transform event：

```objc
- (void)_handlePinchEvent:(NSEvent *)e {
    if (!_gestureContextId) {
        if ([e phase] != 1) return;  // 只在 begin 时锁定
        _gestureContextId = [self contextIdAtWindowLocation:[e locationInWindow]];
        if (!_gestureContextId) return;
        // 通知 NSApp
        [NSApp setGestureEventMask:[NSApp gestureEventMask] | 0x1000000000ULL];
        _gesturePhase = 1;
    } else {
        _gesturePhase = ([e phase] & 0x18) ? [e phase] : 4;
    }

    // ★ 合并 pinch + rotate + translate 三个 NSEvent 到一个 IOHIDEvent
    IOHIDEventRef magnify = NULL, rotate = NULL, translate = NULL;
    [self _coalescePinchStartingWithEvent:e
                            outputMagnify:&magnify
                                   rotate:&rotate
                                translate:&translate];

    IOHIDEventRef hid = [self _createPinchEventWithPhase:_gesturePhase
                                                 magnify:magnify
                                                  rotate:rotate
                                               translate:translate];
    UINSHIDEventAppendLocation(hid, [e modifierFlags], YES, 0, _mouseIsInside, sceneLoc);
    UINSHIDEventAppendContextId(hid, _gestureContextId);

    [[UINSHidManager sharedHidManager] enqueueHidEvent:hid forSceneView:[self sceneView]];
    CFRelease(hid);

    if (_gesturePhase & 0x18) {
        _gestureContextId = 0;
        _gesturePhase = 0;
    }
}
```

可以看到 mac 上 trackpad 的 pinch + rotate + translate 三个独立 NSEvent 在 `_coalescePinchStartingWithEvent:` 里被合并成一个 IOHIDEvent (transform event, type 17)。

### 2.5 注入到 UINSHidManager

`UINSHidManager` 是个简单的锁保护 NSMutableArray 队列：

```objc
@interface UINSHidManager : NSObject {
    struct os_unfair_lock_s _lock;
}
@property NSMutableArray   *queuedEvents;
@property (copy) id /* block */ pingHandler;
+ (instancetype)sharedHidManager;
- (void)enqueueHidEvent:(IOHIDEventRef)e forSceneView:(UINSSceneView *)v;
@end
```

`enqueueHidEvent:forSceneView:` （0x19E8FA9C8）实现：

```objc
- (void)enqueueHidEvent:(IOHIDEventRef)hid forSceneView:(UINSSceneView *)sv {
    if (sv) [sv setEnqueuedTimestampOfLastEvent:CACurrentMediaTime()];
    os_unfair_lock_lock(&_lock);
    [_queuedEvents addObject:(__bridge id)hid];
    void (^ping)(void) = _pingHandler;
    os_unfair_lock_unlock(&_lock);
    if (ping) ping();   // ⚡ 通知消费者
}
```

`pullNextEventFromQueue`（0x19E89FF04）— 消费者用：

```objc
- (IOHIDEventRef)pullNextEventFromQueue {
    os_unfair_lock_lock(&_lock);
    IOHIDEventRef e = [_queuedEvents firstObject];
    if (e) {
        CFAutorelease(CFRetain(e));
        [_queuedEvents removeObjectAtIndex:0];
    }
    os_unfair_lock_unlock(&_lock);
    return e;
}
```

---

## 3. IOHIDEvent → UIEvent：UIEventFetcher 拉取链路

### 3.1 UIEventFetcher 在 mac 上的拉取入口

`UIEventFetcher._pullHIDEvents` （0x1B8E7DDBC）：

```objc
- (void)_pullHIDEvents {
    UINSWorkspace *ws = [UINSWorkspace sharedInstance];
    UINSHidManager *mgr = [ws hidManager];          // ★ 单例从 workspace 取
    while (IOHIDEventRef e = [mgr pullNextEventFromQueue]) {
        [self _receiveHIDEventInternal:e];
    }
}
```

简洁有力 — UIEventFetcher 在 iOS 上是从 BackBoardd IPC 拉，在 mac 上从 `[UINSWorkspace.sharedInstance hidManager]` 拉。语义完全一致，下游路径完全相同：

```
UIEventFetcher._receiveHIDEventInternal:
   → 经过 _filterChain（passive observation filter 等）
   → eventFetcherSink (UIEventDispatcher)
   → UIEventDispatcher.eventFetcherDidReceiveEvents:
   → UIEventDispatcher._flushAndDispatchPendingEvents
   → mainEnvironment (UIEventEnvironment)
   → UIEventEnvironment.UIKitEventForHIDEvent:   ← 类型分发
   → 各种 UIEvent 子类
   → UIWindow.sendEvent: → UIView hit test → UIGestureRecognizer
```

### 3.2 UIEventEnvironment.UIKitEventForHIDEvent: 类型表

`UIEventEnvironment.UIKitEventForHIDEvent:` （0x1B8EEE018）的核心是按 `IOHIDEventGetType` 做 switch 分发：

| HID Type | 进一步条件 | 输出 UIEvent 子类 | 内部 type 编号 |
|----------|-----------|------------------|---------------|
| 1 (vendor) | `_UINSHIDEventIsLookupEvent` | `UILookupEvent` | (lookup) |
| 6 (scroll wheel) | `_UIEventHIDIsScrollEvent` | `UIScrollEvent` | 10 |
| 6 | else | `UIWheelEvent` | 7 |
| 11 (digitizer) | digitizer 子事件 locus 标志 | `UIDragEvent` | (drag) |
| 11 | else | `UITouchesEvent`（含 UITouch） | 0 |
| 17 (pointer) | `_UIEventHIDIsTransformEvent` | `UITransformEvent`（pinch/rotate） | (transform) |
| 17 | iPad idiom 走 keyboard 路径 | `UIPressesEvent` (键盘) | 3 |
| 17 | else | `UIHoverEvent` | 11 |
| 30 (keyboard) | `_UIEventHIDPressTypeForKeyboardHIDEvent != -1` | `UIPhysicalKeyboardEvent` / `UIPressesEvent` | 3 |
| 29 (force) | integer field 1900544 | `UIPressesEvent` | 3 |
| 35 (game) | — | `UIGameControllerEvent` | (game) |
| 39 (pencil barrel) | `_UIEventHIDIsPencilBarrelEvent` | `_UIPencilEvent` | (pencil) |

每个 `_<X>EventForHIDEvent:` 方法都是同一个模式：

```objc
- (id)_<X>EventForHIDEvent:(IOHIDEventRef)hid {
    UIWindow *w   = _UIEventHIDUIWindowForHIDEvent(hid);
    UIScene  *s   = [w _eventRoutingScene];
    return _UIEventEnvironmentEventOfTypeForEventRoutingUIScene(self, <type>, s);
}
```

也就是说每种 UIEvent 子类在每个 UIScene 里都有一个**唯一缓存的实例**（包含累积状态），`_UIEventEnvironmentEventOfTypeForEventRoutingUIScene` 负责返回／复用。HID 事件来时把数据合并进去，再由 UIWindow 投递。这是 iOS 上同样的设计。

---

## 4. 各 UIEvent 子类的合成与投递

下表是 mac 上每种用户输入对应的完整链路：

| 用户输入 | NSEvent | UINSInputView 方法 | UINSMouseEventTranslator handler | 合成 IOHIDEvent | UIEvent 子类 |
|---------|---------|--------------------|---------------------------------|-----------------|------------|
| 鼠标点击 | `mouseDown:` / `mouseUp:` | mouseDown:/mouseUp: | `_handleMouseEvent:contextId:` | `UINSCopyHIDMouseEvent` (type 11 digitizer) | `UITouchesEvent` |
| 鼠标拖动 | `mouseDragged:` | mouseDragged: | 同上 (type=mouseDragged) | 同上 | `UITouchesEvent` |
| 鼠标移动 | `mouseMoved:` | mouseMoved: | 同上 (type=mouseMoved) | type 17 (pointer) | `UIHoverEvent` |
| 鼠标进出 | `mouseEntered:` / `mouseExited:` | mouseEntered:/mouseExited: | `hostEnterExitEventWithType:sceneLocation:` | type 17 (pointer enter/exit) | `UIHoverEvent` |
| 滚轮 | `scrollWheel:` | scrollWheel: | `_handleScrollWheelEvent:` → `_handleRelativeScrollEvent:` | type 6 (relative scroll) | `UIWheelEvent` |
| 触控板滚动 | `scrollWheel:`（phase 非零）| scrollWheel: | `_handleGestureScrollEvent:` | type 6 (gesture scroll) | `UIScrollEvent` |
| 惯性滚动 | `scrollWheel:`（momentum 非零）| scrollWheel: | `_handleMomentumScrollEvent:` | type 6 (momentum) | `UIScrollEvent` (momentum phase) |
| 触控板捏合 | `magnifyWithEvent:` | magnifyWithEvent: | `_handlePinchEvent:` | type 17 + transform (`_createPinchEventWithPhase:...`) | `UITransformEvent` |
| 触控板旋转 | `rotateWithEvent:` | rotateWithEvent: | 与 pinch 合并 | 同上 | `UITransformEvent` |
| 触控板平移 | `translateWithEvent:` | translateWithEvent: | 与 pinch 合并 | 同上 | `UITransformEvent` |
| 触控板触摸 | `touchesBeganWithEvent:` 等 | 同名转发 | `_handleTouchEvent:cancel:` | type 11 (direct digitizer, `_createDirectDigitizerIOHIDEventFromDirectEvent:`) | `UITouchesEvent` |
| 压力 (Force Touch) | `pressureChangeWithEvent:` | pressureChangeWithEvent: | 合并到下个 mouse event | `_UINSHIDCreateForceCGEventFromHIDEvent` | 跟随 `UITouchesEvent.force` |
| 数位板 | `tabletPoint:` | tabletPoint: | (UINSInputView 直接处理) | `UINSCreateHIDTabletEvent` (附加到 mouse event) | `UITouchesEvent.azimuth/altitude` |
| 物理键盘 | `keyDown:` / `keyUp:` | keyDown:/keyUp: | (走 sendKeyEvent 块或 NSTextInputContext) | type 30 (keyboard) | `UIPhysicalKeyboardEvent` / `UIPressesEvent` |
| 修饰键变化 | `flagsChanged:` | flagsChanged: | UINSGameEventTranslator (游戏键时) 或 fall-through | type 30 (modifier) | `UIPhysicalKeyboardEvent` |
| 拖放 | `draggingEntered:` 等 | 同名 | `forwardDragging<X>:` 一族（不入队 HID）| 直接走 `UIDropInteraction` | (UIDragEvent) |

补充说明：

- **UITouch 源**：mac 上 UITouch 完全由鼠标 + trackpad 合成。一次鼠标点击 = 单 UITouch、phase = began/moved/ended、type = `UITouchTypeIndirectPointer`。trackpad 多指触摸（`touchesBeganWithEvent:`）能合成多个 UITouch，type = `UITouchTypeIndirect`。
- **键盘双轨**：mac 键盘事件有两条平行路径：
  1. **物理 key 路径**：转 IOHIDEvent (type 30) → `UIPhysicalKeyboardEvent` / `UIPressesEvent`，被 `UIKeyCommand` / `UIResponder.pressesBegan:` 接收
  2. **输入法路径**：UINSInputView 直接调 `[self.inputContext handleEvent:]`，由 NSTextInputContext / IME 处理，**不进入 IOHIDEvent 系统**。这是为什么 mac UIKit 文本输入用 IME 时走 Cocoa 的 NSTextInputClient 协议（UINSInputView 实现了它）
- **没有 UIClickGestureRecognizer**：UIKit 没有专门的 click recognizer。mac 鼠标点击 → 合成 UITouch → 走 `UITapGestureRecognizer`。右键单独处理：合成 type=2 secondary 的 NSEvent，走 `UIContextMenuInteraction`（pointer-aware）

### 4.1 `UINSEvent`（不是 UIEvent，是 NSEvent 的 UIKit 包装）

容易跟 UIEvent 搞混的另一个类型。UINSInputView.keyDown: 在某些情况下会创建 `UINSEvent` —— 这只是一个轻量级的 NSEvent 包装，专门为快捷键 / 菜单 / sendKeyEvent block 准备的：

```objc
@interface UINSEvent : NSObject
@property BOOL                isDown;
@property long long           modifierFlags;
@property (readonly) NSString *modifiedInput, *unmodifiedInput, *shiftModifiedInput, *commandModifiedInput;
@property unsigned long long  timestampMachAbs;
@property unsigned short      virtualKeyCode;
@property long long           hidUsageCode;
@property unsigned int        contextId;
@property id                  nsEvent;
@property (readonly) struct __CGEvent *cgEvent;
- (instancetype)initWithNSEvent:(NSEvent *)e contextId:(unsigned int)cid;
+ (int)HIDUsageCodeForCharacter:(unsigned short)c modifiers:(unsigned long long)m;
+ (NSString *)charactersForHIDUsageCode:(unsigned short)usage modifiers:(unsigned int)m;
@end
```

`UINSInputView._sendKeyEvent:isDown:`（0x19E8C4080）使用：

```objc
- (BOOL)_sendKeyEvent:(NSEvent *)e isDown:(BOOL)isDown {
    UINSApplicationDelegate *del = [UINSApplicationDelegate sharedDelegate];
    if (![del sendKeyEvent]) return NO;

    unsigned int cid = [[[[[self.sceneView.sceneViewController.windowProxy
                            keyUIWindow] layer] context] contextId];
    UINSEvent *we = [[UINSEvent alloc] initWithNSEvent:e contextId:cid];
    return [del sendKeyEvent](we);
}
```

UINSEvent 仅用于 mac 特有的快捷键 / 菜单等场景，跟 UIEvent / UITouch 不在同一条管线上。

---

## 5. UIGestureRecognizer 在 Mac 上的实现

### 5.1 100% 纯 UIKit — 没有 NSGestureRecognizer 桥接

最干净的结论：**UIGestureRecognizer 在 Mac 上跟在 iOS 上是同一份代码**。

证据：

1. **`NSGestureRecognizerDelegate-Protocol`** 在 UIKitMacHelper 的 dump 里确实存在（`/UIKitMacHelper/ObjCHeaders/NSGestureRecognizerDelegate-Protocol.h`），但这只是 protocol 定义。我用 IDA 搜索整个 binary，**没有任何类**实现这个 protocol 的方法。Protocol 头里的 IMP 地址 0x19E95BB80~0x19E95BBBC 都是 protocol 元数据中的 selector signature 占位，不是真实代码（地址间隔 12 字节，刚好是 protocol method desc 大小）。

2. **所有 `gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:`** 的实现者签名都接收 **`UIGestureRecognizer *`**（来自 UIKitCore 段 0x1B8/0x1B9/0x1BA）。在 AppKit 段 (0x18*) 出现的同名方法（NSScrubber、NSTouchBarCustomizationPreviewCollectionViewItem 等）是 NSGestureRecognizer 用户，跟 UIKit 路径无关。

3. UIKitMacHelper 里所有事件最终都被合成成 IOHIDEvent 注入 UIKit 内部，**NSGestureRecognizer 完全被绕过**。

### 5.2 Why no bridging?

设计上必然如此：
- 如果用 NSGestureRecognizer 桥到 UIGestureRecognizer，得为每种 UI<X>GestureRecognizer 写一个 NS<X> 桥接 + 状态同步。维护成本天文数字。
- AppKit NSGestureRecognizer 体系跟 UIKit UIGestureRecognizer 体系语义有差异（state 机器、failure 关系、simultaneous 规则）。语义同步会引入大量 corner case。
- 直接复用 iOS 的 UIGestureRecognizer 代码，只需要一个 IOHIDEvent 输入源。这就是 UINSHidManager 干的事。

### 5.3 mac 特有的 GR 子类（UIKitCore 中）

在 UIKitCore 内部找出这几个面向 mac 输入的 GR：

| 类 | 用途 |
|----|------|
| `UIHoverGestureRecognizer` | 公开 API，识别鼠标悬停 |
| `_UIInertHoverGestureRecognizer` | 私有，hover 占位（不识别） |
| `_UIPointerInteractionHoverGestureRecognizer` | UIPointerInteraction 内部，pointer hover |
| `_UIPointerInteractionPressGestureRecognizer` | UIPointerInteraction 内部，pointer 按压（鼠标按下） |
| `_UIPointerInteractionPencilHoverDriver` | Pencil hover |
| `UIPanGestureRecognizer` | 公开，鼠标拖动 / trackpad 平移自动识别 |
| `UIScrollViewPanGestureRecognizer` | UIScrollView 内部，接收 UIScrollEvent (trackpad scroll) |
| `_UIScrollViewMockPinchGestureRecognizer` | UIScrollView 内部，接收 UITransformEvent (trackpad pinch) |
| `_UIScrollViewMockPanGestureRecognizer` | UIScrollView 内部 |
| `UIPinchGestureRecognizer` | 公开，trackpad pinch（接收 UITransformEvent） |
| `UIRotationGestureRecognizer` | 公开，trackpad rotate（接收 UITransformEvent） |

注意：
- 这些 GR 通过 `_UITouchesEventRespondable-Protocol`、`_UIScrollEventRespondable-Protocol`、`_UITransformEventRespondable-Protocol`、`_UIHoverEventRespondable-Protocol` 等内部协议接收对应的 UIEvent 子类。**全部纯 UIKit，没有任何 NS 桥**。
- `UIScrollViewPanGestureRecognizer` 在 mac 上响应的是 `UIScrollEvent`（trackpad gesture scroll），不是 `UITouchesEvent`。这跟 iOS 不同 — iOS 上它响应触摸。
- `_UIScrollViewMockPinchGestureRecognizer` / `_UIScrollViewMockPanGestureRecognizer` 名带 "Mock" 是因为它们不直接响应触摸，而是消费已合成好的高级事件（UITransformEvent、UIScrollEvent）。

### 5.4 唯一的反向桥：`_UINSViewGestureRecognizer`

UIKit 在 mac 上**反向**桥的唯一场景是 UIView 嵌套 NSView（通过 `_UINSView` —— UIView 子类，包装 NSView，跟 iOS 上 UIViewController 的 NSViewHost 概念类似但角色相反）。

`_UINSView` 持有的 `_UINSViewGestureRecognizer`（UIGestureRecognizer 子类）干的事是把 UITouch 反向 drain 回 NSEvent / IOHIDEvent，让嵌入的 NSView 能收到点击：

`-[_UINSViewGestureRecognizer touchesBegan:withEvent:]`（0x1B9694370）：

```objc
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.state == UIGestureRecognizerStatePossible &&
        [event allTouches].count == 1) {
        IOHIDEventRef hid = [event _hidEvent];   // ★ 反向：从 UIEvent 取原始 HID
        if (hid) {
            self.state = UIGestureRecognizerStateBegan;
            if (!_hidEvents) {
                _hidEvents = CFArrayCreateMutable(...);
            }
            CFArrayAppendValue(_hidEvents, hid);   // 累积起来
            return;
        }
    }
    self.state = UIGestureRecognizerStateFailed;
}
```

`drainEventQueue`（0x1B96946F8）— 在 _UINSView 准备处理事件时叫：

```objc
- (NSArray *)drainEventQueue {
    NSAssert(_hidEvents != NULL, @"Missing the touches began");
    UIEventDispatcher *d = [UIApp valueForKeyPath:@"eventDispatcher"];

    // ★ 把 UIEvent 之外悬挂的 IOHIDEvent 主动 flush 出去
    [d _flushAndDispatchPendingEvents];

    NSArray *snapshot = [NSArray arrayWithArray:(__bridge NSArray *)_hidEvents];
    CFRelease(_hidEvents);
    _hidEvents = nil;
    return snapshot;
}
```

整个机制：UIView 接到 UITouch → `_UINSViewGestureRecognizer` 把对应 IOHIDEvent 收集起来 → `_UINSView` 在合适时机叫 `drainEventQueue` 把这些事件 flush，下一步用 `UINSEventTranslator.hostEventsFromHIDEvent:`（**反向函数**，0x19E93BAF4）把 IOHIDEvent 转回 NSEvent，丢给嵌入的 NSView 的 NSResponder 链。

`hostEventsFromHIDEvent:` 是这条反向路径的关键：

```c
- (NSArray<NSEvent *> *)hostEventsFromHIDEvent:(IOHIDEventRef)hid {
    NSAssert(IOHIDEventGetType(hid) == 17,   // pointer event
             @"Can only reverse translate pointer events for now");
    NSWindow *win = [self.sceneView window];
    CGFloat x = IOHIDEventGetDoubleValue(hid, 1114112);
    CGFloat y = IOHIDEventGetDoubleValue(hid, 1114113);
    CGPoint loc = [self convertSceneLocationToWindowCoordinates:CGPointMake(x, y)];

    UINSMouseAddendum *adden = UINSMouseAddendumFromHIDEvent(hid);
    NSUInteger btnMask = adden ? (adden->buttonState << 16) : 0;
    NSUInteger clickCount = adden ? adden->clickCount : 1;
    NSEventType evType = adden ? adden->eventType : 0;

    NSMutableArray *result = nil;
    if (evType != 34) {  // 排除某些类型
        NSEvent *e = [NSEvent mouseEventWithType:evType
                                        location:loc
                                   modifierFlags:btnMask
                                       timestamp:[NSProcessInfo.processInfo systemUptime]
                                    windowNumber:[win windowNumber]
                                         context:nil
                                     eventNumber:0
                                      clickCount:clickCount
                                        pressure:1.0];
        result = [NSArray arrayWithObject:e];
    }

    // Force Touch
    if (_UINSHIDGetChildForceEvent(hid)) {
        CGEventRef cg = _UINSHIDCreateForceCGEventFromHIDEvent();
        CGEventSetWindowLocation(cg, loc);
        CGEventSetIntegerValueField(cg, ..., [win windowNumber]);
        NSEvent *force = [[NSEvent alloc] _initWithCGEvent:cg eventRef:NULL];
        result = result ? [result arrayByAddingObject:force]
                        : [NSArray arrayWithObject:force];
        CFRelease(cg);
    }
    return result ?: [NSArray new];
}
```

注意：**这条反向路径只支持 pointer events（IOHIDEventType=17）**，不支持触摸或键盘。原因是 mac 上 UIView 嵌入 NSView 主要场景是 SwiftUI / UIView 里嵌入 AppKit 控件（NSStepper、NSColorWell 等），用鼠标交互足够。

### 5.5 UIScreenEdgePanGestureRecognizer 在 Mac 上

`_UIScreenEdgePanRecognizer`（注意是 _UI 不是 UI）在 UIKitCore 段（0x1b8ecf*~0x1b9c0*），是 UIKit 内部用的实现。它的入参是 UITouch sample、scene-relative 坐标、屏幕方向 — **完全使用 UIKit 输入抽象**，不直接接触 NSEvent。在 mac 上同样工作（虽然 mac 上的"屏幕边缘"在窗口模式下意义有限，主要在全屏场景生效）。

```
incorporateTouchSampleAtLocation:timestamp:modifier:region:interfaceOrientation:forceState:
```

签名里全都是 UIKit 概念（UIInterfaceOrientation 等），没有任何 NS 类型。

---

## 6. 设计观察与意义

### 6.1 单向 NSEvent → IOHIDEvent，正向 99%

输入事件从 NSEvent 变 IOHIDEvent 后，**几乎不会反向**。AppKit 路径只在两个特殊场景被复用：

1. **键盘输入法**（`NSTextInputContext.handleEvent:`）：UINSInputView 直接走 IME 路径，文本编辑用的是 NSTextInputClient 协议，不进入 UIKit 的物理键盘路径
2. **UIView 嵌入 NSView**（`_UINSView` + `_UINSViewGestureRecognizer`）：UIEvent 被反向 drain 回 NSEvent

除此之外，所有事件都是单向的：**NSEvent → 死掉，IOHIDEvent → UIEvent → UIView**。

### 6.2 UINSHidManager 是解耦层

为什么不让 UINSMouseEventTranslator 直接调用 UIEventDispatcher？

- **线程安全**：UIEventFetcher 跑在自己的 thread（专门的 RunLoop），UINSMouseEventTranslator 在主线程被 NSEvent dispatch。锁保护的队列让两个线程安全交换数据
- **批处理**：UIEventDispatcher 用 display link 批量 dispatch（每帧一次），跟 NSEvent 的来源频率解耦
- **可替换**：UINSWorkspace.hidManager 是属性，理论上可以为某些特殊场景注入不同的 manager（比如 sandbox 限制场景）

### 6.3 contextId 路由

每个 UIScene 在 mac 上有自己的 `contextId`（一个 unsigned int，是 USSLayerHost / RenderContext 的 ID）。事件入队前会通过 `contextIdAtWindowLocation:` 做 hit test，把 contextId 嵌入 IOHIDEvent。UIKit 的 UIEventEnvironment 用这个 contextId 找到对应的 UIScene → UIWindow → 投递。

这是 mac 上**多 scene** 的核心：一个 NSWindow 可以包含多个 UIScene（虽然实际很少），每个 UIScene 有独立的 contextId 和事件路由。

### 6.4 性能成本

NSEvent → IOHIDEvent 反向合成有不小的开销：
- 每个 mouseMove 都要做 `mach_absolute_time`、`UINSCopyHIDMouseEvent`、入队 + 拉队、HID type 分发、UIEventEnvironment 缓存查找
- pinch 还要合并三条 NSEvent（magnify/rotate/translate），合成一个 transform IOHIDEvent
- Force Touch 需要等待 / 合并 pressureChange NSEvent

但总体仍在每帧几十微秒内可控范围。trade-off 是工程复杂度（特别是 force / momentum / coalescing）换 UIKit 代码复用率（UIKit Catalyst 几乎不用为 mac 写 GR / event 代码）。

---

## 7. 完整链路图

```
                ┌─ AppKit / NSWindow event routing
                │
NSEvent ────────┴──> UINSInputView.mouseDown:/scrollWheel:/...
                       (NSResponder override，全部转发)
                       │
                       └─ self->_eventTranslator (weak, 多态槽位)
                                  │
                              ┌───┴───────┐
                              ▼           ▼
                    UINSMouseEventTranslator   UINSGameEventTranslator
                              │
                  ┌───────────┼──────────────┬─────────────┬──────────┐
                  ▼           ▼              ▼             ▼          ▼
        _handleMouseEvent  _handleScroll  _handleTouch  _handlePinch  _handleSqueeze
                  │           │              │             │          │
                  ▼           ▼              ▼             ▼          ▼
      UINSCopyHID    UINSCopyHIDScroll   _createDirect  _createPinch  ...
      MouseEvent     EventCollection     DigitizerEvent  EventWith
                  │           │              │             │          │
                  └───────────┴──────────────┴─────────────┴──────────┘
                                       │
                                       ▼
                  [UINSHidManager.sharedHidManager enqueueHidEvent:]
                          (锁保护 NSMutableArray + pingHandler block)
                                       │
                                       ⚡ ping
                                       │
                  UIEventFetcher 自己 thread 的 RunLoop
                                       │
                                       ▼
                   _pullHIDEvents → [hidManager pullNextEventFromQueue]
                                       │
                                       ▼
                   _receiveHIDEventInternal: → filter chain
                                       │
                                       ▼
              UIEventDispatcher.eventFetcherDidReceiveEvents:
                                       │
                                       ▼
                  _flushAndDispatchPendingEvents
                                       │
                                       ▼
              UIEventEnvironment.UIKitEventForHIDEvent:   ← 类型分发
                                       │
       ┌──────────────┬──────────────┬─┴──────────────┬───────────────┐
       ▼              ▼              ▼                ▼               ▼
  UITouchesEvent  UIWheelEvent  UIScrollEvent    UITransformEvent  UIPressesEvent
   (UITouch)                   (gesture phase)  (pinch/rotate)   UIPhysicalKB
       │              │              │                │               │
       └──────────────┴──────────────┴────────────────┴───────────────┘
                                       │
                                       ▼
                          UIWindow.sendEvent:
                                       │
                                       ▼
                  hit test → UIView → UIGestureRecognizer
                            (100% 跟 iOS 一致，没有 NS 桥)
```

反向桥（极少用）：

```
UITouch → _UINSViewGestureRecognizer.touchesBegan:withEvent:
                  │ 收集 [event _hidEvent]
                  ▼
          drainEventQueue (主动 flush)
                  │
                  ▼
   UINSEventTranslator.hostEventsFromHIDEvent: → NSEvent[]
                  │
                  ▼
       嵌入的 NSView 收 NSResponder 调用
```

---

## 8. 关键地址速查表（macOS 26.4，dyld_shared_cache）

### UIKitMacHelper 段（0x19e8*~0x19e9*）

| 地址 | 符号 | 说明 |
|------|------|------|
| 0x19E89BAAC | `-[UINSInputView setSceneView:]` | UINSInputView 关联 sceneView |
| 0x19E8C4CD8 | `-[UINSInputView mouseDown:]` | NSEvent → translator 入口 |
| 0x19E8C4D94 | `-[UINSInputView mouseDragged:]` | 同上 |
| 0x19E8C50F4 | `-[UINSInputView scrollWheel:]` | 同上 |
| 0x19E8C578C | `-[UINSInputView touchesBeganWithEvent:]` | 同上 |
| 0x19E8C48D4 | `-[UINSInputView keyDown:]` | 键盘入口（双轨） |
| 0x19E8C4080 | `-[UINSInputView _sendKeyEvent:isDown:]` | 物理键盘 → UINSEvent |
| 0x19E8CA0E0 | `-[UINSMouseEventTranslator mouseDown:]` | 鼠标点击主流程 |
| 0x19E89FA7C | `-[UINSMouseEventTranslator _handleMouseEvent:contextId:]` | 提取 NSEvent 字段 |
| 0x19E8CAB6C | `-[UINSMouseEventTranslator _handleMouseEventAtSceneLocation:type:...]` | **合成 IOHIDEvent + 入队** |
| 0x19E89FDE8 | `_UINSCopyHIDMouseEvent` | NSEvent → IOHIDEvent 函数 |
| 0x19E8CACFC | `-[UINSMouseEventTranslator _handleScrollWheelEvent:]` | 滚轮三分支 |
| 0x19E8CB6FC | `-[UINSMouseEventTranslator _handleRelativeScrollEvent:]` | 鼠标滚轮 |
| 0x19E8CB238 | `-[UINSMouseEventTranslator _handleGestureScrollEvent:]` | trackpad gesture |
| 0x19E8CADC8 | `-[UINSMouseEventTranslator _handleMomentumScrollEvent:]` | 惯性 |
| 0x19E8CC1E0 | `-[UINSMouseEventTranslator _handlePinchEvent:]` | trackpad pinch |
| 0x19E8CBDD8 | `-[UINSMouseEventTranslator _coalescePinchStartingWithEvent:...]` | 合并 magnify/rotate/translate |
| 0x19E8CC0A0 | `-[UINSMouseEventTranslator _createPinchEventWithPhase:...]` | 合成 transform IOHIDEvent |
| 0x19E8CC778 | `-[UINSMouseEventTranslator _handleTouchEvent:cancel:]` | 触控板触摸 |
| 0x19E8CC9E0 | `_createDirectDigitizerIOHIDEventFromDirectEvent:` | direct touch → IOHIDEvent |
| 0x19E947C48 | `_UINSMouseAddendumFromHIDEvent` | 反向：从 HID 取 button mask |
| 0x19E9476FC | `_UINSHIDEventAppendLocation` | HID 附加位置 |
| 0x19E94765C | `_UINSHIDEventAppendContextId` | HID 附加 contextId |
| 0x19E89FF04 | `-[UINSHidManager pullNextEventFromQueue]` | 消费者用 |
| 0x19E8FA9C8 | `-[UINSHidManager enqueueHidEvent:forSceneView:]` | 生产者用 |
| 0x19E896280 | `+[UINSHidManager sharedHidManager]` | 单例 |
| 0x19E93BAF4 | `-[UINSEventTranslator hostEventsFromHIDEvent:]` | **反向** IOHIDEvent → NSEvent |
| 0x19E93BE98 | `-[UINSEventTranslator hostEnterExitEventWithType:sceneLocation:]` | mouse enter/exit |
| 0x19E93B600 / 0x19E93B680 / 0x19E93B700 | `convertWindowLocationToSceneCoordinates:` 一族 | 坐标变换 |

### UIKitCore 段（0x1b8*~0x1ba*）

| 地址 | 符号 | 说明 |
|------|------|------|
| 0x1B8E7DDBC | `-[UIEventFetcher _pullHIDEvents]` | **从 UINSHidManager 拉事件** |
| 0x1B8E7DE4C | `-[UIEventFetcher _receiveHIDEventInternal:]` | filter chain 入口 |
| 0x1B8E18590 | `-[UIEventDispatcher eventFetcherDidReceiveEvents:]` | dispatcher 接收 |
| 0x1B9F87AF8 | `-[UIEventDispatcher _flushAndDispatchPendingEvents]` | 批量分发 |
| 0x1B8EEE018 | `-[UIEventEnvironment UIKitEventForHIDEvent:]` | **类型分发表** |
| 0x1B9F8677C | `-[UIEventEnvironment _touchesEventForHIDEvent:]` | type 11 → UITouchesEvent |
| 0x1B9F86808 | `-[UIEventEnvironment _pressesEventForHIDEvent:]` | type 30 → UIPressesEvent |
| 0x1B9F86958 | `-[UIEventEnvironment _wheelEventForHIDEvent:]` | type 6 → UIWheelEvent |
| 0x1B9F86F48 | `-[UIEventEnvironment _scrollEventForHIDEvent:]` | type 6 → UIScrollEvent |
| 0x1B9F86E5C | `-[UIEventEnvironment _hoverEventForHIDEvent:]` | type 17 → UIHoverEvent |
| 0x1B9F87034 | `-[UIEventEnvironment _transformEventForHIDEvent:]` | type 17 → UITransformEvent |
| 0x1B9F86B50 | `-[UIEventEnvironment _physicalKeyboardEventForHIDEvent:]` | UIPhysicalKeyboardEvent |
| 0x1B9F86A64 | `-[UIEventEnvironment _gameControllerEventForHIDEvent:]` | UIGameControllerEvent |
| 0x1B9F86D70 | `-[UIEventEnvironment _pencilEventForHIDEvent:]` | _UIPencilEvent |
| 0x1B9F857D8 | `-[UIEventEnvironment _dragEventForHIDEvent:]` | UIDragEvent |
| 0x1B9694370 | `-[_UINSViewGestureRecognizer touchesBegan:withEvent:]` | **反向桥** |
| 0x1B96946F8 | `-[_UINSViewGestureRecognizer drainEventQueue]` | UIEvent → NSEvent flush |

---

## 9. 总结

| 维度 | 结论 |
|------|------|
| AppKit 拦截层 | 仅 `UINSInputView`（NSView 子类）+ `UINSEventTranslator` 子类（mouse/game） |
| 中间数据格式 | **IOHIDEvent**（不是 NSEvent，也不是 UIEvent） |
| 中间存储 | `UINSHidManager.queuedEvents`（锁保护 NSMutableArray） |
| iOS 路径复用率 | 进入 UIEventFetcher 之后 100% 复用 iOS 代码 |
| UIGestureRecognizer 工作原理 | 跟 iOS 完全一致，没有 NSGestureRecognizer 桥 |
| 唯一反向桥 | `_UINSViewGestureRecognizer` → `UINSEventTranslator.hostEventsFromHIDEvent:`（仅支持 pointer event） |
| 输入法路径 | 独立走 NSTextInputContext，不入 IOHIDEvent 系统 |
| 性能 | 每事件多一次 NSEvent → IOHIDEvent 合成 + 队列 + 批量分发，可控 |

跟前两篇研究 ([UIButton-NSButton-Bridge.md](./UIButton-NSButton-Bridge.md)、[UINavigationController-NSToolbar-Bridge.md](./UINavigationController-NSToolbar-Bridge.md)、[UIKit-Public-Views-AppKit-Bridging.md](./UIKit-Public-Views-AppKit-Bridging.md)) 对照看：

- **View 层**（UIButton 等）：A 级用 NSControl 嵌入、B 级 CoreUI 自绘、C 级 NSWindow overlay
- **导航容器层**（UINavigationController）：100% 纯 UIKit
- **NavigationBar 层**：双轨（UIKit + NSToolbar mirror）
- **Event/Gesture 层**（本篇）：单向（NSEvent → IOHIDEvent → UIEvent），UIGestureRecognizer 100% 纯 UIKit

四层加起来构成 mac 上 UIKit 的完整图景。设计哲学一致：**像素与外观靠 NSView，UIKit 行为靠原生 UIKit**。
