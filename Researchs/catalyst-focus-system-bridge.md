# Mac Catalyst Focus System Bridge

> 反向工程目标:UIKitCore + UIKitMacHelper + AppKit (macOS 26.4 dyld_shared_cache)
> 对应 IDA database:`UIKitCore+UIKitMacHelper+AppKit.i64`(session `focus_merged`)
>
> 解决问题:Catalyst 模式下 UIKit `UIFocusSystem` / `UIFocusEnvironment` 体系怎么和 macOS AppKit 的 `NSResponder.firstResponder` / `NSWindow.makeFirstResponder:` 桥接。

---

## 修订记录

### 2026-05-18 — 补充原生 AppKit Focus 内部结构的二轮反编译

针对 §0 第 9 行 / §3.1 第 6 条所说"`NSFocusController` 自己实例化 `UIFocusSystem + NSAppKitFocusBehavior`",原文是对的但**漏了三个关键事实**,在下方 §3.1 第 11–15 条 / §4.3 末尾补全,提要:

1. **`UIFocusSystem` 类不在 UIKitCore 里**,真正实现位置是 **`/System/Library/PrivateFrameworks/FocusEngine.framework`**(macOS 11+ 独立 PrivateFramework)。AppKit 通过 `dyld_shared_cache_arm64e.02.dylddata:__got` 段的 `_OBJC_CLASS_$_UIFocusSystem_ptr` 间接引用,运行时已注册,**不需要 dlopen UIKit**。`UIFocusUpdateContext` / `UIFocusEnvironment` / `UIFocusItem` / `UIFocusItemContainer` / `_UIFocusSystemDelegate` 同样在 FocusEngine 里。
2. **`-[NSWindow _focusController]` 是 lazy init**(`-[NSWindow(NSFocusEngine_Internal) computed_focusController]` @ `0x1859cb0fc`),gate 条件 `_isDeallocating == NO && _wantsFocusSystem == YES`。**普通 NSWindow 默认 `_wantsFocusSystem == NO`**,需要主动 opt-in 才会构造 `NSFocusController` + `UIFocusSystem`。
3. **`-[NSView _focusProxy]` 是 associated-object 缓存的 lazy 构造**(`-[NSView(NSFocusEngine_Private) _focusProxy]` @ `0x1854df6b0`),且子类可以 override **类方法** `+_focusProxyClass` 提供自定义 `NSViewFocusProxy` 子类。**NSView 树天然是 UIFocusEnvironment 树**(`parentFocusEnvironment` 返回 `view.superview._focusProxy ?? view.window._focusProxy`)。
4. spike 程序(`/tmp/appkitplus_focus_spike/spike.m`)实测在 macOS 26.4 原生 AppKit 进程(无 UIKit 链接)里:`NSClassFromString("UIFocusSystem")` ✅、`NSClassFromString("NSFocusController")` ✅、`[[UIFocusSystem alloc] initWithFocusBehavior:[NSAppKitFocusBehavior new]]` ✅ 全部成功;**未发现任何 `iOSSupport` / `UIKit` 镜像被加载**,只发现 `FocusEngine.framework` 在 `_dyld_image_count()` 列表中。

含义:这条 AppKit 内部桥接可以**在原生 AppKit 项目里直接复用**(SPI 风险等同 `_NSDiffableDataSourceDiffer` 之类),不必等到 Catalyst 也不需要 link UIKit。详见 AppKitPlus 路径 C 设计文档。

---

## 0. 核心结论(先看这一段)

| 问题 | 答案 |
|------|------|
| Catalyst 下 UIKit 是否提供 macOS 专属的 `_UIFocusSystem` 子类? | **没有**,只用同一个 `UIFocusSystem`,但绑定到 `_UIFocusBehavior_Mac` 这个 behavior 上 |
| Catalyst 模式下 UIKit Focus 引擎接管 Tab 吗? | **不接管**。`-[_UIFocusBehavior_Mac supportsTabKey]` / `supportsArrowKeys` 都返回 NO,`controlCanBecomeFocused:` 只对 `UITextField` / Full Keyboard Access 返回 YES |
| Tab 键最终走 AppKit 还是 UIKit? | **走 AppKit `nextValidKeyView` 循环**。`UINSInputView` 拦截 `selectNextKeyView:`,先问 UIKit `performActionWithCompletionHandler`,UIKit 不要时回落到 `-[NSView _chooseNewKeyViewWithDirection:]`,直接 `NSWindow makeFirstResponder:` 切到下一个 keyView |
| AppKit firstResponder 变化怎么传到 UIKit? | `-[NSWindow _realMakeFirstResponder:]` 末尾硬编码 `objc_msgSend([self _focusController], "firstResponderDidChange")`,通过 `NSFocusController._primitiveFirstResponderDidChange` 读 `firstResponder._focusProxy` 再调 `[focusSystem _updateFocusImmediatelyToEnvironment:]` |
| UIKit firstResponder 变化怎么反向通知 AppKit? | UIKitCore post `_UIWindowFirstResponderDidChangeNotification`,Catalyst 端 `UINSWindowProxyFocusHelper.uiWindowFirstResponderDidChange:` 监听并 perform `_updateIfUIKitFirstResponderChanged`(0.01s 延迟去抖)→ 比对两侧 firstResponder,必要时调 `NSWindow makeFirstResponder:` 同步 |
| `UINSInputView` 是谁? | **核心桥接 NSView**。每个 Catalyst scene 拥有一个,作为该 `UINSWindow` 的实际 firstResponder,实现完整 `NSResponder` API、`NSTextInputClient`、keyView 循环、聚焦环规则 |
| `_UINSView` 是谁?(注意带下划线) | UIKit 侧的 `UIView` 子类,通过 `NSViewHost` 反向嵌入 AppKit `NSView`(Catalyst 中"UIKit window 嵌 AppKit 控件"场景),它的 `becomeFirstResponder` 把请求转发给 `[NSViewHost makeFirstResponder:]` |
| 谁是 macOS 侧的 focus ring layer? | `UINSFocusRingShapeLayer` / `UINSFocusDoubleRingShapeLayer`(UIKitCore 里的 NS 风格双线 ring),被 `+[UIFocusRingManager shapeLayerClassForItem:client:]` 经 `off_1E6D6FD90` / `off_1E6D6FD88` 间接索引 |
| AppKit 内部有没有"自己的" UIFocusSystem 实例? | **有,且独立**。`NSFocusController` 在自己 `initWithRootFocusEnvironment:` 中 `objc_alloc(UIFocusSystem)` + `NSAppKitFocusBehavior`,跑 `NSWindowFocusProxy` / `NSViewFocusProxy` 作为 UIFocusEnvironment 适配器。这是纯 AppKit 侧的复用,不直接参与 Catalyst |

整体可以用一句话概括:**Catalyst 下 UIKit 提供 UIFocusSystem,但 `_UIFocusBehavior_Mac` 把它降级成"只接管 UITextField + FKA"的窄路径;Tab/方向键的真正 keyView 循环和 firstResponder 切换由 `UINSInputView` ↔ `NSWindow` 在 AppKit 路径上完成,两侧靠 `UINSWindowProxyFocusHelper` 做双向去抖同步。**

---

## 1. 核心类与职责对照表

| 类 | 所在模块 | 职责 |
|---|---|---|
| `UIFocusSystem` | UIKitCore | UIKit 焦点引擎入口,持有 behavior + delegate;只是 registry,真正逻辑在 update path |
| `_UIFocusBehavior_Mac` | UIKitCore | Catalyst/Mac idiom 的 behavior 单例;`supportsTabKey` / `supportsArrowKeys` 全部返回 NO,`controlCanBecomeFocused:` 默认只允许 `UITextField` |
| `_UIFocusSystemSceneComponent` | UIKitCore | per-`UIWindowScene` 的焦点系统持有者,在 `_setupFocusSystem` 中创建 `UIFocusSystem`+behavior 等 |
| `_UIFocusEventDelivery` | UIKitCore | 把 UIPress / focus engine 输入分发给 focus system |
| `UIFocusRingManager` | UIKitCore | UIKit 风格的 focus ring 管理;`shapeLayerClassForItem:client:` 会选择 `UINSFocusRingShapeLayer`(macOS 双线 ring) |
| `UINSInputView` | UIKitMacHelper | **Catalyst 场景里 AppKit 端实际 NSView firstResponder**;实现 `NSTextInputClient`、`acceptsFirstResponder`、`acceptKeyViewHandoff:`、Tab/方向键路由 |
| `UINSWindowProxy` | UIKitMacHelper | per-scene 的 AppKit window 代理;持有 `UINSWindowProxyFocusHelper`、`UINSSceneView`、`UINSInputView` 引用 |
| `UINSWindowProxyFocusHelper` | UIKitMacHelper | **双向 firstResponder 桥**;监听 AppKit 的 `NSWindowDidBecomeKey`、UIKit 的 `_UIWindowFirstResponderDidChangeNotification` 做同步 |
| `UINSSceneView` | UIKitMacHelper | NSView,scene 的 host;`inputView` getter 返回 `UINSInputView` |
| `UINSApplicationDelegate` | UIKitMacHelper | per-process 单例;`performActionWithCompletionHandler` 是 UIKit 注入的回调,`UINSInputView` 用它发起向 UIKit 端的 keyboard action |
| `_UINSView` | UIKitCore | 一个 UIView 子类(注意是 UIView,不是 NSView),通过 `NSViewHost` 在 UIKit 容器中嵌 NSView;`becomeFirstResponder` 转发 `[viewHost makeFirstResponder:]` |
| `NSViewHost` / `NSViewHostingContext` / `NSViewHostingContextRootView` | AppKit | 让 NSView 在 UIView 里跑的 hosting infra(`_UINSView` 用) |
| `NSFocusController` | AppKit | **AppKit 内部独立的焦点控制器**(每个 NSWindow 一个);自己构造 `UIFocusSystem` + `NSAppKitFocusBehavior`,通过 `NSWindowFocusProxy`/`NSViewFocusProxy` 把 NSView 树暴露成 UIFocusEnvironment |
| `NSWindowFocusProxy` / `NSViewFocusProxy` | AppKit | 把 `NSWindow` / `NSView` 适配为 `UIFocusEnvironment` 协议的对象(`_focusProxy`) |
| `NSAppKitFocusBehavior` | AppKit | AppKit 的 behavior 对象(很多方法都是占位,实际值由调用方决定) |
| `UINSFocusRingShapeLayer` / `UINSFocusDoubleRingShapeLayer` | UIKitCore | macOS 风格双线聚焦环(`focusLayerForUserInterfaceStyle:` 给 `+UIFocusRingManager shapeLayerClassForItem:client:` 用) |

---

## 2. 各核心问题展开

### 2.1 UIKit Focus 系统在 Catalyst 模式下的入口

#### 2.1.1 `+[UIFocusSystem focusSystemForEnvironment:]` — 注册表查找

`UIFocusSystem` 没有 Mac 专属子类,所有平台共用同一个类,只通过 `behavior` 区分。

```c
// +[UIFocusSystem focusSystemForEnvironment:] @ 0x1b8d6f140
v7 = qword_1EC7D4550;                                  // NSHashTable of all focus systems
if ( v7 && objc_msgSend(v7, "count") )
{
    v9 = _UIFocusEnvironmentRootAncestorEnvironment(environment);
    if ( objc_msgSend(v7, "containsObject:", v9)
      && objc_msgSend(v9, "_focusSystemIsValid") )
        v10 = v9;   // env 本身就是个 UIFocusSystem(根)
}
return v10;
```

HashTable 由一次性的 `____UIFocusSystemRegister_block_invoke` 初始化(`@ 0x1b9aeb820`),`-[UIFocusSystem initWithFocusBehavior:enabled:]` 时往里 `addObject:`。

#### 2.1.2 `_UIFocusSystemSceneComponent _setupFocusSystem` — 真正的 per-scene 入口

```c
// -[_UIFocusSystemSceneComponent _setupFocusSystem] @ 0x1b9b9c734
if ( objc_msgSend(objc_opt_class(self), "needsFocusSystem") )
{
    v9  = -[_UIFocusSystemSceneComponent _focusBehaviorRespectingApplicationOverride:](self, 1);
    v10 = [[UIFocusSystem alloc] initWithFocusBehavior:v9
                                              enabled:_isFocusSystemActive];
    [v10 setDelegate:self];
    ...
    if ( [v9 syncsFocusAndResponder] ) {
        // 仅当 behavior 要求 first-responder 同步时才装这个观察者
        v24 = [[_UIFocusSceneHostAssertionObserver alloc] initWithScene:v3];
        ...
    }
}
```

关键转折:`_focusBehaviorRespectingApplicationOverride:` 内部:

```c
// -[_UIFocusSystemSceneComponent _focusBehaviorRespectingApplicationOverride:] @ 0x1b9b9dfe8
v7 = _UIFocusBaseBehaviorForTraitCollection(v6);
// _UIFocusBaseBehaviorForTraitCollection @ 0x1ba1d8528
//   => return +[_UIFocusBehavior_Mac sharedInstance];
```

**所有 trait collection 在 Catalyst/Mac 上都返回 `_UIFocusBehavior_Mac` 单例**,根本没有走 idiom 分支。这等于把整个 Focus 引擎"装载在 Mac behavior 上"。

#### 2.1.3 `_UIFocusBehavior_Mac` 的关键行为决定整个 Catalyst Focus 体系

| selector | 返回值 / 行为 |
|---|---|
| `supportsTabKey` | **NO**(`0x1b961cd58 → ret 0`) |
| `supportsArrowKeys` | **NO**(`0x1b961cd50 → ret 0`) |
| `controlCanBecomeFocused:` | 仅当 `UIApp._isFullKeyboardAccessEnabled` 或对象是 `UITextField` 时返回 YES |
| `focusRingVisibility` | 仅当 `_AXSFullKeyboardAccessFocusRingEnabled()` 为 YES 时返回 `2`(可见),否则 `0` |
| `focusSystemDeactivationMode` | `0`(始终激活) |
| `syncsFocusAndResponder` | **未 override**(基类默认 NO);对比 `_UIFocusBehavior_IOS` / `_UIFocusBehavior_TV` / `_UIFocusBehavior_CarPlay` 全部硬编码 YES |

> 反编译证据:`-[_UIFocusBehavior_IOS syncsFocusAndResponder] @ 0x1ba3eee00` 返回 1,而 `_UIFocusBehavior_Mac` 在 lookup 中**找不到**该 selector → 继承基类默认。这是为什么 Catalyst 走的是 **AppKit 主导 + 单向通知 UIKit** 的路线,而不是 iOS/tvOS 那种"UIKit focus 完全镜像 firstResponder"路线。

#### 2.1.4 `_UIFocusSystem _updateFocusImmediatelyToEnvironment:` 怎么被叫到

```c
// -[UIFocusSystem _updateFocusImmediatelyToEnvironment:startDeferringOnLostFocus:suppressLostFocusUpdate:]
// @ 0x1b9ae9c7c
//
// 真正实施 focus update 的 hot path;Catalyst 下两条路径会调到它:
//  (a) AppKit 端:NSFocusController._primitiveFirstResponderDidChange()
//        ↓
//      [focusSystem _updateFocusImmediatelyToEnvironment:_focusProxy]
//  (b) UIKit 端正常 API:UIView.becomeFirstResponder / UIViewController.setNeedsFocusUpdate ...
```

---

### 2.2 UINSView / UINSWindow / UINSResponder 桥接层

#### 2.2.1 `UINSInputView` 是 AppKit 端的实际 firstResponder

`UINSInputView` 继承自 `NSView`(从 selectors 推断),被 `UINSSceneView` 挂在 scene 上,实现了完整的 NSResponder 表面:

```
becomeFirstResponder / resignFirstResponder / acceptsFirstResponder
acceptsFirstMouse: / acceptKeyViewHandoff: / designatedFocusRingView
moveLeft: / moveRight: / moveUp: / moveDown: / scrollPageUp: ...
selectNextKeyView: / selectPreviousKeyView:
insertText:replacementRange: / setMarkedText:.. / ...(整个 NSTextInputClient)
keyDown: / keyUp: / flagsChanged: / mouseDown: / scrollWheel: / ...
forwardKeyboardAction:propagateUpHostResponderChain:
```

它的 `_isNSTextInputContextiOSMacClient` 直接返回 `1`(`@ 0x19e8c2320`)— 告诉 AppKit 的 NSTextInputContext 走 iOSMac 客户端路径。

#### 2.2.2 `becomeFirstResponder` → 通知 UIKit "我们要成为 first responder 了"

```c
// -[UINSInputView becomeFirstResponder] @ 0x19e89ddec
v4 = [self window];
if ( !v4 ) return NO;
[self _maybeWillBecomeFirstResponder];   // 先 ping 到 UIKit 端

v5 = [self window];
v6 = [v5 keyViewSelectionDirection];      // AppKit Tab 方向
if ( v6 == 0 )                            // 0 = 没有方向(鼠标点入)
    [self _maybeDidBecomeFirstResponder];
else if ( v6 == 1 )                       // 1 = Tab forward
    [self _forwardKeyViewAction:@"selectFirstKeyView:" direction:1];
else if ( v6 == 2 )                       // 2 = Tab backward
    [self _forwardKeyViewAction:@"selectLastKeyView:" direction:2];
```

接着是一个左右开弓的状态同步:

```c
// -[UINSInputView _maybeWillBecomeFirstResponder] @ 0x19e8c6438
self->_waitingForMaybeDidBecomeFirstResponder = 1;
windowProxy = [[self sceneView] sceneViewController].windowProxy;
[windowProxy inputViewStartedBecomeFirstResponder];   // 桥接 → UIKit 端

// -[UINSInputView _maybeDidBecomeFirstResponder] @ 0x19e8c64c8
if ( _waitingForMaybeDidBecomeFirstResponder ) {
    BOOL appKitWon = [self _areWeAppKitFirstResponder];
    [windowProxy inputViewFinishedBecomeFirstResponder:appKitWon];
}
```

`UINSWindowProxyFocusHelper.inputViewStartedBecomeFirstResponder` 立刻把 UIKit `keyUIWindow` 变成 application key window:

```c
// -[UINSWindowProxyFocusHelper inputViewStartedBecomeFirstResponder] @ 0x19e8d04f0
windowProxy = objc_loadWeakRetained(&_windowProxyIvar);
keyUIWin    = [windowProxy keyUIWindow];
[keyUIWin makeKeyWindow];                 // UIKit side: 我是 key window
```

`inputViewFinishedBecomeFirstResponder:` 在 AppKit 真的拿到 firstResponder 之后,调 `_setSceneAppKitFocused:` → `[[keyUIWindow _macComponent] _becomeAppKitFocusedScene]`,在 UIKit window 上打 "AppKit focused" 标记。

#### 2.2.3 `resignFirstResponder` 反向通知

```c
// -[UINSInputView resignFirstResponder] @ 0x19e8c63e0
super_resignFirstResponder;
[self _reallyDidResignFirstResponder];

// -[UINSInputView _reallyDidResignFirstResponder] @ 0x19e8c6578
[self _cancelUnfinishedPhysicalKeyboardPresses];
windowProxy = [[self sceneView] sceneViewController].windowProxy;
[windowProxy inputViewResignedFirstResponder];
//  -> -[UINSWindowProxyFocusHelper _setSceneAppKitFocused:NO]
```

#### 2.2.4 `acceptsFirstResponder` 做的两层校验

```c
// -[UINSInputView acceptsFirstResponder] @ 0x19e89ec64
v3 = [self _sceneHostingView];
if ( v3 ) {
    v4 = [v3 uiView];
    v5 = [v4 canBecomeFirstResponder];        // 委托给 UIKit 那边对应的 _UINSView 包装
}
if ( v5 ) {
    currentEvent = [NSApp currentEvent];
    if ( currentEvent )
        v5 = ![NSRemoteView isFakeEvent:currentEvent];   // 假事件不接 first
    else
        v5 = YES;
}
return v5;
```

#### 2.2.5 `UINSWindow` 上的 `_realMakeFirstResponder:` 没有特殊化

`UINSWindow` 没有 override `makeFirstResponder:`(只在 list 中看到 `setWindowController:` / `_layerHostedContext` / `sceneWindowController` / `setInitialSceneContentSize:`)。
**所有 makeFirstResponder 调用都走 `-[NSWindow makeFirstResponder:]` → `-[NSWindow _realMakeFirstResponder:]`**,见 §2.4。

#### 2.2.6 反向桥:`_UINSView`(UIView 包装 NSView)

```c
// -[_UINSView becomeFirstResponder] @ 0x1b9693a38
v3 = [self->_viewHost makeFirstResponder:self->_contentNSView];   // 让 NSView 成为 first
if ( v3 ) {
    super_becomeFirstResponder;                                    // 让 UIView 也成为 first
    [[[self window] _hostWindow] _setHostedView:self->_viewHost];  // host window 记录
}

// -[_UINSView resignFirstResponder] @ 0x1b9693ae0
v3 = [self->_viewHost makeFirstResponder:nil];
if ( v3 ) {
    super_resignFirstResponder;
    NSViewHost *hosted = [[[self window] _hostWindow] _hostedView];
    if ( hosted == self->_viewHost )
        [[[self window] _hostWindow] _setHostedView:nil];
}

// -[_UINSView canBecomeFirstResponder] @ 0x1b9693a30  →  return YES (hard-coded)
```

这是 Catalyst 中的 *少数派* 用法:把一段 AppKit `NSView` 嵌进 UIKit 视图层,UIKit 这边 `_UINSView` 作 first responder 之后,通过 `NSViewHost` 把 AppKit 内的 first responder 也同步切到 `_contentNSView`。

---

### 2.3 Tab 键 / 方向键焦点循环的实现路径

#### 2.3.1 关键事实:**`_UIFocusBehavior_Mac.supportsTabKey == NO`**

意味着 UIKit Focus 引擎 *不会* 直接接收 Tab 键并驱动 `UIFocusSystem`。Tab 走的是 AppKit 自己的 `keyView` 循环。

#### 2.3.2 `UINSInputView` 怎么处理 `selectNextKeyView:`

`-[NSWindow keyDown:]` 自带 keyView routing,会把 Tab 翻译成 `selectNextKeyView:` 发给当前 firstResponder。`UINSInputView` 拦住了:

```c
// -[UINSInputView selectNextKeyView:] @ 0x19e8c62b8
[self _forwardKeyViewAction:@"selectNextKeyView:" direction:1];

// -[UINSInputView selectPreviousKeyView:] @ 0x19e8c62c8
[self _forwardKeyViewAction:@"selectPreviousKeyView:" direction:2];
```

`_forwardKeyViewAction:direction:` 是路由核心:

```c
// -[UINSInputView _forwardKeyViewAction:direction:] @ 0x19e8c5ef0
if ( direction == 1 )      next = [self nextValidKeyView];          // AppKit 一边的下一个
else if ( direction == 2 ) next = [self previousValidKeyView];      // AppKit 一边的上一个
self->_fallbackKeyViewIfNotHandledByFocusSystem = next;             // 暂存

redirectionDisabled = [[self window] _keyViewRedirectionDisabled];
delegate = [UINSApplicationDelegate sharedDelegate];
handler  = [delegate performActionWithCompletionHandler];           // UIKit 注入的 block
keyUIWin = [[self sceneView] keyUIWindow];

// 调 UIKit 端,让它决定要不要"吞下"这次 keyView 跳转
handler(action, keyUIWin, !redirectionDisabled, ^(BOOL uikitHandled){
    if ( ![NSThread isMainThread] ) assert(...);
    if ( !uikitHandled )
        [self _chooseNewKeyViewWithDirection:direction];             // 回落到 AppKit
    [self _maybeDidBecomeFirstResponder];                            // 完成态
});
```

`_chooseNewKeyViewWithDirection:` 才是真正"把 first responder 切到下一个 NSView":

```c
// -[UINSInputView _chooseNewKeyViewWithDirection:] @ 0x19e8c6140
fallback = self->_fallbackKeyViewIfNotHandledByFocusSystem;
if ( !fallback || ![self _isValidKeyView:fallback] ) {
    if ( direction == 1 ) fallback = [self nextValidKeyView];
    else                  fallback = [self previousValidKeyView];
}
if ( fallback ) {
    win = [self window];
    saveDir = [win keyViewSelectionDirection];
    [win _setKeyViewSelectionDirection:direction];
    [win makeFirstResponder:fallback];                             // 直接走 AppKit
    [win _setKeyViewSelectionDirection:saveDir];
    return YES;
}
return NO;
```

#### 2.3.3 跨 scene 的 Tab handoff(从一个 Catalyst window 跳到下一个 window 上的 first/last keyView)

```c
// -[UINSWindowProxy acceptKeyViewHandoff:completionQueue:completionHandler:] @ 0x19e8ee3c8
inputView = [[sceneViewController.sceneView inputView];
handled   = [inputView acceptKeyViewHandoff:isForward];          // 直接转发
dispatch_async(queue, ^{ completion(handled); });

// -[UINSInputView acceptKeyViewHandoff:] @ 0x19e8c6690
if ( ![self window] ) return NO;
direction = forward ? 1 : 2;
return [self _chooseNewKeyViewWithDirection:direction];
```

#### 2.3.4 方向键(moveLeft: / moveUp: / ...)走 UIKit?

`UINSInputView` 也实现了 `moveLeft:` `moveRight:` `moveUp:` `moveDown:` 等,**全部转给 `_forwardKeyboardAction:propagateUpHostResponderChain:`**(不是 keyView 那一套):

```c
// -[UINSInputView moveLeft:] @ 0x19e8c62d8
[self _forwardKeyboardAction:@"moveLeft:" propagateUpHostResponderChain:NO];

// -[UINSInputView _forwardKeyboardAction:propagateUpHostResponderChain:] @ 0x19e8c5cc0
handler = [[UINSApplicationDelegate sharedDelegate] performActionWithCompletionHandler];
handler(action, [sceneView keyUIWindow], YES /* always propagate */, completion);
```

也就是说方向键(以及大部分文档编辑命令)**直接交给 UIKit responder chain**,UIKit 那边决定有没有人处理。不走 AppKit 的 keyView 循环。

#### 2.3.5 总结流程图

```
[Tab key event]
        │
        ▼
[NSWindow keyDown:] → AppKit-level command routing
        │
        ▼
[UINSInputView selectNextKeyView:]
        │
        ▼
[_forwardKeyViewAction:direction:]
   ├── 预存 fallback = [self nextValidKeyView]   (AppKit 下一个 NSView)
   └── 调 UIKit 注入的 handler block
            │
            ▼
   UIKit:有没有"焦点引擎想接管"?(通常 NO,_UIFocusBehavior_Mac.supportsTabKey==NO)
            │
        ┌───┴───┐
        ▼       ▼
       YES     NO  ←── 绝大多数情况
        │       │
        │       ▼
        │   [_chooseNewKeyViewWithDirection:]
        │       │
        │       ▼
        │   [NSWindow makeFirstResponder:fallback]
        │       │
        │       ▼
        │   [NSWindow _realMakeFirstResponder:]
        │       │
        │       ▼
        │   [NSFocusController firstResponderDidChange]
        │   (反向通知 AppKit 自己的 UIFocusSystem,见 §2.4.4)
        │       │
        │       ▼
        │   Catalyst:_UIWindowFirstResponderDidChange notification
        │       │
        │       ▼
        │   UINSWindowProxyFocusHelper.uiWindowFirstResponderDidChange:
        │   (反向 perform 0.01s 之后做对齐,见 §2.4.3)
        ▼
   (UIKit focus 系统自己处理)
```

---

### 2.4 NSResponder / UIResponder 双向桥接

#### 2.4.1 UIKit nextResponder 链 vs AppKit nextResponder 链

两边各自独立。Catalyst 没有把它们拼成一条 chain。桥接是通过 *显式同步两边的 firstResponder* 完成的,不是通过把 chain 接起来。

唯一接近"chain 拼接"的设施是 `UINSResponderProxy`(`@ 0x19e941af4 ...`):它 *动态合成* 一个 NSResponder 子类,把一个 UIKit responder 包成 AppKit responder,用于"AppKit 菜单 / 工具栏 validate action" 的场景:

```
+[UINSResponderProxy responderProxySearchingFromFirstResponderWithTargetForAction:sender:inputView:]
+[UINSResponderProxy responderProxySearchingFromWindowWithTargetForAction:sender:window:]
+[UINSResponderProxy responderProxySearchingFromAppWithTargetForAction:sender:]
-[UINSResponderProxy validateMenuItem:] / validateToolbarItem: / forwardInvocation:
```

也就是说菜单 / 工具栏对应 action 验证会先从 AppKit firstResponder 开始,如果它是 `UINSInputView` 这种,就把搜索委托到 UIKit responder chain 里去找 target。这是 Catalyst 应用里 Cmd+C / Cmd+V 等菜单能从 NSMenu 一路打通到 UIView 的关键。

#### 2.4.2 当 `UITextField` 成为 UIKit firstResponder,谁是 AppKit firstResponder?

**永远是该 scene 的 `UINSInputView`**。UIKit 那边的 `UITextField.isFirstResponder == YES` 跟 AppKit 那边的 `window.firstResponder == UINSInputView` 是两件事情,中间靠 `UINSInputView` 实现 `NSTextInputClient` 把按键 / 输入法事件搬给真正持有 UITextField 的 UIKit responder chain。

证据:`UINSInputView` 有完整的 `insertText:` / `setMarkedText:` / `firstRectForCharacterRange:` / `attributedSubstringForProposedRange:` 实现,*但它并不是 UITextField*。它是 *AppKit-side delegate*,会把所有文本输入操作转给 UIKit `keyUIWindow.firstResponder`。

`-[UINSWindowProxyFocusHelper _updateIfUIKitKeyWindowOrFirstResponderChanged:]` 中有一条专门针对 `UISearchBarTextField` 的特殊化(`cfstr_Uisearchbartex_6`),会比较 AppKit firstResponder 和 UIKit firstResponder,差异时直接 `[appKitWindow makeFirstResponder:UINSInputView]` 强制同步,并发送 `_sendActionsForEditingDidBeginForCatalyst` / `_sendActionsForEditingDidEndForCatalyst` 给 UIKit 那个 `UISearchBarTextField`,补齐两个世界的"编辑开始/结束"通知。

#### 2.4.3 UIKit firstResponder → AppKit 的反向同步(`UINSWindowProxyFocusHelper`)

`UINSWindowProxyFocusHelper.setupWindowObservations:` 注册了两个 UIKit 通知:

```c
// -[UINSWindowProxyFocusHelper setupWindowObservations:] @ 0x19e8d0848
addObserver:self
   selector:@selector(uiWindowDidBecomeApplicationKey:)
       name:UIWindowDidBecomeApplicationKeyNotification   // dlopen UIKitCore symbol
     object:nil

addObserver:self
   selector:@selector(uiWindowFirstResponderDidChange:)
       name:UIWindowFirstResponderDidChangeNotification   // dlopen UIKitCore symbol
     object:nil
```

```c
// -[UINSWindowProxyFocusHelper uiWindowFirstResponderDidChange:]  @ 0x19e8d0f88
[self updateIfUIKitFirstResponderChanged];

// -[UINSWindowProxyFocusHelper updateIfUIKitFirstResponderChanged] @ 0x19e8d12fc
//   assert(pthread_main_np());
[NSObject cancelPreviousPerformRequestsWithTarget:self
                                         selector:@selector(_updateIfUIKitFirstResponderChanged)
                                           object:nil];
[self performSelector:@selector(_updateIfUIKitFirstResponderChanged)
            withObject:nil afterDelay:0.01];     // 10ms 去抖

// -[UINSWindowProxyFocusHelper _updateIfUIKitKeyWindowOrFirstResponderChanged:1] @ 0x19e8d1440
windowProxy.flags |= 0x40;                              // re-entrancy guard
sceneViewController = windowProxy.sceneViewController;
if ( !sceneViewController.providesContentViewToHostWindow ) {
    keyUIWin     = windowProxy.keyUIWindow;
    uikitFirst   = [keyUIWin firstResponder];
    if ( [uikitFirst isKindOfClass:NSClassFromString(@"UISearchBarTextField")] ) {
        appKitKeyWin = [NSApp keyWindow];
        appKitFirst  = [appKitKeyWin firstResponder];
        appKitParent = [self _parentWindowOfResponder:appKitFirst];
        attachedWin  = windowProxy.attachedWindow;
        inputView    = sceneViewController.sceneView.inputView;
        if ( a3 /* fromUIKit */ ) {
            if ( appKitParent == attachedWin && appKitFirst != inputView )
                [attachedWin makeFirstResponder:inputView];
        } else if ( appKitFirst == inputView ) {
            // UIKit 端开始编辑
            if ([uikitFirst respondsToSelector:@selector(_sendActionsForEditingDidBeginForCatalyst)])
                [uikitFirst _sendActionsForEditingDidBeginForCatalyst];
        } else {
            // UIKit 端结束编辑
            if ([uikitFirst respondsToSelector:@selector(_sendActionsForEditingDidEndForCatalyst)])
                [uikitFirst _sendActionsForEditingDidEndForCatalyst];
        }
    }
    [self _updateForRemoteViews];   // 顺带处理 ViewBridge remote 场景
}
```

读到这里很清楚:**Catalyst 的 UIKit→AppKit 同步不是"任何 UIView focus 都触发",而是被压缩到 `UISearchBarTextField`(以及通过 remote view 的 host pivoting)这一狭窄路径**。普通的 UIView focus 在 Catalyst 里根本不会去碰 AppKit 的 first responder—因为 `_UIFocusBehavior_Mac.controlCanBecomeFocused:` 已经在源头屏蔽了 UIView 进入焦点系统。

#### 2.4.4 AppKit firstResponder → UIKit 的反向同步(`NSWindow._realMakeFirstResponder:` 末尾)

每次 AppKit 端 `makeFirstResponder:` 都会经过这个 hot path:

```asm
; -[NSWindow _realMakeFirstResponder:]  尾段汇编 (0x184ac3a28 - 0x184ac3a3c)
184ac3a28  BL _objc_msgSend$_saveFirstResponder
184ac3a30  BL _objc_msgSend$_changeAllAttachmentsFirstResponder
184ac3a34  MOV X0, X19                            ; self (NSWindow)
184ac3a38  BL _objc_msgSend$_focusController      ; [self _focusController]
184ac3a3c  BL _objc_msgSend$firstResponderDidChange  ;  → [focusController firstResponderDidChange]
184ac3a40  MOV W0, #0
184ac3a44  BL _NSAccessibilityHandleFocusChangedForce
184ac3a48  BL __NSPostActiveFirstResponderChanged
```

伪代码视角:

```c
[self _saveFirstResponder];
[self _changeAllAttachmentsFirstResponder];
[[self _focusController] firstResponderDidChange];       // ← 通知 NSFocusController
NSAccessibilityHandleFocusChangedForce(NO);
_NSPostActiveFirstResponderChanged();
```

`NSFocusController` 之后会:

```c
// -[NSFocusController firstResponderDidChange] @ 0x1855d2324
if ( !self.isSynchronizingFirstResponder ) {
    self.isSynchronizingFirstResponder = YES;
    [self _primitiveFirstResponderDidChange];
    self.isSynchronizingFirstResponder = NO;
}

// -[NSFocusController _primitiveFirstResponderDidChange] @ 0x1855d2384
rootEnv  = self.rootFocusEnvironment;
respFirst = [self _firstResponderForEnvironment:rootEnv];   // 找包了 NSResponder 的 _focusProxy
proxy    = nil;
if ( [respFirst respondsToSelector:@selector(_focusProxy)] ) {
    p = [respFirst _focusProxy];
    if ( [p conformsToProtocol:UIFocusEnvironment_Proto] )
        proxy = p;
}
focusedItem = focusSystem.focusedItem;
if ( focusedItem != proxy ) {
    if ( [proxy isKindOfClass:NSViewFocusProxy] ) {
        replacement = [[proxy view] _replacementViewForFocus];
        if ( replacement )
            proxy = [replacement _focusProxy];
    }
    [focusSystem _updateFocusImmediatelyToEnvironment:proxy];   // 驱动 UIFocusSystem
}
```

但要注意:**这是 AppKit 自己的 `UIFocusSystem` 实例**(`NSFocusController.focusSystem`),不是 Catalyst scene 的那个 `_UIFocusSystemSceneComponent.focusSystem`。它们是两套独立的 instance,各自跑各自的 update。Catalyst 那一侧之所以会感知到,是因为 `UINSWindowProxyFocusHelper` 还会再发 `_UIWindowFirstResponderDidChangeNotification`,完成跨边界的真正同步。

> 注意:`NSFocusController` 是 AppKit 自己使用 UIFocusSystem 来实现现代化 keyView 选择(`selectKeyViewWithHeading:`)的复用,它甚至会在 `selectKeyViewWithHeading:` 中先 `[focusItemCache resolveDestination:from:heading:]` 再 `[window makeFirstResponder:]`。这是 AppKit 在自身演进中借了 UIKit 焦点引擎,**不是 Catalyst 桥接**。Catalyst 里这条路径同样存在,因为 `NSWindow` 是公用的。

---

### 2.5 Focus Ring 渲染

#### 2.5.1 macOS 风格双线 ring 的 layer 来源

`UINSFocusRingShapeLayer` + `UINSFocusDoubleRingShapeLayer` 是 UIKitCore 里实现的 NS 风格双线焦点环:

```c
// +[UINSFocusRingShapeLayer focusLayerForUserInterfaceStyle:]  @ 0x1ba6629b0
v3 = [UINSFocusDoubleRingShapeLayer layer];
[v3.bottomBorderLayer setLineWidth:UIFocusRingStyle.minRadius];
[v3.topBorderLayer    setLineWidth:1.5];
return v3;
```

它通过常量数据表(`off_1E6D6FD90` / `off_1E6D6FD88`)被 `+[UIFocusRingManager shapeLayerClassForItem:client:]` 间接索引到:

```c
// +[UIFocusRingManager shapeLayerClassForItem:client:] @ 0x1b9fdd204
if ( [client isEqualToString:@"AXFKATextFieldClient"]
  && UIApp._isFullKeyboardAccessEnabled )
    table = off_1E6D6F5A0;                       // FKA text field 专属
else if ( [client isEqualToString:@"FocusEngineClient"]
       && [item isKindOfClass:UITextField] )
    table = off_1E6D6FD90;                       // 文本框 → UINSFocusRingShapeLayer/DoubleRing
else
    table = off_1E6D6FD88;                       // 默认
return objc_opt_class(*table);
```

#### 2.5.2 UIView 普通焦点用 UIFocusHaloEffect

非 NS 风格 ring(iPad/iOS 那种圆角高亮)走 `UIFocusEffect` / `UIFocusHaloEffect`:

```c
// -[UITextField _defaultFocusEffect] @ 0x1ba3c1788
if ( !borderStyle && !FKA ) return nil;
...
return [UIFocusHaloEffect effectWithRect:...];   // or effectWithPath:
```

`_UIFocusSystemSceneComponent._updateFocusEffectForItem:` 根据 behavior 决定走哪一条:

```c
// -[_UIFocusSystemSceneComponent _updateFocusEffectForItem:] @ 0x1b9b9d8dc
if ( !focusSystem._isEnabled ) {
    if ( self.flags & 2 /* wantsModernRing */ )
        [[self _focusEffectManager] moveFocusToItem:nil];
    else
        [UIFocusRingManager moveRingToFocusItem:nil];
    return;
}
showsRing = [focusSystem.behavior showsFocusRingForItem:item];
if ( self.flags & 2 /* modern */ )
    [[self _focusEffectManager] moveFocusToItem:(showsRing ? item : nil)];
else
    [UIFocusRingManager moveRingToFocusItem:(showsRing ? item : nil)];
```

Catalyst 默认 `flags & 2` 没看到被 `_updateWantsModernRing` 置位(`-[_UIFocusSystemSceneComponent _updateWantsModernRing]` 是空函数 `0x1b9b9d83c` — 完全 no-op),所以默认走 `UIFocusRingManager` → `UINSFocusRingShapeLayer/Double`,这是 macOS 视觉。

#### 2.5.3 谁实际绘制

最终是 `CALayer` 子类(`UINSFocusRingShapeLayer` 继承 `CAShapeLayer`)在 `UIFocusRingManager._viewToAddFocusLayerForItem:forClient:` 找到的宿主 UIView 上添加,**不是 AppKit `NSFocusRingType` / `NSView.drawFocusRingMask`**。
顺带证据:`-[UINSInputView focusRingType] @ 0x19e89f540` 自己实现了一个,但只会被 AppKit 自己绘制 NS 默认 ring 时调用 — 而它本质是个透明 input host,不需要绘制 ring,所以多数实测情况下 NS 默认 ring 也不出现。
另一边 `UINSInputView.designatedFocusRingView` 会优先返回 `_sceneHostingView`(也就是 UIKit 场景视图)。这意味着 *如果* AppKit 真要在 input view 上画 ring,会被代理到 scene host 而不是 input view 自己。

---

### 2.6 UIFocusEffect / UIFocusEnvironment 协议适配

#### 2.6.1 `UIFocusEnvironment` 协议是否直接在 `NSView` 上

**不直接**。在 UIKitMacHelper 中没有看到 `UINSView`/`UINSInputView` 实现 `shouldUpdateFocusInContext:` 等协议方法。

但是 *AppKit 自己*(用于 NSFocusController 那一支)有 `NSWindowFocusProxy` / `NSViewFocusProxy` 作为 NSWindow / NSView 的 *UIFocusEnvironment 包装*:

| selector | NSWindowFocusProxy | NSViewFocusProxy |
|---|---|---|
| `parentFocusEnvironment` | 0x1855b8880 | 0x1859dc22c |
| `preferredFocusEnvironments` | 0x1855b8920 | 0x1859dc320 |
| `focusItemContainer` | 0x1855b891c | 0x1859dc31c |
| `shouldUpdateFocusInContext:` | 0x1855b8bf4 (return 1) | 0x1859dc32c (return 1) |
| `didUpdateFocusInContext:` | 0x1855b8bfc (仅 log) | 0x1859dc334 |
| `setNeedsFocusUpdate` | 0x1855b8d0c | 0x1859dc440 |
| `updateFocusIfNeeded` | 0x1855b8dc4 | 0x1859dc4f8 |
| `canBecomeFocused` | — | 0x1859dc7f4 |

`NSWindowFocusProxy.preferredFocusEnvironments` 会返回:

```c
// -[NSWindowFocusProxy preferredFocusEnvironments] @ 0x1855b8920
NSMutableArray *a = [NSMutableArray array];
initFirst = [window initialFirstResponder];
if ([initFirst respondsToSelector:@selector(_focusProxy)])
    [a addObject:[initFirst _focusProxy]];
if (window.contentView) [a addObject:[window.contentView _focusProxy]];
if ([window _titlebarContainerView]) [a addObject:[[window _titlebarContainerView] _focusProxy]];
return a;
```

这构成了 **AppKit 视图树→ UIFocusEnvironment 树** 的影子结构,让 AppKit 自己内部的 UIFocusSystem 可以遍历 NSView。

#### 2.6.2 `_UINSView.preferredFocusEnvironments`?

代码中没有看到 `_UINSView` 覆盖 `preferredFocusEnvironments`,它使用 `UIView` 默认实现(空数组或 self)。`_UINSView._defaultFocusEffect` 也直接返回 0(`@ 0x1b9693a28 → return 0`),代表 UIKit 包装 NSView 时不画 UIKit 焦点效果,把焦点视觉留给 AppKit 处理。

#### 2.6.3 `UIFocusEffect _resolvedEffectForItem:`

`UIFocusEffect` 的 resolve 函数 `_UIFocusEffectIsSystemDefaultVisible @ 0x1ba09e294` 决定是否使用系统默认效果。Catalyst 下的具体行为依赖 trait collection 和 behavior(没贴出全部反编译,关键是它最终路由到 `_UIFocusEffectManager.moveFocusToItem:` 把 `haloView` 加进 containerView)。

---

## 3. 关键发现 & 未解决问题

### 3.1 关键发现

1. **Catalyst 不创建 macOS 专属 `UIFocusSystem` 子类**;Mac/Catalyst 通过 `_UIFocusBehavior_Mac`(一个 *behavior* 而不是 *system*)来 *降级* 焦点引擎的能力。
2. **`_UIFocusBehavior_Mac` 全面禁用 Tab / Arrow key 路径**(`supportsTabKey/supportsArrowKeys → NO`),把 keyView 循环还给 AppKit。
3. **`syncsFocusAndResponder` 在 Mac behavior 上没有 override → 继承默认 NO**(iOS/CarPlay/TV 都硬编码 YES)。这是 Catalyst 不采用"双向镜像"策略的根因。
4. **Catalyst 的桥接是单向通知+针对性同步**,集中在 `UINSWindowProxyFocusHelper`,而且关键路径只针对 `UISearchBarTextField` 这类需要双向编辑状态对齐的特殊 case。
5. **`UINSInputView` 是 AppKit 端真正的 firstResponder**,持有完整 NSResponder + NSTextInputClient 实现;一切 AppKit 事件先到它,然后:
   - 文本/按键事件 → 转发到 UIKit `keyUIWindow.firstResponder`(经 `performActionWithCompletionHandler`)
   - Tab / 方向键 → 先问 UIKit,UIKit 不要时回落 `[NSWindow makeFirstResponder:nextValidKeyView]`
6. **AppKit `NSFocusController` 是独立产物**:每个 NSWindow 一个,自己实例化 `UIFocusSystem + NSAppKitFocusBehavior`,通过 `NSWindowFocusProxy/NSViewFocusProxy` 把 NSView 树暴露给 UIFocusSystem 引擎。这是 AppKit *复用* UIFocusSystem 引擎实现现代 keyView 解析,**与 Catalyst 桥接无关**。
7. **`-[NSWindow _realMakeFirstResponder:]` 末尾硬编码** `[[self _focusController] firstResponderDidChange]`,这是 AppKit→UIFocusSystem 通知的唯一入口。
8. **Focus ring 视觉**:Catalyst 默认使用 `UINSFocusRingShapeLayer` / `UINSFocusDoubleRingShapeLayer`(UIKitCore 内的 NS 风格双线 ring),通过 `UIFocusRingManager`,**不是 AppKit `NSFocusRingType`**。`_UIFocusSystemSceneComponent._updateWantsModernRing` 是 no-op,这进一步说明 Catalyst 锁定在 NS 风格 ring。
9. **反向桥 `_UINSView`(UIView 包 NSView)**:`becomeFirstResponder` 通过 `NSViewHost makeFirstResponder:` 把焦点切给内嵌 NSView,但 `_defaultFocusEffect` 返回 nil → 焦点视觉由 AppKit 那一侧决定。
10. **`UINSResponderProxy`** 是 *AppKit-style menu/toolbar action validation* 的桥接,把 AppKit 的 `validateMenuItem:` / `forwardInvocation:` 路由到 UIKit responder chain,是 Catalyst 菜单能从 NSMenu 一路打到 UIView 的关键(与 first responder 无直接关系)。
11. **`UIFocusSystem` 实际归属是独立的 `FocusEngine.framework`**(`/System/Library/PrivateFrameworks/FocusEngine.framework`),不是 UIKitCore。AppKit 通过 dyld shared cache 的 GOT(`_OBJC_CLASS_$_UIFocusSystem_ptr` 在 `dyld_shared_cache_arm64e.02.dylddata:__got`)间接引用。运行时验证(2026-05-18 spike):macOS 26.4 原生 AppKit 进程 `_dyld_image_count()` 只看到 FocusEngine,**没有 UIKitCore / iOSSupport**。这彻底解释了为什么 AppKit 可以"内嵌一套 UIFocusSystem"却不需要 link UIKit。
12. **`-[NSWindow _focusController]` 走 `computed_focusController`(`0x1859cb0fc`)lazy 构造**,gate 是 `!_isDeallocating && _wantsFocusSystem`。普通 NSWindow 默认 `_wantsFocusSystem == NO`,所以 `[window _focusController]` 返回 nil —— **AppKit 内置的 Focus 桥接是 opt-in 的**,不是无条件开启。spike 中需要手动 `[[NSFocusController alloc] initWithRootFocusEnvironment:[[NSWindowFocusProxy alloc] initWithWindow:window]]` 才能构造一条。
13. **`-[NSView _focusProxy]`(`0x1854df6b0`)是 associated-object 缓存的 lazy 构造**,`OBJC_ASSOCIATION_RETAIN_NONATOMIC` 模式。每个 NSView 第一次访问时创建对应的 `NSViewFocusProxy`(weakly back-ref view),之后命中缓存。**关键扩展点**:NSView 子类可以 override **类方法** `+_focusProxyClass` 返回自定义 `NSViewFocusProxy` 子类,实现自定义 focus 行为(只要继承 `NSViewFocusProxy` 即可)。
14. **NSView 树天然就是 UIFocusEnvironment 树** —— `-[NSViewFocusProxy parentFocusEnvironment]`(`0x1859dc22c`)返回 `view.superview._focusProxy ?? view.window._focusProxy`,`-[NSViewFocusProxy focusItemsInRect:]`(`0x1859dbd10`)遍历 `view.subviews` 并过滤 `_interactiveBounds` 不为空的 subview。意味着只要 NSView 层级正常、`_interactiveBounds` 配置正确,Focus 引擎就能在整棵树上做几何搜索 —— **不需要单独的 focus environment 注册**。
15. **`NSAppKitFocusBehavior` 全是 placeholder**(`focusDeferral` 等都返回 0/NO/默认值),所有定制都通过 `NSFocusController` 实现 `UIFocusSystemDelegate` 协议(`_focusItemContainerForFocusSystem:` 返回 `rootEnv.focusItemContainer`,`_preferredFocusEnvironmentsForFocusSystem:` 返回 `@[rootEnv]`)。设计上是把 FocusEngine 的"behavior"看作 immutable policy,把"runtime adaptation"留给 delegate —— AppKit 的方向键最终也是通过 `-[NSFocusController navigateWithCommand:]`(`0x1855d1680`)调回 `[NSApp sendAction:selectKeyViewWithHeading:]`,从而复用 AppKit 既有的 keyView 循环。

### 3.2 未完全解决 / 待补充

1. `UINSApplicationDelegate.performActionWithCompletionHandler` 的 setter `setPerformActionWithCompletionHandler:` 在 UIKitMacHelper 内只看到一处 xref(`@ 0x19e952b7c`,数据段),没有定位到 UIKitCore 端注入这个 block 的代码位置。需要单独切到 UIKitCore 数据库进一步追踪。
2. `_UIFocusBehavior_Mac wantsFocusSystemForScene:` 由一个 dispatch_once 设置的 `_MergedGlobals_914` 决定,具体值依赖运行时检测(很可能是 idiom + feature flag),没有完整解开。
3. `+[UIFocusRingManager shapeLayerClassForItem:client:]` 的非命名常量表 `off_1E6D6FD90` / `off_1E6D6FD88` 没有反向出具体每个槽位对应的层类(我们只验证了 `UINSFocusRingShapeLayer` 在表里,但 default 槽 `off_1E6D6FD88` 指向哪个具体 class 没追下去)。
4. `_UIFocusSceneHostAssertionObserver.isActive` 走 `objc_msgSend(focusSystemManager, "isHostAssertingActiveFocusSystem")`,但 `focusSystemManager` 的类没识别;在 Catalyst 路径上 `syncsFocusAndResponder == NO` 时,这个分支根本不进。
5. 报告中只验证了 `UISearchBarTextField` 的 UIKit→AppKit 强同步路径;`_updateForRemoteViews` 走 `+[UINSShadowRemoteViewController divertFirstResponderToApplicableShadowRemoteViewIfNecessary]` 处理 ViewBridge 远端 view,具体的 cross-process 桥逻辑没有展开。

---

## 4. 附录:关键 IDA 符号清单

### 4.1 UIKitCore

| 符号 | 地址 |
|---|---|
| `+[UIFocusSystem focusSystemForEnvironment:]` | `0x1b8d6f140` |
| `+[UIFocusSystem initialize]` | `0x1b9ae4a60` |
| `-[UIFocusSystem initWithFocusBehavior:enabled:]` | `0x1b9ae4b30` |
| `-[UIFocusSystem _setEnabled:]` | `0x1b9ae4c30` |
| `-[UIFocusSystem updateFocusIfNeeded]` | `0x1b9ae8604` |
| `-[UIFocusSystem _updateFocusImmediatelyToEnvironment:startDeferringOnLostFocus:suppressLostFocusUpdate:]` | `0x1b9ae9c7c` |
| `-[UIFocusSystem _didFinishUpdatingFocusInContext:]` | `0x1b9aeaf88` |
| `____UIFocusSystemRegister_block_invoke` | `0x1b9aeb820` |
| `+[_UIFocusBehavior_Mac sharedInstance]` | `0x1b961c9c0` |
| `-[_UIFocusBehavior_Mac wantsFocusSystemForScene:]` | `0x1b961caa8` |
| `-[_UIFocusBehavior_Mac controlCanBecomeFocused:]` | `0x1b961cb08` |
| `-[_UIFocusBehavior_Mac focusRingVisibility]` | `0x1b961cce4` |
| `-[_UIFocusBehavior_Mac focusSystemDeactivationMode]` | `0x1b961cd48` |
| `-[_UIFocusBehavior_Mac supportsArrowKeys]` | `0x1b961cd50` |
| `-[_UIFocusBehavior_Mac supportsTabKey]` | `0x1b961cd58` |
| `_UIFocusBaseBehaviorForTraitCollection` | `0x1ba1d8528` |
| `_UIFocusBehaviorForScene` | `0x1ba1d8480` |
| `-[_UIFocusBehavior_IOS syncsFocusAndResponder]` (对照) | `0x1ba3eee00` |
| `-[_UIFocusBehavior_TV syncsFocusAndResponder]` (对照) | `0x1ba4e1500` |
| `-[_UIFocusBehavior_CarPlay syncsFocusAndResponder]` (对照) | `0x1ba31b848` |
| `+[_UIFocusSystemSceneComponent needsFocusSystem]` | `0x1b9b9c224` |
| `+[_UIFocusSystemSceneComponent sceneComponentForFocusSystem:]` | `0x1b9b9c22c` |
| `-[_UIFocusSystemSceneComponent initWithScene:]` | `0x1b9b9c5dc` |
| `-[_UIFocusSystemSceneComponent _setupFocusSystem]` | `0x1b9b9c734` |
| `-[_UIFocusSystemSceneComponent _focusBehaviorRespectingApplicationOverride:]` | `0x1b9b9dfe8` |
| `-[_UIFocusSystemSceneComponent _isFocusSystemActive]` | `0x1b9b9e080` |
| `-[_UIFocusSystemSceneComponent _updateFocusSystemState]` | `0x1b9b9d228` |
| `-[_UIFocusSystemSceneComponent _updateFocusEffectForItem:]` | `0x1b9b9d8dc` |
| `-[_UIFocusSystemSceneComponent _requestFocusEffectUpdateToEnvironment:]` | `0x1b9b9d840` |
| `-[_UIFocusSystemSceneComponent _updateWantsModernRing]` (空) | `0x1b9b9d83c` |
| `-[_UIFocusSystemSceneComponent _focusSystem:didFinishUpdatingFocusInContext:]` | `0x1b9ba03b4` |
| `-[_UIFocusSystemSceneComponent _validateFocusedItemForFirstResponder:]` | `0x1b9b9e998` |
| `-[_UIFocusSceneHostAssertionObserver initWithScene:]` | `0x1ba490274` |
| `-[_UIFocusSceneHostAssertionObserver isActive]` | `0x1ba4903a8` |
| `+[UIFocusRingManager manager]` | `0x1b8d5439c` |
| `+[UIFocusRingManager updateRingForFocusItem:forClient:]` | `0x1b8d54f24` |
| `+[UIFocusRingManager shapeLayerClassForItem:client:]` | `0x1b9fdd204` |
| `+[UIFocusRingManager moveRingToFocusItem:forClient:]` | `0x1b9fdd3e8` |
| `+[UINSFocusRingShapeLayer focusLayerForUserInterfaceStyle:]` | `0x1ba6629b0` |
| `-[UINSFocusDoubleRingShapeLayer init]` | `0x1ba6625a8` |
| `-[UINSFocusRingShapeLayer init]` | `0x1ba662b88` |
| `-[UIView _defaultFocusEffect]` | `0x1ba5900fc` |
| `-[UITextField _defaultFocusEffect]` | `0x1ba3c1788` |
| `-[_UINSView initWithContentNSView:]` | `0x1b9693024` |
| `-[_UINSView canBecomeFirstResponder]` | `0x1b9693a30` |
| `-[_UINSView becomeFirstResponder]` | `0x1b9693a38` |
| `-[_UINSView resignFirstResponder]` | `0x1b9693ae0` |
| `-[_UINSView canBecomeFocused]` | `0x1b96939bc` |
| `-[_UINSView _defaultFocusEffect]` (返回 nil) | `0x1b9693a28` |
| `-[_UIFocusEffectManager moveFocusToItem:]` | `0x1b9f2f3fc` |

### 4.2 UIKitMacHelper

| 符号 | 地址 |
|---|---|
| `-[UINSWindowProxyFocusHelper initWithWindowProxy:]` | `0x19e8d0474` |
| `-[UINSWindowProxyFocusHelper inputViewStartedBecomeFirstResponder]` | `0x19e8d04f0` |
| `-[UINSWindowProxyFocusHelper inputViewFinishedBecomeFirstResponder:]` | `0x19e8d0550` |
| `-[UINSWindowProxyFocusHelper _setSceneAppKitFocused:]` | `0x19e8d05d0` |
| `-[UINSWindowProxyFocusHelper inputViewResignedFirstResponder]` | `0x19e8d0668` |
| `-[UINSWindowProxyFocusHelper _updateForRemoteViews]` | `0x19e8d0670` |
| `-[UINSWindowProxyFocusHelper windowItselfBecameFirstResponder]` | `0x19e8d0724` |
| `-[UINSWindowProxyFocusHelper setupWindowObservations:]` | `0x19e8d0848` |
| `-[UINSWindowProxyFocusHelper uiWindowFirstResponderDidChange:]` | `0x19e8d0f88` |
| `-[UINSWindowProxyFocusHelper windowDidBecomeKey:]` | `0x19e8d0f8c` |
| `-[UINSWindowProxyFocusHelper _windowDidBecomeKey]` | `0x19e8d1048` |
| `-[UINSWindowProxyFocusHelper windowDidResignKey:]` | `0x19e8d1088` |
| `-[UINSWindowProxyFocusHelper updateIfUIKitKeyWindowChanged]` | `0x19e8d11b8` |
| `-[UINSWindowProxyFocusHelper updateIfUIKitFirstResponderChanged]` | `0x19e8d12fc` |
| `-[UINSWindowProxyFocusHelper _updateIfUIKitFirstResponderChanged]` | `0x19e8d13ec` |
| `-[UINSWindowProxyFocusHelper _updateIfUIKitKeyWindowOrFirstResponderChanged:]` | `0x19e8d1440` |
| `-[UINSWindowProxyFocusHelper updateIfTrueAppKitKeyWindowChanged]` | `0x19e8d169c` |
| `-[UINSWindowProxyFocusHelper _parentWindowOfResponder:]` | `0x19e8d196c` |
| `-[UINSWindowProxy acceptKeyViewHandoff:completionQueue:completionHandler:]` | `0x19e8ee3c8` |
| `-[UINSWindowProxy _setHostedView:]` | `0x19e8f18fc` |
| `-[UINSWindowProxy _hostedView]` | `0x19e8f186c` |
| `-[UINSSceneView inputView]` | `0x19e89ba9c` |
| `-[UINSSceneView focusRingType]` | `0x19e9242d0` |
| `-[UINSInputView initWithFrame:]` | `0x19e89b2f0` |
| `-[UINSInputView setSceneView:]` | `0x19e89baac` |
| `-[UINSInputView becomeFirstResponder]` | `0x19e89ddec` |
| `-[UINSInputView resignFirstResponder]` | `0x19e8c63e0` |
| `-[UINSInputView acceptsFirstResponder]` | `0x19e89ec64` |
| `-[UINSInputView focusRingType]` | `0x19e89f540` |
| `-[UINSInputView _maybeWillBecomeFirstResponder]` | `0x19e8c6438` |
| `-[UINSInputView _maybeDidBecomeFirstResponder]` | `0x19e8c64c8` |
| `-[UINSInputView _reallyDidResignFirstResponder]` | `0x19e8c6578` |
| `-[UINSInputView _areWeAppKitFirstResponder]` | `0x19e8c6604` |
| `-[UINSInputView acceptKeyViewHandoff:]` | `0x19e8c6690` |
| `-[UINSInputView designatedFocusRingView]` | `0x19e8c6708` |
| `-[UINSInputView _hostedFirstResponder]` | `0x19e8c6378` |
| `-[UINSInputView _forwardKeyboardAction:propagateUpHostResponderChain:]` | `0x19e8c5cc0` |
| `-[UINSInputView _forwardKeyViewAction:direction:]` | `0x19e8c5ef0` |
| `-[UINSInputView _chooseNewKeyViewWithDirection:]` | `0x19e8c6140` |
| `-[UINSInputView selectNextKeyView:]` | `0x19e8c62b8` |
| `-[UINSInputView selectPreviousKeyView:]` | `0x19e8c62c8` |
| `-[UINSInputView moveLeft: / moveRight: / moveUp: / moveDown:]` | `0x19e8c62d8 - 0x19e8c6308` |
| `-[UINSInputView keyDown:]` | `0x19e8c48d4` |
| `-[UINSInputView _isValidKeyView:]` | `0x19e8c5c4c` |
| `-[UINSInputView _isNSTextInputContextiOSMacClient]` (return 1) | `0x19e8c2320` |
| `-[UINSApplicationDelegate performActionWithCompletionHandler]` | `0x19e8bcebc` |
| `-[UINSApplicationDelegate setPerformActionWithCompletionHandler:]` | `0x19e897230` |
| `+[UINSResponderProxy responderProxySearchingFromFirstResponderWithTargetForAction:sender:inputView:]` | `0x19e941af4` |
| `+[UINSResponderProxy responderProxySearchingFromWindowWithTargetForAction:sender:window:]` | `0x19e941ff4` |
| `+[UINSResponderProxy responderProxySearchingFromAppWithTargetForAction:sender:]` | `0x19e942218` |

### 4.3 AppKit

| 符号 | 地址 |
|---|---|
| `-[NSWindow makeFirstResponder:]` | `0x184ac3664` |
| `-[NSWindow _realMakeFirstResponder:]` | `0x184ac3768` |
| `+[NSFocusController allControllers]` | `0x1855d0db0` |
| `+[NSFocusController registerController:]` | `0x1855d0e1c` |
| `-[NSFocusController initWithRootFocusEnvironment:]` | `0x1855d1034` |
| `-[NSFocusController _firstResponderForEnvironment:]` | `0x1855d1550` |
| `-[NSFocusController navigateWithCommand:]` | `0x1855d1680` |
| `-[NSFocusController selectKeyViewWithHeading:]` | `0x1855d187c` |
| `-[NSFocusController selectKeyViewFollowingView:]` | `0x1855d1ba0` |
| `-[NSFocusController firstResponderDidChange]` | `0x1855d2324` |
| `-[NSFocusController _primitiveFirstResponderDidChange]` | `0x1855d2384` |
| `-[NSFocusController _focusItemContainerForFocusSystem:]` | `0x1855d262c` |
| `-[NSFocusController _preferredFocusEnvironmentsForFocusSystem:]` | `0x1855d2698` |
| `-[NSFocusController _focusSystem:willUpdateFocusInContext:]` | `0x1855d279c` |
| `-[NSFocusController _focusSystem:didFinishUpdatingFocusInContext:]` | `0x1855d2874` |
| `-[NSFocusController _synchronizeFirstResponderForUpdate:]` | `0x1855d287c` |
| `-[NSFocusController _primitiveSynchronizeFirstResponderForUpdate:]` | `0x1855d2900` |
| `-[NSFocusController _tryToScrollForUpdateContext:]` | `0x1855d2f60` |
| `-[NSWindowFocusProxy initWithWindow:]` | `0x1855b79f8` |
| `-[NSWindowFocusProxy preferredFocusEnvironments]` | `0x1855b8920` |
| `-[NSWindowFocusProxy shouldUpdateFocusInContext:]` | `0x1855b8bf4` |
| `-[NSWindowFocusProxy didUpdateFocusInContext:]` | `0x1855b8bfc` |
| `-[NSViewFocusProxy initWithView:]` | `0x1859daf2c` |
| `-[NSViewFocusProxy canBecomeFocused]` | `0x1859dc7f4` |
| `-[NSViewFocusProxy preferredFocusEnvironments]` | `0x1859dc320` |
| `-[NSViewFocusProxy parentFocusEnvironment]` | `0x1859dc22c` |
| `-[NSViewFocusProxy focusItemContainer]` | `0x1859dc31c` |
| `-[NSViewFocusProxy focusItemsInRect:]` | `0x1859dbd10` |
| `-[NSWindowFocusProxy focusItemContainer]` | `0x1855b891c` |
| `-[NSAppKitFocusBehavior ...]`(全部默认 stub) | `0x185292bcc -` |
| `-[NSAppKitFocusBehavior focusDeferral]` | `0x185292bcc` |
| `-[NSWindow(NSFocusEngine_Internal) computed_focusController]` | `0x1859cb0fc` |
| `-[NSView(NSFocusEngine_Private) _focusProxy]` | `0x1854df6b0` |
| `-[NSViewHost makeFirstResponder:]` | `0x18534e5cc` |
| `-[NSViewHostingContext makeFirstResponder:]` | `0x18532d630` |
| `-[NSViewHostingContextRootView makeFirstResponder:]` | `0x18532bdec` |

### 4.4 FocusEngine.framework(运行时可达,非二进制内反编译)

以下类在原生 AppKit 进程中由 `_dyld_image_count` 验证为已加载,但本研究未进入 FocusEngine.framework 的反编译;路径下次研究可补:

| 符号 | 备注 |
|---|---|
| `UIFocusSystem` | 焦点引擎入口类(同名,与 UIKitCore 共用同一实现) |
| `UIFocusUpdateContext` | 焦点变更上下文(同名) |
| `@protocol UIFocusEnvironment` | 公有协议 |
| `@protocol UIFocusItem` / `UIFocusItemContainer` | 公有协议 |
| `@protocol _UIFocusSystemDelegate` | 私有协议 — NSFocusController 实现它 |
| `/System/Library/PrivateFrameworks/FocusEngine.framework/Versions/A/FocusEngine` | 二进制路径 |
