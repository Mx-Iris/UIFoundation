# 0005 - SettingsStore：改用可观察引用模型并保留属性级失效

- **状态**: Implemented
- **作者**: JH
- **创建日期**: 2026-08-13
- **最后更新**: 2026-08-13
- **所属愿景**: 无
- **关联提案**: [0002](0002-reusable-settings-window.md)（最初抽取 Settings 模块）
- **实现分支 / PR**: `feat/observable-settings-store`
- **配套文档**: [`SettingsWindow.md`](../SettingsWindow.md)

## 摘要

把 `UIFoundationSettings` 的模型契约从「`Codable` 值类型 + 观察整个 `store.value`」改为
「`@Observable` 引用类型 + Store 独立监听所有持久化属性」。业务观察重新获得属性级粒度：读取
`transformer` 的监听不会被 `theme` 变化唤醒；自动保存仍由一个通用 `SettingsStore` 统一负责。

## 动机

0002 为了把保存逻辑做成完全泛型，把模型规定为值类型，并把自动保存挂在 `store.value` 的赋值上。
这种写法持久化简单，但 Observation 只能看到根值：任何设置变化都会唤醒所有设置监听。RuntimeViewer
接回该模块后，`transformer`、Theme、MCP 等监听都会互相唤醒；业务层的 `distinctUntilChanged` 只能
拦住后续工作，不能避免 tracking closure 本身重新执行。

RuntimeViewer 原来的 `@Observable final class Settings` 已经有需要的语义：各顶层 section 是独立的
observable property。问题不在 class，而在于如何让通用 Store 知道「任意持久化属性变了」。

## 前期验证

### Observation 没有对象级通配监听

`withObservationTracking` 只登记 closure 实际读取的属性。只读 `store.value` 只能观察对象替换，无法看到
对象内部属性的原地修改；Store 必须在 tracking closure 中显式触达所有持久化属性。

### 不能用 JSONEncoder 偷懒完成触达

最小实验把 `JSONEncoder().encode(settings)` 放进 tracking closure，随后修改一个 `@Observable` 属性，
`onChange` 没有触发。原因是 `@Observable` 把属性改写成 computed accessor + underscored backing storage，
编译器合成的 `Codable` 路径会直接处理 backing storage，既不保证经过 observable getter，也会把
underscored key 和 observation registrar 暴露进 JSON。因而编码不能兼任观察登记。

### class 模型的粒度符合需求

最小实验读取 `settings.first` 与 `settings.second` 后分别修改属性：读取两者的保存监听会触发；只读取
`first` 的业务监听不会被 `second` 修改触发。RuntimeViewer 的 Transformer 与 Theme 正好是两个顶层
property，因此不需要额外 projection。

## 提议方案

### 模型契约

新增 `SettingsModel`：要求 `AnyObject & Codable & Observable`，并提供：

```swift
@MainActor
func accessPersistedValues()
```

模型在实现中读取每一个参与编码的顶层属性。`PersistentSettings` 继承该协议，并继续提供静态
`SettingsStore<Self>`。

这份列表必须与编码字段同步。漏掉的属性仍会在别的修改触发保存时被编码，但单独修改它不会启动自动保存；
指南与 API 文档都把这一点列为显式契约。

### Store 的监听与重装

`SettingsStore` 自身保持 `@Observable`，`value` 现在是可替换的引用对象。每次 armed tracking 同时读取：

1. `store.value`，用于观察加载或重置造成的整个对象替换；
2. `value.accessPersistedValues()`，用于观察对象内部的持久化属性。

Observation 的 callback 在 `willSet` 阶段触发，而且每次登记只触发一次。Store 把重装延迟到 MainActor
下一次执行，让赋值先提交；随后启动原有防抖保存并重新登记。

一个递增的 `observationGeneration` 解决两类竞态：

- `load()` 替换对象后同步登记新对象，旧对象排队中的 callback 发现 generation 已过期并退出，因此不会
  把刚读到的数据原样写回；
- `save()` 先推进 generation 并重新登记，属性刚变化但尚未执行的 deferred callback 不会在显式保存后
  再排一次重复写入。

### AppSettings

`AppSettings` 改用 `ReferenceWritableKeyPath`，通过 `@Bindable` 绑定当前 `@Observable` 模型。它不要求
setting value 遵守 `Equatable`，也不缓存额外状态；每次取 binding 都重新读取 `Root.store.value`，所以
加载后的替换对象会被接住。

## 替代方案考量

### 保留值类型并为每个 key path 缓存 projection

可行，但被否决。Store 每次根值写入仍要遍历所有 projection 并逐个比较；API 还会要求每个被监听值
`Equatable`，并需要处理 key path 缓存身份、写回根值、首次创建不能顺手登记根值等额外机制。class 模型
本身已经提供相同业务粒度，projection 在这里属于重复建模。

### 恢复每个属性的 didSet

可行，但会把保存职责重新塞回业务模型。新增字段若忘记 `didSet` 同样静默丢保存，而且每个宿主都会重复
防抖接线；不采用。

### 在 tracking closure 中编码整个对象

否决。实验证明合成 Codable 不保证经过 observable getter，并会暴露宏生成的 backing storage；这不是
可靠契约。

### 把所有嵌套 section 也改成 @Observable class

暂不采用。当前粒度是顶层 section：Theme 内任一字段会唤醒 Theme 监听，但不会唤醒 Transformer。
把每个 section 继续拆成引用对象可以获得 leaf 级粒度，却会增加对象身份、编码与替换语义；没有实际热点
证据前不承担这笔复杂度。

## 兼容性与下游影响

- **ABI 兼容性**: 不适用 —— 本库以 SPM 源码分发，使用方每次重新编译。
- **源码兼容性**: 破坏性变更。原来的 struct 模型必须改成 `@Observable final class`，实现
  `accessPersistedValues()`，`AppSettings` key path 也从 `WritableKeyPath` 变为
  `ReferenceWritableKeyPath`。本 API 尚未发布稳定版本，允许在当前迁移批次收敛。
- **RuntimeViewer**: 同一批次改回原有 `@Observable final class Settings`，删除每个属性上的保存
  `didSet`，实现持久化触达列表，并保留 `SettingsAccess` 作为 Store 对象替换后的稳定访问边界。
- **MachOKitUI / PrivateSymbols**: 未使用 `UIFoundationSettings`，无影响。
- **示例 App**: Workbench 模型改为 class；原「修改值类型副本」演示替换成「替换整个设置对象」，同时验证
  reader 与 persistence observation 都会迁移到新对象。

## 测试与验收

1. 读取一个模型属性时，修改无关属性不触发业务 Observation，修改目标属性才触发。
2. 替换整个模型会通知既有 reader。
3. 嵌套 section 修改会自动保存，多次修改仍合并为一次写入。
4. `load()` 不回写刚读到的数据，并在返回前监听新对象；紧接着修改能够保存。
5. 显式 `save()` 不会被尚未执行的 Observation callback 补出第二次写入。
6. `AppSettings` 的 wrapped value 与 binding 均读写当前对象，binding 写入会持久化。

## 实施结果

- UIFoundation Settings 测试 120 项通过，0 warning。
- RuntimeViewerPackages 测试 57 项通过，0 warning；其中新增回归测试直接覆盖
  `transformer` 监听不响应 `theme` 修改。
- 未启动 Simulator，也未执行交互式 UI 验证。

## 决策日志

| 日期 | 决策 | 说明 |
|---|---|---|
| 2026-08-13 | Created → Implemented | RuntimeViewer 接入后需要恢复属性级监听；用户确认采用原有 class + @Observable 方向，由 UIFoundation Store 统一观察保存。 |
