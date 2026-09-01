# UIKitCore 接口设计模式分析与框架设计策略树

> 基于 macOS 26.5.2 dyld shared cache 中 UIKitCore 的 RuntimeViewer 转储做的**接口层**分析：
> 5376 个 ObjC 头文件 + 1061 个 Swift interface（`/Volumes/DyldSharedCaches/macOS/26.5.2/UIKitCore/{ObjCHeaders,SwiftInterfaces}`）。
> 所有结论来自声明层证据（类名、ivar 布局、方法签名、协议遵循），未做反编译验证；
> 需要下钻实现时用同目录的 `UIKitCore.i64` / `UIKitCore+UIKitMacHelper+AppKit.i64`。
> 落笔于 2026-09-01。前半部分是证据，后半部分（第 3 节起）是从证据反推出的框架设计决策树。

## 0. 摘要

UIKit 的接口不是「用了某几个设计模式」，而是三个年代叠出来的地质层，每层设计语言不同：

1. **骨架层**（Smalltalk MVC 遗产）：组合 + 责任链 + 模板方法，三者共用一棵树；
2. **扩展层**（ObjC 惯用法）：定制点全部外包给 delegate / dataSource / target-action，
   框架内部大量使用策略族、抽象工厂、中介者管线；
3. **现代层**（Swift 时代，进行中）：从「协议 + 继承」整体转向「值对象 + 泛型 + 闭包 + Observation」。
   转储里 UIKitCore 内部已有 297 个 Swift 实现的类（`_Tt` 前缀），trait 系统内部在用
   Observation 的读依赖追踪。

贯穿五十年的一致哲学：**框架拥有算法与生命周期，应用只拥有「声明」和「回应」**；
演进从不推倒重来，每一代新范式都以适配器姿态叠在上一代的接缝后面。

## 1. 模式证据清单

### 1.1 骨架：一棵树上的三个模式

- **组合（Composite）**：`UIView.superview/subviews/addSubview:`；`UIViewController`
  containment（`addChildViewController:` / `childViewControllers`）。所有容器
  （`UINavigationController` / `UITabBarController` / `UISplitViewController`）共用同一个
  `NSArray *viewControllers` 整体-部分结构，只是选择策略不同（栈顶 / 互斥选中 / 具名列）。
- **责任链（Chain of Responsibility）**：`UIResponder.nextResponder` 单链接上行，终点是
  `UIApplication`（自身即 `UIResponder`）。私有接口暴露链的工程化程度：
  `_nextResponderUsingTraversalStrategy:`、`_overrideNextResponderWithResponder:forType:`
  （运行时拼接虚拟节点——输入视图、远程视图服务）、`_responderChainDescription`（自带调试器）。
  `hitTest:withEvent:` 是反方向的链，`pointInside:` 是可覆写判定步。`UIScene : UIResponder`
  说明 iOS 13 后场景也插进了这条链。
- **模板方法（Template Method）**：两处铁证。`UIViewController` 存在私有 `__viewWillAppear:`
  驱动方法——框架先记账再调用户覆写的公开钩子，算法骨架握在框架手里；`UIView` 位域里有
  `implementsDrawRect : 1`——框架探测子类是否真的覆写了钩子，没覆写就不分配 backing store。
  模板方法既是扩展点也是性能开关。

### 1.2 边界外包：delegate / dataSource / target-action

- **委托是替代子类化的默认扩展点**，且带统一工程惯例：每个持 delegate 的类都有一块
  respondsToSelector 缓存位域——`UITableView` 约 40 个位（`dataSourceCellForRow : 1` …），
  `UIGestureRecognizer` 约 70 个位，`UIScene` 有 `delegateSupportsWillConnect : 1` 一族。
  能力探测在设值时做一次，热路径零消息发送。
- **dataSource 与 delegate 拆分**是职责分离：数据的归数据（拉取式问询），几何与回收归视图。
  `register…/dequeue…/prepareForReuse` 三件套 + `NSMutableDictionary *_reusableTableCells`
  是按标识符键控的对象池；注册的是 `Class` / `UINib` 这个「原型生产者」而非实例。
- **目标-动作 = 命令（Command）**：`UIControl` 的存储揭示新旧两代 API 的统一——
  `NSMutableArray *_targetActions` 里的 `UIControlTargetAction` 同时持有 `(target, SEL)`
  **和** `UIAction *_actionHandler`，旧式 selector 与新式闭包住在同一个命令对象里，
  分发只有一条路径。`UIMenu` / `UICommand` / `UIKeyCommand` 是命令模式完全体。

### 1.3 可插拔算法：策略、工厂、状态机（私有头里最壮观的部分）

- **策略族**：99 个 `*VisualStyle*` 类——`UIAlertControllerVisualStyleAlert{TV,Car,GlassTV,…}`，
  同一个 alert controller 按平台/形态换皮不换骨。
- **抽象工厂**：`UIInterfaceActionConcreteVisualStyleFactory_{iOS,AppleTV,CarPlay}` 按平台
  生产上面那族策略；键盘另有 62 个 `UIKBRenderFactory*` 具体工厂。公开 API 里最经典的是
  `UIViewControllerTransitioningDelegate`：一个对象成套供应 animator + interaction controller
  + presentation controller，保证三件产品互相配套。
- **参数对象 + 中介者**：`_UIViewControllerTransitionContext` 把 from/to 控制器、容器、几何、
  按 key 访问的视图打包成一个上下文对象递给策略；animator 与 interactor 互不相识，只对上下文说话。
- **状态机（State）**：`UIGestureRecognizer` 的状态字段叫 `_state_DO_NOT_USE_DIRECTLY`，
  转移函数抽成独立的 `_UIGestureRecognizerDriver`，另有 `insideSetState : 1` 重入保护。
- **桥接 / pImpl（Bridge）**：`UISplitViewController` 持有
  `id<_UISplitViewControllerImplementing> _impl`，背后是 `ClassicImpl` 与 `PanelImpl` 两套完整实现；
  diffable data source 同构——两个公开类共享一个 `__UIDiffableDataSource *impl`。
  全库共 43 个 `*Impl` 类。
- **建造者（Builder）**：`_UIMenuBuilder`、`_UIApplicationSceneRequestBuilder`
  （Catalyst 子类覆写定制钩子——builder 本身又套了模板方法）。
- **访问者（Visitor）**：`_UIViewVisitor` / `_UITintColorVisitor` / `_UIMotionEffectsVisitor` 等
  6 个，专职遍历视图树；公开 API 从不暴露遍历。
- **类簇（Class Cluster）**：`UIColor` 背后 `UIDeviceRGBColor` / `UICachedDeviceRGBColor` /
  `UIDynamicCatalogColor` 等十余个私有子类。
- **享元 / identity map**：事件层 `UITouch` 走 per-window identity map 跨 phase 复用同一对象——
  这正是文档要求「不要 retain UITouch」的原因。

### 1.4 元编程：UIAppearance 是「录制回放」代理

`[UIButton appearance]` 返回的 `_UIAppearance` 不执行 setter，而是把每次调用物化成
`NSInvocation` 存进 `_appearanceInvocations`（`_isRecordingInvocations` 把模式写在方法名里），
等真实视图进窗口时回放（`+_applyInvocationsTo:window:matchingSelector:`）。
Proxy + Command + Memento 三合一；`_UIAppearanceRecorder` 还能把调用日志序列化成 `NSData`
送去远程视图服务进程回放——「录消息而不是录值」正是为了跨进程。这也解释了公开行为：
appearance 只对尚未入窗的视图生效。

### 1.5 架构纵线

**分层**——UIKit 是中间层，上下都有明确的座：

```
应用代码（delegate / dataSource / 子类钩子）
UIKit 公开接口
UIKit 私有机器（策略族 / 工厂族 / mediator / visitor）
CoreAnimation（UIView 是 CALayer 的 delegate，layer 为 @dynamic —— 视图即图层适配器）
FrontBoard / BackBoard（UIScene 持有 FBSScene 并任其 delegate；BKSAnimationFence 跨进程同步绘制）
IOKit HID（事件源头）
```

**事件管线**——生产者/消费者 + 线程桥 + 中介者：`UIEventFetcher`（独立线程收 `IOHIDEvent`，
块过滤器链，`CADisplayLink` 限速）→ `UIEventDispatcher`（把后台信号转成主 run loop 的两个
`CFRunLoopSource`——`sendEvent:` 必在主线程的原因）→ `UIEventEnvironment`（HID 事件按类型
工厂化为 UIKit 事件，维护 touch identity map）→ `UIApplication.sendEvent:` → 窗口 → 责任链。
手势仲裁另有中介者 `UIGestureEnvironment`：识别器之间从不直接对话，标脏后由 run loop observer
在一轮末尾按依赖图（`UIGestureGraph`）统一裁决。

**隐形架构惯例**——「标脏 + run loop 检查点合并冲刷」：布局、手势仲裁、appearance 失效、
trait 通知全走这一个惯例。

**UIScene 的设计**（单独值得记）：四个角色分工——`UIScene` 是系统对象的客户端投影
（持有 `FBSScene` 并任其 delegate，适配成 UIKit 惯用法）；`UISceneSession` 是持久身份
（`NSSecureCoding` + `persistentIdentifier` + `stateRestorationActivity`，对 scene 弱引用）；
`UISceneConfiguration` 是声明式装配单（`Class sceneClass / delegateClass`，从 Info.plist 反射
实例化）；`UISceneSessionActivationRequest` + builder 表达「应用只能请求、不能创建」。
内部另有两个决策：组件化组合（`+_registerSceneComponentClass:withKey:predicate:` +
15 个 `_UI*SceneComponent`，按谓词横向挂载，接近 entity-component）；状态同步走 diff
（`FBSSceneSettings` 整体下发 → 算 diff → 分发给注册的 diff action，反向走 clientSettings
事务块——一个小型跨进程 reconciliation 管线）。

### 1.6 现代转向：从 OO 模式到声明式

| 旧世界 | 新世界 | 模式变化 |
|---|---|---|
| `cellForRowAtIndexPath:` 拉取 | diffable snapshot `apply` 推送 | 委托问询 → 不可变值 + 最小编辑脚本（事务对象、专用队列） |
| 字符串 reuseIdentifier + 强转 | `CellRegistration<Cell, Item>` | 运行时约定 → 泛型编译期保证（identifier 从接口上消失） |
| 子类覆写 `drawRect:` | `UIContentConfiguration`：`state → updated(for:) → makeContentView()` | 模板方法 → 纯函数变换 + 工厂 |
| `traitCollectionDidChange:` 一把抓 | 按 trait 注册 + diff 唤醒；`UITraitDefinition` 类型即键 | 单钩子 → 精确观察者 + 类型化环境字典 |

最能说明方向的内部证据：`_UITraitChangeRegistry` 里有
`recordTraitUsage:forTraitEnvironment:insideMethod:`——UIKit 按方法 IMP 记录「这个方法读过
哪些 trait」，变化时只失效那个方法。这是 SwiftUI / Observation 的读依赖追踪装回 ObjC 方法
分发。新旧接缝处理一致：`UITableViewDiffableDataSource` 自己遵循 `UITableViewDataSource`
（适配器），`UITableView` 一行未改。

## 2. 数量统计（转储实测）

| 指标 | 数量 |
|---|---|
| ObjC 头文件总数 | 5376 |
| 公开 `UI*` 类 | 1821 |
| 私有 `_UI*` 类 | 3076 |
| Swift 实现的类（`_Tt` 前缀） | 297 |
| `*VisualStyle*` 策略类 | 99 |
| `UIKBRenderFactory*` 具体工厂 | 62 |
| `*Impl` 实现类（pImpl） | 43 |
| `*Recognizer` | 117 |
| `*Configuration` | 111 |
| `*Interaction` | 96 |
| `*Provider` | 81 |
| `*Animator` | 37 |
| `_UI*SceneComponent` | 15 |
| `*Visitor` | 6 |

注意：RuntimeViewer 转储只发射 `@interface`，`@protocol` 声明不单独成文件——协议契约要从
遵循列表、具体实现类和 delegate 位域反推。

## 3. 框架设计策略树

把上面的证据反推成设计决策树：设计框架时真正面对的不是「要不要用某模式」，而是
「这个定制点该给什么形状的接口」。

### 三条总纲（所有树的根）

1. **先决定控制反转的粒度**：框架拥有算法和生命周期，用户只拥有「声明」和「回应」。
   每设计一个 API 先问：这件事的权威是用户、框架还是系统？答案直接决定接口形状（树 B）。
2. **边界上传值，不传引用**：凡跨越「用户↔框架」边界的东西用值对象——configuration、
   snapshot、request、state token，全带 `copy` 语义。引用只留给有身份的长命对象。
3. **演进靠适配器叠层，不换接缝**：第一版的协议接缝按「十年后还在」设计，
   新范式从它后面滑进去。

### 树 A：定制点——用户想改变行为时，给什么接口？

```
这个定制点是什么性质？
├─ 「事情发生了告诉我」
│   ├─ 单一时刻、单一动作 → 闭包属性 / 命令对象（UIAction 形态）
│   └─ 一组相关时刻，框架还要反问（should/can） → delegate 协议，weak 持有
│       └─ 热路径（每帧/每行/每次触摸都要问）？
│           → 能力探测做一次、缓存起来（UIKit 用 respondsTo 位域；
│             Swift 等价物是「设 delegate 时探测一次存 OptionSet」）
├─ 「数据有多少、第 n 个是什么」（无界、按索引问询）
│   → dataSource 与 delegate 分开 + 注册/出队/复用三件套（对象池）
│   → Swift 下注册给泛型 token，不给字符串（CellRegistration 教训：
│     reuseIdentifier 在现代接口上彻底消失）
├─ 「整个算法可以换」
│   ├─ 单个算法 → 策略协议（UITimingCurveProvider：cubic/spring 两个值类型实现）
│   └─ 一族必须互相配套的对象 → 抽象工厂
│     （transitioningDelegate 教训：animator/interaction/presentation 必须出自同一手，
│      分开给三个属性就会出现不配套的组合）
└─ 「在框架流程里插一步」（框架拥有生命周期）
    → 模板方法，学它的两个细节：
    ├─ 骨架方法私有、钩子公开（__viewWillAppear 先记账再调钩子——
    │   永远不要让用户的覆写能跳过框架记账）
    └─ 钩子成本敏感时，探测「是否真的覆写了」（implementsDrawRect 位）
```

### 树 B：所有权——对象由谁创建、谁持有？

```
谁是这类对象的权威？
├─ 用户代码 → 普通 init，依赖走 designated init 注入
├─ 框架按需生产（cell、page、菜单项）
│   → 用户注册「配方」（Class / 闭包 / Registration token），框架负责实例化 + 池化
│   → 现代倾向：闭包 provider 优于 Class 反射（UITab 用 viewControllerProvider，
│     不再学 UISceneConfiguration 的 Class delegateClass）
└─ 系统 / 外部服务（窗口、场景、会话这类"租来的"资源）
    → 不给公开 init；用户提交 Request 值对象（builder 组装），框架通过 delegate 回应
    → 持久身份与运行实例分离（Session/Scene 教训：能被杀掉重建的东西，
      身份要单独建模并可序列化）
```

### 树 C：状态与样式——外观怎么表达？

```
├─ 属性少、彼此独立 → 直接可变属性 + 标脏重绘
│   （UIFoundation 的 @ViewInvalidating 就是这个形态，够用就停在这里）
├─ 属性成组、随交互状态整体变化
│   → 不可变 configuration 值对象，走三段管线：
│     state token → updated(for:) 纯函数 → makeContentView() 工厂
│   ├─ 把状态物化成一个 state 值（OptionSet/struct），替代 N 个散装 BOOL 回调
│   └─ 内置样式用命名构造器当原型（+plainButtonConfiguration）
├─ 多平台/多形态换皮 → 策略族 + 按平台的工厂
│   （99 个 VisualStyle + 3 个平台工厂；TabBar.Style/ThemedStyle 已是同构）
└─ 不要学：UIAppearance 的 NSInvocation 录制回放代理。
    ObjC 元编程时代的产物，脆、不可静态检查；
    它想解决的问题（全局主题）的现代答案就是上面的 configuration 值对象。
```

### 树 D：数据流——推还是拉？

```
├─ 数据大、变化时机不可预测 → 拉取式（框架需要时问 dataSource）
│   （ToolbarNavigation / WelcomePanel 的「Data is pulled, never pushed」
│    与 UIKit 的选择一致）
├─ 用户整批提交变更 → 快照值对象 + diff + 事务对象（diffable 教训：
│   snapshot 是 struct，apply 走专用队列，diff 由框架算）
├─ 状态沿树继承、可局部覆写 → 环境机制（trait 教训：type-as-key + diff 精确通知）
│   ⚠ 只有真的存在「树形继承 + 覆写 + 大量读者」时才值得建；小框架直接传参
└─ 高频事件 → 管线分段（采集→线程桥→翻译→分发），
    更新用「标脏 + run loop 检查点合并冲刷」
    （UIKit 的隐形架构惯例：布局、手势仲裁、appearance 失效全走它）
```

### 树 E：内部机器——实现怎么组织（不进公开接口）

```
├─ 一个公开类、多套实现可切换 → pImpl/Bridge（UISplitViewController._impl）
│   好处：公开 API 永远稳定，实现可以整个换代
├─ 功能横向挂载、避免子类爆炸 → 组件注册表（UIScene 的 15 个 SceneComponent）
├─ N 个对象互相仲裁 → 中介者 + 依赖图，绝不让它们两两对话（GestureEnvironment）
├─ 树遍历型操作反复出现 → Visitor（UIKit 只在内部用，公开 API 从不暴露遍历）
└─ 类簇：Swift 下用 enum/struct + protocol 代替，不要学 ObjC 类簇
```

## 4. UIFoundation 对照

- **已经同构的**（方向不用动）：TabBar 的 `Style` / `ThemedStyle`（树 C 策略族）、
  `@ViewInvalidating`（树 D 标脏合并）、WelcomePanel / ToolbarNavigation 的拉取式数据源
  （树 D）、`XiblessViewController` 的模板方法、Navigation 的 `ViewTransition` /
  `Interpolator` 分层（树 A 策略 + 树 E）。
- **UIKit 给出升级提示的**：`NSControl` 目前有两套并存的 action API（legacy
  `.box.setAction` 与类型安全的 `.box.actionBlock`，各占一个 associated key）——
  `UIControlTargetAction` 的教训是把 selector 版和闭包版统一进同一个命令对象、
  同一条分发路径，两套 API 只是同一存储的两个门面。
- **将来做「设置/主题全局化」时**：走树 C 的 configuration 值对象，不走 appearance 式代理；
  `SettingsConfiguration` 已经站在正确的一边。
