# NSImageView 与 SF Symbol 动画在 Layer-Backing 路径下的失效根因

> 目标二进制: `/Volumes/Code/Dump/DyldSharedCaches/macOS/26.4/AppKit`
> IDA 数据库: `AppKit.i64`(dyld shared cache,macOS 26.4)
> 关注子类: 用户自定义的 `ImageView : NSImageView`(在 `commonInit` 中强制 `wantsLayer = true`、`layerContentsRedrawPolicy = .onSetNeedsDisplay`、覆盖 `wantsUpdateLayer`、覆盖 `updateLayer`)
> 现象: SF Symbol 动画(`addSymbolEffect:` / `setSymbolImage:withContentTransition:` 等)在该子类上完全不生效。

本报告以反编译/反汇编片段为证据,逐级追溯 NSImageView 的渲染入口、SF Symbol 动画的真实承载体,以及为什么子类一旦覆盖 `updateLayer` 就会让动画载体不再被创建(或被销毁)。

---

## 1. 顶层结论 (TL;DR)

NSImageView 在 macOS 12 之后**并不是真的自己绘制图像**:当满足一组条件(下文称之为 "subview 模式")时,它会懒创建一个私有 subview `_NSImageViewSimpleImageView`(继承自 `_NSSimpleImageView`),由这个 subview 承担:

- 图像绘制(走它自己的 `updateLayer`,addr `0x184aec38c`)
- SF Symbol 动画的全部 API(`addSymbolEffect:options:animated:` 等)
- 通过 RenderBox 的私有 `RBSymbolLayer` 驱动 per-frame 动画

NSImageView 上调用的所有 SF Symbol 方法(`-[NSImageView addSymbolEffect:options:animated:]` `0x1850d3c20`、`removeSymbolEffectOfType:options:animated:` `0x1850d3cd0` 等)**都是 trampoline**,内部:

1. `_updateImageSubviewIfNecessary` → 强制 subview 存在 (前提是 `_usesSubview` 为 YES)
2. `_imageSubview` → 取出 subview
3. 把对应消息转发给 subview

而 `_usesSubview`(`0x184a93620`)的判定中,**有四个会导致它强制返回 NO 的杀手条件**,其中两个直接命中用户子类:

> `_NSSubclassOverridesSelector(NSImageView, SubClass, @selector(drawRect:)) == YES`
> 或 `_NSSubclassOverridesSelector(NSImageView, SubClass, @selector(updateLayer)) == YES`

只要子类覆盖了 `updateLayer`(用户为了画圆角覆盖了它),`_usesSubview` 永远返回 NO → `_NSImageViewSimpleImageView` 不会被创建(`-[NSImageView layout]` 还会主动把它 remove 掉)→ 任何 `addSymbolEffect:` 调用都被转发到一个 `nil` subview → 完全静默失败。

这与 "layer-backed 是否开启" 几乎无关 — 即使保留 `wantsLayer = false`,只要子类覆盖了 `updateLayer`(哪怕只是写个 `super.updateLayer()`),SF Symbol 动画就会失效。`wantsLayer = true` 只是把这个 bug 提前暴露(因为大家通常是为了 layer-backed 才覆盖 `updateLayer`)。

---

## 2. NSImageView 的两条渲染路径

### 2.1 入口三件套全部由 `_usesSubview` 二分

#### `-[NSImageView wantsUpdateLayer]` @ `0x184a9361c`

```c
// 直接 thunk
void *__fastcall -[NSImageView wantsUpdateLayer](void *a1)
{
  return objc_msgSend(a1, "_usesSubview"); // 0x184a9361c
}
```

NSImageView 自己的 `wantsUpdateLayer` **不是常量 YES**,而是和 `_usesSubview` 同步 — subview 模式下走 `updateLayer` 路径,否则走 super(NSControl)的 `drawRect:` 路径。

#### `-[NSImageView updateLayer]` @ `0x184aeefec`

```c
id __fastcall -[NSImageView updateLayer](void *a1)
{
  -[NSImageView _updateRegistrationForIconAppearanceConfigurationChanges](); // 0x184aef000

  v2 = objc_msgSend(a1, "layer");
  if ( !v2 )
    __assert_rtn(..., "NSImageView.m", 568, "layer");

  v3 = v2;
  result = objc_msgSend(a1, "_usesSubview");
  if ( ((unsigned __int8)result & 1) == 0 )       // !_usesSubview
  {
    // 不走 subview,自己负责 layer.contents
    if ( (objc_opt_respondsToSelector(v3, _display_SEL) & 1) == 0 )
      __assert_rtn(..., "[layer respondsToSelector:@selector(_display)]");
    return objc_msgSend(v3, sel(_display));       // 调 layer 的私有 _display
  }
  return result;                                  // _usesSubview=YES → 什么都不做
}
```

关键点:
- `_usesSubview = YES` 路径下,`updateLayer` **不设置任何 contents**,因为绘制由 subview 自己的 layer 承担。
- `_usesSubview = NO` 路径下,它调用 `layer _display`(私有 SEL `0x1F9DA51D4`),这个会驱动 backing layer 自身的 contents 生成 — 等价于 "把 cell 画到 layer 上"。

#### `-[NSImageView drawRect:]` @ `0x184ae83e4`

```c
id __fastcall -[NSImageView drawRect:](_QWORD *a1, ...)
{
  -[NSImageView _updateRegistrationForIconAppearanceConfigurationChanges](); // 0x184ae8414
  if ( ((unsigned int)objc_msgSend(a1, "_usesSubview") & 1) != 0 )
  {
    // subview 模式下,drawRect 只负责画 NSImageFrameStyle 边框,内容由 subview 自己画
    v10 = (void *)a1[68];                         // cell
    objc_msgSend(a1, "bounds");
    return objc_msgSend(v10, "_drawBorderStyleWithRect:inView:", a1); // 0x184ae8468
  }
  else
  {
    v12.super_class = (Class)&OBJC_CLASS___NSImageView;
    return objc_msgSendSuper2(&v12, sel(drawRect:), ...);              // 0x184ae8494
  }
}
```

`drawRect:` 也是按 `_usesSubview` 二分:subview 模式只画外框,内容委托给 subview;非 subview 模式 fallback 到 NSControl.drawRect → NSImageCell.drawWithFrame:inView:。

---

## 3. `_usesSubview` 的完整决策逻辑

### 3.1 反编译(`0x184a93620`)

```c
__int64 __fastcall -[NSImageView _usesSubview](__int64 a1)
{
  v1 = *(_DWORD *)(a1 + 596);
  if ( (v1 & 4) == 0 )                            // bit 2 = "cache valid"
  {
    v3 = objc_opt_class(&OBJC_CLASS___NSImageView);
    v4 = objc_opt_class(a1);                      // self 的 class
    v5 = objc_opt_class(&OBJC_CLASS___NSImageCell);

    v6 = *(_QWORD *)(a1 + 544);                   // NSControl._cell
    v7 = v6 ? objc_opt_class(v6) : objc_msgSend(v4, "cellClass");
    v8 = v7;                                      // 实际 cell class

    v9 = atomic_load(&sNSImageViewUsesSubviewComputedValue);
    if ( v9 == 2                                  // 1) 全局 override 为 NO
      || !v9
         && !_NSGetBoolAppConfig(@"NSImageViewUsesSubview",
                                 default=YES, &cache, NSImageViewUsesSubviewDefaultValueFunction)
                                                  //    或 app 配置关闭
      || _NSSubclassOverridesSelector(v3, v4, @selector(drawRect:))    // 2) 覆盖了 drawRect:
      || _NSSubclassOverridesSelector(v3, v4, @selector(updateLayer))  // 3) 覆盖了 updateLayer
      || v8 != v5                                                      // 4) cellClass != NSImageCell
      || objc_msgSend((id)a1, "_usesCustomLayer") )                    // 5) 用了 custom layer
    {
      v10 = (*(_DWORD *)(a1 + 596) & 0xFFFFFFFD); // 清 bit 1
    }
    else
    {
      v10 = (*(_DWORD *)(a1 + 596) | 2);          // 置 bit 1 = "uses subview"
    }
    *(_DWORD *)(a1 + 596) = v10 | 4;              // bit 2 = cache valid
  }
  return (v1 >> 1) & 1;                           // 返回 bit 1
}
```

### 3.2 关键 ARM64 反汇编(节选自 `0x184a9361c – 0x184a9375c`)

```text
0x184a936b8  ADRP X8, #0x1F9F3AA75@PAGE         ; SEL @"drawRect:"
0x184a936bc  ADD  X2, X8, #0x1F9F3AA75@PAGEOFF
0x184a936c0  MOV  X0, X20                       ; NSImageView class
0x184a936c4  MOV  X1, X21                       ; self class
0x184a936c8  BL   __NSSubclassOverridesSelector
0x184a936cc  TBZ  W0, #0, loc_184A936F8         ; 若未覆盖 drawRect: → 跳下一个检查
0x184a936d0  ...                                 ; 走 false 路径(清 bit 1)

0x184a936f8  ADRP X8, #off_1E5AC5B38@PAGE       ; SEL @"updateLayer"
0x184a936fc  LDR  X2, [X8,#off_1E5AC5B38@PAGEOFF]
0x184a93700  MOV  X0, X20
0x184a93704  MOV  X1, X21
0x184a93708  BL   __NSSubclassOverridesSelector
0x184a9370c  TBNZ W0, #0, loc_184A936D0         ; 若覆盖 updateLayer → 立刻走 false 路径
0x184a93710  CMP  X23, X22                      ; cellClass vs NSImageCell
0x184a93714  B.NE loc_184A936D0
0x184a93718  MOV  X0, X19
0x184a9371c  BL   _objc_msgSend$_usesCustomLayer
0x184a93720  TBNZ W0, #0, loc_184A936D0
0x184a93724  LDR  W8, [X19,X24]
0x184a93728  ORR  W8, W8, #2                    ; 通过 → 置 bit 1 (uses subview)
0x184a9372c  B    loc_184A936D8
```

> 注意 `0x184a936f8 – 0x184a93728` 这段:`updateLayer` 检查的 TBNZ 是 "命中即跳 false 路径"。这就是用户子类的入口陷阱。

### 3.3 `_NSSubclassOverridesSelector` (`0x1849b3c04`)

```c
bool __fastcall _NSSubclassOverridesSelector(objc_class *a1, objc_class *a2, SEL name)
{
  if ( a1 == a2 )                                 // 同类 → 不算 override
    return 0;
  MethodImplementation = class_getMethodImplementation(a1, name); // NSImageView 的 IMP
  v6 = class_getMethodImplementation(a2, name);                   // self class 的 IMP
  if ( MethodImplementation )
    v7 = v6 == 0;
  else
    v7 = 1;
  return !v7 && MethodImplementation != v6;       // IMP 不同 → 被覆盖
}
```

这是按 IMP 比较,无法用 `dynamic`/`@objc(method)` 之类的方式骗过 — Swift `open override func updateLayer()` 必然产生一个独立 IMP。

### 3.4 缓存机制

- bit `0x4` (mask `0x00000004`): cache valid
- bit `0x2` (mask `0x00000002`): "uses subview" 缓存值
- bit `0x1` (mask `0x00000001`): "_imageSubview 已创建"(由 `_setImageSubview:` 维护,见 `0x184aad274`)

`_usesSubview` 第一次调用后会把判定结果固化在 ivar offset 596(`_ivFlags`)。`-[NSImageView _updateUsesSubview]`(`0x184a93840`)会清掉 cache bit 并重新计算,在 `setLayer:` / `setCell:` 等触发时被调用。

### 3.5 触发重算的入口

`-[NSImageView setLayer:]` @ `0x184ae02a8`:

```c
void *-[NSImageView setLayer:](void *a1)
{
  objc_super super = { a1, &OBJC_CLASS___NSImageView };
  objc_msgSendSuper2(&super, sel(setLayer:));     // 0x184ae02d8
  return objc_msgSend(a1, "_updateUsesSubview");  // 0x184ae02f0
}
```

也就是说,**用户在 `commonInit` 里设置 `wantsLayer = true`** 会触发 `setLayer:` → `_updateUsesSubview` → 清缓存 → 下次 `_usesSubview` 重新跑判定,因为子类覆盖了 `updateLayer`,结果会再次得到 NO。

### 3.6 layout 路径下的拆除

`-[NSImageView layout]` @ `0x184aad1e4`:

```c
id -[NSImageView layout](void *a1)
{
  if ( objc_msgSend(a1, "_usesSubview") )
  {
    objc_msgSend(a1, "_updateImageSubview");      // 创建/更新 subview
    objc_msgSend(a1, "_updateBezelView");
  }
  else
  {
    // _usesSubview = NO → 主动销毁 subview!
    objc_msgSend(objc_msgSend(a1, "_imageSubview"), "removeFromSuperview");
    objc_msgSend(a1, "_setImageSubview:", 0);
    objc_msgSend(objc_msgSend(a1, "_bezelView"),  "removeFromSuperview");
    objc_msgSend(a1, "set_bezelView:", 0);
  }
  objc_msgSendSuper2(&super, sel(layout));
}
```

这意味着即便有人在子类失效之前就用过 `addSymbolEffect:`(强行调用 `_updateImageSubviewIfNecessary` 创建了 subview),只要进入下一次 `layout()` 且 `_usesSubview` 是 NO,subview 会被立刻 detach 并清空 — 动画载体被释放,动画戛然而止。

---

## 4. SF Symbol 动画的真实承载体

### 4.1 NSImageView 上所有 Symbol API 都是 trampoline

| selector | addr | 行为 |
|---|---|---|
| `addSymbolEffect:` | `0x1850d3bcc` | 转 `addSymbolEffect:options:` |
| `addSymbolEffect:options:` | `0x1850d3c18` | 转 `addSymbolEffect:options:animated:` |
| `addSymbolEffect:options:animated:` | `0x1850d3c20` | **核心 trampoline**(见下) |
| `removeSymbolEffectOfType:*` | `0x1850d3c7c – 0x1850d3cd0` | 同上模式 |
| `removeAllSymbolEffects*` | `0x1850d3d20 – 0x1850d3d6c` | 同上模式 |
| `setSymbolImage:withContentTransition:*` | `0x1850d3dac – 0x1850d3e08` | 同上模式 |

`-[NSImageView addSymbolEffect:options:animated:]`(`0x1850d3c20`):

```c
void __cdecl -[NSImageView addSymbolEffect:options:animated:](
        NSImageView *self, SEL, NSSymbolEffect *symbolEffect,
        NSSymbolEffectOptions *options, BOOL animated)
{
  v5 = animated;
  -[NSImageView _updateImageSubviewIfNecessary](self);                 // 0x1850d3c44
  v9 = -[NSImageView _imageSubview](self);                             // 0x1850d3c4c
  objc_msgSend(v9, "addSymbolEffect:options:animated:",
               symbolEffect, options, v5);                             // 0x1850d3c78
}
```

`_updateImageSubviewIfNecessary` @ `0x1850d4980`:

```c
void *__fastcall -[NSImageView _updateImageSubviewIfNecessary](void *a1)
{
  result = objc_msgSend(a1, "_usesSubview");
  if ( (_DWORD)result )                           // ← 守门员!
  {
    objc_msgSend(a1, "_updateImageSubview");
    return objc_msgSend(a1, "_updateBezelView");
  }
  return result;                                  // _usesSubview=NO → 直接返回,不创建
}
```

`_imageSubview` @ `0x184a942c8`:

```c
id -[NSImageView _imageSubview](_BYTE *a1)
{
  if ( (a1[596] & 1) != 0 )                       // bit 0 标记 subview 是否已存在
    return objc_getAssociatedObject(a1, key);
  return nil;
}
```

**死锁链清晰可见**:
- `_usesSubview = NO` → `_updateImageSubviewIfNecessary` 直接返回,**不会**创建 subview
- `_imageSubview` 返回 nil
- `objc_msgSend(nil, "addSymbolEffect:options:animated:", …)` 是 ObjC 中合法的 noop
- SF Symbol 调用静默失败,没有任何 warning/log

### 4.2 subview 的懒创建

`-[NSImageView _updateImageSubview]` @ `0x184ad0a30`:

```c
_NSImageViewSimpleImageView *-[NSImageView _updateImageSubview](void *a1)
{
  v2 = objc_msgSend(a1, "_imageSubview");
  if ( !v2 )
  {
    v2 = objc_autorelease(
           -[_NSImageViewSimpleImageView initWithOwnerView:](        // 0x1850d6f5c
             objc_alloc(&OBJC_CLASS____NSImageViewSimpleImageView),
             "initWithOwnerView:", a1));
    -[_NSImageViewSimpleImageView setShouldBeArchived:](v2, ..., 0);
    -[_NSImageViewSimpleImageView setIgnoreHitTest:](v2, ..., 1);
    objc_msgSend(a1, "_setImageSubview:", v2);                       // 写入 associated obj
    objc_msgSend(a1, "_setImageViewHierarchyNeedsDisplay:", 1);
  }
  // ... 计算 frame,setFrame: + addSubview 等
}
```

`_NSImageViewSimpleImageView` 是 `_NSSimpleImageView` 的子类(`_OBJC_CLASS_$__NSImageViewSimpleImageView` 在 `0x1ec34af30`,superclass 字段指向 `0x1ec34b4a8 = _OBJC_CLASS_$__NSSimpleImageView`)。
它本身只覆盖了 `image`(从 owner 拿)、`imageContentStyle`、`userInterfaceLayoutDirection`、`iconAppearanceConfiguration`。真正的 SF Symbol 动画实现全部在父类 `_NSSimpleImageView`。

### 4.3 `_NSSimpleImageView` 才是真正驱动 Symbol 动画的层

通过 ObjC class_ro_t 表枚举,`_NSSimpleImageView` 拥有:

```text
-[_NSSimpleImageView wantsUpdateLayer]                                @ 0x184a7c168    → return 1
-[_NSSimpleImageView updateLayer]                                     @ 0x184aec38c
-[_NSSimpleImageView _enableSymbolEffectsIfNecessary]                 @ 0x1850d5e00
-[_NSSimpleImageView _isSymbolAndRBLayerImageView]                    @ 0x1850d5ea0
-[_NSSimpleImageView _ensureRBLayer]                                  @ 0x1850d5ee4
-[_NSSimpleImageView _teardownRBLayerIfNeeded]                        @ 0x1850d5fac
-[_NSSimpleImageView _configureSymbolLayer]                           @ 0x1850d6960
-[_NSSimpleImageView addSymbolEffect:options:animated:]               @ 0x1850d6b1c
-[_NSSimpleImageView removeSymbolEffectOfType:options:animated:]      @ 0x1850d6d58
-[_NSSimpleImageView removeAllSymbolEffectsWithOptions:animated:]     @ 0x1850d6d00
-[_NSSimpleImageView setSymbolImage:withContentTransition:options:]   @ 0x1850d6db0
```

#### `-[_NSSimpleImageView wantsUpdateLayer]`(`0x184a7c168`)

```c
bool -[_NSSimpleImageView wantsUpdateLayer](...) { return 1; }
```

它**强制返回 YES**,而且是直接常量,不像 NSImageView 那样取决于其它条件。

#### `-[_NSSimpleImageView updateLayer]`(`0x184aec38c`)

```c
void -[_NSSimpleImageView updateLayer](_NSSimpleImageView *self, SEL)
{
  if ( -[_NSSimpleImageView _isSymbolAndRBLayerImageView](self) )
  {
    -[_NSSimpleImageView _configureSymbolLayer](self);    // SF Symbol 路径
  }
  else
  {
    // 普通图像:直接生成 CGImage 设到 layer.contents
    v3 = -[_NSSimpleImageView layer](self);
    -[_NSSimpleImageView _teardownRBLayerIfNeeded](self);
    v5 = -[_NSSimpleImageView image](self);
    // ... 用 effectiveAppearance / iconAppearanceConfiguration / imageContentStyle
    // 通过 NSImageHintAppearance / NSImageHintCTM / kCIContextOutputColorSpace
    // 调 CGImageForProposedRect:context:hints: 拿 CGImage,然后写入 layer
  }
}
```

`_isSymbolAndRBLayerImageView` 与 `_shouldUseRBSymbolLayer` ivar 协同 — 当 image 是 symbol 时,`_enableSymbolEffectsIfNecessary`(`0x1850d5e00`)会把 ivar 置 1,并通过 `_ensureRBLayer` 准备 `RBSymbolLayer`。

#### `-[_NSSimpleImageView _enableSymbolEffectsIfNecessary]`(`0x1850d5e00`)

```c
void -[_NSSimpleImageView _enableSymbolEffectsIfNecessary](_NSSimpleImageView *self, SEL)
{
  if ( !self->_shouldUseRBSymbolLayer
    && objc_msgSend(-[_NSSimpleImageView image](self), "_isSymbolImage") )
  {
    self->_shouldUseRBSymbolLayer = 1;
    -[_NSSimpleImageView _ensureRBLayer](self);
    -[_NSSimpleImageView _configureSymbolLayer](self);

    // 把 owner NSImageView 标记 needsDisplay
    v3 = -[_NSSimpleImageView superview](self);
    if ( objc_opt_isKindOfClass(v3, NSImageView_class) )
      v5 = v3;
    else
      v5 = nil;
    objc_msgSend(v5, "setNeedsDisplay:", 1);
  }
}
```

#### `-[_NSSimpleImageView addSymbolEffect:options:animated:]`(`0x1850d6b1c`)

```c
void -[_NSSimpleImageView addSymbolEffect:options:animated:](
        _NSSimpleImageView *self, SEL, id effect, id opts, bool animated)
{
  -[_NSSimpleImageView _enableSymbolEffectsIfNecessary](self);

  v9  = -[RBSymbolLayer animator](self->_symbolLayer);             // ← 关键:RBSymbolLayer animator
  v10 = [[[effect _rbOptionsWithEffectOptions:opts] mutableCopy] autorelease];

  // 处理 wiggle / scale / disappear / drawoff
  if ( animated )
    objc_msgSend(v9, "addAnimation:options:",
                 [[effect _rbAnimation] integerValue], v10);
  ...
  objc_msgSend(v9, "setDepth:", depth);
  objc_msgSend(v9, "setHidden:", needsHidden & 1);
}
```

`self->_symbolLayer` 是 `RBSymbolLayer`(RenderBox framework 的私有类),它持有一个 `animator`(`-[RBSymbolLayer animator]`),所有 per-frame 动画都靠它驱动(底层应当是 `CADisplayLink` / `CADisplayLinker` + `CAAnimation`,但这些都在 RenderBox 内部)。

---

## 5. 用户子类失败的完整追踪

回到用户代码:

```swift
open class ImageView: NSImageView {
    private func commonInit() {
        wantsLayer = true                                    // (a)
        layerContentsRedrawPolicy = .onSetNeedsDisplay       // (b)
        setup()
    }
    open override var wantsUpdateLayer: Bool { true }        // (c)
    open override func updateLayer() {                       // (d)
        super.updateLayer()
        layer?.cornerRadius = isRounded ? max(bounds.midX, bounds.midY) : 0
    }
}
```

让我们走一遍:

1. `init(frame:)` → `super.init(frame:)` → `-[NSImageView initWithFrame:]`(`0x184a93368`)
   - 没有立刻调用 `_updateUsesSubview`。但 `_ivFlags |= 0x60000000` 设置了一些 default flags,并调用 `_commonInit`。
   - 此时 `_usesSubview` 的 cache bit (bit 2) **未设置**。

2. `commonInit()` 中 `wantsLayer = true` → 触发 `NSView.setWantsLayer:` → 最终触发 `-[NSImageView setLayer:]`(`0x184ae02a8`):
   - 调用 super.setLayer:
   - 调用 `_updateUsesSubview`(`0x184a93840`),后者清掉 cache bit (bit 2) 并立即重新走 `_usesSubview` → 触发判定。

3. `_usesSubview` 跑判定(`0x184a93620`):
   - `_NSSubclassOverridesSelector(NSImageView, ImageView, drawRect:)` = **NO**(用户未覆盖)→ 通过
   - `_NSSubclassOverridesSelector(NSImageView, ImageView, updateLayer)` = **YES**(用户覆盖了!)→ **走 false 路径**
   - 结果:bit 1 清零,bit 2 置位。`_usesSubview = NO`。

4. 由于 `_usesSubview = NO`,且 `_imageSubview` 还没创建,bit 0 也是 0。当用户写 `imageView.addSymbolEffect(.bounce)`:
   - `-[NSImageView addSymbolEffect:options:animated:]`(`0x1850d3c20`)被调用
   - 内部 `_updateImageSubviewIfNecessary`(`0x1850d4980`)发现 `_usesSubview = NO`,直接 return,**不创建 subview**
   - 紧接着 `_imageSubview` 返回 nil
   - 最后一句 `objc_msgSend(nil, "addSymbolEffect:options:animated:", …)` — ObjC nil-messaging,默默无效

5. 接下来 `imageView.image = aSymbolImage`:
   - `-[NSImageView setImage:]`(`0x184a94738`) → `NSImageViewSetObjectValue` → 内部会调用 cell 的 setObjectValue: 并 `setNeedsDisplay:`
   - 由于 `wantsLayer = true` 且 `wantsUpdateLayer`(用户覆盖了 = YES,但 NSImageView 自己的 `wantsUpdateLayer` 也会被覆盖路径决定),AppKit 走 `updateLayer` 路径
   - 用户的 `updateLayer` 调用 `super.updateLayer()` → `-[NSImageView updateLayer]`(`0x184aeefec`)
   - `_usesSubview = NO` 分支 → 调用 `objc_msgSend(layer, sel(_display))` → CALayer 的私有 `_display` 会触发 cell 把图像绘制到 layer.contents

6. 用户看到的是:
   - **图像本身能显示**(因为 NSImageView 的 fallback 路径仍然能让 cell 通过 `layer _display` 把 image 画到 backing layer 上,这条路径不需要 subview)
   - **`addSymbolEffect:` 完全无效**(subview 不存在,所有 symbol API 是空 dispatch)
   - **圆角能生效**(用户自己的 updateLayer 在 super 之后设了 cornerRadius)

7. 任何 `setNeedsLayout:` 触发的 `-[NSImageView layout]` 都会走 `_usesSubview = NO` 分支,把任何残留的 subview 拆掉 — 这意味着即使你绕开 trampoline、强行通过私有方法或 KVC 给某个 subview 装动画,下一次 layout 也会被清掉。

---

## 6. 为什么 `_usesSubview` 会有这种 "杀手开关"

这是 Apple 在 macOS 12 引入 `_NSSimpleImageView` 做 layer-backed 绘制路径时的兼容保护:

- **如果你的子类已经接管了 `drawRect:` 或 `updateLayer`**,Apple 假定你想要 "自己控制怎么画",于是退化到 "经典 NSImageCell 在你的 layer 上画"(`_display` 私有 SEL)的模式。
- 这条退化路径**只是绘制兼容**,它不会让 `_NSSimpleImageView` 出现 → SF Symbol 动画相关的 RBSymbolLayer / RBSymbolLayer.animator 没人持有 → 你的 `addSymbolEffect:` 找不到家。
- 类似地,如果你的 cellClass 不是 NSImageCell(自定义 cell)、调用了 `_usesCustomLayer`,也会得到同样的退化。

`drawRect:` 和 `updateLayer` 的覆盖检查使用 `class_getMethodImplementation` 来对比 IMP — 任何在 Swift 里 `override func updateLayer()` 都会被识别,**没有办法用 dynamic / @objc(method) 之类的技巧绕过**。

---

## 7. 修复建议(按优先级,从最稳到最激进)

### 7.1 推荐:**不覆盖 `updateLayer`,圆角通过 CAShapeLayer mask 实现**

最小代价、最安全。让 NSImageView 保留默认的 layer-backed 路径(`_usesSubview = YES`,subview 模式启用),只通过 `layer.mask` 给整个 view 应用圆角形状。

```swift
open class ImageView: NSImageView {
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        wantsLayer = true
        // 不覆盖 updateLayer / drawRect:,不强制 layerContentsRedrawPolicy
        setup()
    }
    open func setup() {}

    @ViewInvalidating(.layout)   // ← 注意:改成 layout invalidating(因为我们用 mask)
    @IBInspectable
    open var isRounded: Bool = false

    open override func layout() {
        super.layout()
        updateRoundedMaskIfNeeded()
    }

    private func updateRoundedMaskIfNeeded() {
        guard isRounded else {
            layer?.mask = nil
            return
        }
        let radius = max(bounds.midX, bounds.midY)
        let maskLayer = (layer?.mask as? CAShapeLayer) ?? CAShapeLayer()
        maskLayer.frame = bounds
        maskLayer.path = CGPath(roundedRect: bounds,
                                cornerWidth: radius, cornerHeight: radius,
                                transform: nil)
        layer?.mask = maskLayer
    }
}
```

要点:
- **关键约束**:不要 override `updateLayer`、不要 override `drawRect:`,不要换 cell 类。这样 `_usesSubview = YES` 一直成立。
- `layer.mask = CAShapeLayer` 会作用在整棵 sublayer 树上,包含 subview `_NSImageViewSimpleImageView` 的 backing layer 也会被裁剪到圆角内。SF Symbol 动画依旧在 RBSymbolLayer 上运行,只是被 mask 形状裁掉边角而已。
- 不会阻断 `_usesSubview` 的判定。

### 7.2 折中:保留 `wantsLayer = true`,但**不接管 `updateLayer`**,只在 layout 阶段管 `cornerRadius`

如果你想要的是 `layer.cornerRadius` 那种贴边硬边的圆角(不是 mask path),仍可以做到 — 关键是别覆盖 `updateLayer`:

```swift
open class ImageView: NSImageView {
    private func commonInit() {
        wantsLayer = true
        setup()
    }
    open func setup() {}

    @ViewInvalidating(.layout)
    @IBInspectable
    open var isRounded: Bool = false

    open override func layout() {
        super.layout()
        if isRounded {
            layer?.cornerRadius = max(bounds.midX, bounds.midY)
            layer?.masksToBounds = true       // 否则圆角对 sublayer 无效
        } else {
            layer?.cornerRadius = 0
            layer?.masksToBounds = false
        }
    }
}
```

注意:
- `layer.masksToBounds = true` 才能让 cornerRadius 作用到 sublayer(包括 `_NSImageViewSimpleImageView` 的 layer)。否则圆角只会作用在 NSImageView 自己的 layer.backgroundColor 上,而不影响 subview。
- SF Symbol 动画继续在 subview 的 RBSymbolLayer 上正常运行。

### 7.3 不推荐:保留覆盖 `updateLayer`,但**手动把 `addSymbolEffect:` 桥接给 subview**

理论上可以通过给图层手动加一个 `_NSSimpleImageView` 来恢复 SF Symbol 路径,但代价巨大:
- 必须自己创建 / 维护 subview 的生命周期
- 还需要复制 NSImageView 内部对 placeholder / asynchronous preparation / iconAppearanceConfiguration 的处理
- 任何系统 `layout()` 调用都会因为 `_usesSubview = NO` 把你的 subview 干掉(见 `-[NSImageView layout]` 0x184aad1e4)

这条路属于 "对抗 AppKit",**不要走**。

### 7.4 如果一定要走 "完全自绘"

如果业务上确实需要完全控制绘制(例如复杂滤镜、特殊蒙版),那就同时放弃 SF Symbol 动画。在这种情况下,改成继承 `NSView` 而不是 `NSImageView`,自行画 `NSImage`,这样语义更清晰。继续继承 NSImageView 然后又覆盖 `updateLayer` 是一个语义陷阱 — 看上去你还是 "NSImageView",但实际丢失了它的 modern path 全部能力(SF Symbol、placeholder I/O、iconAppearanceConfiguration、asynchronous preparation)。

---

## 8. 给 `UIFoundation` 项目内部的具体建议

考虑到 `Sources/UIFoundationAppKit/Base/LayerBackedView.swift` 已经是这套 "强制 wantsLayer + 覆盖 updateLayer" 的基类抽象,**不应该把它直接继承到 NSImageView 子类上**。建议:

1. 不要让 NSImageView 子类继承 `LayerBackedView`。
2. 为图像类提供一个独立基类(例如 `XiblessImageView`)只:
   - `wantsLayer = true`(让系统自己接管 backing layer)
   - 提供 `setup()` / `firstLayout()` hook
   - 把圆角等装饰通过 `layer.mask`(或 `layer.cornerRadius + masksToBounds` 在 `layout()` 中设)实现,而**不覆盖 `updateLayer` 或 `drawRect:`**
3. 在 `LayerBackedView` 的文档里加一条警告:**继承自该类的 view 不应再用 NSImageView / NSImageView 子类做组合**(因为这两个的 layer-backed 协议是不兼容的)。

---

## 9. 反汇编/反编译关键地址速查

| 名称 | 地址 |
|---|---|
| `-[NSImageView initWithFrame:]` | `0x184a93368` |
| `-[NSImageView setLayer:]` | `0x184ae02a8` |
| `-[NSImageView wantsUpdateLayer]` | `0x184a9361c` |
| `-[NSImageView _usesSubview]` | `0x184a93620` |
| `-[NSImageView _updateUsesSubview]` | `0x184a93840` |
| `-[NSImageView drawRect:]` | `0x184ae83e4` |
| `-[NSImageView updateLayer]` | `0x184aeefec` |
| `-[NSImageView _imageSubview]` | `0x184a942c8` |
| `-[NSImageView _setImageSubview:]` | `0x184aad274` |
| `-[NSImageView _updateImageSubview]` | `0x184ad0a30` |
| `-[NSImageView _updateImageSubviewIfNecessary]` | `0x1850d4980` |
| `-[NSImageView layout]` | `0x184aad1e4` |
| `-[NSImageView setNeedsDisplayInRect:]` | `0x184a94264` |
| `-[NSImageView _shownImage]` | `0x1850d3310` |
| `-[NSImageView addSymbolEffect:options:animated:]` | `0x1850d3c20` |
| `_NSSubclassOverridesSelector` | `0x1849b3c04` |
| `_NSImageViewSimpleImageView` class | `_OBJC_CLASS_$__NSImageViewSimpleImageView` @ `0x1ec34af30` |
| `_NSImageViewSimpleImageView initWithOwnerView:` | `0x1850d6f5c` |
| `_NSSimpleImageView` class | `_OBJC_CLASS_$__NSSimpleImageView` @ `0x1ec34b4a8` |
| `-[_NSSimpleImageView wantsUpdateLayer]` | `0x184a7c168` |
| `-[_NSSimpleImageView updateLayer]` | `0x184aec38c` |
| `-[_NSSimpleImageView _enableSymbolEffectsIfNecessary]` | `0x1850d5e00` |
| `-[_NSSimpleImageView _ensureRBLayer]` | `0x1850d5ee4` |
| `-[_NSSimpleImageView _configureSymbolLayer]` | `0x1850d6960` |
| `-[_NSSimpleImageView addSymbolEffect:options:animated:]` | `0x1850d6b1c` |

---

## 10. 一句话总结

> NSImageView 的 SF Symbol 动画依赖一个私有的 `_NSImageViewSimpleImageView` 子 view,但 `_usesSubview`(`0x184a93620`)只在子类**没有**覆盖 `drawRect:`、`updateLayer`,且使用默认 `NSImageCell`、未启用 custom layer 时才返回 YES。用户子类覆盖了 `updateLayer`(`_NSSubclassOverridesSelector` 命中)→ subview 永不创建,所有 `addSymbolEffect:` 调用沦为 nil-messaging,动画无声失效。修复方法是**不要覆盖 `updateLayer`/`drawRect:`**,把圆角改用 `layer.mask = CAShapeLayer` 或 `layer.cornerRadius + masksToBounds`(在 `layout()` 里设置)。
