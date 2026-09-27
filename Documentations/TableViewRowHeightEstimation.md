# TableViewRowHeightEstimation —— 关掉 AppKit 的行高估算，让分组列表不再叠行

`UIFoundationAppleInternal`（`AppleInternal` trait）下的 `tableView.box.estimatesRowHeights`，
读写 AppKit 的私有开关 `-[NSTableView _estimatesRowHeights]` / `-_setEstimatesRowHeights:`。
行高不一致的表格里，AppKit 对还没测量过的行只按估算高度排布，之后边测边修正；这个开关控制
要不要估算。决策记录见 [`Evolutions/0026-table-view-row-height-estimation.md`](Evolutions/0026-table-view-row-height-estimation.md)，
逆向依据见 [`Researchs/AppKit-NSTableView-RowHeightEstimation-Internals.md`](../Researchs/AppKit-NSTableView-RowHeightEstimation-Internals.md)。

## 什么时候需要它

症状：source list 样式、带分组行（group row）、并且有可展开条目的 `NSOutlineView`，在列表滚到靠后位置时
`reloadData()` 或者展开一个条目，之后再一滚动，就会看到**两行画在同一个位置、文字叠在一起**。

原因：source list 样式下，除第一个外每个分组行上方都多出 13 pt 间距，行高因此不一致，AppKit 自动进入估算
模式。靠后位置发生结构变化时，下一次布局按估算摆好一部分行、再在中途修正估算，已经摆好的行不会被挪回去；
再滚动时按修正后位置摆进来的行就画在它们上面。15.5、26.6.2、27.0 上实测行为完全一致。

三个条件缺一不可：行高不一致（分组行已足够）、列表里至少有一个可展开条目、在估算还没被测量覆盖的
靠后位置发生重载或展开。

## 用法

```swift
outlineView.delegate = self
outlineView.box.estimatesRowHeights = false   // 必须在设置 delegate 之后
```

delegate 可能被改动的表格（包括用 RxCocoa / RxAppKit 这类 delegate 代理绑定的表格），在子类里跟着 delegate
一起重新关掉。AppKit 在 setter 里打开估算，这里在同一个 setter 返回前关掉，中间没有任何行按估算摆放，
所以不会碰到契约 2：

```swift
final class GroupedOutlineView: NSOutlineView {
    override var delegate: (any NSOutlineViewDelegate)? {
        didSet { box.estimatesRowHeights = false }
    }
}
```

读回来是 `Bool?`：`nil` 表示这个系统上没有这对私有方法，此时赋值什么也不做。

## 宿主必须遵守的契约

1. **设置 delegate 会把估算重新打开。** `-[NSTableView setDelegate:]` 与 `-[NSOutlineView setDelegate:]`
   每次 delegate 真正变化时都会调用 `_setEstimatesRowHeights:YES`（逆向报告第 2 节）。先设 delegate
   再关估算，顺序反了就等于没关。delegate 代理会自己重设 delegate（为了刷新 AppKit 的
   `respondsToSelector:` 缓存），所以只在绑定完关一次不够，要在 delegate 的 setter 里关。
2. **切换开关不会挪动屏幕上已有的行。** AppKit 只是丢弃算好的行几何（下次用到时重算），既不 `reloadData`、
   也不重新摆放已有的行视图，所以按估算摆好的行会一直留在原位，直到表格重载。实测：在列表靠后位置、估算摆好的
   行已经显示时关掉估算，27 行错位；之后布局一次、`noteHeightOfRows(withIndexesChanged:)` 都不恢复，`tile()`
   反而开始叠行，只有 `reloadData()` 能摆正（逆向报告 4.5 节）。所以要么在表格显示行之前切换 —— 在设置
   delegate 的同一次调用里切换就满足这一点 —— 要么切换后自己调一次 `reloadData()`。
3. **关掉之后每次重载要算一遍全部行高。** 1.4 万行、行高由 `rowHeight` 与分组行决定的列表，`reloadData` 加布局
   实测多 3–6 ms；几千行以内测不出差别。开了 `usesAutomaticRowHeights` 的大表格没有测过 —— 那种表格的行高要靠
   Auto Layout 算出来，关掉估算的代价可能大得多，用之前先量。
4. **不要用应用级默认值 `NSTableViewCanEstimateRowHeights` 代替它。** 这个 `NSUserDefaults` 键同样能关掉估算，
   但对进程里**所有**表格生效，而且在第一次被读取后缓存到进程结束（逆向报告 3.1 节）。
5. **全部是私有 API。** 新系统去掉这对方法时，属性返回 `nil`、赋值无效，叠行问题会回来。
   `TableViewRowHeightEstimationTests` 里有一条用 `withKnownIssue` 写的预警测试：只要 AppKit 仍会叠行它就通过；
   哪天 AppKit 自己修好了，它会以「Known issue was not recorded」失败，提醒重新评估这个开关还需不需要。

## 已知限制

- **带动画收起的一处存疑现象。** 关掉估算后，曾在一段有其它进程同时跑动画的时间里连续 4 次观察到：带动画地
  收起一个条目后，下方的分组行没有跟着上移；之后在相同条件下重跑 50 余次都没有再出现，不带动画的收起从未出现。
  详见逆向报告 4.3 节。若在宿主里遇到，给 `expandItem` / `collapseItem` 包一层零时长的 `NSAnimationContext`
  可以避开。
