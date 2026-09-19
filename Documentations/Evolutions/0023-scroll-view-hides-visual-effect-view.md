# 0023 - ScrollView：isHiddenVisualEffectView 更名为 hidesVisualEffectView

- **状态**: Implemented
- **创建日期**: 2026-09-19
- **最后更新**: 2026-09-19

## 摘要

`ScrollView.isHiddenVisualEffectView` 这个名字有两处不对。一是语法：`is` + `hidden` +
名词读作「是一个 hidden visual effect view」，而它其实是一个开关。二是词性选错：Swift API
Design Guidelines 里 `is…` 前缀留给「断言当前状态」的布尔量，而这个属性表达的是**策略**
—— 它只在 `didAddSubview(_:)` 里被读到，把**之后**加进来的 `NSVisualEffectView` 设为
`isHidden = true`；打开它之前就已在位的 vibrancy 视图不受影响，读它也不告诉你当前有没有、
是否隐藏。表达持续行为的布尔量在 AppKit 里一律用第三人称动词，`NSScrollView` 自己身上就是
`autohidesScrollers` / `drawsBackground` / `scrollsDynamically`，同族还有
`NSProgressIndicator.hidesWhenStopped`、`NSWindow.hidesOnDeactivate`。

本提案把它更名为 `hidesVisualEffectView`，**行为一行不改**，旧名以
`@available(*, deprecated, renamed:)` 的转发计算属性保留。

## 方案

`Sources/UIFoundationAppKit/Base/ScrollView.swift`：

- 新增存储属性 `public var hidesVisualEffectView: Bool = false`，并补上此前完全缺失的文档
  注释 —— 「只对之后加进来的 subview 生效」这条必须写在注释里，否则下一个读者仍会按状态
  语义去理解它。
- 旧名降级为转发计算属性并标 `@available(*, deprecated, renamed: "hidesVisualEffectView")`。
  旧属性原本是 `public var` 存储属性（类虽 `open`，属性不是），子类无法覆写，换成计算属性
  不构成破坏性变更。
- `didAddSubview(_:)` 改读新名。

库内唯一调用点 `WelcomePanel/WelcomePanel+ScrollView.swift` 同批改用新名，否则自家构建会
冒 deprecation 警告。

**不做的两件事，都是有意的：**

- **不加 `didSet` 让赋值作用于已存在的 `NSVisualEffectView`。** 那会把「改名」变成「改行为」，
  而选 `hides…` 这个名字的前提正是承认并如实表达现有语义。真要改成状态语义，另开提案。
- **不删旧名。** 本库是多个项目的公共底座，旧名留着，下游可以在自己的节奏里迁移。

**源码兼容性**：兼容。旧名可用，行为不变，下游只会收到一条 deprecation 警告，不会编译失败。
**ABI 兼容性**：不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。
**下游影响**：RuntimeViewer、MachOKitUI、PrivateSymbols 三个已知下游若用到该属性，各自会多
一条警告，改名即可消除；无需同批次迁移。本库不提供 `ScrollView` 的使用指南，故无指南需要
同步；`Documentations/Evolutions/0011-welcome-panel.md` 提到该属性用法的那一句已随本批次
更新为新名（连同两处已失效的行号引用）。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-09-19 | 按轻量档记录，不走完整档 | 公开 API 改名、要进 `main`、下游会依赖，按提案制不属于豁免；但它不改架构、不破坏源码兼容，够不上完整档 |
| 2026-09-19 | 选 `hidesVisualEffectView`，不选 `isVisualEffectViewHidden` | 该属性是策略而非状态，`is…` 会误导读者以为赋值对已存在的 subview 生效；`hides…` 与 `NSScrollView` 自身的 `autohidesScrollers` / `drawsBackground` 同族 |
| 2026-09-19 | 不顺带改行为（不加 `didSet` 遍历现有 subviews） | 名字要如实描述现有语义；改语义是另一件事，混在改名里会让下游拿到一个名字变了、行为也变了的属性 |
| 2026-09-19 | 旧名保留为 deprecated 转发，不直接删除 | 本库是多个项目的公共底座，源码兼容优先于名字整洁 |
| 2026-09-19 | 转 `Implemented`：不需要配套指南或实现说明，无新术语 | 改动是单个属性更名，`ScrollView` 本就没有独立指南，未引入任何新概念 |
