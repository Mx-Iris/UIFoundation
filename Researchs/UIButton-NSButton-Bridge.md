# UIButton → NSButton 桥接机制

> 基于 macOS 26.4 dyld_shared_cache 中 UIKitCore、UIKitMacHelper、AppKit 的反编译
> IDA database: `UIKitCore+UIKitMacHelper+AppKit.i64`

## 0. 摘要

UIButton 在 Mac/Mac‑idiom 下并不是"渲染成 NSButton 的样子"，而是**把一个真正的 NSButton（或 NSPopUpButton / `_NSMenuButton` / `_NSDynamicallyBorderedButton` 等）当作子视图嵌入自己**。

整个桥接代码全部位于 **UIKitCore**（不是 UIKitMacHelper）：UIKitMacHelper 只在更上层的 `NSViewHost` / `NSViewBridge` 通道里出现。换句话说，UIKitCore 自己就同时引用了 AppKit 的 NS 类型，并定义了一组配套的 NSButton 子类与类别。

与 `NSSegmentedControl + UINSSegmentedControl`、`NSPopUpButton + UINSPopUpButton` 这种 UIKitMacHelper 桥接不同，**UIButton 没有专门的 `UINSButton` 中间类**。它复用原生 NSButton/NSPopUpButton，通过：

1. `UIButtonRepresentable` 协议把 NSControl 子类标记为"能代表 UIButton 的视觉载体"
2. `UIButtonMacVisualElement` (UIView) 作为外壳容纳 NSControl
3. `_UINSView` (NSViewHost 包装) 完成 NSView ↔ UIView 跨框架嵌入

完成最终的"UIButton 内部跑着真 NSButton"。

---

## 1. 类型骨架

```
UIButton (UIControl, UIView)                       // 用户看到的 API 类
  └── _visualProvider : id<UIButtonVisualProvider>
        ▶ Mac 上实际类型：UIButtonMacVisualProvider
            (继承自 UIButtonMacLegacyVisualProvider，又继承自 UIButtonLegacyVisualProvider)
        └── _element : UIButtonMacVisualElement   (UIView)
              ├── button   : NSControl<UIButtonRepresentable>*   ← 真正的 NSButton/NSPopUpButton
              ├── bridge   : _UINSView                            ← NSView↔UIView 桥接（NSViewHost）
              └── (UIView 自己作为 UIButton 的 subview)
```

`UIButtonRepresentable` 是 UIKitCore 定义的协议，让 NSControl 子类可以"代表"一个 UIButton：

- `NSButton (UIButtonRepresentable)` —— 标准 NSButton 类别
- `NSPopUpButton (UIButtonRepresentable)` —— 带菜单的按钮走这条路
- `_NSDynamicallyBorderedButton : NSButton` —— 默认情况下使用的 NSButton 子类
- `_NSGlassButton : NSButton` —— Liquid Glass 风格按钮
- `_NSBorderlessButton : NSButton` —— 永久无边框版本
- `UIButtonMacIdiomCell : NSButtonCell` —— 配套的 cell
- `_NSMenuButton`（来自 AppKit）—— 当 UIButton 配置了 menu 时使用

---

## 2. 选择 visual provider 的逻辑

`-[UIButton visualProviderClassForTraitCollection:]` 在 `0x1B996D114`，简化伪码：

```c
provider = [self _visualProviderClass]                     // hook 点，默认 0
        ?: [self _visualProviderClassForIdiom:idiom];      // hook 点，默认 0
if (!provider) {
    // 1. 查全局字典 __UIButtonIdiomsToVisualProviderClasses
    // 2. 兜底：根据 idiom + button 标志位选硬编码的类
    if (idiom == 2 /* UIUserInterfaceIdiomMac */) {
        provider = (button has modern config)
                 ? *off_1E6D6F1C0
                 : UIButtonLegacyVisualProvider;
    } else if (idiom == 5 && [self behavioralStyle] == 2) {
        provider = (button has modern config)
                 ? UIButtonMacVisualProvider          // *off_1E6D6F1D8
                 : UIButtonMacLegacyVisualProvider;   // *off_1E6D6F1D0
    } else {
        provider = (modern) ? UIButtonConfigurationVisualProvider
                            : UIButtonLegacyVisualProvider;
    }
}
return [provider visualProviderForButton:self];
```

类指针表（用 IDA 校验过）：

| 偏移 | 类 |
|------|----|
| `0x1ec7a18a8` | `UIButtonMacVisualProvider` |
| `0x1ec7a18f8` | `UIButtonMacLegacyVisualProvider` |
| `0x1ec7a1948` | `UIButtonLegacyVisualProvider` |
| `0x1ec7a1998` | `UIButtonConfigurationVisualProvider` |

进入 Mac path 的条件：**idiom == 5 (Pad) + `behavioralStyle == 2 (Mac)`** —— 也就是用 SwiftUI/UIKit 在 Mac Catalyst "Optimized for Mac" 模式下、或显式 `preferredBehavioralStyle = .mac` 的 UIButton。

`+_visualProviderClass` 与 `+_visualProviderClassForIdiom:` 在 UIButton 上是**空 hook**（直接返回 0）：

```
+[UIButton _visualProviderClassForIdiom:]:
    MOV X0, #0
    RET
```

它们是给子类/扩展点提供的覆盖入口。

---

## 3. 创建 NSControl —— `+visualElementForUIButton:` (`0x1B9F9C294`)

```c
+ (UIButtonMacVisualElement *)visualElementForUIButton:(UIButton *)button {
    id ns;
    if (button._currentConfiguration == nil          // 旧 API
        || button.menu != nil
        || button.changesSelectionAsPrimaryAction
        || button.showsMenuAsPrimaryAction)
    {
        ns = [self nsControlForMenuAndNonConfigurationButtons:button];
    } else {
        ns = [_UIButtonConfigurationCatalystTranslator
                  nsButtonForConfiguration:button._currentConfiguration
                          traitCollection:button.traitCollection];
    }
    [self _forwardPropertiesOnUIButton:button toButtonRepresentable:ns];
    return ns ? [[self alloc] initWithUIButtonRepesentable:ns] : nil;
}
```

注意拼写："Repesentable" —— Apple 自己代码里的拼写错漏，已 baked 进 selector，不会修。

两条工厂分支：

- 现代 `UIButtonConfiguration` 且不带 menu/select → `_UIButtonConfigurationCatalystTranslator nsButtonForConfiguration:traitCollection:`
- 其余情况（旧 API、或带 menu/select） → `+nsControlForMenuAndNonConfigurationButtons:`

---

## 4. 真正决定哪种 NSControl 子类 —— `+nsControlForMenuAndNonConfigurationButtons:` (`0x1B9F9BE70`)

去掉日志/语义上下文后的核心决策树（`buttonType` 是 `UIButtonType`）：

| 分支 | 创建的 NSControl |
|------|-----------------|
| `buttonType == 124` (deprecated SPI，会打 fault log) | `NSPopUpButton`，pull-down = NO |
| `buttonType == 125` (deprecated SPI) | `NSPopUpButton`，pull-down = YES |
| `buttonType == 128` | `+[NSButton buttonWithTitle:target:action:]` + bezelStyle 11 + `controlSize = 3` |
| `buttonType == 129` | `+[NSButton …]` + bezelStyle 11 + buttonType 6 (toggle) |
| 其余 + `showsMenuAsPrimaryAction == YES` | `[[NSPopUpButton alloc] initWithFrame:pullsDown:!changesSelectionAsPrimaryAction]`，可加 toolbar bezel + 在 SDK ≥ 10.15.4 + `_resolvedMacIdiomStyle == 2` 时关 bordered |
| 其余 + `menu != nil` | **`_NSMenuButton`**（AppKit 私有），`setToggles:changesSelectionAsPrimaryAction` |
| 其余 + `changesSelectionAsPrimaryAction == YES` | NSButton + buttonType 6 + 可能 bezelStyle 11 |
| **默认（最常见）** | **`_NSDynamicallyBorderedButton`** + `setImagePosition:NSImageRight` + 根据 `_semanticContext == 3 (toolbar)` 决定 bezel/bordered |

`_semanticContext == 3` 的分支都会设 `bezelStyle = NSBezelStyleToolbar (11)` 并打开 `_setSemanticContext:4`（NSToolbarItem 内部用的语义）。

最后无论走哪条分支，都会按 trait collection 的 `toolbarItemPresentationSize` 设置 `controlSize`。

---

## 5. 把 NSControl 装进 UIView —— `-[UIButtonMacVisualElement initWithUIButtonRepesentable:]` (`0x1B9F9C4EC`)

```c
self->_button = ns;                                  // strong
// 7 个 tracking 事件统统挂回自己
[ns addTarget:self action:@selector(trackingBeganAction:)         forControlEvents:1];
[ns addTarget:self action:@selector(trackingDraggingEnterAction:) forControlEvents:16];
[ns addTarget:self action:@selector(trackingEndedInsideAction:)   forControlEvents:4];
[ns addTarget:self action:@selector(trackingDraggingExitedAction:)forControlEvents:32];
[ns addTarget:self action:@selector(trackingEndedOutsideAction:)  forControlEvents:8];
[ns addTarget:self action:@selector(trackingInsideAction:)        forControlEvents:64];
[ns addTarget:self action:@selector(trackingOutsideAction:)       forControlEvents:128];

[NSNotificationCenter.defaultCenter
    addObserver:self selector:@selector(willPopUpNotification:)
           name:NSPopUpButtonWillPopUpNotification object:ns];

self->_bridge = [[_UINSView alloc] initWithContentNSView:ns];   // NSViewHost 包装
self->_bridge.frame = self.bounds;
self->_bridge.autoresizingMask = 18;       // width|height
[self addSubview:self->_bridge];
```

`_UINSView` 内部持有 `NSViewHost` 和 `NSViewHostingTraits`，把 NSView 嵌入 UIView 树是 macOS 13+ 提供的 cross-framework 通道（详见 `MacCatalyst-Architecture-Research.md`）。

随后 `-[UIButtonMacLegacyVisualProvider initWithVisualElement:button:]` (`0x1BA2EBBC8`) 把 visualElement 拼到 UIButton 上：

```c
[visualElement setButtonControl:button];   // visualElement 弱引用回 UIButton
[button addSubview:visualElement];         // ← 关键：UIButton 的 subview 树就是 visualElement
self->_element = visualElement;
```

最终的 view 嵌套：

```
UIButton                       ← UIControl
  └─ UIButtonMacVisualElement  ← UIView
        └─ _UINSView           ← UIView（NSViewHost 内部）
              └─ NSButton/NSPopUpButton/_NSDynamicallyBorderedButton/_NSMenuButton
```

---

## 6. 属性同步（UI → NS）

### 一次性同步（创建时）—— `+_forwardPropertiesOnUIButton:toButtonRepresentable:` (`0x1B9F9C3E0`)

```c
// 1) primary role / buttonType==126 → 默认按钮（回车触发）
if ((button.role == 1 || button.buttonType == 126) && [ns isKindOfClass:NSButton.class])
    [ns setKeyEquivalent:@"\r"];

// 2) tint
if (UIColor *t = button._interactionTintColor) [ns setContentTintColor:t];   // 自动转 NSColor

// 3) buttonType 126/127 用 small control size
if ((button.buttonType & ~1) == 126) [ns setControlSize:NSControlSizeSmall];
```

### 持续同步（NSButton+UIButtonRepresentable 类别）

UIButton 调 `setTitle:forState:` / `setImage:forState:` 时，类别版本只在 `state == 0` (Normal) 时同步到 NSButton —— NSButton 没有 per-state 文案概念。Image 还会被强制为 `.alwaysOriginal` rendering mode 并经 `UIImageToNSImage()` 转成 `NSImage`。

```c
// 0x1B9F9D014
- (void)setTitle:(NSString *)t forState:(NSUInteger)s {
    if (s != 0) return;                          // 非 normal 全部忽略
    [self setTitle:t];
    [self _updateImagePosition];
}

// 0x1B9F9D128
- (void)setImage:(UIImage *)img forState:(NSUInteger)s {
    if (img.renderingMode == 0)
        img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    NSImage *ns = UIImageToNSImage(img);
    if (s != 0) return;
    [self setImage:ns];
    [self _updateImagePosition];
}
```

`UIButtonMacVisualProvider` 自己的 `_updateBackgroundViewWithConfiguration:` / `_updateTitleWithConfiguration:` / `_applyButtonValuesToConfiguration:` 负责后续整体刷新。

---

## 7. 事件回路（NS → UI）

UIKitMacHelper 在 NSControl 上注入了 `addTarget:action:forControlEvents:`，事件位掩码与 `UIControlEvents` 完全一致。`UIButtonMacVisualElement` 收到回调后只做一件事：把同样的 mask **送回真正的 UIButton**：

```c
// 0x1B9F9C770  trackingBeganAction:        → mask 1   (TouchDown)
// 0x1B9F9C7B8  trackingInsideAction:       → mask 4   (TouchDragInside)
// 0x1B9F9C800  trackingOutsideAction:      → mask 8   (TouchDragOutside)
// 0x1B9F9C848  trackingDraggingEnterAction:→ mask 16  (TouchDragEnter)
// 0x1B9F9C890  trackingDraggingExitedAction:→ mask 32  (TouchDragExit)
// 0x1B9F9C8D8  trackingEndedInsideAction:  → mask 64  (TouchUpInside)
// 0x1B9F9C920  trackingEndedOutsideAction: → mask 128 (TouchUpOutside)
- (void)trackingEndedInsideAction:(id)sender {
    [[self buttonControl] sendActionsForControlEvents:64];  // UIControlEventTouchUpInside
}
```

完整链路：

```
鼠标事件
  ↓ AppKit NSCell tracking
NSButton（UIKitMacHelper 扩展过的 NSControl）
  ↓ 触发 UIControlEvents 数值的 control event
UIButtonMacVisualElement.trackingXxxAction:
  ↓ [self.buttonControl sendActionsForControlEvents:mask]
UIButton（标准 UIControl dispatch）
  ↓
用户的 target/action / UIAction / @objc func
```

UIButton 端 `_visualProvider`、`_externalDrawingStyleForState:`、`_externalBorderColorForState:`、`_externalImageColorForState:` 这一组 "external" 方法是反向通道——NSButton 子类（如 `_NSDynamicallyBorderedButton`）查询 UIButton 当前应有的颜色/边框样式时用。

---

## 8. 关键地址速查

| 符号 | 地址 |
|------|------|
| `+[UIButton visualProviderClassForTraitCollection:]` | `0x1B996D114` |
| `+[UIButton _visualProviderClass]` | `0x1B996CFA4`（空 hook，返回 0） |
| `+[UIButton _visualProviderClassForIdiom:]` | `0x1B996CFAC`（空 hook，返回 0） |
| `+[UIButtonMacVisualElement visualElementForUIButton:]` | `0x1B9F9C294` |
| `+[UIButtonMacVisualElement nsControlForMenuAndNonConfigurationButtons:]` | `0x1B9F9BE70` |
| `+[UIButtonMacVisualElement _forwardPropertiesOnUIButton:toButtonRepresentable:]` | `0x1B9F9C3E0` |
| `-[UIButtonMacVisualElement initWithUIButtonRepesentable:]` | `0x1B9F9C4EC` |
| `-[UIButtonMacLegacyVisualProvider initWithVisualElement:button:]` | `0x1BA2EBBC8` |
| `-[NSButton(UIButtonRepresentable) setTitle:forState:]` | `0x1B9F9D014` |
| `-[NSButton(UIButtonRepresentable) setImage:forState:]` | `0x1B9F9D128` |
| `+[_UIButtonConfigurationCatalystTranslator nsButtonForConfiguration:traitCollection:]` | `0x1BA23E8B8` |
| `_OBJC_IVAR_$_UIButtonMacVisualElement._button` | `0x1ec791718` |
| `_OBJC_IVAR_$_UIButtonMacVisualElement._bridge` | `0x1ec79171c` |
| `_OBJC_IVAR_$_UIButtonMacLegacyVisualProvider._element` | `0x1eab2615c` |

---

## 9. 一句话总结

UIButton 在 Mac/Mac‑idiom 下并不是"渲染成 NSButton 的样子"，而是**把一个真正的 NSButton（或 NSPopUpButton/`_NSMenuButton`/`_NSDynamicallyBorderedButton` 等）当作子视图嵌入自己**：选哪一个由 `UIButtonMacVisualElement` 工厂决定（按 `buttonType`、`menu`、`changesSelectionAsPrimaryAction`、`showsMenuAsPrimaryAction`、`semanticContext` 路由），属性通过 `NSButton(UIButtonRepresentable)` 类别同步过去，事件通过 7 条 `addTarget:action:forControlEvents:` 把 NSControl tracking 映射回 `UIControlEvents` 再 `sendActionsForControlEvents:` 给 UIButton；NSView 与 UIView 之间的跨框架嵌入由 `_UINSView` (`NSViewHost`) 完成。
