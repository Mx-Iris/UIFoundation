# 0008 - SettingsConfiguration：把共享配置移出 Window Controller

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-14
- **最后更新**: 2026-08-14
- **所属愿景**: 无
- **关联提案**: [0006](0006-settings-window-configuration.md)（首次集中设置自定义项）、[0007](0007-settings-scene.md)（新增原生 Settings Scene）
- **实现分支 / PR**: `main`
- **配套文档**: [`SettingsWindow.md`](../SettingsWindow.md)

## 摘要

把 `SettingsWindowController.Configuration` 提升为顶层 `SettingsConfiguration`。这个值同时服务
`SettingsWindowController`、`SettingsScene` 与 `SettingsRootView`，不属于其中任何一个呈现入口；继续嵌套在
window controller 下会让 SwiftUI Scene 调用方通过一个并未使用的 AppKit controller 类型来取得共享配置。

不保留旧嵌套别名。相关 API 尚未发布，当前直接收敛到唯一名称，避免形成两套长期入口。

## 动机

0006 落地时只有完整的 `SettingsWindowController` 与可嵌入的 `SettingsRootView` 两个入口，以 controller 作为
namespace 尚可解释。0007 新增 `SettingsScene` 后，所有权已经发生变化：

- controller 使用 title、窗口尺寸与内容配置；
- scene 使用内容尺寸、sidebar 与导航配置；
- root view 使用 sidebar 与导航配置。

此时 `SettingsWindowController.Configuration` 的名字错误表达成「controller 的内部配置」，同时使
`SettingsScene(configuration:)` 的公开签名泄漏另一个呈现方式。用户明确要求：「Configuration 拿出来，
不要放到 WC 里面。」

## 提议方案

新增顶层值类型并删除嵌套声明：

```swift
@available(macOS 14.0, *)
public struct SettingsConfiguration {
    public var title: String
    public var contentWidth: CGFloat
    public var minimumContentHeight: CGFloat
    public var sidebarWidth: CGFloat
    public var sidebarIconSize: CGFloat
    public var showsNavigationControls: Bool
}
```

三个入口统一使用：

```swift
SettingsWindowController(configuration: SettingsConfiguration(...)) { ... }
SettingsScene(configuration: SettingsConfiguration(...)) { ... }
SettingsRootView(configuration: SettingsConfiguration(...)) { ... }
```

属性、默认值与行为全部不变；只调整类型的名称与声明位置。`SettingsConfiguration.title` 仍只由
`SettingsWindowController` 消费，因为原生 SwiftUI `Settings` Scene 的标题由系统管理。

## 替代方案考量

### 保留 SettingsWindowController.Configuration typealias

否决。用户要求不要把 Configuration 放在 window controller 下；保留别名仍会留下该入口，并继续暗示错误的
所有权。API 尚未发布，没有兼容负担值得为它保留第二个名字。

### 嵌套到 SettingsScene

否决。只是把同一个归属错误从一个呈现入口移到另一个，controller 与 root view 又会反向依赖 Scene namespace。

### 使用顶层 Configuration

否决。过于宽泛，会污染 `UIFoundationSettingsUI` 的顶层 namespace，也无法从调用点看出它配置的是 Settings。
完整名称 `SettingsConfiguration` 符合项目禁止缩写的命名规则。

## 兼容性与下游影响

- **ABI 兼容性**: 不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。
- **源码兼容性**: 显式写出 `SettingsWindowController.Configuration` 的调用点必须改成
  `SettingsConfiguration`；依赖参数上下文使用 `.init(...)` 的调用点无需修改。
- **发布状态**: 嵌套类型尚未发布，本次不提供 deprecated alias。
- **RuntimeViewer**: 源码调用目前使用 `.init(sidebarIconSize: 15)`，本身可继续编译；文档中显式类型名需改为
  `SettingsConfiguration`，并把调用点写全以验证新入口。
- **其他下游**: 当前未发现显式使用这个尚未发布类型的调用点。

## 测试与验收

1. 三个公开入口的签名都只出现顶层 `SettingsConfiguration`。
2. 测试以显式顶层类型构造默认值与自定义值，不再出现旧嵌套名称。
3. RuntimeViewer 使用 `SettingsConfiguration(sidebarIconSize: 15)` 的调用形状完成下游编译验证。
4. Settings trait 完整测试原始退出码为 0；macOS 示例使用独立 DerivedData 构建通过。
5. 全仓当前 API 与指南不再出现 `SettingsWindowController.Configuration`；Evolution 0006、0007 的历史正文除外。

## 实施结果

- 删除 `SettingsWindowController+Configuration.swift`，新增顶层 `SettingsConfiguration.swift`；六个属性、默认值与
  initializer 行为不变，也没有添加旧嵌套名称的 alias。
- `SettingsWindowController`、`SettingsScene` 与 `SettingsRootView` 的公开 initializer 和 configuration 属性
  全部改用顶层类型。测试、示例 App 与公开指南均显式构造 `SettingsConfiguration`，当前 API 搜索不再出现旧名。
- RuntimeViewer 的真实调用改成 `SettingsConfiguration(sidebarIconSize: 15)`，其 agent 指南与 Settings 迁移记录
  同步更新。一个直接依赖本地 UIFoundation 的最小 macOS 15 下游 package 使用相同调用形状编译通过，原始
  `swift build` 退出码为 0，0 warning、0 error。
- UIFoundation 的 `swift test --traits Settings` 以原始退出码 0 通过 125 项测试，0 warning、0 error；macOS
  示例 App 使用 `/tmp/codex/DerivedData/UIFoundation` 独立构建通过。
- 两个仓库的 `git diff --check` 均通过，`Package.resolved` 未改变。RuntimeViewer 整仓未重复触发已知的依赖图
  阻塞；本次公开 API 调用由最小下游编译覆盖。未启动 Simulator、未运行 App，也未做交互式 UI 验证。

## 决策日志

| 日期 | 决策 | 说明 |
|---|---|---|
| 2026-08-14 | Created as Draft | 0007 新增 Scene 后，共享配置不再属于 window controller namespace。 |
| 2026-08-14 | Accepted → In Progress | 用户明确要求把 Configuration 从 WC 中拿出来。 |
| 2026-08-14 | Implemented | 顶层类型、三个入口、RuntimeViewer 下游、测试、示例与文档已同步，不保留旧 alias。 |
