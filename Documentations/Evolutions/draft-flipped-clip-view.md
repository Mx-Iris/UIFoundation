# Draft - FlippedClipView：让滚动视图的内容从左上角开始

- **状态**: In Progress
- **创建日期**: 2026-11-14
- **最后更新**: 2026-11-14
- **实现分支 / PR**: `feature/flipped-clip-view`

## 摘要

`NSClipView` 只在文档视图翻转时才翻转。表格、大纲、文本视图本身是翻转的，放进滚动视图里从顶部开始；
stack view 和普通 `NSView` 不翻转，比滚动视图高时，一打开就停在内容的底部。示例 App 的几个演示页正是
这样打开的；QuickActionBar 内部和下游项目也各自写过一份「总是翻转的 clip view」。本提案把它做成库里的
公开类 `FlippedClipView`，再给 `NSScrollView` 加一个创建方法 `NSScrollView.box.makeFlipped()`，
返回已经装好这个 clip view 的滚动视图。

## 方案

- **`FlippedClipView`**（`UIFoundationAppKit/Base/FlippedClipView.swift`）：`open class`，继承
  `NSClipView`，`isFlipped` 恒为 `true`。不加 trait，`import UIFoundation` 即可用。
- **`NSScrollView.box.makeFlipped()`**：放在 `.box` 下，与 `NSToolbar.box.makeAutomaticIdentifier(for:)`
  一样是类型级工厂，名字照 Swift API 设计规范以 `make` 开头。返回调用它的那个类
  （`SelfSizingScrollView.box.makeFlipped()` 得到 `SelfSizingScrollView`）；除了 clip view，其余与
  `Base()` 一致，原 clip view 的 `drawsBackground` 与 `backgroundColor` 照搬过去。
- **库内去重**：QuickActionBar 结果列表改用 `FlippedClipView`，删掉它私有的同名类，行为不变。
- **示例 App**：五个以 stack view 为文档的演示页（Spotlight Panel、Quick Action Bar、Quick Action Bar
  Browse Buttons、System HUD、Custom Tooltip）改用 `makeFlipped()`。文档视图本来就翻转的滚动视图
  （日志文本、表格、大纲、侧栏）不动。
- **测试**：`FlippedClipViewTests` 以 AppKit 自己的 clip view 为对照：普通 clip view 随文档视图翻转、
  打开不翻转的高文档时停在底部；`FlippedClipView` 停在顶部；`makeFlipped()` 返回调用的那个类、背景设置不变。
- **文档**：`uifoundation-widgets` skill 补上这两个 API 和「stack view 放进滚动视图会停在底部」这个坑，
  插件版本升到 1.4.0；`AGENTS.md` 的示例 App 一节加一条约定；README 的 `.box` 一节加一行示例。

未经询问采用的假设：

- 不改 `ScrollView` 和 `scrollableDocumentView()` 等现有工厂的默认 clip view。改了会让下游所有不翻转的
  文档从底部挪到顶部，属于行为变更，这次只新增。
- 不另写使用指南：`FlippedClipView` 没有签名之外的契约，「为什么需要它」写在类型的文档注释和插件 skill 里。

下游影响：纯新增。RuntimeViewer、MachOKitUI、PrivateSymbols 不改代码就没有任何变化。下游自己写过的
flipped clip view 可以换成这个；不换也不会撞名——模块自己声明的类型优先于导入的同名类型。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-14 | 创建，直接进入实现 | 示例 App 的演示页打开时停在底部；用户要求把翻转的 clip view 加进库（多处用到），并加一个创建「原点在左上角」的滚动视图的便捷方法，即批准 |
| 2026-11-14 | 工厂放在 `.box` 下，命名 `makeFlipped()` | 本库约定 AppKit 类型上的扩展都走 `.box`；「flipped」是 AppKit 对「原点在左上角」的叫法，与 `FlippedClipView` 同词便于搜到 |
| 2026-11-14 | 工厂照搬原 clip view 的背景设置 | 让它与 `Base()` 只差 clip view 这一处，调用方原先对背景的设置不受影响 |
