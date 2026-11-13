# ScrollPockets —— 让浮在列表上的栏也有滚动边缘效果

`UIFoundationAppleInternal`（`AppleInternal` trait）下 `NSScrollView.box` 的一组封装，读写 AppKit 的私有
scroll pocket 接口。macOS 26 起，内容滚到栏底下时 AppKit 会在那条边上模糊、变暗内容，这层效果叫滚动边缘效果，
由滚动视图自己加的 `NSScrollPocket` 视图来画，AppKit 内部把它叫 scroll pocket。AppKit 只替窗口标题栏和
split view item 的 accessory 安排它；自己做的、浮在列表上的栏，要靠这组接口登记才有效果。另有一块不属于任何
滚动视图的独立 pocket `ScrollPocketView`，用来盖住并排的几个滚动视图（见「几个滚动视图并排伸到标题栏底下时」）。决策记录见
[`Evolutions/0029-scroll-view-scroll-pockets.md`](Evolutions/0029-scroll-view-scroll-pockets.md)，逆向依据见
[`Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md`](../Researchs/AppKit-NSScrollView-ScrollPocket-Internals.md)。

## 什么时候需要它

列表全高、栏浮在它上面（Xcode 导航区的做法），而栏不是 split view item 的 accessory 时：内容能从栏底下滚过，
却没有边缘效果，文字清清楚楚地从栏的空隙里露出来。公开 API 里，`preferredScrollEdgeEffectStyle` 只存在于
`NSTitlebarAccessoryViewController` 和 `NSSplitViewItemAccessoryViewController` 上。

## 用法

两种办法，Xcode 两种都用。

**登记容器**：把浮在边上的栏登记到那条边，pocket 至少伸到栏的另一侧。

```swift
scrollView.box.registerScrollPocketContainer(filterBar, on: .bottom)
// 栏不再浮在这条边上时：
scrollView.box.unregisterScrollPocketContainer(filterBar, on: .bottom)
```

**常显一条边**：不登记任何东西，让 pocket 按 inset 的高度一直存在。栏已经变成滚动视图的安全区时最省事。

```swift
scrollView.additionalSafeAreaInsets.bottom = filterBar.frame.height
scrollView.box.alwaysShownScrollPocketEdges = [.top, .bottom]
```

所有方法在 macOS 26 以前、或 AppKit 缺这个私有方法时什么都不做；`alwaysShownScrollPocketEdges` 此时读回
`nil`，`scrollPocketStyle(on:)` 读回 `nil`。改某条边的 pocket 样式用 `setScrollPocketStyle(_:on:)`（取值的含义见契约 5）。检查 pocket 实际摆成什么样用 `scrollPocket(on:)`，它只读，不会创建。

登记为容器的栏，再覆写 `_scrollPocketElementStyle`（声明在 `NSView_Private.h`）回答 2，也就是 bar 样式：
AppKit 给 split view item accessory 套的包装视图答 2，Xcode 的过滤栏和导航区分段控件栏也都答 2，
DVTUserInterfaceKit 27.2 把这个值叫作 Bar（`NSViewWithScrollPocketElementStyleBar` 0xD5F68、
`-[DVTFilterExpressionControlBar _scrollPocketElementStyle]` 0xA3A38）。

```swift
@available(macOS 26.0, *)
override var _scrollPocketElementStyle: Int {
    NSView.barScrollPocketElementStyle
}
```

### 几个滚动视图并排伸到标题栏底下时（编辑区分栏）

AppKit 把一个窗口里所有伸到标题栏底下的 pocket 放进同一个 backdrop 分组，这个分组只截一次图，在第一个 pocket 绘制时
截。之后才绘制的东西——旁边那个滚动视图、盖在第一个 pocket 上面的视图（比如 Minimap）——都不在截图里，它们上方的
标题栏只剩一块平的窗口底色。两种解法，决策记录见
[`Evolutions/draft-scroll-pockets-across-scroll-views.md`](Evolutions/draft-scroll-pockets-across-scroll-views.md)：

**一块独立的 pocket 盖住所有滚动视图（Xcode 编辑区的做法）**：`ScrollPocketView` 放在所有滚动视图之后、框住标题栏
那一条，它的 `captureView` 放在它们之前、同一位置。它一次截全，也盖住了画在各自 pocket 上面的视图。

```swift
let toolbarEdgeEffect = ScrollPocketView(edge: .top)        // style 2，不画分隔线
editorAreaView.addSubview(toolbarEdgeEffect.captureView!, positioned: .below, relativeTo: nil)
editorAreaView.addSubview(toolbarEdgeEffect)                // 在所有分栏之后
// 两者都框在 editorAreaView 的顶边到安全区顶边之间，随布局一起变。
```

默认是 style 2（`ScrollPocketView.hardStyle`）：内容模糊后盖一层近乎不透明的底色重放，内容只透出很少一点，和 Xcode
一样。style 0 和 1 把配方交给 pocket 的元素决定，而独立 pocket 没有元素，什么都不画。它不接点击。

**给每个滚动视图各起一个分组**：在包着各个滚动视图的视图上设 `NSView.box.titlebarBackdropGroupName`，名字各不相同即可。

```swift
leadingPaneView.box.titlebarBackdropGroupName = "EditorPane-\(leadingPaneID)"
trailingPaneView.box.titlebarBackdropGroupName = "EditorPane-\(trailingPaneID)"
```

名字设在外层视图上，之后为新内容建出来的 pocket 也会继承；设在已经上屏的层级上，里面现有的 pocket 也会跟着换组。
读回 `nil` 表示这个视图没起名、沿用上层的。各组只模糊自己 pocket 背后的东西，盖在 pocket 上面的视图（Minimap）照样
清晰。两种解法可以叠用：压在独立 pocket 下面的那层分好组，透出来的部分也是完整的模糊。

## 必须遵守的契约

以下各条都是在 macOS 27.2 上实测的。

1. **底部 pocket 的高度跟的是滚动视图自己的 `contentInsets.bottom`，不是 clip view 的。** 只给 clip view 设了
   inset、滚动视图自己是 0 时，常显的底部 pocket 高度为 0，等于没有效果，而列表照样让开了栏——看上去一切正常。
   让栏变成滚动视图的安全区、并保持滚动视图的 `automaticallyAdjustsContentInsets` 开着，滚动视图的 inset 就会
   跟着安全区走。要在顶部多留空隙（Xcode 多留 8 点），改 clip view 的 `contentInsets`，不要改滚动视图自己的。
2. **顶部 pocket 的高度跟的是顶部安全区，不是 inset。** 只设 `contentInsets.top`、没有安全区时，顶部 pocket 高度为 0。
3. **底部 pocket 只在登记了容器、或这条边常显时才存在。** 顶部的 pocket 视图一直存在，没东西撑开它时高度为 0。
4. **登记要配对撤销。** 栏移走、换掉，或者不再浮在这条边上时，记得 `unregisterScrollPocketContainer(_:on:)`。
   27.2 没有办法读回已登记的容器（27.0 有的 `_registeredPocketContainersOnEdge:` 在 27.2 已经删掉了），所以出错时
   无从查起。
5. **数值不是契约。** 27.2 上 style 2 是 Hard 配方（内容模糊后盖一层近乎不透明的底色），0 和 1 把配方交给 pocket
   的元素决定，3 及以上会让 AppKit trap（Xcode 27 在有第二级的导航器顶边设 2，否则 0）；`_scrollPocketElementStyle`
   的取值也是 27.2 上读到的。新系统要重新核对，`ScrollPocketTests` 里有几条专门盯这些值。
6. **分组各自截图，模糊在分界处断开。** 起了名的分组只模糊自己 pocket 背后的东西，两个相邻 pocket 的模糊在交界处
   各取各的边，不会连成一片。只有一个滚动视图伸到标题栏底下时不要起名，留在窗口的分组里和标题栏背景一起截图。
   `ScrollPocketTests` 里有一条专门确认「默认共用一个分组」，它变红说明 AppKit 改了做法，这一节要重新核对。
7. **`ScrollPocketView` 的 `captureView` 必须放在它所盖内容的后面、同一位置。** 底色重放就是从这块截的；不放进视图
   层级，Hard 配方那层近乎不透明的底色没有来源。两者的位置要一起跟着布局变。

## 坑

- **从外面看不出 pocket 画没画。** 实测所有 pocket 视图都是 `isHidden == false`、alpha 为 1，测试只能测几何。
  27.2 上要看 pocket 用的是什么画法，读它的图层名：`ThinFilm…` 是软模糊，`HardPocket…`、`OpaquePocket…` 是近乎
  不透明的实色；`NSHardPocketView` 在 27.2 上总是隐藏的，看它判断不了。分组看名字里带 `ContentBlur` 的那个
  `CABackdropLayer` 的 `groupName`。
- **标题栏上一块平的窗口底色，先查分组。** 内容明明滚到了标题栏底下，标题栏的一段却是均匀的底色、毫无纹理时，
  多半是这段和别处共用一个 backdrop 分组、截图早于这段内容的绘制，见上文「用法」最后一段。
- **私有方法会在小版本之间消失。** `_registeredPocketContainersOnEdge:` 在 27.0 里有、27.2 里没有，直接调用会抛
  `unrecognized selector`。封装里每个方法都先查 `instancesRespond(to:)`（维护时保持这一点，新加的方法也要查），自己绕过封装直接调私有方法时也要这么做。
