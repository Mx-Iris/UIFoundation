# FocusEngine.framework Internals

> 反向工程目标:`/System/Library/PrivateFrameworks/FocusEngine.framework`(macOS 26.4 dyld_shared_cache)
> 对应 IDA database:`/Volumes/Code/Dump/DyldSharedCaches/macOS/26.4/FocusEngine.i64`(session `focus_engine`)
>
> 解决问题:FocusEngine.framework 提供了哪些类/协议、公开 vs 私有边界在哪、UIFocusSystem 的真实方法面、与 AppKitPlus 的集成路径如何选择。
>
> 配套阅读:[`catalyst-focus-system-bridge.md`](./catalyst-focus-system-bridge.md)(Catalyst / AppKit 桥接全景);本文专注 FocusEngine 自身。

---

## 0. 一句话定位

FocusEngine.framework 是 macOS 11+ 抽出的**独立 PrivateFramework**,把"焦点引擎"从 UIKitCore 和 AppKit 中剥离成共享基础设施:
- 提供 `UIFocusSystem` / `UIFocusUpdateContext` / `UIFocusMovementHint` / `UIFocusMovementAction` / `UIFocusDebugger` 公开类
- 提供 `UIFocusEnvironment` / `UIFocusItem` / `UIFocusItemContainer` / `UIFocusItemScrollableContainer` / `UIFocusDebuggerOutput` 公开协议
- 提供大量私有 `_UI*` 类做内部算法(focus map、region 评分、group navigation、deferral throttle 等)
- 通过 `_UIFocusSystemDelegate` / `_UIFocusBehavior`(在 UIKitCore 里)抽象出"宿主"接口,UIKit、AppKit 各自实现自己的 delegate / behavior 注入引擎

**含义**:任何 macOS 原生进程加载 AppKit 时,FocusEngine.framework 已经在 `_dyld_image_count()` 列表中(实测 macOS 26.4 原生 AppKit 进程,见 `catalyst-focus-system-bridge.md` 修订记录第 4 条 spike 输出),`NSClassFromString("UIFocusSystem")` 立即可达,**无需 dlopen**。

---

## 1. 公开 / 私有边界

| 命名前缀 | 状态 | 数量 | 是否安全暴露 |
|---|---|---|---|
| `UIFocus*`(无下划线) | UIKit 公开 API | 5 类 + 5 协议 | ✅ 可直接使用 |
| `_UIFocus*` / `_UI*` | UIKit 私有 SPI | 60+ 类 + 17 协议 | ⚠️ 仅通过 `SPIObfuscation.h` 间接引用 |

公开类:`UIFocusSystem`, `UIFocusUpdateContext`, `UIFocusMovementHint`, `UIFocusMovementAction`, `UIFocusDebugger`
公开协议:`UIFocusEnvironment`, `UIFocusItem`, `UIFocusItemContainer`, `UIFocusItemScrollableContainer`, `UIFocusDebuggerOutput`

**注意**:`UIFocusGuide` / `UIFocusContainerGuide` / `UIFocusEffect` 这些 UIKit *公开* 类**不在 FocusEngine 里**,它们在 UIKitCore 里。FocusEngine 只提供 impl 引擎(`_UIFocusGuideImpl` / `_UIFocusContainerGuideImpl`),public 类是 UIKitCore 在 impl 之上的薄包装。这是 AppKitPlus `NSFocusGuide` 也要在 FocusEngine `_UIFocusGuideImpl` 之上自己实现的原因。

---

## 2. 类清单(65 个 ObjC class,按职责分组)

### 2.1 核心引擎 / 公开类

| 类 | 地址 | 备注 |
|---|---|---|
| `UIFocusSystem` | `0x2987b87b8` | 引擎入口,111 个方法,见 §3 |
| `UIFocusUpdateContext` | `0x2987b8790` | 焦点变更上下文,52 个方法,见 §4 |
| `UIFocusMovementHint` | `0x2994e23c0` | 连续移动视觉 hint,11 个方法 |
| `UIFocusMovementAction` | `0x2994e2730` | 一次移动 action 描述,7 个方法 |
| `UIFocusDebugger` | `0x2994e26b8` | 静态 debug 助手,10 个 `+` 方法 |

### 2.2 Focus 树 / 节点(私有)

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIFocusUpdateRequest` | `0x2987b8470` | 由 `requestFocusUpdateToEnvironment:` 创建,包装 target environment |
| `_UIFocusMovementRequest` | `0x2994e2550` | 一次方向键 / hint 引发的移动请求 |
| `_UIAccessibilityFocusUpdateRequest` | `0x2994e28e8` | a11y 引发的 focus 更新 |
| `_UIFocusUpdateThrottle` | `0x2994e2820` | 程序触发 focus 更新的节流器 |
| `_UIFocusTreeLock` / `_UIFocusTreeLockItem` | `0x2987b8498` / `0x2994e2af0` | 并发场景下锁定 focus 树的某子树 |
| `_UIFocusItemInfo` | `0x2987b8678` | `id<UIFocusItem>` 的内部缓存包装 |
| `_UIFocusItemDummy` | `0x2994e2528` | 占位空 item(测试 / sentinel) |

### 2.3 Region & Map(几何搜索引擎,私有)

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIFocusMap` | `0x2987b8628` | 当前 focus 系统所有可见 item 的几何索引 |
| `_UIFocusMapRect` | `0x2987b8600` | Map 中的一个矩形 entry |
| `_UIFocusMapSnapshot` | `0x2987b85d8` | Map 的不可变快照,搜索时使用 |
| `_UIFocusMapSnapshotter` | `0x2987b85b0` | 构造快照的工厂 |
| `_UIFocusMapSearchInfo` | `0x2994e25a0` | 搜索过程的 in-flight 状态 |
| `_UIFocusRegion` | `0x2987b8560` | 搜索的几何区域基类 |
| `_UIFocusItemRegion` | `0x2987b8650` | UIFocusItem 在 region 视角下的包装 |
| `_UIFocusGuideRegion` | `0x2994e2a00` | UIFocusGuide 对应的 region,53 个方法 |
| `_UIFocusContainerGuideRegion` | `0x2994e2dc0` | UIFocusContainerGuide 对应的 region |
| `_UIFocusSpeedBumpRegion` | `0x2994e2b90` | 跨越时减速的 region(scroll boundaries) |
| `_UIFocusPromiseRegion` / `_UIFocusPromiseItem` | `0x2994e2870` / `0x2994e2d70` | 异步加载场景的占位 region/item |
| `_UIFocusRegionEvaluator` | `0x2987b8510` | 对一组 region 打分排序 |
| `_UIFocusRegionContainerProxy` | `0x2987b8538` | 把外部容器(NSView 等)适配成 region container |
| `_UIFocusSearchInfo` | `0x2987b84c0` | 一次搜索的输入 / 输出包 |
| `_UIFocusRegionSearchContextState` | `0x2987b84e8` | 跨多 region 的搜索状态机 |

### 2.4 Movement & Linear Cache

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIFocusMovementPerformer` | `0x2987b8588` | 执行 movement 的状态机,delegate 是 UIFocusSystem |
| `_UIFocusMovementInfo` | `0x2994e2410` | 一次 movement 的 immutable 描述(direction / source / target) |
| `_UIFocusRegionMovementInfo` | `0x2994e2618` | Region 视角下的 movement 数据 |
| `_UIFocusLinearMovementCache` | `0x2994e2a50` | 一直按方向键时缓存的线性序列(避免每次重新构造) |
| `_UIFocusLinearMovementSequence` | `0x2994e2b40` | 上面 cache 的序列对象 |

### 2.5 Preferred / Container Enumeration

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIFocusEnvironmentPreferenceEnumerator` | `0x2987b86a0` | 深度遍历 `preferredFocusEnvironments` 链 |
| `_UIFocusEnvironmentPreferenceEnumerationContext` | `0x2987b86c8` | 遍历过程的状态(visited set 等) |
| `_UIFocusEnvironmentPreferenceCache` | `0x2994e26e0` | 跨多次 update 的 preference 缓存 |
| `_UIFocusEnvironmentPreferenceCacheNode` | `0x2994e2190` | 缓存树节点 |
| `_UIFocusEnvironmentContainerTuple` | `0x2987b86f0` | `(environment, container)` pair |
| `_UIFocusEnvironmentScrollableContainerTuple` | `0x2994e2be0` | 同上但 container 是 scrollable |
| `_UIDeepestPreferredEnvironmentSearch` | `0x2987b8718` | "钻到底"搜索算法(`preferredFocusEnvironments` 递归求叶子) |

### 2.6 Group 系统(分组导航)

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIFocusGroup` | `0x2994e20c8` | 一个 focus group 节点 |
| `_UIFocusNullGroup` | `0x2994e20a0` | 空 group sentinel |
| `_UIFocusGroupHistory` | `0x2994e2140` | 用户跨 group 切换的历史(用于"返回上一组") |
| `_UIFocusGroupMap` | `0x2994e2c30` | 当前 focus 系统的 group 拓扑 |
| `_UIDynamicFocusGroupMap` | `0x2994e2c80` | 动态(SwiftUI 用)的 group map 变种 |

### 2.7 Guide 系统(focus 引导)

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIFocusGuideImpl` | `0x2994e21e0` | UIFocusGuide 的真实实现(39 方法,见 §5) |
| `_UIFocusContainerGuideImpl` | `0x2994e2230` | UIFocusContainerGuide 的真实实现(6 方法) |
| `_UIFocusContainerGuideFallbackItemsContainer` | `0x2994e29b0` | Container guide 的 fallback item 容器 |

### 2.8 Hosted Focus(跨进程 / ViewBridge 场景)

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIHostedFocusSystem` | `0x2994e2cd0` | `UIFocusSystem` 的子系统包装,用于把焦点状态镜像到 host 进程 |
| `_UIHostedFocusSystemDelegateProxy` | `0x2994e2aa0` | Hosted 系统的 delegate 代理 |
| `_UIHostedFocusSystemItemContainer` | `0x2994e2cf8` | Hosted 系统的 item container |

>  `-[UIFocusSystem _hostFocusSystem]` (`0x241bd5c3c`) 在基础 `UIFocusSystem` 中 `return 0;`,只有 `_UIHostedFocusSystem` 子类返回非空。Catalyst 中 cross-process focus sync 走这条路径。AppKitPlus 同进程场景不需要。

### 2.9 Debug & 报告

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIDebugIssue` / `_UIDebugIssueReport` / `_UIDebugIssueReportFormatter` | `0x2987b8768` / `0x2987b8740` / `0x2994e2370` | 一个可报告的问题及其聚合 |
| `_UIDebugLogStatement` / `_UIDebugLogReport` / `_UIDebugLogReportFormatter` | `0x2994e2280` / `0x2994e22d0` / `0x2994e2348` | 日志条目及其聚合 |
| `_UIDebugReportFormatter` / `_UIDebugReportComponents` | `0x2994e2460` / `0x2994e24b0` | 通用报告基础设施 |
| `_UIFocusDebuggerStringOutput` | `0x2994e2640` | `UIFocusDebugger` 返回的 `id<UIFocusDebuggerOutput>` 字符串实现 |
| `_UIFocusUpdateReport` / `_UIFocusUpdateReportFormatter` | `0x2994e2780` / `0x2994e27f8` | 一次 focus 更新的完整 trace 报告 |

### 2.10 杂项

| 类 | 地址 | 角色 |
|---|---|---|
| `_UIFocusWeakHelper` | `0x2994e2960` | weak ref wrapper |
| `_UIFocusInputDeviceInfo` | `0x2994e2910` | 触发 focus 移动的输入设备元数据(键盘 / 遥控器 / game controller) |

---

## 3. UIFocusSystem 详解(111 个方法)

### 3.1 Designated initializer

`-[UIFocusSystem initWithFocusBehavior:enabled:]` @ `0x241bcfdc0`(`initWithFocusBehavior:` @ `0x241bcfdb8` 是单参数 alias)。

反编译要点:
1. `[super init]`
2. 存 behavior 到 ivar `+144`
3. 存 `enabled` 到 byte ivar `+61`
4. 创建 `_UIFocusMovementPerformer`(`0x2987b8588`),`setDelegate:self`,存 ivar `+64`
5. 注册 self 到全局 `_MergedGlobals_7`(所有 active focus systems 的集合)
6. 调 `_focusBehaviorDidChange`(初始化 behavior-derived caches)

**含义**:behavior 是 designated 参数,但实际接口是 duck typing —— FocusEngine 只通过 `respondsToSelector:` + `msgSend` 调用 behavior。AppKitPlus 直接复用 AppKit 的 `NSAppKitFocusBehavior`(spike 已验证可工作),不需要自己实现 behavior 类。

### 3.2 Delegate selector caching(`-[UIFocusSystem setDelegate:]` @ `0x241bd5d58`)

setDelegate 不只是存 weak ref —— 它对 delegate 调用 **17 个 selector** 的 `respondsToSelector:` 检查,把结果缓存到 `_flags` bitfield 的 bit 6–22 区间,后续 dispatch 走 fast path。

> **方法识别(2026-05-18 二轮反向)**:
>
> 17 个 selector 通过 `_objc_msgSend$_focusSystem:*` ObjC msg-send stub 表(`UIKitCore:__objc_stubs` 段)+ `_UIFocusSystemSceneComponent` / `NSFocusController` 类的 instance method 清单交叉验证识别。`_UIFocusSystemDelegate` 协议 `_OBJC_INSTANCE_METHODS__UIFocusSystemDelegate` 的 method count(读 method list header @ `0x241bdd320`)是 **18**,而 setDelegate 缓存 17 位 ——
> 推测第 18 个 method(可能是 `_focusItemContainerForFocusSystem:` 的 required 路径)直接在 dispatch 时调用,不走 selector caching。
>
> **bit position 到具体 selector 的精确映射**(每个 bit 对应哪个具体 method)需要单独反编译每个 flag 的下游 dispatch 点(在 `_updateFocusWithContext:report:` / `_sendDidUpdateFocusNotificationsInContext:` 等内部 method 中按 bit 分支)—— 留作 follow-up。

| flag bit | selector | 来源(已在合并库识别) |
|---|---|---|
| 0x40 – 0x400000 | 以下 17 个 selector 之一(精确 bit↔selector 映射待续作反编译) | `UIKitCore:__objc_stubs` + `_UIFocusSystemSceneComponent` impls |

**17 个 `_UIFocusSystemDelegate` optional methods**(按字母序排列;实现者:UIKitCore `_UIFocusSystemSceneComponent` 实现全部 17 个,AppKit `NSFocusController` 选择性实现其中 7 个):

| Selector | UIKitCore 实现 `_UIFocusSystemSceneComponent` | AppKit 实现 `NSFocusController` |
|---|---|---|
| `_focusItemContainerForFocusSystem:` | ✓ `0x1b9ba0680` | ✓ `0x1855d262c` |
| `_preferredFocusEnvironmentsForFocusSystem:` | (未在表中确认) | ✓ `0x1855d2698` |
| `_focusSystem:containsChildOfHostEnvironment:` | (none — 走 _UIHostedFocusSystemDelegateProxy 路径) | — |
| `_focusSystem:didCancelFocusUpdateInContext:` | ✓ `0x1b9ba0614` | — |
| `_focusSystem:didFinishUpdatingFocusInContext:` | ✓ `0x1b9ba03b4` | ✓ `0x1855d2874` |
| `_focusSystem:didUpdateDeferralTarget:` | ✓ `0x1b9ba077c` | — |
| `_focusSystem:didUpdateFocusInContext:` | ✓ `0x1b9ba00fc` | — |
| `_focusSystem:environment:didUpdateFocusInContext:` | ✓ `0x1b9ba058c` | — |
| `_focusSystem:focusItemsInRect:` | (主要由 _UIHostedFocusSystemDelegateProxy 实现) | — |
| `_focusSystem:handleFailedMovementRequest:` | ✓ `0x1b9ba0780` | — |
| `_focusSystem:isScrollingScrollableContainer:targetContentOffset:` | ✓ `0x1b9ba0a58` | — |
| `_focusSystem:shouldRestoreFocusInContext:` | ✓ `0x1b9b9fa1c` | — |
| `_focusSystem:shouldReverseLayoutDirectionForEnvironment:` | ✓ `0x1b9ba0ba8` | — |
| `_focusSystem:shouldReverseLinearWrappingForEnvironment:` | ✓ `0x1b9ba0c9c` | — |
| `_focusSystem:willMessageNewFocusNodes:` | ✓ `0x1b9ba0538` | — |
| `_focusSystem:willMessageOldFocusNodes:` | ✓ `0x1b9ba04e4` | — |
| `_focusSystem:willUpdateFocusInContext:` | ✓ `0x1b9b9fc88` | ✓ `0x1855d279c` |

>  AppKit 只实现 7 个 method(`focusItemContainerForFocusSystem:` / `preferredFocusEnvironmentsForFocusSystem:` / `_focusSystem:willUpdateFocusInContext:` / `_focusSystem:didFinishUpdatingFocusInContext:` 加另外几个可能从基类继承)—— 这意味着对 macOS 原生 AppKit 应用,FocusEngine 内部跳过了 ~10 个 callback 路径(`_focusSystem:didCancelFocusUpdateInContext:` 等),focus 模型相对 UIKit 更简化。AppKitPlus port 需要的 callback 子集与 AppKit 已有的 7 个高度重合。

**对 AppKitPlus 设计的含义**:
- `NSFocusEnvironment` 协议的 `shouldUpdateFocusInContext:` / `didUpdateFocusInContext:withAnimationCoordinator:` 这两个 environment-level callback 跟 `_UIFocusSystemDelegate` 的 system-level callback **不是同一组**(前者在 environment 上,后者在 NSFocusController 上)。AppKitPlus 用户接触前者,后者完全藏在 `_NSFocusBridge` 内。
- 因为 AppKit 只用 7 个,AppKitPlus 包装层不需要重新声明 17 个 delegate method —— 沿用 AppKit `NSFocusController` 既有实现即可,不增加 SPI 表面。

### 3.3 Public 方法

| 方法 | 地址 | 用途 |
|---|---|---|
| `+[UIFocusSystem environment:containsEnvironment:]` | `0x241bd187c` | **类方法**,判断 `descendant` 是否在 `ancestor` 的 focus 子树中 |
| `-focusedItem` | `0x241bd03e0` | 当前焦点 item |
| `-requestFocusUpdateToEnvironment:` | `0x241bd199c` | 公开请求 API,内部构造 `_UIFocusUpdateRequest` 后调 `_requestFocusUpdate:` |
| `-updateFocusIfNeeded` | `0x241bd3754` | 立即结算挂起的更新 |
| `-shouldUpdateFocusInContext:` | `0x241bd1868` | `UIFocusEnvironment` 协议实现 |
| `-didUpdateFocusInContext:` | `0x241bd1870` | 同上 |
| `-preferredFocusEnvironments` | `0x241bd1774` | 同上 |
| `-parentFocusEnvironment` | `0x241bd1598` | 同上(返回 nil,根节点) |
| `-focusItemContainer` | `0x241bd1640` | 同上 |
| `-setBehavior:` | `0x241bd63e4` | 公开 setter,可运行时切换 behavior |

### 3.4 私有路径(关键内部入口)

| 方法 | 地址 | 用途 |
|---|---|---|
| `-_requestFocusUpdate:` | `0x241bd1a70` | 真正的更新入口,接收 `_UIFocusUpdateRequest` |
| `-_updateFocusImmediatelyToEnvironment:` | `0x241bd51f0` | 跳过 deferral / throttle,立即把焦点切到指定 environment |
| `-_updateFocusImmediatelyToEnvironment:startDeferringOnLostFocus:suppressLostFocusUpdate:` | `0x241bd4e70` | 完整签名版本 |
| `-_updateFocusWithContext:report:` | `0x241bd40e4` | 接收已构造的 context,带 debug report 收集 |
| `-_focusEnvironmentWillBecomeInvisible:` / `-_focusEnvironmentDidBecomeVisible:` | `0x241bd20b4` / `0x241bd28d8` | 当 environment 进入 / 离开可见状态时通知引擎 |
| `-_focusEnvironmentDidAppear:` / `-_focusEnvironmentWillDisappear:remainingInHierarchy:` | `0x241bd2970` / `0x241bd21d0` | 视图层级变化时通知 |
| `-_topEnvironment` | `0x241bd31f8` | 焦点树最顶端节点(通常是 root environment) |
| `-_deepestPreferredFocusEnvironment` | `0x241bd5a74` | 沿 `preferredFocusEnvironments` 链钻到底的当前结果 |
| `-_buildFocusItemAncestorCacheIfNecessary` | `0x241bd5620` | 构造 ancestor 缓存,加速 `containsEnvironment:` 等查询 |
| `-_isEnvironmentEligibleForFocusUpdate:fallbackToEnvironment:debugReport:` | `0x241bd32d0` | 判断 environment 是否当前可获焦,带 debug report |
| `-invalidateFocusItemContainer:` | `0x241bd5520` | 让引擎丢弃对某 container 的缓存(用于 container 内容变化) |
| `-_setOverrideFocusDeferralBehavior:` | `0x241bd1360` | 临时 override deferral 策略 |
| `-_performWithoutFocusUpdates:` | `0x241bd4ccc` | 跑一段 block 期间禁用焦点更新 |
| `-_simulatedNonDeferredProgrammaticFocusUpdateToEnvironment:` | `0x241bd520c` | 测试用 — 模拟程序触发更新(跳过 deferral) |
| `-_closestFocusableItemToPoint:inEnvironment:constrainedToRect:distanceMeasuringUnitPoint:itemFilter:` | `0x241bd534c` | 几何查询 — 最近可焦 item |

### 3.5 测试钩子(`_uiktest_*`)

| 方法 | 地址 |
|---|---|
| `_uiktest_updateFocusToItem:` | `0x241bd5c44` |
| `_uiktest_setPreviousFocusedItem:` | `0x241bd5c94` |
| `_uiktest_disableFocusDeferral` | `0x241bd5ca0` |
| `_uiktest_disableThrottle` | `0x241bd5d18` |

>  这四个方法是 UIKit 自家测试用,把 deferral / throttle 关掉后可以做 deterministic 断言。AppKitPlus 写 parity test 时可以 obfuscate 调用这些钩子来稳定行为。

---

## 4. UIFocusUpdateContext 详解(52 个方法)

### 4.1 Designated init(全部私有)

| 方法 | 地址 |
|---|---|
| `_initWithFocusUpdateRequest:` | `0x241bb6054` |
| `_initWithFocusMovementRequest:nextFocusedItem:` | `0x241bb6224` |
| `_initWithContext:` | `0x241bb63b4` |

公开 `init` 抛断言,context 总由 UIFocusSystem 内部构造,不能用户实例化。

### 4.2 Public 属性

| 方法 | 地址 |
|---|---|
| `previouslyFocusedItem` | `0x241bb6f24` |
| `nextFocusedItem` | `0x241bb6f7c` |
| `focusHeading` | `0x241bb73a8` |
| `focusBehavior` | `0x241bb7f18` |

>  `focusBehavior` 是 public,但返回 `id<_UIFocusBehavior>` —— `_UIFocusBehavior` 协议**不在 FocusEngine**(在 UIKitCore 里)。AppKitPlus 决定**不暴露**这个属性,避免传播 UIKitCore 私有协议依赖。

### 4.3 私有内部状态

| 方法 | 地址 | 用途 |
|---|---|---|
| `_destinationItemInfo` | `0x241bb7028` | 目标 item 的 `_UIFocusItemInfo` 缓存对象 |
| `linearSortedFocusItems` | `0x241bb706c` | 按线性方向排序的可焦 item 列表 |
| `_focusVelocity` | `0x241bb73e8` | 当前焦点的速度向量 |
| `_isInitialMovement` | `0x241bb7458` | 是否本次连续移动的第一步 |
| `_focusedGuide` | `0x241bb7514` | 当前 focused guide(如果有) |
| `_setFocusRedirectedByGuide:` | `0x241bb7568` | 标记本次更新由 guide 重定向 |
| `_commonAncestorEnvironment` | `0x241bb72f0` | source / target 在 environment 树的最近公共祖先 |
| `_focusGroupMap` | `0x241bb7954` | 当前 group 拓扑 |
| `_previouslyFocusedGroupIdentifier` / `_nextFocusedGroupIdentifier` | `0x241bb7a48` / `0x241bb7b00` | group 变化前后的标识符 |
| `_willUpdateFocusFromFocusedItem:` / `_didUpdateFocus` | `0x241bb76b0` / `0x241bb7748` | 引擎在 commit 前 / 后调用的内部钩子 |

---

## 5. _UIFocusGuideImpl 详解(39 个方法)

### 5.1 Lifecycle

- `-initWithDelegate:` @ `0x241ba9860`,**delegate 不能为 nil**(否则抛 NSAssertion)
- delegate 必须实现 `_UIFocusGuideRegionDelegate` 协议(`0x295402f68`)
- delegate 协议方法:
  - `-focusGuideRegion:preferredFocusEnvironmentsForMovementRequest:` @ `0x241ba9efc`
  - `-focusGuideRegion:willParticipateAsDestinationRegionInFocusUpdate:` @ `0x241ba9fc0`

### 5.2 Public-like API(对应 UIKit `UIFocusGuide`)

| 方法 | 地址 |
|---|---|
| `-setEnabled:` / `-isEnabled` | `0x241ba9980` / `0x241ba9974` |
| `-setPreferredFocusEnvironments:` / `-preferredFocusEnvironments` | `0x241ba9ba8` / `0x241ba9a9c` |
| `-frame` | `0x241ba9c44` |

`setPreferredFocusEnvironments:` 反编译(`0x241ba9ba8`):copy array,nil → 替换为 `__NSArray0__` 单例,设置 ivar flag `0x20`(`_didSetPreferredFocusedEnvironments`)。

### 5.3 UIFocusEnvironment 协议实现

| 方法 | 地址 |
|---|---|
| `parentFocusEnvironment` | `0x241ba9c60` |
| `focusItemContainer` | `0x241ba9c58` |
| `canBecomeFocused` | `0x241ba9c50`(返回 NO,guide 自身不可获焦) |
| `setNeedsFocusUpdate` | `0x241ba9cf0` |
| `updateFocusIfNeeded` | `0x241ba9cf4` |
| `shouldUpdateFocusInContext:` | `0x241ba9cf8` |
| `didUpdateFocusInContext:` | `0x241ba9d00` |

### 5.4 内部修饰位(影响搜索行为)

| 方法 | 地址 | 含义 |
|---|---|---|
| `_setIsUnoccludable:` | `0x241ba99a0` | guide 不能被上层 region 遮挡 |
| `_setIsUnclippable:` | `0x241ba99cc` | guide 不被 search rect clip |
| `_setFocusPriorityRequired:` | `0x241ba99f8` | 标记为"必须"优先级 |
| `_setIgnoresSpeedBumpEdges:` | `0x241ba9a24` | 不受 speed bump 影响 |
| `_setAutomaticallyPreferOwningItem:` | `0x241ba9a50` | 自动倾向 owning item |

### 5.5 `_UIFocusContainerGuideImpl`(6 个方法)

| 方法 | 地址 |
|---|---|
| `-initWithDelegate:` | `0x241baa118` |
| `-_isEligibleForFocusInteraction` | `0x241baa170` |
| `-_searchForFocusRegionsInContext:` | `0x241baa1c0` |
| `-fallbackItemProvider` / `-setFallbackItemProvider:` | `0x241baa410` / `0x241baa418` |

>  `fallbackItemProvider` 是 block 属性,容器引导在 region 内没有 preferred 时调用此 block 获取兜底 item。AppKitPlus `NSFocusContainerGuide.fallbackItemProvider` 直接对应。

---

## 6. 协议清单(22 个)

### 6.1 公开协议

| 协议 | 地址 | 备注 |
|---|---|---|
| `UIFocusEnvironment` | `0x295402d28` | 焦点环境基础协议 |
| `UIFocusItem` | `0x295402d88` | 可获焦 item(继承 UIFocusEnvironment) |
| `UIFocusItemContainer` | `0x295403268` | item 容器(几何查询入口) |
| `UIFocusItemScrollableContainer` | `0x295403388` | 可滚动 container(焦点移出可见区域时自动滚动) |
| `UIFocusDebuggerOutput` | `0x2954031a8` | Debugger 返回值的 marker 协议 |
| `NSObject` | `0x295402cc8` | 标准协议(non-Focus) |
| `NSCopying` | `0x295402e48` | 标准协议(non-Focus) |
| `BSXPCCoding` | `0x295403028` | BoardServices XPC 编码(hosted focus 用) |

### 6.2 私有协议

| 协议 | 地址 | 角色 |
|---|---|---|
| `_UIFocusSystemDelegate` | `0x2954032c8` | **UIFocusSystem 的 delegate** — UIKitCore 的 `_UIFocusSystemSceneComponent` 和 AppKit 的 `NSFocusController` 都实现它 |
| `_UIFocusEnvironmentPrivate` | `0x295402ea8` | UIFocusEnvironment 的 private extension(更多内部 hook) |
| `_UIFocusEnvironmentInternal` | `0x2954034a8` | 内部状态接口(visibility / appear 事件等) |
| `_UIFocusEnvironmentPlatformSupport` | `0x295403448` | 平台特化接口(差异点) |
| `_UIFocusRegionContainer` | `0x295402f08` | Region container 抽象(`_UIFocusMap` 实现它) |
| `_UIFocusGuideRegionDelegate` | `0x295402f68` | `_UIFocusGuideImpl` 与 `_UIFocusGuideRegion` 沟通用 |
| `_UIDebugIssueReporting` | `0x295402fc8` | 可被记入 issue report 的对象 |
| `_UIFocusEnvironmentPreferenceEnumerationContext` | `0x295403088` | 遍历 preferredFocusEnvironments 时的 context |
| `_UIFocusEnvironmentPreferenceEnumerationContextDelegate` | `0x2954030e8` | 同上的 delegate |
| `_UIFocusRegionSearchContext` | `0x295403148` | Region 搜索过程的 context |
| `_UIFocusMapArea` | `0x295403208` | Focus map 中的区域抽象 |
| `_UIHostedFocusSystemDelegate` | `0x295403328` | Hosted 系统的 delegate(cross-process) |
| `_UIFocusMovementPerformerDelegate` | `0x2954033e8` | `_UIFocusMovementPerformer` 的 delegate(UIFocusSystem 实现) |
| `_UIFocusUpdateRequesting` | `0x295402de8` | 表示一次"焦点更新请求"的抽象(`_UIFocusUpdateRequest` 等实现) |

---

## 7. _UIHostedFocusSystem 子系统

`_UIHostedFocusSystem` 是 `UIFocusSystem` 的子类,用于把焦点系统的状态镜像到另一个进程(典型场景:Catalyst 中 NSWindow 持有的 UIKit scene 在 ViewBridge 隔离的子进程渲染时)。

关键 entrypoint:
- `-[UIFocusSystem _hostFocusSystem]` @ `0x241bd5c3c`:基础类 `return 0;`,子类返回 self
- `_UIHostedFocusSystem` / `_UIHostedFocusSystemDelegateProxy` / `_UIHostedFocusSystemItemContainer` 三件套

AppKitPlus 是同进程使用,**完全不涉及**这条路径。本研究不进一步展开。

---

## 8. AppKitPlus 集成路径(基于本研究)

### 8.1 包装层级表

| AppKitPlus 类 / 协议 | 底层来源 | 实现策略 |
|---|---|---|
| `NSFocusEnvironment`(协议) | `UIFocusEnvironment`(public) | 直接 mirror,签名不变 |
| `NSFocusItem`(协议) | `UIFocusItem`(public) | 直接 mirror |
| `NSFocusItemContainer`(协议) | `UIFocusItemContainer`(public) | 直接 mirror |
| `NSFocusSystem`(类) | `UIFocusSystem`(public) | SPI obfuscation 包装,thin facade |
| `NSFocusUpdateContext`(类) | `UIFocusUpdateContext`(public) | SPI obfuscation 包装,只暴露 4 个 public 属性 |
| `NSFocusMovementHint`(类) | `UIFocusMovementHint`(public) | 直接 SPI 包装 |
| `NSFocusMovementAction`(类) | `UIFocusMovementAction`(public) | 直接 SPI 包装 |
| `NSFocusDebugger`(类) | `UIFocusDebugger`(public) | 直接 SPI 包装(全是 class methods) |
| `NSFocusGuide`(类) | `_UIFocusGuideImpl` + `_UIFocusGuideRegion`(SPI) | NSLayoutGuide 子类,自己实现 `_UIFocusGuideRegionDelegate`,内部持 impl/region pair |
| `NSFocusContainerGuide`(类) | `_UIFocusContainerGuideImpl`(SPI) | NSFocusGuide 子类,加 `fallbackItemProvider` |
| `NSView (Focus)` | `-[NSView _focusProxy]`(SPI,见 catalyst 文档) | 直接 expose,提供 `+focusItemProxyClass` 扩展点 |
| `NSWindow (Focus)` | `-[NSWindow _wantsFocusSystem]` / `_focusController`(SPI) | opt-in `wantsFocusSystem` setter + lazy `focusSystem` getter |

### 8.2 不暴露的边界

- `_UIFocusBehavior` 协议(UIKitCore 私有) — AppKitPlus 直接复用 `NSAppKitFocusBehavior`(AppKit 内已存在),用户不接触 behavior
- `_UIHostedFocusSystem` 子系统 — 同进程不需要
- `UIFocusUpdateContext.focusBehavior` 属性 — 返回 `_UIFocusBehavior`,会传播私有依赖,不暴露
- `_UIFocusGroupMap` / `_UIFocusMap` 等内部数据结构 — 引擎自己用,用户不需要

### 8.3 SPI 调用面

走 `SPIObfuscation.h`:
- `NSP_CACHED_SPI_CLASS("UIFocus", "System")` — 拿 `UIFocusSystem` 类
- `NSP_CACHED_SPI_CLASS("UIFocus", "UpdateContext")` — 拿 `UIFocusUpdateContext` 类
- `NSP_CACHED_SPI_CLASS("_UIFocusGuide", "Impl")` — 拿 `_UIFocusGuideImpl` 类
- `NSP_CACHED_SPI_CLASS("NSFocus", "Controller")` — 拿 AppKit 的 `NSFocusController`
- `NSP_CACHED_SPI_SEL("_focus", "Controller")` / `NSP_CACHED_SPI_SEL("_focus", "Proxy")` — NSWindow / NSView 私有 accessors
- `NSP_CACHED_SPI_SEL("set_wants", "FocusSystem:")` — NSWindow opt-in setter(待二次验证 selector 实名)

---

## 9. 未解决 / 待补充

1. §3.2 的 16 个 selector 地址需要去 `__objc_methname` 段反向回名字,确定 `_UIFocusSystemDelegate` optional 方法的具体清单。
2. `_UIFocusMap` 的几何索引算法(quadtree / 直接列表)未反编译,影响理解大量 focus item 时的性能特征。
3. `_UIFocusUpdateThrottle` 的节流参数(时间窗口 / 触发阈值)未读出,Catalyst 端的 `UINSWindowProxyFocusHelper` 用 10ms 去抖,FocusEngine 自己的节流时基不一定相同。
4. `_UIFocusLinearMovementCache` 的失效策略(focus 树变化时是否清空)未读出,可能影响长序列方向键导航的体感。
5. AppKitPlus `NSFocusGuide` 设计依赖 `_UIFocusGuideRegion` 的 `setOwningEnvironment:`,完整 attach/detach 时序需要在实现阶段再用反编译验证。

---

## 10. 附录:本研究使用的关键 IDA 符号

| 符号 | 地址 | 来源 |
|---|---|---|
| `-[UIFocusSystem initWithFocusBehavior:enabled:]` | `0x241bcfdc0` | FocusEngine |
| `-[UIFocusSystem setDelegate:]` | `0x241bd5d58` | FocusEngine |
| `-[UIFocusSystem setBehavior:]` | `0x241bd63e4` | FocusEngine |
| `-[UIFocusSystem requestFocusUpdateToEnvironment:]` | `0x241bd199c` | FocusEngine |
| `-[UIFocusSystem _hostFocusSystem]` | `0x241bd5c3c` | FocusEngine |
| `+[UIFocusSystem environment:containsEnvironment:]` | `0x241bd187c` | FocusEngine |
| `-[_UIFocusGuideImpl initWithDelegate:]` | `0x241ba9860` | FocusEngine |
| `-[_UIFocusGuideImpl setPreferredFocusEnvironments:]` | `0x241ba9ba8` | FocusEngine |
| `_OBJC_CLASS_$_UIFocusSystem` | `0x2987b87b8` | FocusEngine |
| `_OBJC_CLASS_$__UIFocusGuideImpl` | `0x2994e21e0` | FocusEngine |
| `_OBJC_CLASS_$__UIFocusContainerGuideImpl` | `0x2994e2230` | FocusEngine |
| `_OBJC_PROTOCOL_$__UIFocusSystemDelegate` | `0x2954032c8` | FocusEngine |
| `_OBJC_PROTOCOL_$__UIFocusGuideRegionDelegate` | `0x295402f68` | FocusEngine |
