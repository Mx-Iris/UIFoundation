# UINavigationController/UINavigationBar → NSToolbar 桥接机制

> 基于 macOS 26.4 dyld_shared_cache 中 UIKitCore、UIKitMacHelper、AppKit 的反编译
> IDA database: `UIKitCore+UIKitMacHelper+AppKit.i64`
>
> 配套参考：[`UIButton-NSButton-Bridge.md`](UIButton-NSButton-Bridge.md)、[`MacCatalyst-Architecture-Research.md`](MacCatalyst-Architecture-Research.md)

## 0. 摘要

UINavigationController 在 macOS 上是**双轨渲染**：

1. **UIKit 主轨**：`UINavigationController.navigationBar (UINavigationBar)` 仍然是纯 UIKit `UIView`，由 `_UINavigationBarVisualProviderModernIOS`（或 Swift 版 `_UINavigationBarVisualProviderModernIOSSwift`）画出。**UINavigationBar 自身没有任何 mac‑specific visual provider** —— 看 `+_visualProviderClassForNavigationBar:` (`0x1B95EDB74`) 的反编译，分支只有 CarPlay 和 iOS modern/legacy，**没有 Mac 分支**。
2. **AppKit 镜像轨（可选）**：当宿主 scene 提供了 `UIWindowScene.titlebar (UITitlebar)`、并且全局 gate `+[_UINavigationBarNSToolbarProxy _supportsNSToolbarNavigationHosting]` 返回 YES 时，UINavigationBar 通过 `_UINavigationBarNSToolbarProxy` 把内容**额外**投影到一份真正的 `NSToolbar`，挂在 `id<UINSWindow>` 即 NSWindow 子类上。两轨内容是**镜像**关系，不是替代。

也就是说：**UINavigationController 既不是"纯 UIKit Host"也不是"完全 NSToolbar 化"**——它是 UIKit 自渲染 + 把 `UIBarButtonItem` 投影成 `NSToolbarItem` 给 macOS titlebar/toolbar 显示。`UIBarButtonItem.customView` 这种自定义视图通过 `NSUIViewToolbarItem` + `UINSToolbarItemSceneHostingView` 跨进程嵌入回 NSToolbar。

---

## 1. 涉及的类（全部在 UIKitCore，除注明外）

### 1.1 UIKit 一侧（导航栏自身）

| 类 | 角色 |
|----|------|
| `UINavigationController : UIViewController` | 标准 UIKit，**没有专属 mac visual provider** |
| `UINavigationBar : UIView` | 纯 UIKit；提供 `currentNSToolbarSection` / `updateCurrentNSToolbarSection` |
| `_UINavigationBarVisualProviderModernIOS` | macOS 实际使用的 visual provider |
| `UIBarButtonItem : UIBarItem <_UINavigationBarNSToolbarItemIdentifying>` | 提供 `_NSToolbarSourceItem`、`_canProduceNSToolbarItem`、`_applyPropertiesToNSToolbarItem:includingMenu:` |
| `UIBarButtonItemGroup <_UINavigationBarNSToolbarItemIdentifying, _UINavigationBarNSToolbarItemGroupProviding>` | 提供 group 的 `_viableToolbarItems`、`_updateGroupItem:withVisibleItems:withManager:isPrimary:` |

### 1.2 桥接层（UIKitCore，连接 UIKit ↔ AppKit）

| 类/协议 | 角色 |
|---------|------|
| **`UITitlebar : NSObject <_UISceneComponentProviding>`** | 代表 macOS 窗口 titlebar，是 `UIWindowScene.titlebar` 的实体；持有 `_hostWindow: id<UINSWindow>`、`_toolbar: NSToolbar`、`_navigationBarProxy` |
| **`_UINavigationBarNSToolbarProxy : NSObject <NSToolbarDelegate>`** | 核心 NSToolbar 代理；持有 `_reusedToolbar: NSToolbar`、`_currentToolbarConfiguration`、`_nsToolbarItemManager` |
| `_UINavigationBarNSToolbarItemManager` | NSToolbarItem 制造与缓存；维护 `toolbarItemsToSourceMap` / `toolbarItemsToChildBarButtonItemsMap` / `_inflightItems` |
| `_UINSToolbarItemTuple` | 一个 identifier 对应的 `NSToolbarItem` 元组：`primaryItem`、`secondaryRepresentations`（用于 customization panel） |
| `_UINSToolbarItemGenerator <_UINavigationBarNSToolbarItemIdentifying>` | 系统级 generator：`backButtonGeneratorForLayout:`、`flexibleSpaceGenerator`、`sidebarToggleGenerator`、`spaceGenerator` |
| `_UINSToolbarConfiguration` | 缓存 `toolbarAllowedItems` / `toolbarDefaultItems` / `toolbarFixedItems` 等用于 diff |
| `_UINavigationBarNSToolbarLayout` | proxy 在 update 时让 participants 计算的 NSToolbar 布局描述 |
| `NSUIViewToolbarItem : NSToolbarItem` | 把 UIView 装进 NSToolbarItem 的容器；持有 `_uiView`、`_engineHostingView`、`_sceneHostingView` |
| `UINSToolbarItemEngineHostingView : UIView` | UIKit 一侧的 hosting view，"观察"原 UIView，托一个 `NSISEngineDelegate` 做跨框架 Auto Layout 协作 |

### 1.3 AppKit 一侧（UIKitMacHelper）

| 类/协议 | 角色 |
|---------|------|
| **`UINSWindow : NSWindow`** | 实际承载 catalyst scene 的 NSWindow 子类 |
| `<UINSWindow>` 协议 | 提供 `toolbar`、`setToolbar:`、`toolbarStyle`、`titlebarSeparatorStyle`、`representedURL`、`_hostedView: NSViewHost`、`UIScene` 等 cross-framework 访问 |
| `UINSToolbarItemSceneHostingView : UINSSceneHostingView <_NSToolbarItemLayoutWrapper>` | NSToolbarItem.view 的实体；通过 scene-based remote view hosting 嵌入 UIKit |
| `UINSReplicantToolbarItem` / `UINSToolbarReplicantView` | 把同一份内容"复制"到溢出菜单/customization panel 的辅助类型 |
| `UINSSearchToolbarItem` / `UINSSharingToolbarItem` | UIKit 搜索栏 / 分享按钮在 NSToolbar 中的特殊实现 |

### 1.4 关键协议

```objc
@protocol _UINavigationBarNSToolbarProxyParticipating <NSObject>
@required
- (id)layoutForNSToolbar:(id)nSToolbar forceUpdate:(BOOL)forceUpdate;
- (void)persistLayoutAfterNSToolbarCustomizationWithIncludedIdentifiers:(id)i excludedIdentifiers:(id)e;
@optional
- (void)_toolbarProxyDidUnregisterParticipant:(id)p;
@end

@protocol _UINavigationBarNSToolbarItemIdentifying <NSObject>
@required
@property (nonatomic, copy, readonly) NSString *_nstoolbarItemIdentifier;
- (BOOL)_isSpecialCasedAppKitItemIdentifier:(id)id;
- (id)_uniquifyNSToolbarItemIdentifierAgainstExisting:(id)existing;
- (id)_makeNSToolbarItemForInsertingInToolbar;
- (id)_makeNSToolbarItemForCustomizationPanelFromPrimaryItem:(id)primary;
@end

@protocol _UINavigationBarNSToolbarItemGroupProviding <NSObject>
@required
@property (nonatomic, copy) NSString *_sectionForGeneratingToolbarIdentifiers;
@property (nonatomic, copy) NSString *_subsectionForGeneratingToolbarIdentifiers;
- (id)_viableToolbarItems;
- (void)_updateGroupItem:(id)g withVisibleItems:(id)visible withManager:(id)mgr isPrimary:(BOOL)p;
@end
```

---

## 2. 启用条件 —— `_supportsNSToolbarNavigationHosting`

`+[_UINavigationBarNSToolbarProxy _supportsNSToolbarNavigationHosting]` (`0x1BA2F0FE4`) 是整个机制的总开关：

```c
+ (BOOL)_supportsNSToolbarNavigationHosting {
    static dispatch_once_t once = -1;
    if (once != -1) dispatch_once(&once, ^{ _MergedGlobals_1188 = ...; });
    return _MergedGlobals_1188;
}
```

返回值缓存在全局变量 `_MergedGlobals_1188`，由 dispatch_once block 在首次访问时计算。该 gate 需要：宿主进程是 catalyst（platform=6）、scene 提供了 `UITitlebar`、相应 SDK 版本以上，等等。**不在 catalyst 进程下时它返回 NO**，整个 NSToolbar 镜像通道关闭，UINavigationBar 就只剩纯 UIKit 渲染。

---

## 3. 整体所有权链

```
UIWindowScene
  └── titlebar : UITitlebar                                ← UIWindowScene.titlebar (macOS 26)
        ├── _hostWindow      : id<UINSWindow>              ← weak; 实际是 UINSWindow (NSWindow 子类)
        │       └── attachedWindow / sceneView / _hostedView (NSViewHost)
        ├── _toolbar         : NSToolbar                   ← 用户显式设置或来自 proxy
        ├── _navigationBarProxy : _UINavigationBarNSToolbarProxy
        │       ├── _reusedToolbar           : NSToolbar   ← proxy 自己 alloc 的
        │       ├── _currentToolbarConfiguration : _UINSToolbarConfiguration
        │       ├── _nsToolbarItemManager    : _UINavigationBarNSToolbarItemManager
        │       │       ├── toolbarItemsToSourceMap
        │       │       ├── toolbarItemsToChildBarButtonItemsMap
        │       │       └── _inflightItems  : { id → _UINSToolbarItemTuple }
        │       ├── _registeredParticipants  : NSMutableArray  ← UINavigationBar 等
        │       ├── tabBarProvider           : id<_UINavigationBarNSToolbarProxyTabBarItemProviding>
        │       └── owningTitlebar           : UITitlebar (weak, ← back‑pointer)
        └── _currentBottomPaletteView : UIView
```

`UINavigationBar` 通过 `_UINavigationBarNSToolbarProxyParticipating` 协议**注册成 participant**。每次 navigation item 变化，proxy 会向所有 participants 询问 `layoutForNSToolbar:forceUpdate:`，得到一份 `_UINavigationBarNSToolbarLayout`，再据此构造/更新 NSToolbar 内容。

---

## 4. NSToolbar 实例的创建 —— `_setupToolbarIfNecessary` (`0x1BA2F3614`)

```c
- (void)_setupToolbarIfNecessary {
    if (self->_reusedToolbar) return;
    NSToolbar *t = [[NSToolbar alloc] initWithIdentifier:
        [NSString stringWithFormat:@"com.apple.UIKit.BridgedNSToolbar.%p", self]];
    [t setAutosavesConfiguration:NO];
    self->_reusedToolbar = t;
}
```

- identifier 形如 `"com.apple.UIKit.BridgedNSToolbar.0x103fae0a0"`，**绑定到 proxy 实例的指针**。所以每个 UITitlebar 一份 NSToolbar，proxy 销毁后这个 toolbar 也跟着消失
- `setAutosavesConfiguration:NO` —— UIKit 自己负责持久化（通过 `_persistCurrentToolbarCustomizationsForToolbar:withAfterEditIdentifiers:` 与 `_persistDisplayModeForToolbar:`），**不让 NSToolbar 自动写 user defaults**

NSToolbar 与 NSWindow 的挂接由 `UITitlebar._updateToolbar` (`0x1B8E13EC8`) 完成：

```c
- (void)_updateToolbar {
    NSToolbar *t = self->_toolbar;
    BOOL hosting = [_UINavigationBarNSToolbarProxy _supportsNSToolbarNavigationHosting];
    if (!t && hosting)
        t = self->_navigationBarProxy.toolbar;     // 从 proxy 拿到 _reusedToolbar

    id<UINSWindow> w = self->_hostWindow;          // weak; UINSWindow (NSWindow 子类)
    if (w.toolbar != t) {
        if (hosting) [self->_navigationBarProxy willSetNewToolbar];
        [w setToolbar:t];                          // ← 真正挂到 NSWindow
        if (t) [self _ensureWindowStyleMaskTitledIsSet];
        if (hosting) [self->_navigationBarProxy didSetNewToolbar];
    }
}
```

---

## 5. NSToolbarDelegate 实现 —— proxy 替 NSToolbar 答题

`_UINavigationBarNSToolbarProxy` 实现 `NSToolbarDelegate` 的 6 个方法，都委托到 manager 或 participants：

| `NSToolbarDelegate` 方法 | proxy 实现地址 | 行为 |
|--------------------------|---------------|------|
| `toolbarAllowedItemIdentifiers:` | `0x1BA2F3ED8` | 返回 `_currentToolbarConfiguration.toolbarAllowedItems` |
| `toolbarDefaultItemIdentifiers:` | `0x1BA2F3E68` | 返回 `_currentToolbarConfiguration.toolbarDefaultItems` |
| `toolbarImmovableItemIdentifiers:` | `0x1BA2F3EE0` | 不可移动的（fixed）item 集合 |
| `toolbar:itemIdentifier:canBeInsertedAtIndex:` | `0x1BA2F3EE8` | 检查 customization panel 是否允许在某位置插入 |
| **`toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:`** | **`0x1BA2F3DD0`** | 核心制造入口 |
| `toolbarWillAddItem:` / `toolbarDidRemoveItem:` / `toolbarDidReorderItem:` | `0x1BA2F3F9C` / `0x1BA2F43A0` / `0x1BA2F43A8` | 用户交互后回写到 `_currentToolbarConfiguration` 并 persist |

核心入口 `-toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:`：

```c
- (NSToolbarItem *)toolbar:(NSToolbar *)tb
       itemForItemIdentifier:(NSToolbarItemIdentifier)id
       willBeInsertedIntoToolbar:(BOOL)willInsert
{
    if (id == NSToolbarTabBarTabItemsItemIdentifier) {
        // tab bar 由独立 provider 接管
        return [self.tabBarProvider tabBarItemForNSToolbarProxy:self];
    }
    return [self.nsToolbarItemManager
        nstoolbarItemRepresentationForIdentifier:id
                          wantPrimaryItem:willInsert
                              cachedItemOK:NO];
}
```

---

## 6. UIBarButtonItem → NSToolbarItem —— manager 制造路径

`-[_UINavigationBarNSToolbarItemManager nstoolbarItemRepresentationForIdentifier:wantPrimaryItem:cachedItemOK:]` (`0x1BA35346C`) 简化伪码：

```c
- (NSToolbarItem *)nstoolbarItemRepresentationForIdentifier:(id)id
                                              wantPrimaryItem:(BOOL)wantPrimary
                                                cachedItemOK:(BOOL)cacheOK
{
    // 1) 先在 toolbarItemsToChildBarButtonItemsMap (group 子项) 找
    //    再在 toolbarItemsToSourceMap (顶层 source) 找
    id<_UINavigationBarNSToolbarItemIdentifying> source =
        toolbarItemsToChildBarButtonItemsMap[id] ?:
        toolbarItemsToSourceMap[id];
    if (!source) return nil;

    // 2) inflight tuple 是 (primary, [secondaryRepresentations])
    _UINSToolbarItemTuple *tuple = _inflightItems[id]
        ?: ({ tuple = [_UINSToolbarItemTuple new];
              _inflightItems[id] = tuple; tuple; });

    // 3) primary 路径
    NSToolbarItem *result;
    if (wantPrimary || ...) {
        if (cacheOK && !specialCased && tuple.primaryItem) {
            result = tuple.primaryItem;                     // 缓存命中
        } else {
            result = [source _makeNSToolbarItemForInsertingInToolbar];   // ← 实际制造
            tuple.primaryItem = result;
            tuple.isGroupItem = [source isKindOfClass:UIBarButtonItemGroup.class];
        }
    }

    // 4) customization panel 的 secondary 路径
    if (!wantPrimary || (also-need-secondary)) {
        NSMutableArray *reps = tuple.secondaryRepresentations
            ?: ({ reps = [NSMutableArray new];
                  tuple.secondaryRepresentations = reps; reps; });
        NSToolbarItem *sec = [source _makeNSToolbarItemForCustomizationPanelFromPrimaryItem:result];
        // 在 reps 中找老的并替换 / 否则 append
        result = sec;
    }

    // 5) 把 UIBarButtonItem 当前属性应用到 NSToolbarItem
    [self _validateSingleItemOrGroup:result
                       isPrimaryItem:wantPrimary
                         visibleOnly:NO
                 withVisibleChildren:nil
                          withSource:source];
    [self _revalidateIfSourceHasChangedForTuple:tuple withCurrentSource:source];
    return result;
}
```

`_validateSingleItemOrGroup:` 内部最终会调到 UIBarButtonItem 的 `_applyPropertiesToNSToolbarItem:includingMenu:`。

### 6.1 `-[UIBarButtonItem _applyPropertiesToNSToolbarItem:includingMenu:]` (`0x1B95DFC08`)

属性映射表（直接从反编译翻出）：

| UIBarButtonItem 属性 | NSToolbarItem 设置 | 备注 |
|---------------------|-------------------|------|
| `resolvedTitle` (fallback `@""`) | `setLabel:` & `setToolTip:` & `setTitle:` (无 image 时) | label 用作标签和 tooltip |
| `_resolvedImage` | `setImage:`（设置后不再 setTitle） | 优先使用 image |
| `customView` (UIView*) | 当 NSToolbarItem 是 `NSUIViewToolbarItem` → `setUIView:` | flag bit `obj[201] & 0x20` 控制 |
| `_effectiveMenuRepresentation` | `setItemMenuFormRepresentation:` | 仅在 `includingMenu == YES` |
| `menu` (UIMenu*) | 当 NSToolbarItem 是 `NSMenuToolbarItem` → `setItemMenu:` | 自动转换 |
| `isEnabled` | `setEnabled:` | 总是同步 |

可生产性 `-[UIBarButtonItem _canProduceNSToolbarItem]` (`0x1B95DFA10`)：

```c
- (BOOL)_canProduceNSToolbarItem {
    if ((flags[225] & 1)) return NO;                       // 某个 "noToolbar" bit
    if ([self _isSectionBreakSpaceItem]) return NO;
    if (dyld_program_sdk_at_least(0x13000000000002)) return YES;   // SDK ≥ 19.x: 即使 spaceItem 也允许
    return ![self isSpaceItem];                            // 老 SDK：space 禁止
}
```

### 6.2 系统 generator：back / sidebar toggle / space

`_UINSToolbarItemGenerator` 提供四个工厂方法：

```objc
+ (id)backButtonGeneratorForLayout:(_UINavigationBarNSToolbarLayout *)layout
                            handler:(id /* block */)handler
                       configurator:(id /* block */)configurator;   // 0x1BA2EFDB0
+ (id)sidebarToggleGenerator;                                       // 0x1BA2F0250
+ (id)flexibleSpaceGenerator;                                       // 0x1BA2F0138
+ (id)spaceGenerator;                                               // 0x1BA2F01C4
```

它们各自实现 `_UINavigationBarNSToolbarItemIdentifying`，伪装成 source。`_makeNSToolbarItemForInsertingInToolbar` 内部对 sidebar toggle 这种"特殊"identifier 走 AppKit 自带 item（`_isSpecialCasedAppKitItemIdentifier:` 返回 YES），所以分支会跳过 inflight 缓存，每次让 AppKit 自己生成。

---

## 7. UIView 嵌入 NSToolbarItem —— `NSUIViewToolbarItem`

当 UIBarButtonItem 是 `customView` 模式（用户给了 UIView），NSToolbarItem 端用 `NSUIViewToolbarItem`：

```objc
@interface NSUIViewToolbarItem : NSToolbarItem {
    UIView *_uiView;                                        // 224
    UINSToolbarItemEngineHostingView *_engineHostingView;   // 232
    UINSToolbarItemSceneHostingView *_sceneHostingView;     // 240
}
- (id)initWithItemIdentifier:(id)id uiView:(id)v;           // 0x1BA02D9F8
@end
```

显示路径：

```
NSToolbar 渲染 NSToolbarItem
  └── NSToolbarItem.view = UINSToolbarItemSceneHostingView   (NSView, UIKitMacHelper)
        ├── 继承 UINSSceneHostingView                          ← scene‑based remote view host
        ├── 实现 _NSToolbarItemLayoutWrapper                  ← AppKit toolbar 私有 layout 协议
        └── 通过 SceneHosting 嵌入 UIKit scene
              └── scene 内部根 view: UINSToolbarItemEngineHostingView (UIView, UIKitCore)
                    ├── _observedView : UIView   ← 原 customView
                    └── _secondaryEngineDelegate : NSISEngineDelegate
                          ← 把 UIKit 端 Auto Layout 与 AppKit 的 NSISEngine 协调
                          (跨框架约束系统的桥)
```

注意有两个不同的 view：
- `UINSToolbarItemSceneHostingView` 在 **AppKit (NSView) 一侧**，由 UIKitMacHelper 提供
- `UINSToolbarItemEngineHostingView` 在 **UIKit (UIView) 一侧**，由 UIKitCore 提供，实现协议 `UINSToolbarItemEngineHostingView_forUIKitMacHelper` 暴露给 UIKitMacHelper

二者之间靠 scene‑based remote view hosting 通信（同一进程，不是 RVC）。AppKit 一侧只看到一个 NSView，UIKit 一侧只看到一个 UIView，layout/event 通过共享的 `NSISEngine` 透明协调。

---

## 8. 双向更新流程

### 8.1 UI → NS（UIBarButtonItem 改了 → NSToolbar 刷新）

```
[UIBarButtonItem.title = ...] / [UINavigationItem setRightBarButtonItems:]
      ↓
UIBarButtonItem 内部 KVO / 通知
      ↓
UINavigationBar (作为 participant)
      ↓ 协议方法
_UINavigationBarNSToolbarProxy._itemNeedsNSToolbarUpdate:        (0x1BA2F4D94)
      ↓ 排队
_UINavigationBarNSToolbarProxy.updateBridgedToolbar              (0x1BA2F1320)
      ↓ 设 needsUpdate flag
UITitlebar._updateFromNavigationBarProxy
      ↓
重新调 NSToolbarDelegate 回路：
      NSToolbar → toolbar:itemForItemIdentifier:...
      → manager 找到 source UIBarButtonItem
      → tuple.primaryItem 已存在则复用，否则新建
      → _applyPropertiesToNSToolbarItem:includingMenu:YES
```

### 8.2 NS → UI（用户在 NSToolbar customization panel 拖动 / 删除）

```
NSToolbar customization panel
      ↓ NSToolbarDelegate callback
proxy.toolbarWillAddItem: / toolbarDidRemoveItem: / toolbarDidReorderItem:
      ↓
_currentToolbarConfiguration.toolbarCurrentItems 更新
      ↓
proxy._persistCurrentToolbarCustomizationsForToolbar:withAfterEditIdentifiers:   (0x1BA2F44BC)
proxy._persistDisplayModeForToolbar:                                              (0x1BA2F46BC)
      ↓
participants 收到通知 (_UINavigationBarToolbarProxyUpdateRelatedToolbarsNotification)
```

NSToolbarItem 上点击的 action 走 NSToolbar 自身的 target/action（`NSMenuToolbarItem`、`NSUIViewToolbarItem` 内部），最终触发原 UIBarButtonItem.action（target/action 在 `_makeNSToolbarItemForInsertingInToolbar` 阶段就已经原样转移到 NSToolbarItem 上）。

---

## 9. UINavigationBar 与 proxy 的关系

UINavigationBar 自身**没有直接持有 proxy**——它只是注册成 participant：

```objc
// _UINavigationBarNSToolbarProxy
- (void)registerToolbarParticipant:(id<_UINavigationBarNSToolbarProxyParticipating>)p;     // 0x1BA2F13B8
- (void)unregisterToolbarParticipant:(id)p;                                                // 0x1BA2F1440
```

UINavigationBar 与同一 titlebar 上的其他 participant（侧栏、检查器、tab bar 等）共同贡献 layout，proxy 在 build 时调：

```objc
- (void)_buildToolbarFromSidebarLayout:(id)sidebarLayout
                   supplementaryLayout:(id)supplementaryLayout
                         contentLayout:(id)contentLayout
                       inspectorLayout:(id)inspectorLayout;     // 0x1BA2F19FC
```

合并后形成 NSToolbar 的最终 item identifier 列表。`UINavigationBar.currentNSToolbarSection` 返回的就是合并后该 navigation bar 在 NSToolbar 里所属的 section（leading/center/trailing）。

---

## 10. 关键地址速查

| 符号 | 地址 |
|------|------|
| `+[_UINavigationBarNSToolbarProxy _supportsNSToolbarNavigationHosting]` | `0x1BA2F0FE4` |
| `-[_UINavigationBarNSToolbarProxy initWithTitlebar:]` | `0x1BA2F10AC` |
| `-[_UINavigationBarNSToolbarProxy _setupToolbarIfNecessary]` | `0x1BA2F3614` |
| `-[_UINavigationBarNSToolbarProxy updateBridgedToolbar]` | `0x1BA2F1320` |
| `-[_UINavigationBarNSToolbarProxy toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:]` | `0x1BA2F3DD0` |
| `-[_UINavigationBarNSToolbarProxy toolbarAllowedItemIdentifiers:]` | `0x1BA2F3ED8` |
| `-[_UINavigationBarNSToolbarProxy toolbarDefaultItemIdentifiers:]` | `0x1BA2F3E68` |
| `-[_UINavigationBarNSToolbarProxy toolbarWillAddItem:]` | `0x1BA2F3F9C` |
| `-[_UINavigationBarNSToolbarProxy toolbarDidRemoveItem:]` | `0x1BA2F43A0` |
| `-[_UINavigationBarNSToolbarProxy _buildToolbarFromSidebarLayout:supplementaryLayout:contentLayout:inspectorLayout:]` | `0x1BA2F19FC` |
| `-[_UINavigationBarNSToolbarProxy registerToolbarParticipant:]` | `0x1BA2F13B8` |
| `-[_UINavigationBarNSToolbarItemManager nstoolbarItemRepresentationForIdentifier:wantPrimaryItem:cachedItemOK:]` | `0x1BA35346C` |
| `-[_UINavigationBarNSToolbarItemManager nstoolbarItemForPopoverPresentationFromUIBarButtonItem:]` | `0x1BA353B94` |
| `-[UITitlebar _updateToolbar]` | `0x1B8E13EC8` |
| `-[UITitlebar _updateFromNavigationBarProxy]` | `0x1BA02C3F4` |
| `-[UITitlebar _ensureWindowStyleMaskTitledIsSet]` | `0x1BA02BE3C` |
| `+[UINavigationBar _visualProviderClassForNavigationBar:]` | `0x1B95EDB74` |
| `-[UIBarButtonItem _applyPropertiesToNSToolbarItem:includingMenu:]` | `0x1B95DFC08` |
| `-[UIBarButtonItem _canProduceNSToolbarItem]` | `0x1B95DFA10` |
| `-[UIBarButtonItem _NSToolbarSourceItem]` | `0x1B95E084C` |
| `-[NSUIViewToolbarItem initWithItemIdentifier:uiView:]` | `0x1BA02D9F8` |
| `+[_UINSToolbarItemGenerator backButtonGeneratorForLayout:handler:configurator:]` | `0x1BA2EFDB0` |
| `+[_UINSToolbarItemGenerator sidebarToggleGenerator]` | `0x1BA2F0250` |
| `+[_UINSToolbarItemGenerator flexibleSpaceGenerator]` | `0x1BA2F0138` |
| `+[_UINSToolbarItemGenerator spaceGenerator]` | `0x1BA2F01C4` |

---

## 11. 与 UIButton 桥接的对比

| 维度 | UIButton (UIControl) | UINavigationController/Bar |
|------|----------------------|---------------------------|
| 触发条件 | idiom == 5 + `behavioralStyle == 2` | scene 提供 `UITitlebar` + `+_supportsNSToolbarNavigationHosting` 返回 YES |
| Mac‑specific visual provider | 有：`UIButtonMacVisualProvider` | **没有**——一直用 iOS modern provider |
| 嵌入 NSView 到 UIView | 用 `_UINSView` (NSViewHost) | 不需要——NavigationBar 自身是纯 UIKit |
| 嵌入 UIView 到 NSView | 不需要 | 用 `UINSToolbarItemSceneHostingView` (UIKitMacHelper) + `UINSToolbarItemEngineHostingView` (UIKitCore) |
| AppKit ↔ UIKit 转换关系 | UIButton **替换为** NSButton | UIBarButtonItem **镜像复制为** NSToolbarItem，UIKit 端依旧渲染 |
| 事件流向 | NSButton 事件 → UIButton.sendActionsForControlEvents | NSToolbarItem.action 直接是原 UIBarButtonItem.action（拷贝过去），target 也一样 |

---

## 12. 一句话总结

UINavigationController 在 macOS 上**不是用 NSToolbar 替代渲染**，而是：UINavigationBar 仍由 iOS modern visual provider 全 UIKit 渲染（`UIView` 子树）；同时——只要宿主 scene 暴露了 `UIWindowScene.titlebar (UITitlebar)` 且 catalyst gate `_supportsNSToolbarNavigationHosting` 打开——`_UINavigationBarNSToolbarProxy` 实现 `NSToolbarDelegate`，把 `UIBarButtonItem` 通过 `_makeNSToolbarItemForInsertingInToolbar` + `_applyPropertiesToNSToolbarItem:` 镜像成 `NSToolbarItem`，挂到 `UINSWindow (NSWindow 子类)` 的 `toolbar` 上。`UIBarButtonItem.customView` 这种自定义 UIView 走 `NSUIViewToolbarItem` → `UINSToolbarItemSceneHostingView` (NSView) → SceneHosting → `UINSToolbarItemEngineHostingView` (UIView) 的跨框架嵌入；点击事件直接复用原 target/action，不需要像 UIButton 那样反向转发。
