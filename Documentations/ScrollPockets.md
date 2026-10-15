# ScrollPockets —— 让浮在列表上的栏也有滚动边缘效果

`UIFoundationAppleInternal`（`AppleInternal` trait）下 `NSScrollView.box` 的一组封装，读写 AppKit 的私有
scroll pocket 接口。macOS 26 起，内容滚到栏底下时 AppKit 会在那条边上模糊、变暗内容，这层效果叫滚动边缘效果，
由滚动视图自己加的 `NSScrollPocket` 视图来画，AppKit 内部把它叫 scroll pocket。AppKit 只替窗口标题栏和
split view item 的 accessory 安排它；自己做的、浮在列表上的栏，要靠这组接口登记才有效果。决策记录见
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
`nil`，`scrollPocketStyle(on:)` 读回 `nil`。检查 pocket 实际摆成什么样用 `scrollPocket(on:)`，它只读，不会创建。

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

## 必须遵守的契约

1. **底部 pocket 的高度跟的是滚动视图自己的 `contentInsets.bottom`，不是 clip view 的。** 只给 clip view 设了
   inset、滚动视图自己是 0 时，常显的底部 pocket 高度为 0，等于没有效果，而列表照样让开了栏——看上去一切正常。
   让栏变成滚动视图的安全区、并保持滚动视图的 `automaticallyAdjustsContentInsets` 开着，滚动视图的 inset 就会
   跟着安全区走。要在顶部多留空隙（Xcode 多留 8 点），改 clip view 的 `contentInsets`，不要改滚动视图自己的。
2. **顶部 pocket 的高度跟的是顶部安全区，不是 inset。** 只设 `contentInsets.top`、没有安全区时，顶部 pocket 高度为 0。
3. **底部 pocket 只在登记了容器、或这条边常显时才存在。** 顶部的 pocket 视图一直存在，没东西撑开它时高度为 0。
4. **登记要配对撤销。** 栏移走、换掉，或者不再浮在这条边上时，记得 `unregisterScrollPocketContainer(_:on:)`。
   27.2 没有办法读回已登记的容器（27.0 有的 `_registeredPocketContainersOnEdge:` 在 27.2 已经删掉了），所以出错时
   无从查起。
5. **数值不是契约。** `scrollPocketStyle` 各个值画出什么样还没弄清（Xcode 27 在有第二级的导航器顶边设 2，
   否则 0）；`_scrollPocketElementStyle` 的取值是 27.2 上读到的，新系统要重新核对，`ScrollPocketTests` 里有一条
   专门盯这些值。

## 坑

- **从外面看不出 pocket 画没画。** 实测所有 pocket 视图都是 `isHidden == false`、alpha 为 1，测试只能测几何。
- **私有方法会在小版本之间消失。** `_registeredPocketContainersOnEdge:` 在 27.0 里有、27.2 里没有，直接调用会抛
  `unrecognized selector`。封装里每个方法都先查 `instancesRespond(to:)`，自己绕过封装直接调私有方法时也要这么做。
