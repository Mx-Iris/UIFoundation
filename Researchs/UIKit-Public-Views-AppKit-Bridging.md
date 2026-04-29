# UIKit 公开 View 在 macOS 上的 AppKit 介入分类

> 基于 macOS 26.4 dyld_shared_cache 中 UIKitCore、UIKitMacHelper、AppKit 的反编译
> IDA database: `UIKitCore+UIKitMacHelper+AppKit.i64`
>
> 配套参考：
> - [`UIButton-NSButton-Bridge.md`](UIButton-NSButton-Bridge.md) — A 级嵌入模式的代表性逆向
> - [`UINavigationController-NSToolbar-Bridge.md`](UINavigationController-NSToolbar-Bridge.md) — 容器/Toolbar 的镜像桥接
> - [`MacCatalyst-Architecture-Research.md`](MacCatalyst-Architecture-Research.md) — `_UINSView` / `NSViewHost` / scene hosting 总图

## 0. 摘要

UIKit-on-macOS 在视图层用 **三段策略**：

1. **嵌入真 NSControl**（A 级）：小型基础控件（开关 / 滑块 / 颜色井 / 进度条 / 按钮）通过 UIKitCore 内部的 `_UINSView` (`NSViewHost` 包装) 直接把 NSControl host 进 UIView 树
2. **CoreUI 自绘 Aqua/Glass**（B 级）：风格强烈但行为不复杂的控件（分段 / 步进 / 文本框背景）由 UIKit 自己绘制——通过 `_UICoreUIWidget` 私有 widget 让 UIKit 出像素，**不**实例化 NSControl
3. **Overlay 弹出 AppKit 控件**（C 级）：复杂选择器（紧凑日期选择器）UIKit 一侧只显示文字标签，点击时弹出由独立 NSWindow/NSPanel 承载的 AppKit 控件

除此之外的所有大型 View（标签、图像、滚动视图、表/集合视图、文本视图、各种 Bar、Picker、Refresh、Activity、PageControl、SearchBar、VisualEffect、Calendar）**100% 纯 UIKit**——它们对"我跑在 macOS 上"无感，AppKit 只在 scene 层（`UINSWindow` / `UINSSceneViewController` / `_UINSView`）介入承载整个 UIKit 树。

数字：扫描 30 个公开 UIView 子类，**约 70% 不接 AppKit**。

---

## 1. 评级标准

| 等级 | 含义 | 关键证据 |
|------|------|---------|
| **A** | 嵌入真 NSControl/NSView | mac visual element 的 ivar 直接是 NSControl 类型 + `_UINSView *_bridge`；事件经 7 条 `trackingXxxAction:` / `valueChanged:` 双向桥接 |
| **B** | UIKit 自绘 AppKit 视觉 | 用 `_UICoreUIWidget` 私有 widget 输出 Aqua/Glass 像素，**不** alloc NSControl |
| **C** | overlay 弹出 AppKit 控件 | 路径含 `UINSOverlay…` / `UINSShadow…` 等 protocol，通过独立 NSWindow/NSPanel 承载 |
| **N** | 纯 UIKit | dumps 里找不到 mac visual element / `_UINSView` / NSControl 类型；可能仅有 platform metrics 或样式常量类 |

---

## 2. A 级：嵌入真 NSControl（5 个）

公共特征：`_visualElement` 是个 UIView，持有 `_UINSView *_bridge` (NSViewHost 包装) + 一个真实的 NSXxx 控件 ivar；事件经 `addTarget:action:forControlEvents:` 7 条 tracking 通道双向同步（与 [`UIButton-NSButton-Bridge.md`](UIButton-NSButton-Bridge.md) 第 7 节描述的同构）。

| UIKit View | Mac visual element | 嵌入的 AppKit 控件 | 关键 ivar |
|------------|-------------------|-------------------|----------|
| **UIButton** | `UIButtonMacVisualElement : UIView` | `NSButton` / `NSPopUpButton` / `_NSDynamicallyBorderedButton` / `_NSMenuButton` / `_NSGlassButton` | `NSControl<UIButtonRepresentable> *_button`、`_UINSView *_bridge` |
| **UISwitch** | `UISwitchMacVisualElement` 或 `UISwitchMacCheckboxVisualElement` | **`NSSwitch`**（默认）或 **`NSButton`** (checkbox style) | `NSSwitch *_macSwitch` / `NSButton *_macCheckbox`，配 `_UINSView *_bridge` |
| **UISlider** | `_UISliderMacVisualElement` | **`NSSlider`** | `NSSlider *_nsSlider`、`_UINSView *_bridge`、7 条 `trackingXxxAction:` |
| **UIColorWell** | `_UIColorWellMacVisualStyle` | **`_NSColorWell`** (UIKitCore 私有子类) | `_UINSView *_hostView`、`_UINSColorWell *_nsColorWell` |
| **UIProgressView** | `UIProgressViewMacVisualElement` | **`NSProgressIndicator`** | `NSProgressIndicator *_wrappedProgressIndicator`、`UIView *_hostView` |

UIButton 的完整流程详见 [`UIButton-NSButton-Bridge.md`](UIButton-NSButton-Bridge.md)；其余 4 个走完全同构的模式，只是把 `NSButton` 换成对应的 NSControl。

---

## 3. B 级：CoreUI 自绘 Aqua（3 个）

公共特征：mac visual element 没有 `_UINSView` ivar，没有任何 NSControl 引用。它们持有一个 `_UICoreUIWidget *coreUIWidget`——这是一个 UIKit 内部封装 `CoreUI.framework` 私有 API 的 widget，**直接让 UIKit 自己画出 Aqua/Glass 风格的像素**，不实例化 AppKit 控件。

| UIKit View | Mac visual element | 渲染机制 |
|------------|-------------------|---------|
| **UISegmentedControl** | `UISegmentedControlMacBezelView : UIView` + 三个 StyleProvider (`UISegmentedControlMacBezelStyleProvider` / `UISegmentedControlMacGlassStyleProvider` / `UISegmentedControlMacStyleProvider`) | `_UICoreUIWidget *coreUIWidget` 在 `_updateBackingLayer` 中输出 segment bezel |
| **UIStepper** | `UIStepperMacVisualElement : UIView` | **`CALayer *_backingLayer`** 自绘 + `NSTimer *_repeatTimer` 处理 autorepeat；不嵌 NSStepper |
| **UITextField** | `_UITextFieldMacBackgroundView : UIView` + `_UITextFieldMacBackgroundProvider` | `_UICoreUIWidget *coreUIWidget` 画 Aqua bezeled 边框；编辑/选择/输入仍走 UIKit TextKit |

> ⚠️ UIKitMacHelper 中**有** `NSSegmentedControl+UINSSegmentedControl` 类别，但它是给"原本就是 NSSegmentedControl 的 NSToolbarItem"用的——比如 SwiftUI 在 macOS 上配置工具栏分段时——而不是 UISegmentedControl 在 macOS 上转过去。`UISegmentedControl` 自身始终走 CoreUI 自绘。

---

## 4. C 级：overlay 弹出 AppKit 控件（1 个）

| UIKit View | Mac 视图 | overlay 行为 |
|------------|---------|------|
| **UIDatePicker**（compact 模式） | `_UIDatePickerMacCompactView : UIView` | 持有 `id<UINSOverlayDatePicker>` 和 `id<UINSShadowDatePicker>` 协议；UIKit 一侧只是几个 UITextField 显示当前值，点击时调 `createBridgedOverlayDatePickerIfNecessary…` 弹出独立 NSWindow/NSPanel 承载的 NSDatePicker |

`_UIDatePickerMacCompactView.h` 关键属性：

```objc
@property id<UINSOverlayDatePicker> macOverlayDatePicker;
@property id<UINSShadowDatePicker>  shadowDatePicker;
@property BOOL isShowingMacOverlay;
- (BOOL)createBridgedOverlayDatePickerIfNecessaryElement:(long long)element;
- (BOOL)createBridgedOverlayDatePickerIfNecessaryForClickOnPoint:(struct CGPoint)point;
```

非 compact 模式（轮盘 / 日历）走 N 级，UIKit 自渲染。

---

## 5. N 级：纯 UIKit（21 个）

下列公开 View 在 macOS 上**完全是 UIKit 渲染**——dumps 中找不到任何 mac visual element / `_UINSView` / NSControl 桥接：

| View | 备注 |
|------|------|
| **UIView** | 基类，layer-backed UIView |
| **UIControl** | 基类 |
| **UIWindow** | view 自身纯 UIKit；scene 层桥接到 `UINSWindow (NSWindow 子类)`，与 view 无关 |
| **UILabel** | 纯文本绘制 |
| **UIImageView** | 纯图像绘制 |
| **UIScrollView** | `_UIScrollDynamicsiOSMac` 仅调橡皮筋 / 减速参数，纯 UIKit 计算 |
| **UICollectionView** | UIScrollView 子类 |
| **UITableView** | `UITableConstants_Mac : UITableConstants_Pad` 只提供 sidebar appearance / header bg class 选择 |
| **UITextView** | 用 TextKit 自渲染，不嵌 NSTextView |
| **UIToolbar** | UIKit 自绘——**它不是** NSToolbar；NSToolbar 桥接是 `UINavigationController` 的事，见专文 |
| **UINavigationBar** | UIKit 自绘 (`_UINavigationBarVisualProviderModernIOS`)，与 NSToolbar 是**镜像**关系 |
| **UITabBar** | `_UIFloatingTabBarPlatformMetrics_Mac` / `_UIFloatingTabBarPlatformMetrics_GlassMac` 仅 metrics |
| **UIRefreshControl** | |
| **UIPageControl** | |
| **UIActivityIndicatorView** | |
| **UIPickerView** | |
| **UISearchBar** | `_UISearchTextFieldVisualStyle_macOS` 是空 stub |
| **UIVisualEffectView** | |
| **UIPopoverBackgroundView** | |
| **UIInputView** | |
| **UICalendarView** | `_UICalendarViewPlatformMetrics_Mac` 仅 metrics |

> 仅有 `_*PlatformMetrics_Mac` / `_*VisualStyle_macOS` 类的 View **算 N 级**。这些类在 dumps 里通常只有 1–3 行，仅返回 macOS 下的尺寸 / 字号 / 颜色常量，没有 NSXxx 类型出现在 ivar 或 method 里。

---

## 6. 不是 View 但相关的 AppKit 桥接

完整起见——这些不是 UIView，但常被误以为是"View 在 macOS 上的实现":

| UIKit 概念 | macOS 实现 | 关键文件 / 证据 |
|-----------|-----------|----------------|
| `UISheetPresentationController` (modal sheet) | `_UISheetHostManagerMac` + `UINSSheetManager` → **NSWindow attached sheet** | `_UISheetHostManagerMac.h` 有 `_beginNSSheetPresentation`、`_contentSizeForNSSheet`、`appkitDidPresent` flag |
| `UIPopoverPresentationController` | `_UIPopoverHostManagerMac` → 每个 popover 是**独立的 UIScene**，再被装进 NSPanel | `popoverSceneForPopoverWithIdentifier:` |
| `UIBarButtonItem`（在 UINavigationBar / UIToolbar 中） | 镜像为 **`NSToolbarItem`**（不是替代） | 见 [`UINavigationController-NSToolbar-Bridge.md`](UINavigationController-NSToolbar-Bridge.md) |
| `UIAlertController` | `_UIAlertControllerPhoneTVMacView` / `_UIAlertControlleriOSMacBackgroundView` —— 走 AppKit alert 风格的 UIView 重绘，不嵌 NSAlert | dumps 中两个 .h |
| `UIWindowScene` | `UINSSceneViewController` (UIKitMacHelper) host 进 `UINSWindow (NSWindow 子类)` | `UINSWindow-Protocol.h`、`MacCatalyst-Architecture-Research.md` |
| `UIMenu`（context menu） | macOS 上走 NSMenu | 待考证 |

值得注意：**UIToolbar ≠ NSToolbar**。UIToolbar 是 N 级（UIKit 自渲染）；只有 UINavigationController/UINavigationBar 通过 `_UINavigationBarNSToolbarProxy` 把内容**镜像**到 NSToolbar 上。

---

## 7. UIKitCore 给 AppKit 加的反向扩展

UIKitCore 反向给若干 AppKit 类加了 category 来支持桥接：

| UIKitCore 中的 NS 扩展 | 用途 |
|----------------------|------|
| `NSButton (UIButtonRepresentable)` | 实现 UIButton 的 `setTitle:forState:` / `setImage:forState:` 等接口的 NSButton 版本 |
| `NSPopUpButton (UIButtonRepresentable)` | 同上，给 menu button 用 |
| `NSView (iOSMac)` | `ui_baselineOffsetsAtSize:` —— 让 NSView 也能像 UIView 那样报告基线，供 NSToolbarItem 嵌入 UIView 时跨框架协作 |
| `NSMenuToolbarItem (NSToolbarAdditions)` | 让 NSMenuToolbarItem 接受 UIBarButtonItem 来源 |

UIKitMacHelper 中的 NS+UINS 类别（共 10 个，全部用于宿主集成而非 view 桥接）：

```
NSAppearance+UINSAppearance
NSApplication+UINSApplicationSwizzling
NSExtensionContext+UIKitMacHelper
NSMenuItem+UINSApplicationShortcutMenuItem
NSObject+UINSUtilities
NSPopUpButton+UINSPopUpButton
NSSegmentedControl+UINSSegmentedControl   ← 给 NSToolbar 中原生 NSSegmentedControl 用
NSSharingService+UIKitAdditions
NSSharingServicePickerToolbarItem+UINSShareSheet
NSWindow+UINSWindow
```

---

## 8. 数字统计

扫描 30 个公开 UIView 子类（UIWebView 等已废弃跳过）：

| 等级 | 数量 | 占比 | 包含的 View |
|------|------|------|-------------|
| **A 级**（嵌入 NSControl） | 5 | ~17% | UIButton, UISwitch, UISlider, UIColorWell, UIProgressView |
| **B 级**（CoreUI 自绘 Aqua） | 3 | ~10% | UISegmentedControl, UIStepper, UITextField |
| **C 级**（overlay 弹 AppKit 控件） | 1 | ~3% | UIDatePicker (compact 模式) |
| **N 级**（纯 UIKit） | 21 | ~70% | 其余所有 |

也就是说**约 70% 的公共 View 在 macOS 上不接 AppKit**；接 AppKit 的几乎都是"原生外观必须由 NSControl 才像样"的小型控件（按钮、开关、滑块、进度条、颜色井、日期选择器、数字步进器、分段控件、文本框）；大型容器和图文 View 全部留在 UIKit 内。

---

## 9. 设计逻辑观察

为什么 Apple 选择"小控件下沉到 NSControl，大容器留在 UIKit"？三个推断：

1. **像素一致性 vs 行为一致性的折衷**：用户对小控件（按钮、开关）有强烈的"原生外观"心理预期，必须像 macOS 控件；而对滚动视图、表格、文本视图，行为（橡皮筋、长按选中、键盘快捷键）一致比像素一致更重要——所以这些保持 UIKit
2. **可达性 / 焦点链**：嵌入真 NSControl 让 macOS VoiceOver、Tab 键焦点链、键盘 Mnemonic 等"白嫖"了 AppKit 已有的 a11y 树；自绘控件需要自己实现这些
3. **合成性能**：大容器（UICollectionView / UITableView / UIScrollView）一帧要管成千上万个 cell，跨框架嵌入开销巨大；小控件每个 view 一两个 NSControl，开销忽略不计

A/B 级之间的选择则更现实：**有现成 AppKit 等价物**就用（A），**没有等价物或外观差异大但行为简单**就 CoreUI 自绘（B）。例如 `NSStepper` 视觉上与 iOS UIStepper 差距过大，硬嵌反而不像，UIKit 选择自绘 Aqua 风格 `+/-` 按钮（B）；而 `NSSlider` 的 visual 与 UISlider 几乎对得上，直接嵌（A）。
