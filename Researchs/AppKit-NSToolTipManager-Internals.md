# AppKit `NSToolTipManager` 内部实现与可定制改造方案

> 调研对象：macOS 26.5 / `dyld_shared_cache_arm64e` 中的 AppKit
> 调研工具：RuntimeViewerMCP dump 出来的 ObjCHeaders + IDA Pro `idalib` MCP
> 调研目标：摸清系统 tooltip 的渲染管线，找出可以"和系统行为一致、只换样式"的最小改造路径，落地到 `UIFoundationAppleInternal` 模块
> 状态：调研已完成，实现方案 **待批准** 后开工

---

## 1. 背景

`NSView.toolTip` 触发的系统提示框由 `NSToolTipManager` 接管，外观完全由私有渲染管线决定，公开 API 上没有任何可调样式的开关：

- `NSViewToolTipOwner` 协议只能换**文本**（每个矩形区域返回不同的 `NSString`），样式、字体、背景、圆角、padding、阴影一概不能动。
- `NSToolTipManager` 公开方法只有 `+sharedToolTipManager` 和 `-setInitialToolTipDelay:`，仅暴露延迟。
- `NSColor.toolTipColor` 存在但是**私有**符号，普通工程无法直接拿到。

因此唯一的可控路径是吃下 `NSToolTipManager` 的私有 hook —— 这正是放进 `UIFoundationAppleInternal` 模块的合理理由。

---

## 2. 类结构总览

```text
NSToolTipManager  (单例 +sharedToolTipManager)
├─ _normalToolTipPanel        : NSToolTipPanel : NSPanel
│       contentView           = NSVisualEffectView  (material=.toolTip / 17)
│                                 └─ NSCustomToolTipDrawView (autolayout pin 四边)
└─ _expansionToolTipPanel     : NSToolTipPanel : NSPanel
        contentView           = NSVisualEffectView  (material=.toolTip / 17)
                                  └─ NSCustomToolTipDrawView

NSToolTip                     ── 数据模型：view / cell / owner / string / trackingRect
                                   ownerIsDisplayDelegate / isExpansionToolTip / fadesOutWhenInactive

NSToolTipStringDrawingLayoutManager  ── 单例，计算 attributed string 的最佳尺寸
                                       (+sizeForDisplayingAttributedString:)

NSViewToolTipOwner            ── 公开协议，决定"显示什么字"，决定不了样式

NSViewDynamicToolTipManager  ── per-view 动态 tooltip 跟踪器
NSTableViewDynamicToolTipManager
_NSMenuToolTipManager
```

### 2.1 `NSToolTipManager` ivar 布局

```objc
@interface NSToolTipManager : NSObject {
    NSMapTable *_toolTipsByView;                        // +8
    CGFloat _toolTipDelay;                              // +16   ← 公开 setter 控制
    NSDate *_timeToolTipRemovedFromScreen;              // +24
    struct __CFRunLoopTimer *_toolTipDisplayTimer;      // +32
    CGFloat _currentFadeValue;                          // +40
    NSTimer *_fadeTimer;                                // +48
    NSWindow *_lastToolTipWindow;                       // +56  (weak)
    NSToolTip *_currentDisplayedNormalToolTip;          // +64  ← 显示时序里唯一的"当前 view"线索
    NSToolTipPanel *_normalToolTipPanel;                // +72
    NSCustomToolTipDrawView *_normalToolTipDrawView;    // +80
    NSToolTip *_currentDisplayedExpansionToolTip;       // +88
    NSToolTipPanel *_expansionToolTipPanel;             // +96
    NSCustomToolTipDrawView *_expansionToolTipDrawView; // +104
}
```

### 2.2 `NSToolTipPanel`

```objc
@interface NSToolTipPanel : NSPanel {
    NSString *_toolTipString;                           // +520
}
@property (nonatomic, strong) NSString *toolTipString;
- (void)_setLevelToShowAboveWindow:(id)window;
@end
```

### 2.3 `NSCustomToolTipDrawView`

```objc
@interface NSCustomToolTipDrawView : NSView
@property (strong) NSToolTip *toolTipObject;
@property (copy)   NSAttributedString *attributedString;
@property          CGSize margin;
@end
```

### 2.4 `NSToolTip`

```objc
@interface NSToolTip : NSObject {
    struct {
        int32_t ownerIsDisplayDelegate : 1;
        int32_t fadesOutWhenInactive   : 1;
        int32_t isExpansionToolTip     : 1;
        int32_t reserved               : 29;
    } ttFlags;                                          // +32
    NSDictionary *_dataDictionary;                      // +56
    void *_weakData;                                    // +64
}
@property (nonatomic, copy)     NSString *string;
@property (nonatomic, readonly) NSView   *view;
@property (nonatomic, readonly) NSCell   *cell;
@property (nonatomic, readonly) id        owner;
@property (nonatomic, readonly) CGRect    trackingRect;
@property (nonatomic) BOOL ownerIsDisplayDelegate;
@property (nonatomic, readonly) BOOL fadesOutWhenInactive;
@end
```

---

## 3. 系统默认外观参数

| 项 | 默认值 | 出处方法（IDA 地址） |
|---|---|---|
| 字体 | `[NSFont toolTipsFontOfSize:0]` 私有；找不到则 fallback `Helvetica 10pt` | `-[NSToolTipManager toolTipAttributes]`  `0x184CA3F10` |
| 文本色 | `NSColor.labelColor`（公开语义色） | `-[NSToolTipManager toolTipTextColor]`  `0x184CA3FA0` |
| 背景色 | `NSColor.toolTipColor`（私有；与毛玻璃配套） | `-[NSToolTipManager toolTipBackgroundColor]`  `0x184CA4DFC` |
| 内边距 padding | `CGSize(width: 6, height: 2)` | `-[NSToolTipManager toolTipContentMargin]`  `0x184CA4838` |
| 距光标 Y 偏移 | `cursorScale × 18.0`（由 `CGSGetCursorScale` 拿） | `-[NSToolTipManager toolTipYOffset]`  `0x184CA48C0` |
| 窗口圆角/阴影 | `NSVisualEffectView material:.toolTip` 系统画 | `-[NSToolTipManager _newToolTipWindow]`  `0x184CA4AB0` |
| 窗口 styleMask | `0`（borderless） | 同上 |
| 窗口 backing | `NSBackingStoreBuffered` | 同上 |
| 窗口 level | `103` + `_setLevelToShowAboveWindow:` 进一步抬到父窗口之上 | 同上 |
| 显示延迟 | `_toolTipDelay`（公开 `setInitialToolTipDelay:`） | `-[NSToolTipManager setInitialToolTipDelay:]`  `0x185688090` |
| 失活后淡出 | 10.0 秒（写死） | `-[NSToolTipManager displayToolTip:]` 末尾 |
| 文本对齐 | `[NSAttributedString drawWithRect:options:1 context:_sharedStringDrawingContext]`，`options=1` 即 `usesLineFragmentOrigin` | `-[NSCustomToolTipDrawView drawRect:]` |

### 3.1 `toolTipAttributes` 详细

```c
+ (void)_invoke_block_for_toolTipAttributes() {
    NSFont *font = [NSFont toolTipsFontOfSize:0.0];
    // 私有 +[NSFont toolTipsFontOfSize:] —— 系统 tooltip 字体
    if (!font ||
        ([font.fontName isEqualToString:@"Helvetica"] && font.pointSize == 12.0)) {
        font = [NSFont fontWithName:@"Helvetica" size:10.0];   // 兜底
    }
    return @{
        NSFontAttributeName            : font,
        NSForegroundColorAttributeName : [self toolTipTextColor],
    };
}
```

结果用 `dispatch_once` 缓存进 `qword_1EC6D13A8` 全局变量。**子类 override 此方法可完全绕过缓存**，但若同进程中既存在原始结果也存在自定义结果，要注意原始 dispatch_once 只会跑一次。

### 3.2 `_drawToolTipBackgroundInView:` —— 实心 vs 毛玻璃的开关

```c
- (void)_drawToolTipBackgroundInView:(NSView *)view {
    NSColor *background = [self toolTipBackgroundColor];
    if ([background isEqualTo:[NSColor toolTipColor]] &&
        [view isKindOfClass:[NSVisualEffectView class]]) {
        [view drawRect:view.bounds];                // 保留毛玻璃
    } else {
        [background set];
        NSRectFill(view.bounds);                    // 实心，盖掉毛玻璃
    }
}
```

→ 任何让 `toolTipBackgroundColor != NSColor.toolTipColor` 的改写都会自动切到实心填充。

---

## 4. 显示流程

### 4.1 入口

1. 鼠标进 tracking rect → `-[NSToolTipManager mouseEnteredToolTip:inWindow:withEvent:]` (`0x184B6D4B8`)
2. → `-[NSToolTipManager startTimer:userInfo:]` (`0x184B6D678`)
3. CFRunLoopTimer 到点 → `-[NSToolTipManager _toolTipTimerFiredWithToolTip:]` (`0x184B79D44`)
4. → `-[NSToolTipManager displayToolTip:]` (`0x184B79E3C`)

### 4.2 `displayToolTip:` 核心流程

```text
view  = [tooltip view]
window = [view window]
if (![window _showToolTip]) return;                // 窗口禁用 tooltip 则提前返回

string = [tooltip string]
owner  = [tooltip owner]

if (tooltip.ownerIsDisplayDelegate) {
    // —— 自定义绘制路径 ——
    frame = [owner view:view customToolTip:tag frameForToolTipWithDisplayInfo:data];
    frame = [view convertRect:frame toView:nil];
    origin = [window convertBaseToScreen:frame.origin];
} else {
    // —— 标准文本路径 ——
    if (owner respondsTo: view:stringForToolTip:point:userData:) {
        string = [owner view:view stringForToolTip:tag point:p userData:data];
    } else {
        string = [owner description];   // 兜底
    }

    attributed = [[NSAttributedString alloc] initWithString:string
                                                attributes:[self toolTipAttributes]];

    size = [NSToolTipStringDrawingLayoutManager sizeForDisplayingAttributedString:&attributed];
    margin = [self toolTipContentMargin];
    windowSize = (round(size.w + margin.w*2), round(size.h + margin.h*2));

    origin = mouseLocation + ( … 内部 RTL/Y 偏移调整 … )
}

// 屏幕边缘翻转
origin = [self onScreenToolTipWindowFrameOriginForToolTip:tooltip
                                              windowFrame:(origin, windowSize)
                                                    where:mouseLocation
                                                 location:windowOriginInView];

// 选 panel：normal 还是 expansion
panel = tooltip.isExpansionToolTip ? _expansionToolTipPanel : _normalToolTipPanel;
if (panel == nil) {
    panel = [self _newToolTipWindow];
    self->_normalToolTipPanel = panel;            // 或 expansion 那一边
    isNew = YES;
}

[self installContentView:contentView forToolTip:tooltip toolTipWindow:panel isNew:isNew];
[panel _setLevelToShowAboveWindow:window];
[panel setFrame:(origin, windowSize) display:???];
contentView = [panel contentView];                 // == NSVisualEffectView
_NSSetWindowAlpha(panel.windowNumber, 1.0);
[panel setAppearanceParent:(ownerIsDisplayDelegate ? view : window)];

[self addDrawingSubviewForToolTip:tooltip
                  attributedString:attributed
                            inView:contentView];

[panel orderFront:nil];

if (tooltip.fadesOutWhenInactive) {
    [self startTimer:0 userInfo:@10.0];            // 10 秒后淡出
}
```

### 4.3 `_newToolTipWindow` —— 窗口创建

```c
- (NSToolTipPanel *)_newToolTipWindow {
    NSToolTipPanel *panel = [[NSToolTipPanel alloc]
        initWithContentRect:NSMakeRect(0, 0, 10, 10)
                  styleMask:0                      // borderless
                    backing:NSBackingStoreBuffered
                      defer:NO];
    panel.releasedWhenClosed = NO;
    panel.level = 103;                              // 私有 tooltip level
    panel.hidesOnDeactivate = NO;
    panel->_auxiliaryStorage->_explicitWMWindowType = 3;
    [panel _updateWMWindowType];

    NSVisualEffectView *content = [[NSVisualEffectView alloc] init];
    content.material      = 17;                     // NSVisualEffectMaterial.toolTip
    content.blendingMode  = 0;                      // .behindWindow
    content.state         = 1;                      // .active
    content.flipped       = YES;
    panel.contentView     = content;
    return panel;
}
```

**圆角与阴影完全来自 `NSVisualEffectMaterial.toolTip` 的系统绘制**：换掉这个 material 就没了系统圆角，得自己重画。

### 4.4 `addDrawingSubviewForToolTip:attributedString:inView:`

```c
- (void)addDrawingSubviewForToolTip:(NSToolTip *)tooltip
                   attributedString:(NSAttributedString *)attributed
                             inView:(NSView *)visualEffectView {
    CGSize margin = [self toolTipContentMargin];
    NSCustomToolTipDrawView *draw =
        tooltip.isExpansionToolTip ? self->_expansionToolTipDrawView
                                   : self->_normalToolTipDrawView;
    if (!draw) {
        draw = NSToolTipCreateCustomDrawViewInView(visualEffectView);
        // ↑ 创建 + 加到 visualEffectView 并 pin 四个 anchor
        if (tooltip.isExpansionToolTip) self->_expansionToolTipDrawView = draw;
        else                            self->_normalToolTipDrawView    = draw;
    }
    draw.toolTipObject    = tooltip;
    draw.attributedString = attributed;
    draw.margin           = margin;
    draw.needsDisplay     = YES;
}
```

### 4.5 `-[NSCustomToolTipDrawView drawRect:]`

```c
- (void)drawRect:(CGRect)rect {
    if (!self.toolTipObject) return;
    if (self.toolTipObject.ownerIsDisplayDelegate) {
        // —— 100% 自定义：把绘制权交给 owner ——
        [self.toolTipObject.owner
            view:self.toolTipObject.view
             customToolTip:self.toolTipObject.trackingNum
             drawInView:self
             displayInfo:self.toolTipObject.data];
        return;
    }
    // —— 默认路径：画 attributed string ——
    NSRect bounds = self.bounds;
    bounds.origin.x += self.margin.width;          // LTR；RTL 走另一支
    bounds.origin.y += self.margin.height;
    bounds.size.width -= self.margin.width;        // ← 注意：只减一次（IDA 实测）
    [self.attributedString
        drawWithRect:bounds
             options:NSStringDrawingUsesLineFragmentOrigin  // 1
             context:[NSCell _sharedStringDrawingContext]];
}
```

### 4.6 `onScreenToolTipWindowFrameOriginForToolTip:windowFrame:where:location:`

- 遍历 `NSScreen.screens`，找到 `mouseLocation` 所在屏幕；如果都不在，退化为 `view.window.screen.frame`。
- 把 `windowFrame` 与屏幕 `frame` 做 `NSContainsRect` 检查；越右就左移、越下就上移（用 `toolTipYOffset` 作为垂直翻转量）。
- 然后一段 ARM64 FMOV `#0.125` + ceil/round 的"亚像素吸附"逻辑，把 frame origin 对齐到像素。

### 4.7 `toolTipContentViewWithAttributedString:location:where:windowFrame:toolTip:` —— 命名误导

虽然名字带 `contentView`，**返回值固定是 `0`**，函数实际职责只是 in-place 修改 `windowFrame->origin`：

```c
- (id)toolTipContentViewWith…windowFrame:(CGRect *)windowFrame … {
    switch ([NSApp userInterfaceLayoutDirection]) {
        case 0: /* LTR */
            windowFrame->origin.x = where.x;
            break;
        case 1: /* RTL */
            windowFrame->origin.x = where.x - windowFrame->size.width;
            break;
    }
    windowFrame->origin.y = where.y;
    windowFrame->origin.y -= windowFrame->size.height + [self toolTipYOffset];
    return nil;
}
```

### 4.8 `installContentView:forToolTip:toolTipWindow:isNew:`

**空实现**。是为子类预留的扩展点，不动它系统行为不变。

---

## 5. 可改造的虚 hook 总表

下表所有方法都是 `NSToolTipManager` 的实例方法（普通 Obj-C dispatch），子类化 + swizzle 都能 hook。

| 方法 | 控制什么 | 风险 |
|---|---|---|
| `-toolTipAttributes` | 字体 + 文本色（dispatch_once 缓存——子类覆盖直接绕过） | 改返回值后整个 attributed string 重算尺寸正确 |
| `-toolTipTextColor` | 文本色（被 `toolTipAttributes` 默认实现读取） | 同上 |
| `-toolTipBackgroundColor` | 背景；非默认值自动切实心填充、抹掉毛玻璃 | 抹掉毛玻璃 = 抹掉圆角与阴影 |
| `-toolTipContentMargin` | 内边距 padding | 影响窗口尺寸计算 → 文本居中表现 |
| `-toolTipYOffset` | 与光标的纵向距离 | 仅影响位置 |
| `-_newToolTipWindow` | 窗口类、level、contentView 类、visual-effect material | 整个外观替换的最佳入口 |
| `-installContentView:forToolTip:toolTipWindow:isNew:` | 系统留的空 hook，可塞圆角/阴影/边框 view | 系统默认空，最安全 |
| `-addDrawingSubviewForToolTip:attributedString:inView:` | 完全替换 draw view 树 | 维护成本最高 |
| `-_drawToolTipBackgroundInView:` | 背景画法（默认上面那段判断） | 影响 redraw 性能 |

非 hook 性的开关：

- **`-setInitialToolTipDelay:`** 公开 API，整套延迟时序。
- **NSToolTip `ownerIsDisplayDelegate` + 自定义 owner**：完全自绘 `drawRect:` 而不动 manager；但 owner 注册接口（`_setToolTip:forView:cell:rect:owner:ownerIsDisplayDelegate:userData:`）是私有的。

---

## 6. 改造方案

### 6.1 改什么决定方法

| 想改 | 实现路径 |
|---|---|
| 字体 / 字色 | override `toolTipAttributes` 或 `toolTipTextColor` |
| padding | override `toolTipContentMargin` |
| Y 偏移 | override `toolTipYOffset` |
| 显示延迟 | 公开 `setInitialToolTipDelay:` 即可 |
| 实心背景（不要毛玻璃） | override `toolTipBackgroundColor` 返回非 `NSColor.toolTipColor` |
| **圆角 / 阴影 / 边框** | override `_newToolTipWindow`：跳过 `NSVisualEffectView`，用项目里现成的 `LayerBackedView` 当 contentView |
| 富文本 / 图标 | override `addDrawingSubviewForToolTip:…`，或直接用 `NSAttributedString` 通过 `view.toolTip = string` 兼容 API（系统会 `initWithString:attributes:` 抹掉富文本，因此需要额外通道传 attributed） |
| 跟随鼠标 / 自定义动画 | 不在 manager 提供能力之内；需绕过 manager 自己起一套窗口 |

### 6.2 全局生效 vs 单 view 生效

`NSToolTipManager` 是进程级单例，hook 之后**会影响进程内全部 tooltip**。为了允许"只想给我自己的 view 换样式"，我们用**当前显示视图查找**做 per-view 样式：

1. 在 `displayToolTip:` 上挂一个 override 包一层，在调用 `callSuper(toolTip)` 之前把 `toolTip.view` 暂存进一个**线程本地变量** `currentDisplayingView`。
2. 我们覆写的 `toolTipAttributes` / `toolTipBackgroundColor` / `toolTipContentMargin` / `toolTipYOffset` 在调用期间通过这个 TLS 取到 view。
3. 从 view 上取 `@AssociatedObject` 挂载的 `ToolTipStyle?`；没有就退回 `globalStyle`；再没有就 fallback 系统原实现（即 `callSuper()`）。
4. `displayToolTip:` 调用结束后清 TLS。

这是同步调用栈、单线程（主线程）执行，TLS 是干净可靠的。

---

## 7. 实现方案落地

> **Hook 机制选型**：采用 `FrameworkToolbox/ObjCRuntimeToolbox` 的 `@DynamicSubclassHook` 宏（KVO 风格的 isa-swizzling），**不**使用 `method_exchangeImplementations`。理由：
> - 不污染 `NSToolTipManager` 的 IMP 表，原类零修改，便于和未来其他 hook / KVO 叠加。
> - `install` / `uninstall` 是 ref-counted 的，可逆且幂等。
> - `@DynamicSubclassOverride` 会自动生成 `callSuper(...)` 桥接，"调原实现"写法直观。
> - 唯一约束：宏禁止 `@MainActor` / `async` / `throws` 等修饰；所有 hook 方法必须是普通同步 nonisolated 函数。`NSToolTipManager` 全流程在主线程运行，这条由 AppKit 运行时不变量保证，编译期不需要标注。

### 7.1 文件布局

```text
Sources/UIFoundationAppleInternalObjC/include/
   NSToolTipManager_UIFoundationPrivate.h    ── 私有方法的 @interface 声明（@available 全标 macOS 10.15+）
   NSToolTip_UIFoundationPrivate.h           ── @class NSToolTip; + 最小 @interface NSToolTip : NSObject @end
                                                 （只是为了让 Swift 能持有该参数类型，不调用其方法）
   NSColor_ToolTipColor.h                    ── +[NSColor toolTipColor]
   NSFont_ToolTipFont.h                      ── +[NSFont toolTipsFontOfSize:]（fallback 检测用）

Sources/UIFoundationAppleInternal/Tooltip/
   ToolTipStyle.swift                        ── 值类型样式
   CustomToolTipManager.swift                ── 公开 API：install / globalStyle / setStyle(_:for:)
                                                 内含 currentDisplayingView TLS 与 currentResolvedStyle 解析
   CustomToolTipManagerHook.swift            ── @DynamicSubclassHook 容器
   NSView+CustomToolTip.swift                ── view.box.customTooltipStyle 入口
```

### 7.2 公开 Swift API 草案

```swift
public struct ToolTipStyle: Sendable {
    public var font: NSFont?
    public var textColor: NSColor?
    public var backgroundColor: NSColor?         // 非 nil → 抑制毛玻璃，自绘实心
    public var contentMargin: CGSize?            // padding
    public var yOffsetFromCursor: CGFloat?
    public var initialDelay: TimeInterval?

    // —— 选 1-B 时启用的扩展位 ——
    public var cornerRadius: CGFloat?
    public var borderColor: NSColor?
    public var borderWidth: CGFloat?
    public var shadow: NSShadow?

    public static let system: ToolTipStyle       // 全 nil
    public static let `default`: ToolTipStyle    // 推荐预设
}

public final class CustomToolTipManager {
    public static let shared: CustomToolTipManager

    /// 一次性安装 swizzle；幂等。
    public static func install()

    public var globalStyle: ToolTipStyle

    /// 给单个 view 覆盖样式。
    public func setStyle(_ style: ToolTipStyle?, for view: NSView)
}

extension NSView {
    // 通过 .box 命名空间挂上
    // view.box.customTooltipStyle = ToolTipStyle.default.with { $0.cornerRadius = 8 }
}
```

### 7.3 Hook 容器与 `install()` 内部细节

```swift
// CustomToolTipManagerHook.swift
@DynamicSubclassHook(of: NSToolTipManager.self, suffix: "Customizable")
struct CustomToolTipManagerHook {
    // 包住 displayToolTip:，在同步调用栈期间把 toolTip.view 推进 TLS
    @DynamicSubclassOverride
    func displayToolTip(_ toolTip: NSToolTip) {
        CustomToolTipManager.shared.beginDisplay(toolTip: toolTip)
        defer { CustomToolTipManager.shared.endDisplay() }
        callSuper(toolTip)
    }

    @DynamicSubclassOverride
    func toolTipAttributes() -> [NSAttributedString.Key: Any] {
        guard let style = CustomToolTipManager.shared.currentResolvedStyle else {
            return callSuper()
        }
        var attributes = callSuper()
        if let font = style.font            { attributes[.font] = font }
        if let textColor = style.textColor  { attributes[.foregroundColor] = textColor }
        return attributes
    }

    @DynamicSubclassOverride
    func toolTipTextColor() -> NSColor {
        CustomToolTipManager.shared.currentResolvedStyle?.textColor ?? callSuper()
    }

    @DynamicSubclassOverride
    func toolTipBackgroundColor() -> NSColor {
        CustomToolTipManager.shared.currentResolvedStyle?.backgroundColor ?? callSuper()
    }

    @DynamicSubclassOverride
    func toolTipContentMargin() -> CGSize {
        CustomToolTipManager.shared.currentResolvedStyle?.contentMargin ?? callSuper()
    }

    @DynamicSubclassOverride
    func toolTipYOffset() -> CGFloat {
        CustomToolTipManager.shared.currentResolvedStyle?.yOffsetFromCursor ?? callSuper()
    }

    // —— 选 1-B 时再启用以下两个 ——
    // @DynamicSubclassOverride
    // func _newToolTipWindow() -> NSWindow { ... 用 LayerBackedView 替换 NSVisualEffectView ... }
    //
    // @DynamicSubclassOverride
    // func installContentView(_ contentView: NSView?,
    //                          forToolTip toolTip: NSToolTip,
    //                          toolTipWindow window: NSWindow,
    //                          isNew: Bool) {
    //     callSuperIfImplemented(contentView, toolTip, window, isNew)
    //     CustomToolTipManager.shared.applyCornerAndShadowIfNeeded(toWindow: window)
    // }
}

// CustomToolTipManager.swift
public final class CustomToolTipManager {
    public static let shared = CustomToolTipManager()
    private init() {}

    public var globalStyle: ToolTipStyle = .system

    // —— 公开 API ——
    public static func install() {
        // ref-counted；先 force-realize 单例再装钩子
        CustomToolTipManagerHook.install(on: NSToolTipManager.shared())
    }
    public static func uninstall() {
        CustomToolTipManagerHook.uninstall(from: NSToolTipManager.shared())
    }
    public func setStyle(_ style: ToolTipStyle?, for view: NSView) {
        // 通过 @AssociatedObject 挂到 view
    }

    // —— Hook 间共享的 TLS ——
    @TaskLocal private static var currentDisplayingView: NSView?
    func beginDisplay(toolTip: NSToolTip) {
        // ...
    }
    func endDisplay() {
        // ...
    }
    var currentResolvedStyle: ToolTipStyle? {
        // perView → globalStyle → nil（nil 时 hook 直接调 callSuper）
    }
}
```

要点：
- `install` / `uninstall` **ref-counted**：调用次数必须配对。
- `callSuper()` 在宏体内由 `@DynamicSubclassOverride` 注入，无需自己写 `unsafeBitCast`。
- `displayToolTip:` 在 hook 容器中接收的 `NSToolTip` 参数来自 `NSToolTip_UIFoundationPrivate.h` 暴露的最小声明。
- TLS 用 `@TaskLocal` 还是普通 `Thread.current.threadDictionary` 由实现时决定；`NSToolTipManager` 完全跑在主线程，二者皆可。

### 7.4 选 1-B 时的圆角 / 阴影实现

```text
override _newToolTipWindow:
    panel = 像系统一样建（同样 styleMask=0、level=103、WMWindowType=3）
    panel.backgroundColor = .clear
    panel.opaque = NO
    panel.hasShadow = ???    // 见下
    contentView = LayerBackedView()    // 项目里已有，自带 cornerRadius/border/shadow
    panel.contentView = contentView
    return panel

override installContentView:forToolTip:toolTipWindow:isNew:
    if 当前 style 有圆角/阴影/边框需求:
        把 contentView (LayerBackedView) 的 cornerRadius/border*/shadow* 按 style 设置
    系统原 addDrawingSubviewForToolTip:… 会照常把 NSCustomToolTipDrawView 加到 contentView 上
    它的 layout pin 四个 anchor 即可继续工作
```

注意：**`NSCustomToolTipDrawView` 的 `drawRect:` 默认实现没有自带圆角裁切**，原本靠 `NSVisualEffectView` 的 layer mask 给画的。换成 `LayerBackedView` 后需要把 `clipsToBounds` 风格交给 `LayerBackedView.cornerRadius`（已实现 corner radius + masksToBounds）。

### 7.5 私有符号 ObjC 头声明示例

```objc
// NSToolTip_UIFoundationPrivate.h
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// 仅为了让 Swift 能持有 NSToolTip 类型，作为 hook 方法参数 / 字段类型。
// 不调用其方法；属性只暴露我们读得到的两个。
@interface NSToolTip : NSObject
@property (nonatomic, readonly) NSView *view;
@property (nonatomic, readonly) NSCell *cell;
@end

NS_ASSUME_NONNULL_END
```

```objc
// NSToolTipManager_UIFoundationPrivate.h
#import <AppKit/AppKit.h>
#import "NSToolTip_UIFoundationPrivate.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSToolTipManager (UIFoundationPrivate)
- (NSDictionary<NSAttributedStringKey, id> *)toolTipAttributes;
- (NSColor *)toolTipBackgroundColor;
- (NSColor *)toolTipTextColor;
- (CGSize)toolTipContentMargin;
- (CGFloat)toolTipYOffset;
- (id)_newToolTipWindow;
- (void)installContentView:(nullable NSView *)contentView
                forToolTip:(NSToolTip *)toolTip
             toolTipWindow:(NSWindow *)window
                     isNew:(BOOL)isNew;
- (void)displayToolTip:(NSToolTip *)toolTip;
@end

@interface NSColor (UIFoundationPrivate)
+ (NSColor *)toolTipColor;
@end

NS_ASSUME_NONNULL_END
```

---

## 8. 安装策略选项

| 方案 | 描述 | 优点 | 缺点 |
|---|---|---|---|
| **A：显式 install** | 用户在 `applicationDidFinishLaunching:` 调 `CustomToolTipManager.install()` | 安全；不污染其他 app；易关掉 | 多一步配置 |
| **B：自动 install** | 模块 load 时 `__attribute__((constructor))` 自动 swizzle | 零配置 | 入侵 NSToolTipManager 单例的进程全部 tooltip；任何意外都背锅在 UIFoundation 头上 |

**建议 A**。

---

## 9. 风险与未决事项

1. **`toolTipAttributes` 的 dispatch_once 缓存**：若在 `install()` 之前**就已经**有代码调用过 `[manager toolTipAttributes]`（缓存命中），原 IMP 已经把结果存入全局 `qword_1EC6D13A8`。`DynamicSubclassHook` 切的是 isa 入口，覆写后我们的 override 不读那个全局缓存——所以**我们这边总是新鲜的**；但若其它模块持有了那次缓存返回的字典，他们看到的是旧值。低概率风险，且其它模块极不可能这么做。
2. **`NSColor.toolTipColor` ABI 稳定性**：13/14/15/26 系列都存在该符号；后续若 Apple 改名，需要补 fallback。
3. **`NSVisualEffectMaterial.toolTip == 17`** 自 10.14 起稳定。
4. **`_newToolTipWindow` 的 WMWindowType 私有字段**：未来若 ivar 重排会崩。若仅做 1-A，可不动该方法，规避此风险。
5. **`UIFoundationAppleInternal` 的既有约束**：明确禁止上 App Store；本改造完全符合该模块定位。
6. **`@DynamicSubclassHook` 的 `@MainActor` 禁用约束**：宏在编译期拒绝 `@MainActor` / `async` / `throws` / `mutating` 的 hook 方法。我们所有 hook 方法都是普通 `func`，不加 actor 隔离；调用线程由 `NSToolTipManager` 的主线程不变量保证。若未来 AppKit 把 tooltip 调度搬到非主线程，会引出 TLS 读写线程不一致——届时需要把 TLS 换成 `@TaskLocal` 之类显式 propagation。
7. **`DynamicSubclassHook` 是 `.dynamic` 库**：`FrameworkToolbox` 已把 `ObjCRuntimeToolbox` 声明为动态 product，避免 dealloc sentinel 跨 dylib 失效。`UIFoundationAppleInternal` 引入后需要确认产物形态不冲突（项目目前每个 product 都是默认的 static；新引入一个 dynamic 依赖在 SPM 下是允许的）。

---

## 10. 待用户决策

**问题 1：要不要支持圆角 / 阴影 / 自定义边框？**

- 选 **A**：不支持。`backgroundColor`、字体、padding、Y 偏移、延迟够用。最小入侵，零额外私有 ivar 接触。
- 选 **B**（推荐）：支持。同时 override `_newToolTipWindow` + `installContentView:…`，content view 换成项目已有的 `LayerBackedView`。代价是放弃系统毛玻璃；圆角/阴影/边框全部可控。

**问题 2：安装策略？**

- 选 **A**（推荐）：用户显式调 `CustomToolTipManager.install()`。
- 选 **B**：模块自动 install。

**问题 3（可选）：要不要 per-view 样式覆盖？**

- 选 **A**：只支持全局 `globalStyle`，实现最简。
- 选 **B**（推荐）：支持 per-view（通过 `box.customTooltipStyle`），用线程本地变量在 `displayToolTip:` 调用栈期间穿透。

---

## 附录：本次调研用到的关键 IDA 地址

| 符号 | 地址 |
|---|---|
| `+[NSToolTipManager sharedToolTipManager]` | `0x184A2DA44` |
| `-[NSToolTipManager displayToolTip:]` | `0x184B79E3C` |
| `-[NSToolTipManager toolTipAttributes]` | `0x184CA3F10` |
| `___37-[NSToolTipManager toolTipAttributes]_block_invoke` | `0x185688B7C` |
| `-[NSToolTipManager toolTipTextColor]` | `0x184CA3FA0` |
| `-[NSToolTipManager toolTipBackgroundColor]` | `0x184CA4DFC` |
| `-[NSToolTipManager toolTipContentMargin]` | `0x184CA4838` |
| `-[NSToolTipManager toolTipYOffset]` | `0x184CA48C0` |
| `-[NSToolTipManager _newToolTipWindow]` | `0x184CA4AB0` |
| `-[NSToolTipManager installContentView:forToolTip:toolTipWindow:isNew:]` | `0x184CA4BAC` |
| `-[NSToolTipManager addDrawingSubviewForToolTip:attributedString:inView:]` | `0x185688C50` |
| `-[NSToolTipManager _drawToolTipBackgroundInView:]` | `0x184CA4D40` |
| `-[NSToolTipManager onScreenToolTipWindowFrameOriginForToolTip:windowFrame:where:location:]` | `0x184CA4904` |
| `-[NSToolTipManager toolTipContentViewWithAttributedString:location:where:windowFrame:toolTip:]` | `0x184CA4844` |
| `NSToolTipCreateCustomDrawViewInView` (C func) | `0x185688D20` |
| `-[NSCustomToolTipDrawView drawRect:]` | (按符号解析) |
| `-[NSToolTipPanel _setLevelToShowAboveWindow:]` | `0x184CA4BB0` |
| `+[NSColor toolTipColor]` | `0x184CA4E08` |
| `-[NSToolTipManager mouseEnteredToolTip:inWindow:withEvent:]` | `0x184B6D4B8` |
| `-[NSToolTipManager startTimer:userInfo:]` | `0x184B6D678` |
| `-[NSToolTipManager _toolTipTimerFiredWithToolTip:]` | `0x184B79D44` |
| `-[NSToolTipManager setInitialToolTipDelay:]` | `0x185688090` |
