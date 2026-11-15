# Draft - 最低系统提到 macOS 14

- **状态**: In Progress
- **创建日期**: 2026-11-15
- **最后更新**: 2026-11-15
- **实现分支 / PR**: `feature/raise-deployment-target-to-macos-14`

## 摘要

AppKitPlus 从 0.23.0 之后的下一版起，最低系统是 macOS 14.0（AppKitPlus 仓库的提案
`0117-raise-deployment-target-to-macos-14.md`）。原因是部署目标低于 macOS 13.3 时，Swift 给它改过运行时名的协议
生成的协议记录用源码名，对这些协议做 `as?`、采纳都会悄悄失效（[swiftlang/swift#94329](https://github.com/swiftlang/swift/issues/94329)）。
SwiftPM 按包图检查二进制 target 的平台要求，比的是本库自己声明的下限，不是 App 的：本库还停在 macOS 12 时，
打开 `AppKitPlus` trait 就解析失败，App 的部署目标是 15 也一样；`platforms` 只有一个值，不能随 trait 变。
本提案把本库的 macOS 下限提到 14，赶在 AppKitPlus 发版之前：下限高于依赖的下限没有问题，晚于它发版才会留下
一段编不过的空窗。其余平台不变。

## 方案

- **`Package.swift`**：`platforms` 的 `.macOS(.v12)` 改成 `.macOS(.v14)`，上方注释改写成新的理由。
  `Package.resolved` 的 pin 不动，`originHash` 改成新清单的 `shasum -a 256`——对不上时，下一次构建会不带 trait
  重新解析，把 AppKitPlus 的 pin 删掉（AGENTS.md 构建一节）。对 AppKitPlus 的约束仍是 `from: "0.6.0"`：
  提到 14 之后，0.6.0–0.23.0（macOS 12）和之后的版本（macOS 14）都能用。
- **示例 App**：target 的部署目标从 12.0 提到 14.0（Debug、Release 两处；project 级本来就是 14.0）。低于所依赖的
  包的下限，Xcode 拒绝构建。
- **`ComponentLayoutExample`**：示例自带的包，`platforms` 从 `.v12` 提到 `.v14`，`Package.resolved` 的 `originHash`
  同样改掉。它开着 `AppKitPlus` trait 依赖本库，下限低于本库也会解析失败。说明「为什么压在 12」的几段注释改写；
  各章节上的 `@available(macOS 14.0, *)` 从此冗余，留着不删。
- **文档**：AGENTS.md 三处（最低系统；Settings 两个 product 为什么不进 umbrella；示例 App 一条里的部署目标），
  README 的要求一行（还写着早已过时的 10.15），`AppKitPlus.md` 第 3 节，`SettingsWindow.md` 两处，`FilterUI.md`
  一处，一处测试注释里的部署目标。

落地步骤：

1. 本库的下限、`originHash` 与文档（完成）。验证：全 trait `swift build`。
2. 示例 App 与 `ComponentLayoutExample` 的下限，AGENTS.md 示例一条（完成）。验证：从新副本构建示例 App。

最后跑全 trait 测试（分四段）。

未经询问采用的假设：

- **不清理冗余的可用性判断。** 提到 14 之后，源码、测试与示例里 macOS 14 及以下的 `@available` / `#available`
  约 340 处恒为真。照上次抬下限（`0017-appkitplus-layer-backed-view`）的做法留着：清理只有可读性收益，混进来
  diff 没法审。
- **Settings 两个 product 仍不进 umbrella。** 当初留在外面是为了不把 macOS 14 压给所有使用方，这条理由随本次失效；
  要不要并进去是另一个决定。
- **不发版。** 按版本号依赖本库的下游，要等下一次发版才拿到这次改动。

下游影响：抬高的是所有使用方的最低系统，与开不开 trait 无关。本机依赖本库、部署目标低于 14 的有 6 个 App，
它们要么把部署目标提到 14，要么把对本库的依赖钉在提下限之前：

- 跟 `main` 的 CodeOrganizer（12.0）、CodeSnippetsSync（12.0）、NeteaseCloudMusicUploader（11.0）：本库推送之后，
  下次更新依赖就编不过。
- 按版本号的 LyricsX（12）、XMLViewer（12）、StarLight（13）：本库下一次发版之后才受影响。

RuntimeViewer、MachOKitUI、PrivateSymbols、XCOrganizer 和其余依赖本库的项目都在 14 以上，不受影响。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-11-15 | Created as Draft | AppKitPlus 下一版起要求 macOS 14，本库下限低于它时打开 `AppKitPlus` trait 就解析失败 |
| 2026-11-15 | 按 `implement-feature` 流程直接做 | 用户同意现在就提；提案由 agent 起草，用户事前未审阅 |
| 2026-11-15 | 开始实现 | |
| 2026-11-15 | 整体提到 14，不把 AppKitPlus 钉在 0.23.x | AppKitPlus 那份提案里用户已选定：依赖它的三个包整体提到 14 |
| 2026-11-15 | 赶在 AppKitPlus 发版之前提 | 下限高于依赖不会出错；晚于它发版，开着 trait 的使用方一重新解析就编不过 |
| 2026-11-15 | 冗余的可用性判断不清理，Settings 不并进 umbrella，不发版 | 都是独立的决定，混进来会让这次改动变大；理由见「方案」的假设 |
