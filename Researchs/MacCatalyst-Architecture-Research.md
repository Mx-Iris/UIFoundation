# Mac Catalyst 架构深度研究

> 基于 macOS 26.4 dyld_shared_cache 中 AppKit、UIKitCore、UIKitMacHelper 的反编译
> IDA database: `UIKitCore+UIKitMacHelper+AppKit.i64`

## 0. 摘要

Mac Catalyst 不是"在 macOS 上重新实现 UIKit"，而是一种**在同一个进程内同时承载 AppKit 和 UIKit 两个 UI 框架**的设计：

- AppKit 和 UIKit 共存于同一地址空间（dyld 同时加载两者）
- AppKit 提供窗口、菜单、剪贴板、文档、共享面板等"宿主壳"
- UIKit 在自己的"小宇宙"里 layout/draw/composite，生成 CALayer 树
- UIKitMacHelper 是把两个框架粘合起来的胶水层，外加一层巧妙的非对称依赖管理

整个机制大量复用了 AppKit 早就存在的私有基础设施（最初为 iOS Simulator 设计的 `NSViewHost` / `NSViewHostingContext` 系统、CALayerHost 层托管、ViewBridge 跨进程 RVC、FBSScene IPC 协议、SoftLinking framework 等），并用 zippered binary + `_CFMZEnabled()` runtime gate 把它们组合成可以同时跑在 macOS native 和 macCatalyst 两种平台上的代码。

---

## 1. 二进制层：模块与依赖

### 1.1 三个模块的物理位置和平台标识

| Framework | 路径 | LC_BUILD_VERSION |
|---|---|---|
| **AppKit** | `/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit` | platform=1 (macOS) **+** platform=6 (catalyst) |
| **UIKitMacHelper** | `/System/Library/PrivateFrameworks/UIKitMacHelper.framework/Versions/A/UIKitMacHelper` | platform=1 **+** platform=6 |
| **UIKitCore** (catalyst) | `/System/iOSSupport/System/Library/PrivateFrameworks/UIKitCore.framework/Versions/A/UIKitCore` | platform=6 only |

- AppKit 和 UIKitMacHelper 都是 **zippered binary**：同一份 mach-o 通过两条 `LC_BUILD_VERSION` 命令同时声明支持 macOS native 和 maccatalyst 两个平台，dyld 在两种进程下都接受加载
- UIKitCore (catalyst variant) 物理位置在 `/System/iOSSupport/...` 子树下，只声明 maccatalyst 一个平台

### 1.2 LC_LOAD_DYLIB 依赖图

```
catalyst app (binary platform=6)
  ├─[DYLIB]→ UIKitCore (catalyst)
  │           ├─[DYLIB]→ AppKit (zippered)
  │           ├─[DYLIB]→ UIKitMacHelper (zippered)
  │           └─[DYLIB]→ UIKitServices
  │
  └─[DYLIB]→ Foundation, CoreFoundation, ...

UIKitMacHelper 自己的依赖（关键非对称）：
  ├─[DYLIB]→ AppKit                ✓ 硬依赖
  ├─[DYLIB]→ ViewBridge            ✓ 硬依赖（用于跨进程 RVC）
  ├─[DYLIB]→ UIKitServices         ✓
  ├─[DYLIB]→ FuseBoardServices     ✓ (in-process 伪 SpringBoard)
  ├─[DYLIB]→ BackBoardServices     ✓ (HID/事件)
  ├─[DYLIB]→ SkyLight              ✓ (WindowServer 私有接口)
  ├─[DYLIB]→ SoftLinking           ✓ (动态加载 UIKit 的 helper)
  └─[X]    UIKit / UIKitCore        ✗ 完全不在硬依赖中
```

**关键事实**：UIKitMacHelper **没有** LC_LOAD_DYLIB UIKit 或 UIKitCore。它对整个 UIKit 的访问全部通过 SoftLinking framework 在运行时按需加载（见 §9）。这是为了保持 zippered 兼容性——加载到 macOS native 进程时不能拖入 UIKit 的副作用。

### 1.3 这个非对称设计的物理含义

- 每个 catalyst app 启动时，由于 `UIKitCore → AppKit` 这条传递依赖，**AppKit dylib 必然被 dyld 加载到 catalyst 进程的地址空间**
- AppKit 的所有 ObjC class（`NSWindow`, `NSApplication`, `NSView`, `NSResponder`, `NSColor`, `NSFont` 等）在进程启动后已经注册到 ObjC runtime，`objc_getClass("NSWindow")` 能直接拿到
- 而 UIKitMacHelper 即使被加载到 macOS native 进程也"零副作用"——`+load` 中的 `_CFMZEnabled()` 检查会失败、SoftLinking 不会触发任何 dlopen、UIKit 永远不会被加载

---

## 2. UIKitMacHelper 的核心类（约 290 个 UINS* 类）

### 2.1 窗口 / 视图层桥接
| 类 | 父类 | 作用 |
|---|---|---|
| `UINSWindow` | **NSWindow** | catalyst scene 的 NSWindow 子类，每个 UIWindowScene 对应一个 |
| `UINSSceneWindowController` | **NSWindowController** | 持有 `UIScene`、管理 UINSWindow 生命周期；`-windowClass` 返回 `UINSWindow` |
| `UINSSceneViewController` | **NSViewController** | 持有 UIScene + UINSSceneView + UINSWindowProxy |
| `UINSSceneView` | **NSView** | layer-backed、`isFlipped=YES`，内含 `_zoomLayer` (CALayer) 和 `_sceneLayer` (USSLayerHost) |
| `USSLayerHost` | **CALayer** | 实际是对 `CALayerHost` 的薄封装，通过 `+layerHostForContextID:` 引用 UIKit 发布的远程 layer |
| `UINSSceneHostingView` | **NSView** | 将一个 UIWindow 嵌入任意 NSView 树的容器（用于辅助 hosting 场景） |

### 2.2 响应者 / 事件 / 输入桥接
| 类 | 父类 | 作用 |
|---|---|---|
| `UINSResponderProxy` | **NSResponder** | 把 UIKit responder 包装成 NSResponder，让 menu validation / responder chain 跨框架 |
| `UINSWindowProxy` | NSObject | 持有 `NSWindow *_attachedWindow` + `UIWindow *_uiWindow` 的双向桥接器 |
| `UINSEventTranslator` | NSObject | 早期（macOS 11 时代）的 NSEvent ↔ UIEvent 翻译器；macOS 26 中大部分方法已是空 stub，事件路由由 AppKit 内部的 NSViewHostingContextRootView 接管 |
| `UINSMouseEventTranslator` / `UINSGameEventTranslator` | NSObject | 鼠标和 game controller 事件翻译 |

### 2.3 应用生命周期桥接
| 类 | 父类 | 作用 |
|---|---|---|
| `UINSApplicationDelegate` | NSObject | UIApplicationDelegate 的 mac-side callback 容器（注意：不是 NSApplication 的 delegate） |
| `UINSApplicationLifecycleController` | NSObject | NSApp ↔ UIApp 双单例的状态机协调器 |
| `UINSAppKitBackgroundingController` | NSObject | 直接调用 `[NSApp setActivationPolicy:0]` 切换前台 |
| `UINSUIKitBackgroundingController` | NSObject | 控制 UIApplication background state |
| `UINSAppKitTerminationController` / `UINSUIKitTerminationController` | NSObject | 双侧终止协调 |
| `UINSAppLifecycleState*` (10+ 个状态类) | UINSAppLifecycleState | 状态机的具体状态：Inert、LaunchingToForeground、Running、Mummified、TerminatingPastPointOfNoReturn 等 |
| `NSApplication(UINSApplicationSwizzling)` | category | swizzle NSApplication 的 8+ 个方法 |

### 2.4 跨进程 RVC 客户端（ViewBridge 用户）
| 类 | 父类 | 实际服务 |
|---|---|---|
| `UINSShadowRemoteViewController` | **NSRemoteViewController** | 通用 ViewBridge shadow 基类，跟踪 UIViewController/UIView/UIWindow 三元组 |
| `UINSSystemPreferencesRemoteViewController` | **NSRemoteViewController** | 嵌入系统设置面板 |
| `UINSDocumentPickerViewController` | NSObject | 持有 NSOpenPanel/NSSavePanel，桥接 UIDocumentPickerVC |
| `UINSDocumentBrowserViewController` | NSObject | 嵌入 Files.app 文件浏览器 |
| `UINSCloudSharingController` | NSObject | iCloud 共享面板 |
| `UINSFontPickerController` | NSObject | 字体选择面板 |
| `UINSShareSheetController` | NSObject | 共享面板 |
| `UINSAlert` | NSObject | UIAlertController → NSAlert |
| `UINSShadowDatePicker`, `UINSOverlayDatePicker` | various | 日期选择器 popover |
| `UINSPDFPrintingView` | NSView | 打印面板桥接 |

注：参见 §10，理解为什么这些是 ViewBridge 客户端而不是 catalyst 自己的 layer hosting。

### 2.5 控件 / 工具栏桥接（AppKit 控件作为 UIControl 的实现后端）
- `NSPopUpButton+UINSPopUpButton`, `NSSegmentedControl+UINSSegmentedControl` — UIControl 的 AppKit native 实现
- `UINSSearchToolbarItem`, `UINSSharingToolbarItem`, `UINSReplicantToolbarItem`, `UINSToolbarItemSceneHostingView` — UIToolbar → NSToolbar 桥接
- `UINSPopupButtonCell` — 用于内嵌 popup 的 cell

### 2.6 拖放 / 剪贴板 / 输入
- `UINSDragManager`, `UINSDragSession`, `UINSDropSession`, `UINSDragImage`, `UINSDragItem` — 把 NSDragging* 协议桥接到 UIDrag* API
- `UINSDropFilePromiseReader`, `UINSDropFilePromisedReaderTemporaryDirectory` — 处理 file promise drop
- `UINSPasteboard`, `UINSPasteboardWritingItemProvider` — UIPasteboard ↔ NSPasteboard
- `UINSInputView`, `UINSKeyboardEventHandler-Protocol`, `UINSBlockTextInputDelegate` — 文本输入桥接
- `UINSBridgedSearchTextField` — UISearchBar → NSSearchField

### 2.7 游戏模式 / 触控模拟（macOS 14+ Game Mode + Touch Alternatives）
- `UINSGameModule`, `UINSGameModuleConfigViewController`
- `UINSGameModuleDigitizer`, `UINSGameModuleJoystick`, `UINSGameModuleSwipe`, `UINSGameModuleTap`, `UINSGameModuleTilt`, `UINSGameModuleTrackpadCapture`, `UINSGameModuleScrollDrag`, `UINSGameModuleSlider`, `UINSGameModuleMotion`
- `UINSVirtualDigitizer`, `UINSVirtualFinger`, `UINSVirtualMotionDevice` — 把鼠标键盘合成假触摸事件
- `UINSTouchAccommodationVisualizer`, `UINSTouchAlternativesConfigurationView`

---

## 3. 同进程渲染机制：layer 树是怎么从 UIKit 接到 NSView 上的

### 3.1 USSLayerHost 是 CALayerHost 的薄封装
```c
// 0x19E89EA68
+ (id)layerHostForContextID:(unsigned int)contextID
{
    CALayerHost *layer = [CALayerHost layer];      // 不是 USSLayerHost 自己，而是 CALayerHost
    [layer setContextId:contextID];
    [layer setValue:@YES forKeyPath:@"preservesFlip"];
    return layer;
}
```
USSLayerHost 类的 `setContextId:` 方法只有一行 `self->_contextId = a3;`——它实际上是一个空壳 wrapper，真正的 layer 实例是 AppKit 私有的 `CALayerHost`。

⚠️ **命名空间消歧义**：UIKitMacHelper 的 `USSLayerHost` 跟 `UIKitSystemAppServices.framework` 中的 `USS*` 类（`USSServicesClient`、`USS*Request`）**前缀巧合相同但属于不同的 framework**。USSLayerHost 落在 `UIKitMacHelper:__text @ 0x19E89EA68`，是 UIKitMacHelper 自己的私有 `CALayer` 子类；UIKitSystemAppServices 的 USS* 在 `UIKitSystemAppServices:__text @ 0x1CB34xxxx`，是 BSXPC 客户端 + `NSSecureCoding` payload 类，跟 USSLayerHost 没有继承关系。详见 §14.4。

### 3.2 UINSSceneView 的 layer 链
```
UINSSceneView (NSView)
  ├ wantsLayer = YES
  ├ isFlipped = YES   ← override 返回 1
  └ self.layer (NSView 自动创建的 CALayer)
        └─ _zoomLayer (CALayer)
              ├ transform = scale * counter-rotation
              ├ shouldRasterize = (zoom != 1.0)
              ├ rasterizationScale = backing scale
              ├ minificationFilter / magnificationFilter = (依据缩放选)
              └─ _sceneLayer (USSLayerHost = CALayerHost, preservesFlip=YES)
                    ├ contextId = UIKit 发布 layer 的 mach context ID
                    └─ <UIKit's full CALayer tree>  ← 远程引用
```

### 3.3 接入流程：`-[UINSSceneView _setHostedContextId:]`
```c
- (void)_setHostedContextId:(unsigned int)contextID
{
    [_sceneLayer removeFromSuperlayer];
    _sceneLayer = nil;
    if (contextID) {
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        _sceneLayer = [USSLayerHost layerHostForContextID:contextID];
        [_sceneLayer setPreloadsCache:YES];
        [_sceneLayer setBounds:CGRectZero];
        [_sceneLayer setPosition:CGPointZero];
        [_sceneLayer setAnchorPoint:CGPointZero];           // 左上角 anchor
        [_sceneLayer setTransform:CATransform3DIdentity];
        [_sceneLayer setShouldRasterize:NO];
        [_sceneLayer setMinificationFilter:kCAFilterNearest];
        [_sceneLayer setMagnificationFilter:kCAFilterNearest];
        [self _updateZoomLayer];
        [_zoomLayer setSublayers:@[_sceneLayer]];
        [CATransaction commit];
    }
}
```

CALayerHost + mach context ID 这套机制原本是为**跨进程图层托管**设计的（XPC remote view、ViewBridge），catalyst 把它用在了"同进程内、跨子系统"的 layer 引用：UIKit 子系统发布 layer，UIKitMacHelper 子系统通过 contextID 引用并显示。这种"自己引用自己进程发布的 context"的用法是 catalyst 设计的关键 reuse。

---

## 4. 坐标系翻转：三层 isFlipped 保险

### 4.1 NSView 层：UINSSceneView 强制 isFlipped=YES
```c
// 0x19E89BA8C
bool -[UINSSceneView isFlipped] { return 1; }
```
一旦 NSView.isFlipped=YES：
- frame/bounds 用 top-left origin
- `convertPoint:fromView:nil` 自动从 NSWindow (bottom-left) 转到自己 (top-left)，**不需要做 `windowHeight - y` 减法**
- sublayer 也按 top-left 排布

### 4.2 NSViewHosting 层：NSViewHostingTraits.flipped
```c
bool -[NSViewHostingTraits isFlipped] { return self->_flipped; }
```
当用 NSViewHost 嵌入 hosted view 时（见 §6），传入的 traits 对象 `_flipped=YES`，让整个 hosted 子树都按 UIKit 坐标系工作。

### 4.3 CALayerHost 层：preservesFlip
`[layer setValue:@YES forKeyPath:@"preservesFlip"]`——这是 CALayerHost 私有 KVC 属性。开启后，被托管的 UIKit layer tree 保留它原本的几何方向，不会被 NSView 的 layer geometry flip 状态二次翻转。

### 4.4 事件坐标转换
`-[UINSEventTranslator convertWindowLocationToSceneCoordinates:]`：
```c
CGPoint result = [sceneView convertPoint:windowLocation fromView:nil];
result = [sceneView convertPointToScene:result];
return result;
```
第一步利用 NSView 的 isFlipped 链路完成 Y 翻转，**完全不需要手动减法**。

---

## 5. 缩放与 HiDPI

### 5.1 三个 scale factor 的语义
- `sceneToSceneViewScaleFactor` — UIKit point ↔ NSView point 的缩放比，典型值：
  - `1.0` — "Optimize for Mac" 模式，UIKit 用 macOS point 排版
  - `0.77` — "Scale Interface to Match iPad" 模式（旧默认），UIKit 用 iPad point 排版后整体缩 77%
  - `1.5` — 某些设备/idiom 组合
- `backingScaleFactor` — NSWindow 的 retina 因子 (1.0 / 2.0)
- `rasterizationScaleFactor` — UIKit 内部 contentsScale

### 5.2 `-[UINSSceneView _updateZoomLayer]` 的滤镜选择
```c
double zoom = self.sceneToSceneViewScaleFactor;
double backing = self.window.backingScaleFactor;
double raster = self.rasterizationScaleFactor / backing;

if (fabs(zoom - raster) < 0.00005) {
    filter = kCAFilterNearest;       // 1:1 pixel-perfect
    rasterScale = 1.0;
} else if (fabs(zoom / 0.77 - raster) < 0.001 && raster <= 3.0) {
    filter = kCAFilterASG77;         // ★ 苹果专门为 0.77 写的滤镜
} else if (fabs(raster - 1.5) < 0.00005) {
    filter = kCAFilterASG;
} else if (zoom >= raster) {
    filter = kCAFilterLinearlySampledLinear;
} else {
    filter = kCAFilterASG;
}

[_zoomLayer setRasterizationScale:rasterScale];
[_zoomLayer setShouldRasterize:(fabs(zoom - raster) >= 0.00005)];
[_zoomLayer setMinificationFilter:filter];
[_zoomLayer setMagnificationFilter:filter];
```

**`kCAFilterASG77`** 是 CoreAnimation 的私有 CAFilter 名字，"ASG" 应该是 *Anisotropic Smoothed Gradient*。苹果**专门**为 catalyst 的 0.77 这一个非整数缩放比例编写了优化滤镜——这是 catalyst 早期"iPad 模式"在 mac 上不糊的关键。

### 5.3 Retina 处理
`-[UINSSceneView viewDidChangeBackingProperties]`：
```c
[self _updateRasterizationScaleFactor];
[self _updateUIKitSceneProperties];
```
当窗口被拖到不同 retina 屏幕时，重新计算 scale 并通过 FBSScene 通知 UIKit。

---

## 6. 几何同步：FBSScene + BKSAnimationFenceHandle

### 6.1 触发链
```
NSWindow 被 user 拖动缩放
  ↓
NSView 收到 setFrameSize:
  ↓
NSView 触发 layout
  ↓
-[UINSSceneView layout] (0x19E89C098)
   [CATransaction begin]
   [self _updateUIKitSceneProperties]   ← 关键
   [super layout]
   [self _updateZoomLayer]
   [CATransaction commit]
```

### 6.2 `_updateUIKitSceneProperties` 的实际工作
```c
// 0x19E923A44 (简化)
- (void)_updateUIKitSceneProperties
{
    // 1. 创建 BackBoardServices animation fence 同步 AppKit ↔ UIKit 动画
    id fence = [BKSAnimationFenceHandle newFenceHandleForContext:self.layer.context];
    [windowScene _synchronizeDrawingWithFence:fence];
    [fence invalidate];

    // 2. 把 NSView bounds 转换为 UIKit scene 坐标
    CGSize sceneSize = [self convertSizeToScene:self.bounds.size];
    sceneSize.width = ceil(sceneSize.width);
    sceneSize.height = ceil(sceneSize.height);

    // 3. 收集所有几何/显示参数
    double scale = self.rasterizationScaleFactor;
    BOOL P3 = [self.window canRepresentDisplayGamut:NSDisplayGamutP3];
    NSEdgeInsets insets = self.sceneContentInsets;
    unsigned displayID = [self.window.screen.deviceDescription[@"NSScreenNumber"] unsignedIntValue];

    // 4. 防抖：和上次发送的对比
    if (sizesEqual && other params unchanged) return;

    // 5. ★ 通过 FrontBoardServices 通知 UIKit
    UINSWorkspace *workspace = [UINSWorkspace sharedInstance];
    FBSScene *fbsScene = [workspace fbsSceneForSceneIdentifier:_sceneIdentifier error:nil];

    [fbsScene updateClientSettingsWithBlock:^(FBSMutableSceneClientSettings *settings) {
        settings.size = sceneSize;
        settings.contentInsets = insets;
        settings.scale = scale;
        settings.displayID = displayID;
        settings.gamut = P3;
    }];
}
```

### 6.3 关键洞察
- **catalyst 进程内的 `FBSScene` 是一个 IPC 客户端代理**，对端不是 in-process 的 stub，而是 macOS 上的独立 daemon 进程 `UIKitSystem.app`（`com.apple.UIKitSystemApp`）内由 `FuseBoard.framework` server 端实现的"假 SpringBoard / FBSceneManager"。FBSWorkspace 通过 mach 端口 `com.apple.frontboard.systemappservices` 与 daemon 双向通信。详见 §14
- 因此"Catalyst 同进程 layer hosting"应当精确表述为：**渲染** in-process（UIKit layer tree 在 catalyst 进程内 build & composite），**场景元数据 / 生命周期** out-of-process（settings、`fu_hostingContextID`、resize、active state 等都通过 XPC 与 daemon 同步）
- UIKitMacHelper 在 catalyst 进程内扮演"FBSScene 客户端 + 几何/坐标桥接"：把 NSWindow 的几何变化通过 FBSScene 客户端协议反向通知 daemon
- UIKit 端的 UIWindowScene 接收 `client settings` 变更 → 触发 traitCollection 变更 → 触发 layout → 重新发布 layer → USSLayerHost 显示
- **`BKSAnimationFenceHandle`** 让 NSWindow 的 frame 动画与 UIKit 的 layout 动画在 CARenderServer 内**严格同步提交**，避免 resize 时撕裂

---

## 7. 事件路由：复用 AppKit 私有 NSViewHost 基础设施

### 7.1 NSViewHost 三件套
catalyst 没有自己写一套事件路由，而是复用了 AppKit 早期为 **iOS Simulator** 设计的私有 view hosting 系统：

```
NSViewHost : NSView                      (0x18534E4BC)
  ├ _context: NSViewLayerHostingContext
  │    └ _rootView: NSViewHostingContextRootView   ← 假装自己是 NSWindow.contentView
  │         ├ _isViewRoot = YES                    ← 私有协议，标记 view root
  │         ├ _firstResponder (weak)               ← 自己的 first responder
  │         ├ _trackingAreas / _activeTrackingAreas (NSMutableSet)  ← 自己的 tracking 系统
  │         ├ _hostingContext (weak)
  │         ├ _contentView                         ← 真正的 hosted view（catalyst 里就是 UIKit 的 view root）
  │         ├ _traits (NSViewHostingTraits, copy)
  │         └ wantsLayer=YES, masksToBounds=NO
  │
  └ _layerHost: CALayerHost                       ← 又一个独立的 CALayerHost
```

`-[NSViewHost initWithView:traits:delegate:]` 反编译：
```c
self = [super init];
self->_context = [[NSViewLayerHostingContext alloc] initWithContentView:contentView 
                                                                  traits:traits 
                                                                delegate:self];
self->_layerHost = [[CALayerHost alloc] init];
objc_storeWeak(&self->_delegate, delegate);
```

### 7.2 NSViewHostingContextRootView 是个伪 NSWindow.contentView
```c
bool -[NSViewHostingContextRootView _isViewRoot] { return 1; }
```

它实现了一套完整的"NSWindow.contentView 行为"：
- `firstResponder`, `makeFirstResponder:`
- `nextEventMatchingMask:untilDate:inMode:dequeue:` —— 自己的 event 队列
- `sendEvent:`, `sendMouseEntered:`, `sendMouseExited:`, `sendMouseMoved:` —— 自己的事件分发
- `keyDown:`, `keyUp:`, `flagsChanged:`
- `_setTrackingRect:inside:owner:userData:useTrackingNum:` —— 自己的 tracking 系统
- `_displayScale`, `isInKeyWindow`, `isVisible`, `hasKeyAppearance`
- `_setWantsToHostAutolayoutEngine:YES` —— 自己有独立的 NSISEngine

### 7.3 `-[NSViewHostingContextRootView sendEvent:]`
```c
- (void)sendEvent:(NSEvent *)event {
    NSEventType type = event.type;
    NSResponder *target;
    
    if ((1 << type) & 0x46) {              // mouseDown / rightDown / otherDown
        target = [self _hitTestForEvent:event];
    } else if ((1 << type) & 0x320) {      // mouseEntered / Exited / Moved
        target = self;
    } else {                               // keyDown / keyUp / flagsChanged
        target = [self firstResponder] ?: self;
    }
    
    switch (type) {
        case 1:  [target mouseDown:event];      break;
        case 2:  [target mouseUp:event];        break;
        case 5:  [self sendMouseMoved:event];   break;
        case 6:  [target mouseDragged:event];   break;
        case 8:  [self sendMouseEntered:event]; break;
        case 9:  [self sendMouseExited:event];  break;
        case 10: [target keyDown:event];        break;
        case 11: [target keyUp:event];          break;
        case 12: [target flagsChanged:event];   break;
    }
}
```

`-[NSViewHostingContextRootView sendMouseMoved:]` 是 200+ 行的完整 NSTrackingArea 系统再实现：维护两个 NSMutableSet (`_activeTrackingAreas`, `_trackingAreas`)，每次 mouseMoved 计算 enter/exit/move 并构造 `+[NSEvent enterExitEventWithType:...]` 发送给 owner。

### 7.4 完整事件流
```
WindowServer → NSEvent
  ↓
NSApplication run loop → -[NSApplication sendEvent:] 
  (被 _uinsSwizzledSendEvent: 加了 catalyst-defined event 过滤)
  ↓
NSWindow sendEvent:
  ↓ (NSView hit test 命中 NSViewHostingContextRootView，因为它 _isViewRoot=YES)
  ↓
-[NSViewHostingContextRootView sendEvent:]
  ↓ (NSView 自动 Y 翻转坐标)
  ↓ (派发到 first responder 或 hit-tested view)
  ↓
hosted view (UIKit 端)
  ↓ UIKit 内部把 NSEvent 转换为 UITouch / UIPress
  ↓
UIResponder.touchesBegan: / pressesBegan: ...
```

注意：UINSEventTranslator 的 `mouseDown:`/`mouseUp:` 等方法在 macOS 26 已经是单条 `RET` 指令，事件路由的工作完全由 AppKit 的 NSViewHostingContextRootView 接管。UINSEventTranslator 现在主要在反向场景使用（把 IOHIDEvent 翻译回 NSEvent）。

---

## 8. Application 双子模式与 Swizzling

### 8.1 双单例
catalyst 进程内同时存在：
- `NSApplication *NSApp` — AppKit 单例，管理菜单、文档、剪贴板、激活策略等
- `UIApplication *UIApp` — UIKit 单例，管理 UIScene、UIWindow、UIResponder chain 等

### 8.2 UINSApplicationLifecycleController 状态机
持有以下 controller，互相协调：
- `UINSAppKitBackgroundingController` ↔ `UINSUIKitBackgroundingController`
- `UINSAppKitTerminationController` ↔ `UINSUIKitTerminationController`
- `UINSWindowStateController`

`-[UINSAppKitBackgroundingController _becomeForegroundIfNecessary]`：
```c
LSApplicationASN asn = _LSGetCurrentApplicationASN();
CFTypeRef appType = _LSCopyApplicationInformationItem(-2, asn, kLSApplicationTypeKey);
if (CFEqual(appType, kLSApplicationForegroundTypeKey)) return YES;
return [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
```
直接用 LaunchServices 检查类型 + 直接调 `[NSApp setActivationPolicy:]`。

### 8.3 NSApplication swizzling
`+[NSApplication(UINSApplicationSwizzling) load]`：
```c
+ (void)load {
    if (_CFMZEnabled()) {
        objc_msgSend(self, "_uinsExchangeImplementation:with:", @"sendEvent:", @"_uinsSwizzledSendEvent:");
        objc_msgSend(self, "_uinsExchangeImplementation:with:", @"isActive", @"_uinsSwizzledIsActiveApp");
        objc_msgSend(self, "_uinsExchangeImplementation:with:", @"showHelp:", @"_uinsSwizzledShowHelp:");
        objc_msgSend(self, "_uinsExchangeImplementation:with:", @"orderFrontStandardAboutPanel:", @"_swizzledOrderFrontStandardAboutPanel:");
        // ... 共 8 个 method exchange ...
    } else {
        os_log_error("UIKitMacHelper.framework is loaded into a non-MacCatalyst process. This is harmless, but likely incorrect.");
    }
}
```

`_CFMZEnabled` 是 CoreFoundation 的导出函数（MZ = Mac Zippered）。它返回当前进程是否运行在 catalyst ABI 下。整个 swizzling 被这个 gate 包裹，确保只在 catalyst 模式激活。

`_uinsSwizzledSendEvent:` 实际做的事情：
```c
- (void)_uinsSwizzledSendEvent:(NSEvent *)event {
    id delegate = [self delegate];
    if ([delegate respondsToSelector:@selector(shouldPreventAppFromAppearingInactive)]
        && [delegate shouldPreventAppFromAppearingInactive]
        && event.type == 13                              // NSEventTypeAppKitDefined
        && event.subtype <= 22
        && ((1 << event.subtype) & 0x400014) != 0) {
        // 静默吞掉特定的 AppKit-defined 事件
    } else {
        [self _uinsSwizzledSendEvent:event];             // 调用原 sendEvent:
    }
}
```

---

## 9. SoftLinking：UIKitMacHelper 是怎么"运行时找到 UIKit"的

### 9.1 苹果内部的 SoftLinking.framework
UIKitMacHelper 硬链 `/System/Library/PrivateFrameworks/SoftLinking.framework/Versions/A/SoftLinking`，但**不**硬链 UIKit 或 UIKitCore。所有对 UIKit 符号的访问都通过 SoftLinking framework 在运行时按需加载。

参考：WebKit 在 `Source/WTF/wtf/cocoa/SoftLinking.h` 提供了等价的开源宏实现。苹果内部的 SoftLinking.framework 是闭源的，但可以从 WebKit 的开源版本理解其设计哲学。

### 9.2 SoftLinking 模板的实际产物
WebKit `SOFT_LINK_FRAMEWORK(framework)` 宏生成：
```c
static void* frameworkLibrary() {
    static void* dylib = ^{
        void* result = dlopen("/System/Library/Frameworks/" #framework ".framework/" #framework, RTLD_NOW);
        RELEASE_ASSERT_WITH_MESSAGE(result, "%s", dlerror());
        return result;
    }();
    return dylib;
}
```

苹果版本生成的代码几乎一样，只是底层调用换成 `_sl_dlopen`。在 IDB 中，UIKitMacHelper 有 **5 个独立的 `UIKitLibrary()` 副本**（IDA 自动加 `_0`, `_1`, `_2`, `_3` 后缀），每个对应一个引用了 UIKit 的 .m 文件——这是 SoftLinking 宏的 `static` 关键字导致的去重失败，正是这个宏的指纹。

第一个 `UIKitLibrary()` 反编译（0x19e8bd748）：
```c
void *UIKitLibrary()
{
    char *outError = NULL;
    if (!UIKitLibraryCore_frameworkLibrary) {
        block_t b = ^{ /* __UIKitLibraryCore_block_invoke_0 */ };
        sl_framework_descriptor_t desc = *(sl_framework_descriptor_t *)&off_1E6574E50;
        UIKitLibraryCore_frameworkLibrary = _sl_dlopen(&desc, &outError);
    }
    if (!UIKitLibraryCore_frameworkLibrary) {
        [[NSAssertionHandler currentHandler]
            handleFailureInFunction:@"void *UIKitLibrary(void)"
                               file:@"UINSApplicationDelegate.m"
                         lineNumber:87
                        description:@"%s", outError];
    }
    if (outError) free(outError);
    return UIKitLibraryCore_frameworkLibrary;
}
```

### 9.3 SoftLinking framework descriptor 的结构
`off_1E6574E50` 是一个 16 字节的描述符，包含 primary + fallback 两个路径：

| 描述符 | 用途 | primary | fallback |
|---|---|---|---|
| `off_1E6574E50` | UIKit | `/System/Library/Frameworks/UIKit.framework/UIKit` | `/System/Library/Frameworks/UIKit.framework/Contents/MacOS/UIKit` |
| `off_1E6574CA8` | UIKitCore | `/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore` | `/System/Library/PrivateFrameworks/UIKitCore.framework/Contents/MacOS/UIKitCore` |

**这两个路径在 macOS 物理文件系统上根本不存在！** 真实位置是：
- `/System/iOSSupport/System/Library/Frameworks/UIKit.framework/Versions/A/UIKit`
- `/System/iOSSupport/System/Library/PrivateFrameworks/UIKitCore.framework/Versions/A/UIKitCore`

如果直接用裸 `dlopen()`（像 WebKit 开源宏那样），在 catalyst 进程内会立刻失败。`_sl_dlopen` 的核心价值就是它知道 catalyst 平台下的 dyld 路径重映射规则——它内部会按平台自动把 iOS 风格路径转换到 iOSSupport 子树下的实际位置。

这就是为什么 SoftLinking 必须存在：它让一份 UIKitMacHelper 源代码（写得"看起来像 iOS 上的 UIKit consumer"）可以同时跑在 iOS、Catalyst、iOS Simulator 多个平台上。

### 9.4 dlsym 用法对应 SOFT_LINK_POINTER
之前在 `viewDidMoveToWindow` 看到的：
```c
v15 = UIKitLibrary_3();
v16 = j__dlsym(v15, "UIApplicationStatusBarHeightChangedNotification");
qword_1EC4CCFE8 = ...;

v20 = UIKitLibrary_3();
v21 = j__dlsym(v20, "UIApp");
qword_1EC4CCFF0 = ...;
```
对应 WebKit `SOFT_LINK_POINTER(UIKit, UIApp, UIApplication *)` 的展开：
```c
static UIApplication * pointerUIApp;
static UIApplication * initUIApp() {
    void** pointer = (void**)dlsym(UIKitLibrary(), "UIApp");
    pointerUIApp = (UIApplication *)*pointer;     // 解一层引用
    getUIApp = UIAppFunction;
    return pointerUIApp;
}
```

### 9.5 与"harmless 加载到非 catalyst 进程"的关系
UIKitMacHelper 没有硬链 UIKit/UIKitCore，所以当它被加载到 macOS native 进程时：
1. dyld 不会强制加载 UIKit
2. `+load` 跑，但 `_CFMZEnabled()` 返回 false
3. 没有任何 `_sl_dlopen` 被调用
4. UIKit 永远不会被加载到这个进程
5. 所有 UINS* 类的方法只要不被调用，引用的 UIKit 符号都是 lazy unresolved 的

这就是 "harmless" 的物理含义。SoftLinking 是 zippered binary 设计的关键基础设施。

### 9.6 IDB 中找到的 SoftLinking 痕迹
```
0x19e8bd748  UIKitLibrary
0x19e8d23b4  UIKitLibrary_0           ← UINSWindow.m
0x19e8ecaa4  UIKitLibrary_1
0x19e8f2814  UIKitLibrary_2
0x19e9258ec  UIKitLibrary_3           ← UINSSceneView.m:48
0x19e8a993c  UIKitCoreLibrary         ← NSUIImageUpcallStubs.m:13
0x19e8c188c  UIKitCoreLibrary_0
0x19e93ffbc  UIKitCoreLibrary_1
0x19e94ff08  j__sl_dlopen             (PLT stub to SoftLinking framework)

___UIKitLibraryCore_block_invoke
___UIKitLibraryCore_block_invoke_0
___UIKitLibraryCore_block_invoke_1
___UIKitLibraryCore_block_invoke_2
___UIKitLibraryCore_block_invoke_3
___UIKitLibraryCore_block_invoke_4
```

---

## 10. ViewBridge 的真实角色 ⚠️

**重要纠正**：ViewBridge **不是** catalyst 自己用来 host UIView 的机制。

### 10.1 ViewBridge 的真实定义
ViewBridge.framework 是 macOS（也存在于 iOS 上对应的 `RemoteViewServices` / `_UIRemoteView` 早期实现）的 **跨进程 view controller hosting** 框架，专为**沙箱隔离 + 数据敏感** UI 场景设计。它的核心 API 是 `NSRemoteViewController` —— 一个本地 ViewController 子类，背后真实的 ViewController 跑在另一个 XPC 进程里，通过 `NSXPCConnection` 远程调用。

**典型用例（在 catalyst 之前就已经存在）**：

| 场景 | 主进程类 | 服务进程 |
|---|---|---|
| 文件选择 | `NSOpenPanel` / `NSSavePanel` | `com.apple.appkit.xpc.openAndSavePanelService` |
| 共享面板 | `NSSharingService*` | `com.apple.ShareKit.shareKitHelper` |
| 字体面板 | `NSFontPanel` | `com.apple.fontd` 的 view service |
| 系统设置面板 | 系统设置子面板 | 系统设置守护进程 |
| 通知权限 | TCC prompt | `com.apple.tccd` |
| 钥匙串确认 | 密码确认对话框 | `com.apple.security.agent` |

**为什么要这样设计**：主 app（沙箱）不能直接访问用户文件系统，所以让一个独立的、有特殊权限的进程渲染文件选择器，主 app 只能"看到"用户最终选中的 URL。这是 macOS 沙箱模型的核心机制。

iOS 上对应的是 `RemoteViewController`（很早就存在），用于联系人选择、照片选择、邮件 compose 等系统提供的"代用 ViewController"。

### 10.2 ViewBridge 在 catalyst 中的实际用途
catalyst 通过 UIKitMacHelper 把 UIKit 的 picker / sharing / preferences API **映射到 macOS 上已有的这些 RVC 服务**：

```
catalyst app: presentViewController:UIDocumentPickerViewController
       ↓
UIKitMacHelper: UINSDocumentPickerViewController.m
       ↓ 直接构造 NSOpenPanel
       ↓
[NSOpenPanel beginSheetModalForWindow:...]
       ↓ AppKit 内部
       ↓ NSRemoteOpenPanel (NSRemoteViewController 子类)
       ↓ NSXPCConnection
       ↓
com.apple.appkit.xpc.openAndSavePanelService（独立进程）
       ↓ 真正的 NSOpenPanel UI 在这里渲染
```

确认证据：
- `UINSDocumentPickerViewController` 持有 `NSOpenPanel *_openPanel` 和 `NSSavePanel *_savePanel` ivars——它**直接**构造原生 NSOpenPanel 让 AppKit 通过 ViewBridge 走 RVC
- `UINSSystemPreferencesRemoteViewController : NSRemoteViewController`——直接是 NSRemoteViewController 的子类，是真正的 ViewBridge 客户端
- `UINSShadowRemoteViewController : NSRemoteViewController`——通用基类，跟踪 `UIViewController *_trackedViewController`、`UIView *_trackedView`、`UIWindow *_trackedUIWindow` 三元组

### 10.3 ViewBridge ≠ catalyst 主 scene 的 layer hosting

| 特性 | catalyst 主 scene 的 layer hosting | ViewBridge / NSRemoteViewController |
|---|---|---|
| 进程模型 | **同进程**：UIKit 和 AppKit 在同一个 catalyst 进程地址空间 | **跨进程**：主 app + 独立 service 进程通过 XPC 通信 |
| 实现机制 | NSViewHost / NSViewHostingContextRootView / CALayerHost (mach context ID) | NSRemoteViewController / NSXPCConnection / 也是 CALayerHost (mach context ID) |
| 用途 | 让 UIKit 在 catalyst 进程内渲染 | 沙箱隔离的数据敏感 UI（文件选择、系统设置、通知等） |
| 是不是 catalyst 引入的 | catalyst 用了，但 NSViewHost 早在 iOS Simulator 时代就存在 | 完全不是为 catalyst 设计的，macOS / iOS 上都早已存在 |

两者底层都用到了 **CALayerHost + mach context ID** 这个 CoreAnimation 原语（这是 layer 跨边界引用的通用机制），但**用途和目的完全不同**。之前把 ViewBridge 笼统称为"远程 view hosting"是不准确的。

---

## 11. iosmac-abi 下使用 AppKit 的可行性

### 11.1 决定性证据

**证据 A：AppKit 是 zippered binary**
```
AppKit HEADER:
  LC_BUILD_VERSION: platform=1 minos=0x1a0400 sdk=0x1a0400  ← macOS
  LC_BUILD_VERSION: platform=6 minos=0x1a0400 sdk=0x1a0400  ← MacCatalyst
```

**证据 B：AppKit.tbd 显式列出 maccatalyst targets**
```yaml
# /Applications/Xcode.app/.../MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit.tbd
targets: [ x86_64-macos, x86_64-maccatalyst, arm64e-macos, arm64e-maccatalyst ]
install-name: '/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit'
```

**证据 C：苹果亲自编译了 AppKit 的 maccatalyst Swift 接口**
```
/Applications/Xcode.app/.../MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Versions/C/Modules/AppKit.swiftmodule/
├── arm64e-apple-ios-macabi.swiftinterface     ← maccatalyst!
├── x86_64-apple-ios-macabi.swiftinterface     ← maccatalyst!
├── arm64e-apple-macos.swiftinterface
└── x86_64-apple-macos.swiftinterface
```
swift-module-flags: `-target arm64e-apple-ios26.4-macabi -enable-objc-interop ...`，并用 `@available(macCatalyst 18.0, macOS 15.0, *)` 标注。

**证据 D：UIKitCore (catalyst variant) 直接 LC_LOAD_DYLIB AppKit**
每个 catalyst app 启动时 AppKit dylib 必然被加载。

**证据 E：UIKitMacHelper 自身就在 catalyst 进程内疯狂调用 AppKit**
`[NSApp setActivationPolicy:0]`、`[NSWindow setStyleMask:]`、KVO 监听 `NSWindowDidEnterFullScreenNotification` 等等。

### 11.2 唯一的"限制"
- iOSSupport SDK 子树 (`/System/iOSSupport/System/Library/Frameworks/`) **不包含** AppKit.framework
- Xcode 编译 catalyst target 时 framework search path 优先指向 iOSSupport 子树
- 默认情况下 `import AppKit` 找不到 module

### 11.3 突破方法
1. **Build Settings → Other Linker Flags** 加 `-Wl,-framework,AppKit`，或者干脆直接 `import AppKit` 配合手动 framework search path
2. **运行时反射**：`objc_getClass("NSWindow")` + `objc_msgSend` 永远可用，无需任何配置
3. **dlopen**：`dlopen("/System/Library/Frameworks/AppKit.framework/AppKit", RTLD_NOW)` 一定成功，因为 AppKit 已经被 UIKitCore 加载

### 11.4 苹果**没有**采取的阻止机制
- ❌ dyld 拒绝加载 AppKit 到 catalyst 进程
- ❌ AppKit 内部 `_CFMZEnabled()` 检测后罢工
- ❌ AppKit.tbd 排除 maccatalyst target
- ❌ 不为 catalyst 编译 AppKit.swiftmodule
- ❌ 在 macOS SDK 中删除 AppKit headers

### 11.5 结论
**苹果通过 SDK 路径配置进行的"软隐藏"，而不是物理或运行时限制。AppKit 在 iosmac-abi 下完全可用。**

---

## 12. 把所有兼容问题串起来的对照表

| 问题 | 解决机制 |
|---|---|
| iOS top-left vs macOS bottom-left 坐标系 | `UINSSceneView.isFlipped=YES` + `NSViewHostingTraits.flipped=YES` + `CALayerHost.preservesFlip=YES` 三层保险 |
| UIView 渲染到屏幕 | UIKit 把 layer 树发布到 mach context ID → `CALayerHost` 通过 contextID 引用 → 嵌入 NSView 的 layer 树 |
| iPad point → Mac 物理像素 | `_zoomLayer.transform` 缩放；`kCAFilterASG77` 等专用 CAFilter 抗锯齿；`shouldRasterize=YES` 加速 |
| NSWindow resize ↔ UIKit 几何同步 | layout → `_updateUIKitSceneProperties` → `[FBSScene updateClientSettingsWithBlock:]`；`BKSAnimationFenceHandle` 同步动画 |
| Retina backing scale | `viewDidChangeBackingProperties` → `_updateRasterizationScaleFactor` → 通过 FBSScene 重新发布 |
| NSEvent ↔ UITouch | `NSViewHostingContextRootView` 拦截 NSWindow.sendEvent 后路由到 hosted UIView |
| NSTrackingArea (鼠标 hover) | NSViewHostingContextRootView 自实现完整的 tracking area 系统 |
| First responder 跨框架 | NSViewHostingContextRootView 有自己的 firstResponder；`UINSResponderProxy : NSResponder` 包装 UIResponder 出现在 NSResponder chain |
| Autolayout 引擎冲突 | `_setWantsToHostAutolayoutEngine:YES`：view root 自带 NSISEngine；`UINSBridgingLayoutConstraint` 桥接 |
| 应用生命周期（前后台、终止） | `UINSApplicationLifecycleController` 状态机 + 直接调 `[NSApp setActivationPolicy:]` |
| 菜单 / Touch Bar / 共享 | `UINSWindowProxy` 注入 NSToolbar/NSTouchBar/NSSharingService 到 NSWindow，回调 UIKit responder chain |
| 文件选择 / 系统设置 / 共享面板 | 通过 ViewBridge / NSRemoteViewController 走原生 macOS XPC 服务（`UINSDocumentPickerViewController` → NSOpenPanel；`UINSSystemPreferencesRemoteViewController : NSRemoteViewController` 等） |
| UIKit 在 zippered binary 中的依赖 | SoftLinking framework + `_sl_dlopen` + framework descriptor 双路径 fallback + 平台路径重映射 |
| UIKitMacHelper 加载到非 catalyst 进程 | `+load` 中 `if (_CFMZEnabled()) { swizzle }` gate + SoftLinking lazy 加载，整体零副作用 |

---

## 13. 待验证 / 未深入的问题

1. **`_CFMZEnabled` 的具体实现**：它是 CoreFoundation 导出符号 (`__CFMZEnabled`)，需要在 CoreFoundation IDB 中验证它是基于 `dyld_get_active_platform()` 还是其他方式判断 catalyst 进程
2. **`_sl_dlopen` 的内部路径重映射规则**：是查 dyld 接口、还是 SoftLinking 自己维护一张表？需要 IDB load SoftLinking.framework 验证
3. ~~**FBSScene 在 catalyst 进程内的具体实现**~~ ✅ **已解答（详见 §14）**：FBSScene 在 catalyst 进程内是 **IPC 客户端代理**，对端是 `UIKitSystem.app` daemon 进程内由 `FuseBoard.framework` server 创建的真实场景对象。FBSWorkspace 连接的 mach 端口是 `com.apple.frontboard.systemappservices`
4. **catalyst 进程内的 BKSHIDEvent 投递路径**：HID 事件是从 NSEvent 翻译过来，还是 BackBoardServices 直接对接 hidd？
5. **ViewBridge 在 macOS 26 是否还原生支持 maccatalyst 平台 RVC**：之前所有 `NSRemote*` 类是 zippered 还是只有 macOS native 平台
6. **macOS 26 引入的 Liquid Glass** 在 catalyst 中的实现：UIKitMacHelper 中有 `NSGlassAwareView-Protocol.h`，需要看它是怎么把 glass effect 应用到 catalyst window 的

---

## 14. UIKitSystem.app daemon 与 services framework 链

之前的 §1-§13 聚焦在 catalyst 进程**内部**的桥接机制。本节补充另一条横跨进程边界的机制：catalyst 进程跟 macOS 上一个独立守护进程 **`UIKitSystem.app`** 之间的关系，以及联系它们的 **`UIKitServices.framework`** 和 **`UIKitSystemAppServices.framework`**。

> IDA database: `UIKitSystem.app/Contents/MacOS/UIKitSystem.i64`（UIKitSystem daemon 自身）
> UIKitServices / UIKitSystemAppServices 已加载到 `UIKitCore+UIKitMacHelper+AppKit.i64`

### 14.1 三者的物理形态

| 目标 | 类型 | Bundle ID / 位置 | 命名前缀 |
|---|---|---|---|
| **`UIKitSystem.app`** | macOS background daemon (`LSBackgroundOnly=YES`) | `com.apple.UIKitSystemApp`；`/System/Library/CoreServices/UIKitSystem.app/` | — |
| **`UIKitServices.framework`** | dylib (zippered) | `/System/Library/PrivateFrameworks/UIKitServices.framework/` | **`UIS`** |
| **`UIKitSystemAppServices.framework`** | dylib (zippered) | `/System/Library/PrivateFrameworks/UIKitSystemAppServices.framework/` | **`USS`** |

### 14.2 UIKitSystem.app —— catalyst 体系的"假 SpringBoard 守护进程"

#### 14.2.1 自我描述

`main()` 在参数检查失败时打印（原始字符串字面量）：

> "UIKitSystem.app is the **system shell for iosmac applications**. It cannot be started directly."

Apple 用了 **iosmac** 一词。这是一个由 launchd 按需启动的 daemon，不能由用户直接运行，必须通过 `system_app_start` 参数触发。

#### 14.2.2 Info.plist 注册的服务

```
BSServiceDomains → com.apple.frontboard:
  MachName: com.apple.frontboard.systemappservices
  Services:
    com.apple.frontboard.system-service
    com.apple.frontboard.workspace-service  (DefaultWorkspace = FBSceneManager)
    com.apple.fuseboard.accessibility-service

UIDeviceFamily: [ 2 ]                  ← 向系统注册为"iPad class"设备
UIRequiredDeviceCapabilities: [ x86_64 ]
```

关键：默认 workspace 是 **`FBSceneManager`**——即 FrontBoardServices 的场景管理器在这个 daemon 进程内运行。

#### 14.2.3 main 的全貌

```c
// 反编译自 UIKitSystem.i64, _main @ 0x1000032D0
int main(int argc, const char **argv) {
    // 1. 必须 ./UIKitSystem system_app_start
    if (argc != 2 || ![argv[1] isEqual:@"system_app_start"]) {
        os_log_error("UIKitSystem.app is the system shell for iosmac applications. "
                     "It cannot be started directly.");
        exit(64);
    }

    // 2. 把自己注册到 WindowServer + LaunchServices（绕过 AppKit）
    CGSMainConnectionID();
    void *h = dlopen("/.../HIServices.framework/HIServices", RTLD_NOW|RTLD_LOCAL);
    ((void(*)(int))dlsym(h, "_RegisterApplication"))(0);
    ((void(*)(void))dlsym(h, "_SignalApplicationReady"))();
    [[LSApplicationWorkspace defaultWorkspace]
        registerApplication:[NSBundle mainBundle].bundleURL];

    // 3. 把 WindowServer 的 CGEvent 端口接入 main run loop
    installEventRunLoopSource();   // CGSGetEventPort → CFMachPort → CFRunLoopSource

    // 4. 把整个 SpringBoard 模拟逻辑交给 FuseBoard
    FUServerInitialize();          // ← 唯一的实质调用
    [[NSRunLoop mainRunLoop] run]; // 永驻
}
```

#### 14.2.4 关键观察

- **极薄的 launcher**：整个 mach-o 只有 31 项 imports，没有 UIKit / UIKitCore / UIKitMacHelper / AppKit 中任何一个
- **`FUServerInitialize` 来自 iOSSupport 路径**：`/System/iOSSupport/System/Library/PrivateFrameworks/FuseBoard.framework`——FuseBoard 是 SpringBoard 在 catalyst 模式下的服务端实现
- **绕过 AppKit 注册 GUI app**：用 `dlopen HIServices` + 私有 `_RegisterApplication` / `_SignalApplicationReady`，因为它不链接 AppKit
- **CGEvent 接收**：`installEventRunLoopSource` 通过 `CGSGetEventPort` 拿 WindowServer 事件 mach port，把 CGEvent 接入 run loop——为 FuseBoard server 提供事件输入

### 14.3 UIKitSystemAppServices —— catalyst 调用 daemon 的高层 wrapper

这个 framework 只有 8 个公开类：`USSServicesClient`（XPC client）+ 7 个 `USS*Request`（`NSSecureCoding` payload：Background / SceneActive / SceneResize / OpenURL / UserActivity / UserNotification / EnableAccessibility）。

#### 14.3.1 `-[USSServicesClient connect]` —— 借用 UIApplication 的 workspace

```c
// UIKitSystemAppServices:__text @ 0x1CB340FFC
- (void)connect {
    id app = [NSClassFromString(@"UIApplication") sharedApplication];
    self->_workspace = [app _workspace];   // FBSWorkspace
    NSAssert(_workspace, @"there's nothing we can do without a valid FBSWorkspace");
}
```

- **不自己建立 mach 连接**，而是从 `UIApplication.sharedApplication._workspace` 借用已有的 `FBSWorkspace`
- 用 `NSClassFromString` 而非直接引用——**反向解耦**：UIKitSystemAppServices 不硬依赖 UIKit

#### 14.3.2 `-[USSServicesClient createNewSceneOfSize:...]`

```c
// UIKitSystemAppServices:__text @ 0x1CB3410F0
FBSMutableSceneClientSettings *s = [FBSMutableSceneClientSettings new];
[s fu_setPreferredSize:size];                   // ← fu_ = FuseBoard category
[s fu_setPreferredDisplayID:CGMainDisplayID()];
[s fu_setState:isBackground ? 1 : 3];
FBSWorkspaceSceneRequestOptions *opts = [FBSWorkspaceSceneRequestOptions new];
[opts setIdentifier:identifier];
[opts setInitialClientSettings:s];
[self createNewSceneWithOptions:opts completionHandler:handler];
```

`fu_*` 是 **FuseBoard 在 `FBSMutableSceneClientSettings` 上加的 category**。iOS 上 SpringBoard 决定 app 的窗口大小/display；catalyst 反过来——app 自己有 NSWindow，所以反过来告诉 daemon "我多大、在哪个 display 上"。这是 FuseBoard 对 FrontBoardServices 协议的**反向扩展**。

#### 14.3.3 `-[USSServicesClient hostingContextIDForSceneWithIdentifier:error:]`

```c
// UIKitSystemAppServices:__text @ 0x1CB34123C
FBSScene *scene = [self sceneForIdentifier:identifier];      // 进程内缓存
unsigned int cid = [[scene settings] fu_hostingContextID];   // FuseBoard 写入的字段
return cid;
```

**`fu_hostingContextID` 是 FuseBoard 在 FBSSceneSettings 上注入的 category 属性**，由 daemon 端分配后通过 XPC 推送回 catalyst 进程。这就串起了 §3 中的 `[UINSSceneView _setHostedContextId:]` —— contextID 的真正来源是 UIKitSystem daemon。

#### 14.3.4 USSServicesClient 的真实地位

`xrefs_to +[USSServicesClient sharedInstance] @ 0x1CB340C58` 在整个 UIKitMacHelper / UIKitCore / AppKit 段内**无任何运行时调用方**（仅自身 method table）。

结论：USSServicesClient 是个**导出的便利 API 层**，给外部使用者（PluginKit、UI extension、第三方代码）用。catalyst 主路径直接走 `[UIApplication _workspace]` → FrontBoardServices，**绕过了 USSServicesClient**。

### 14.4 USS 前缀的双重命名空间（消歧义） ⚠️

| `USS` 出现位置 | 真实归属 Segment | 父类 / 角色 |
|---|---|---|
| `USSLayerHost` (1 个类) | `UIKitMacHelper:__text @ 0x19E89EA68` | `: CALayer`，是 `CALayerHost` 的薄 wrapper，in-process layer hosting 用 |
| `USSServicesClient` + 7 个 `USS*Request` | `UIKitSystemAppServices:__text @ 0x1CB34xxxx` | `: NSObject`，BSXPC client + NSSecureCoding payload |

**两者命名空间巧合相同但属于不同 framework，没有继承关系。** USSLayerHost 可能是从一份更早的内部 "UIKit System Services" 头文件里复制出来的历史命名。

### 14.5 UIKitServices —— UIS* 类的 BSXPC 服务总线

UIKitServices 约 140 个 `UIS*` 类，主要形态是 **BSXPC service / client 配对**：

| Service 端 | Client 端 | 用途 |
|---|---|---|
| `UISApplicationStateService` | `UISApplicationStateClient` | badge / background network / wake interval |
| `UISApplicationSupportService` | `UISApplicationSupportClient` | app init context / destroy scenes / passcode unlock |
| `UISSceneHostingExternalSettingsModifierService` | `...Client` | 远程修改 scene hosting settings |
| (Protocol) `UISSlotMachineProtocol` | — | widget slot 内容交换 |

此外还有一组 `UISScene*PlacementConfiguration`（Standard / Fullscreen / Background / Overlay / Push / Replace / Prominent / Ordered / Preserved）—— 场景 placement 协商类；`UISDeviceContext` / `UISDisplayContext` / `UISCompatibilityContext` —— 设备和显示环境信息类；`UIS*Drawing` 系列 —— 文本 / 矢量 glyph / path 绘制原语。

服务端持有 `BSServiceConnectionListener`（BackBoardServices XPC server 抽象），客户端持有 `BSServiceConnection`。

#### 14.5.1 在 catalyst 主流程内的可见性

`UISApplicationStateClient.initWithBundleIdentifier:`、`setBadgeValue:` 等方法在这套 dyld cache 里**也只命中自身 method table，没有外部调用方**。

真正的消费方可能是：
- **未加载到这个 IDA database 的系统 UI 模块**（NotificationCenter / SpotlightUI / Control Center 等）
- 通过 `NSClassFromString` / `NSInvocation` / `NSXPCConnection` protocol selector 动态调用，绕过静态 xref
- iOS 原生 UIKit 进程（UIKitServices 本来就是 iOS 全平台的基础设施）

UIKitServices 在 catalyst "普通 app 路径"上大部分被 macOS native 等价物（`NSDockTile` 设 badge、`NSWorkspace`、`NSExtension` 等）替代。

### 14.6 完整链路图

```
                                           ┌────────────────────────────────────┐
                                           │  UIKitSystem.app daemon            │
                                           │  com.apple.UIKitSystemApp          │
                                           │                                    │
                                           │  main():                           │
                                           │    CGSMainConnectionID             │
                                           │    dlopen HIServices               │
                                           │    _RegisterApplication            │
                                           │    CGSGetEventPort → RunLoop       │
                                           │    FUServerInitialize()            │
                                           │                                    │
                                           │  FuseBoard.framework (server):     │
                                           │    FBSceneManager                  │
                                           │    分配 fu_hostingContextID        │
                                           │    mach: com.apple.frontboard.     │
                                           │      systemappservices             │
                                           └──────────────▲─────────────────────┘
                                                          │ XPC (mach)
┌─────────────────────────────────────────────────────────┴──────────────────────┐
│ catalyst app process                                                           │
│                                                                                │
│  UIApplication startup                                                         │
│    └─ FBSWorkspace ──────────────────────► mach 端口 (上面的 daemon)           │
│                                                                                │
│  ┌─────────────┐  ┌──────────────────┐  ┌──────────────────┐                  │
│  │ UIKitCore   │→ │ FrontBoard       │← │ UIKitSystemApp   │                  │
│  │ (UIApp)     │  │ Services         │  │ Services         │                  │
│  │             │  │  FBSWorkspace    │  │  USSServicesClient│                  │
│  │             │  │  FBSScene        │  │  (借用_workspace) │                  │
│  │             │  │  FBSSceneSettings│  │  USS*Request      │                  │
│  └─────────────┘  └──────────────────┘  └──────────────────┘                  │
│       │                  │                                                     │
│       │     fu_hostingContextID (FuseBoard category on FBSSceneSettings)       │
│       ▼                  │                                                     │
│  ┌───────────────────────┴──────────────────────────────────────────────────┐  │
│  │ UIKitMacHelper                                                           │  │
│  │   UINSSceneView._setHostedContextId:(contextID)                          │  │
│  │     └─ _zoomLayer                                                        │  │
│  │         └─ _sceneLayer = USSLayerHost(contextID)                         │  │
│  │            ↑ UIKitMacHelper 自己的 CALayer 子类（跟 USS*Services 无关）   │  │
│  └──────────────────────────────────────────────────────────────────────────┘  │
│                                                                                │
│  ┌──────────────────┐                                                          │
│  │ UIKitServices    │  UIS* ~140 classes (badge / state / placement /         │
│  │                  │  display / drawing / slot …)                            │
│  │                  │  实际消费方在 NotificationCenter 等系统 UI 模块          │
│  └──────────────────┘                                                          │
└────────────────────────────────────────────────────────────────────────────────┘
```

### 14.7 本节解答的历史待验证项

§13 #3 "FBSScene 在 catalyst 进程内是真 in-process 还是 IPC stub" —— 现在确认：
- `FBSScene` 是 **IPC 客户端代理**，对端是 UIKitSystem.app daemon 内的 FuseBoard server
- `FBSWorkspace` 连接 mach 端口 `com.apple.frontboard.systemappservices`
- "in-process layer hosting" 精确表述：**渲染** in-process（UIKit layer tree 在 catalyst 进程内构建），**场景元数据 / 生命周期** out-of-process（从 daemon XPC 同步）
- `fu_hostingContextID` 由 daemon 端分配后写入 `FBSSceneSettings` 推送回 catalyst 进程

### 14.8 附录：UIKitSystem.app / UIKitSystemAppServices 关键地址

| 函数 | 地址 | 所在模块 |
|---|---|---|
| `_main` (UIKitSystem.app) | `0x1000032D0` | UIKitSystem.i64 |
| `_installEventRunLoopSource` (UIKitSystem.app) | `0x100003690` | UIKitSystem.i64 |
| `-[USSServicesClient connect]` | `0x1CB340FFC` | UIKitSystemAppServices |
| `-[USSServicesClient createNewSceneOfSize:...]` | `0x1CB3410F0` | UIKitSystemAppServices |
| `-[USSServicesClient hostingContextIDForSceneWithIdentifier:error:]` | `0x1CB34123C` | UIKitSystemAppServices |
| `-[USSServicesClient sceneForIdentifier:]` | `0x1CB343CD0` | UIKitSystemAppServices |
| `+[USSServicesClient sharedInstance]` | `0x1CB340C58` | UIKitSystemAppServices |
| `-[UISApplicationStateService delegate]` | `0x1C196AF94` | UIKitServices |
| `-[UISApplicationSupportService sharedInstance]` | `0x1C197FBEC` | UIKitServices |
| `-[UISApplicationStateClient initWithBundleIdentifier:]` | `0x1C1964194` | UIKitServices |

---

## 附录 A：关键反编译地址

| 函数 | 地址 |
|---|---|
| `+[NSApplication(UINSApplicationSwizzling) load]` | `0x19E895C98` |
| `-[NSApplication(UINSApplicationSwizzling) _uinsSwizzledSendEvent:]` | `0x19E8AC938` |
| `-[UINSWindow newWindowForTab:]` | `0x19E94A0F4` |
| `-[UINSSceneWindowController windowClass]` | `0x19E9365B8` |
| `-[UINSSceneWindowController _prepareWindowPostLoadIsFirstWindow:transitionContext:]` | `0x19E9365C4` |
| `-[UINSSceneView isFlipped]` | `0x19E89BA8C` |
| `-[UINSSceneView _sharedInit]` | `0x19E89B844` |
| `-[UINSSceneView layout]` | `0x19E89C098` |
| `-[UINSSceneView setFrameSize:]` | `0x19E922C28` |
| `-[UINSSceneView viewDidMoveToWindow]` | `0x19E89C888` |
| `-[UINSSceneView viewDidChangeBackingProperties]` | `0x19E89D66C` |
| `-[UINSSceneView _setHostedContextId:]` | `0x19E89E884` |
| `-[UINSSceneView _updateUIKitSceneProperties]` | `0x19E923A44` |
| `-[UINSSceneView _updateZoomLayer]` | `0x19E923254` |
| `-[UINSSceneView _updateTransformsForZoomScale:]` | `0x19E9230AC` |
| `-[UINSSceneView convertPointFromScene:]` | `0x19E89FA50` |
| `-[UINSSceneHostingView initWithUIView:]` | `0x19E932814` |
| `+[USSLayerHost layerHostForContextID:]` | `0x19E89EA68` |
| `-[USSLayerHost setContextId:]` | `0x19E9495D4` |
| `-[UINSWindowProxy attachToWindow:]` | `0x19E8ED278` |
| `-[UINSApplicationLifecycleController initWithAppDelegate:]` | `0x19E896F6C` |
| `-[UINSAppKitBackgroundingController makeAppKitForeground]` | `0x19E944BB4` |
| `-[UINSAppKitBackgroundingController _becomeForegroundIfNecessary]` | `0x19E94562C` |
| `-[UINSEventTranslator convertWindowLocationToSceneCoordinates:]` | `0x19E93B600` |
| `-[UINSEventTranslator hostEventsFromHIDEvent:]` | `0x19E93BAF4` |
| `-[NSViewHost initWithView:traits:delegate:]` | `0x18534E4BC` |
| `-[NSViewHost sendEvents:]` | `0x18534E6CC` |
| `-[NSViewHostingTraits isFlipped]` | `0x18534EC08` |
| `-[NSViewHostingContextRootView _isViewRoot]` | `0x18532B650` |
| `-[NSViewHostingContextRootView initWithHostingContext:contentView:traits:]` | `0x18532BA44` |
| `-[NSViewHostingContextRootView sendEvent:]` | `0x18532C010` |
| `-[NSViewHostingContextRootView sendMouseMoved:]` | `0x18532C714` |
| `UIKitLibrary` (SoftLinking helper #0) | `0x19E8BD748` |
| `UIKitLibrary_3` (SoftLinking helper #4, UINSSceneView.m) | `0x19E9258EC` |
| `UIKitCoreLibrary` (SoftLinking helper, NSUIImageUpcallStubs.m) | `0x19E8A993C` |
| `j__sl_dlopen` (PLT to SoftLinking) | `0x19E94FF08` |

## 附录 B：关键数据地址

| 标签 | 地址 | 内容 |
|---|---|---|
| UIKit framework descriptor (UINSApplicationDelegate.m) | `0x1E6574E50` | primary: `/System/Library/Frameworks/UIKit.framework/UIKit`<br>fallback: `/System/Library/Frameworks/UIKit.framework/Contents/MacOS/UIKit` |
| UIKit framework descriptor (UINSSceneView.m) | `0x1E6575670` | (相同两个路径) |
| UIKitCore framework descriptor | `0x1E6574CA8` | primary: `/System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore`<br>fallback: `/System/Library/PrivateFrameworks/UIKitCore.framework/Contents/MacOS/UIKitCore` |

## 附录 C：参考资料
- WebKit 的开源 SoftLinking 宏：https://github.com/WebKit/WebKit/blob/main/Source/WTF/wtf/cocoa/SoftLinking.h
- IDA database (dyld cache 三模块): `/Volumes/Code/Dump/DyldSharedCaches/macOS/26.4/UIKitCore+UIKitMacHelper+AppKit.i64`
  - 已额外加载 UIKitServices / UIKitSystemAppServices 两个模块（§14 分析）
- IDA database (UIKitSystem daemon): `/Volumes/Code/Dump/UIKitSystem/UIKitSystem.app/Contents/MacOS/UIKitSystem.i64`
- ObjCHeaders: `/Volumes/Code/Dump/DyldSharedCaches/macOS/26.4/{UIKitMacHelper,UIKitCore,AppKit,UIKitServices,UIKitSystemAppServices}/ObjCHeaders/`
- SwiftInterfaces: `/Volumes/Code/Dump/DyldSharedCaches/macOS/26.4/{UIKitCore,AppKit}/SwiftInterfaces/`
- macOS SDK AppKit.tbd: `/Applications/Xcode.app/.../MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Versions/C/AppKit.tbd`
- macOS SDK AppKit.swiftmodule: `/Applications/Xcode.app/.../MacOSX.sdk/System/Library/Frameworks/AppKit.framework/Versions/C/Modules/AppKit.swiftmodule/`
