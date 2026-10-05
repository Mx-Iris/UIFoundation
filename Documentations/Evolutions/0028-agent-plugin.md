# 0028 - 讲本库的两个 agent skill 随库作为插件发布

- **状态**: Implemented
- **创建日期**: 2026-10-05
- **最后更新**: 2026-10-05
- **所属愿景**: 无
- **实现分支 / PR**: `feature/agent-plugin`（快进合入 `main`）
- **配套文档**: 无独立文档 —— 安装说明在 README 的 Agent Plugin 一节，维护规则在 `AGENTS.md` 的 Documentation 一节

## 摘要

`uifoundation-widgets`（写 AppKit 代码前先查本库已经提供了什么，以及 `Label`、`ScrollView`、
构建器的坑）与 `uifoundation-settings-layer`（在 `PersistentSettings` 上搭一个 app 的设置层）
这两个 agent skill 只讲本库，却一直放在维护者本机的全局 skill 目录里：别的使用者装不到，库改了
也没人同步。现在把它们搬进本仓库，做成 Claude Code 与 Codex 都能从 GitHub 安装的插件
`uifoundation`，随 API 一起维护。做法与 MachOSwiftSection 的 `swift-section` 插件、RxAppKit 的
`rxappkit-bindings` 插件一致。

## 方案

- 新增 `AgentPlugins/uifoundation/`：两个工具各一份插件清单（`.claude-plugin/plugin.json`、
  `.codex-plugin/plugin.json`，版本 `1.0.0`）加两个 skill；仓库根新增两份 marketplace 清单
  （`.claude-plugin/marketplace.json`、`.agents/plugins/marketplace.json`）。marketplace 与插件都叫
  `uifoundation`，安装 id 是 `uifoundation@uifoundation`。
- skill 正文沿用原文，逐条对照 `main` 的源码核对，修正了这些漂移：
  - 工具栏 item 自 0.32.0（提案 [`0019`](0019-toolbar-item-action-and-bordered.md)）起都能链式写
    `.target(_:action:)`，原文「`NSToolbar.Button` 的 action 没有链式写法、只能拉成局部变量」已过时；
  - `ScrollView.drawsBackground` 不是只读，而是赋值被忽略、恒读 `false`；
  - 补上 `scrollableGridView()`，并写明只有 single-column 系列才设 `headerView = nil` 并加列
    （「AppKit 把第一列设为 outline 列」一条另做了实测，属实）；
  - `Label` 默认把字符串同步进 `toolTip`（`syncStringValueToolTip`），原文未提；
  - 设置层要求开启 opt-in 的 `Settings` trait，否则两个模块编译为空，原文清单漏了这一步；
  - `InMemorySettingsStorage` 在没有数据时必须抛 `FileSystemSettingsStorage.LoadError.noStoredData`，
    store 只把这一种错误当作「还没写过」；
  - 原文指向的 RuntimeViewer 参考实现目前只在它的 `next` 分支上。

  另外去掉了只在维护者本机存在的路径，`description` 去掉中文触发词、只留英文（公开仓库），
  `uifoundation-widgets` 末尾补一句指向 `appkitplus` 插件的 `appkit-app-modernization` skill。
- `AGENTS.md` 的 Documentation 一节加一条规则：改了这两个 skill 描述的公开 API，同一提交里更新
  对应 skill，并升两份插件清单的 `version` —— 两个工具都只在版本号变化时才更新已安装的插件。
- README 加 Agent Plugin 一节（安装与更新命令）；`Documentations/README.md` 登记插件位置。
- 不改任何源码：源码兼容性不涉及，下游（RuntimeViewer、MachOKitUI、PrivateSymbols）零影响。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-10-05 | 两个 skill 合进一个插件 `uifoundation`，skill 名保持不变 | 讲的是同一个库；沿用原名，其他 skill 与文档里对它们的引用不必跟着改名 |
| 2026-10-05 | `description` 去掉中文触发词，只留英文 | 公开仓库；与已发布的 `swift-section`、`rxappkit-bindings` 插件一致 |
| 2026-10-05 | 版本号从 `1.0.0` 起，与库的版本号无关 | 插件只在版本号变化时更新；跟库版本走会让两次发版之间的 skill 修正发不出去 |
| 2026-10-05 | 状态置为 Implemented | 与插件同一提交落地，Claude Code 与 Codex 的校验均通过 |
| 2026-10-05 | 合入 `main`，编号 0028 | 落地时取 `origin` 各分支上的最大编号 0027 加一 |
