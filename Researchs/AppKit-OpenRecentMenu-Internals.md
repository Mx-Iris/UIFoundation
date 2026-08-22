# AppKit Open Recent 菜单的认领与插入机制

> 调研对象：macOS 26.6 / `dyld_shared_cache_arm64e` 中的 AppKit（`AppKit.i64`，IDA `idalib` MCP）
> 调研动机：Evolution 0009 的 `MainMenu.File.openRecent()` 在 document-based App 里与系统
> 自动插入的 Open Recent 并存，File 菜单出现两个 Open Recent（用户实测截图）；而 xib 里的
> Open Recent 从不重复。要回答「xib 为什么不重复、代码菜单为什么重复」。
> 结论摘要：**系统按私有菜单名 `NSRecentDocumentsMenu` 认领 Open Recent** —— xib 的
> `systemMenu="recentDocuments"` 在 nib 解码收尾时转正为该名字并登记；`NSDocumentController`
> 先按名查、查到就接管那一个（清空重灌），查不到才按 `openDocument:` action 定位 Open… 项
> 另插一个。代码菜单没有名字 → 查不到 → 另插 → 两个。
> 状态：调研完成，结论已落地（标准 File 菜单移除 Open Recent，见 0009 决策日志）。

---

## 1. nib 解码端：`systemMenu` 属性如何变成菜单名

`-[NSMenu _finishedMakingConnections]`（`0x1849e2f34`）在 nib 装载收尾时把 IB 形式的
私有名（下划线前缀）转正并登记：

| IB 编码名（`_menuName` 初值） | 转正后的注册名 |
|---|---|
| `_NSMainMenu` | `NSMainMenu` |
| `_NSServicesMenu` | `NSServicesMenu` |
| `_NSWindowsMenu` | `NSWindowsMenu` |
| `_NSFontMenu` | `NSFontMenu` |
| `_NSAppleMenu` | `NSAppleMenu` |
| `_NSRecentDocumentsMenu` | **`NSRecentDocumentsMenu`** |
| `_NSHelpMenu` | （不入表，直接 `[NSApp setHelpMenu:self]`） |
| `_NSRevertDocumentMenuName` | `NSRevertDocumentMenuName` |

即 xib 的 `systemMenu` 属性全家都走这条路 —— 这就是 Interface Builder 侧特殊菜单接线的
真身。注册后可用 `+[NSMenu _menusWithName:]` 全局查询。

同函数还有一条启发式：菜单首项的 action 是 `orderFrontFontPanel:` 且 target 是
`NSFontManager.shared` 时，自动命名为 `NSFontMenu` —— 仅 nib 路径生效，代码构建的菜单
不经过 `_finishedMakingConnections`。

## 2. 认领端：`-[NSDocumentController _installOpenRecentMenus]`

`0x1849ed450`，逻辑骨架：

```c
v3 = [NSMenu _menusWithName:@"NSRecentDocumentsMenu"];
if ([v3 count] != 0)
    goto 跳过插入;                                  // ← xib 菜单在此被认领，绝不重复
// 没有注册名下的菜单，且满足两个条件才自行插入：
//   [self documentClassNames] 非空（document-based）
//   [self maximumRecentDocumentCount] != 0
// 遍历主菜单每个顶层 submenu：
//   idx = [submenu indexOfItemWithTarget:nil andAction:@selector(openDocument:)];
//   命中 → [_recentItemsController _createOpenRecentMenuItem] 插到 idx+1
跳过插入:
// 对注册名下的每个菜单（含刚创建的）统一接管：
//   removeItemAtIndex: 清空全部 items        ← xib 里那个 Clear Menu 只是占位，被扔掉
//   [_recentItemsController _addClearMenuItemToMenu:withTitle:] 重建 Clear Menu
//   [menu setDelegate:_subMenuDelegate]      ← 行内容惰性填充
```

四个要点：

1. **认领按名字，不按结构。** 有注册名 → 接管；无名字的代码菜单对它不可见。
2. **插入按 action 定位。** 查不到名字时，按 `openDocument:` 找 Open… 项、插在其后 ——
   这解释了重复场景中系统那个 Open Recent 的位置（紧跟 Open…）。
3. **非文档 App 不插入。** `documentClassNames` 为空或 `maximumRecentDocumentCount == 0`
   直接跳过 —— 代码菜单自带的 Open Recent 在非文档 App 里永远是死结构。
4. **被认领的菜单内容完全归系统。** 清空重灌 + delegate 惰性填充；xib 提供的只是壳。

## 3. 同函数的其余注入：标准 selector 保真的意义

`_installOpenRecentMenus` 接着对 autosave-in-place 的文档 App 继续按 action 定位标准项
并增强 File 菜单：

- 按 `saveDocument:` / `saveDocumentAs:` 定位后插入 **Duplicate**（`duplicateDocument:`，
  ⇧⌘S 的 alternate）、**Rename…**、**Move To…**；
- `revertDocumentToSaved:` 项被隐藏，换成 "Revert To" 子菜单 —— 该子菜单**现场调用
  `-[NSMenu _setMenuName:@"NSRevertDocumentMenuName"]` 注册**（私有设名不是民间技巧，
  AppKit 自己就这么干）；
- `allowsAutomaticShareMenu` 时按 `saveDocumentToPDF:` / `saveDocument:` 定位插入
  Share 项；
- 按 `newDocument:` 定位构建 New Document touch bar。

**这意味着 0009「标准 selector 逐字照抄模板」不只是保真洁癖**：文档型 App 的整套系统
增强都按这些 action 定位落点，selector 走样一个，对应的增强就落不上。

## 4. 图标：`-[NSMenu _actionImageNameFromMenuName]`

macOS 26 按注册名解析菜单项图标（`0x18540bd9c` 引用 `NSRecentDocumentsMenu`）。这解释了
重复场景截图里系统的 Open Recent 带时钟图标、代码构建的没有 —— 无名字连图标解析都不参与。
普通菜单项的图标（New / Open… / Close / Save… 等）则按 action 解析，代码菜单同等享受。

## 5. 对本库的结论

- **标准 File 菜单不再包含 Open Recent**（0009 落地修正）：文档型 App 系统自动插入能用的
  那个；非文档型 App 本来就不该有。
- `MainMenu.File.openRecent()` 工厂保留：宿主手动维护 recent 列表
  （`NSDocumentController.shared.recentDocumentURLs` + `menuNeedsUpdate(_:)`）仍是真实
  场景。
- 若将来要「与 xib 完全同权」（被系统接管、免手动维护、带图标），路径是
  `UIFoundationAppleInternal` 中经私有 `-[NSMenu _setMenuName:]` 注册
  `NSRecentDocumentsMenu` —— 本次调研把该路径从可行推测升级为 AppKit 自用的做法；未立项。

## 6. 关键地址

| 符号 | 地址（imagebase `0x1849b9000`） |
|---|---|
| `-[NSMenu _finishedMakingConnections]` | `0x1849e2f34` |
| `-[NSDocumentController _installOpenRecentMenus]` | `0x1849ed450` |
| `+[NSMenu _menusWithName:]` | `0x1849e95b4` |
| `-[NSMenu _setMenuName:]` | `0x1849cef34` |
| `-[_NSRecentItemsMenuController _createOpenRecentMenuItem]` | `0x1851f43b8` |
| `-[_NSRecentItemsMenuController _addClearMenuItemToMenu:withTitle:]` | `0x1851f4290` |
| `-[NSDocumentControllerSubMenuDelegate updateMenu:withEvent:withFlags:]` | `0x184c51550` |
| `-[NSMenu _actionImageNameFromMenuName]` | `0x18540bd9c` |
