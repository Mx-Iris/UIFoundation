# Draft - PlaybackSlider：Music 全屏播放器的时间进度条

- **状态**: Accepted
- **创建日期**: 2026-10-28
- **最后更新**: 2026-10-28
- **实现分支**: `feature/playback-slider`

## 摘要

在 `UIFoundationAppKit` 新增 `PlaybackSlider`，用 Swift 移植 AppKitPlus 0.19.0 的 `NSPlaybackSlider`。它复刻的是
Music 26.6 全屏播放器的时间进度条：

- 静止时是一条 7 pt 高、没有滑块的胶囊；
- 按下时，进度立刻跳到指针处，胶囊用弹簧长到 16 pt；
- 松手后缩回。

起因是 LyricsX 的歌词面板。它原本为了这个进度条接入了 AppKitPlus，评估之后决定不为一个控件集成 AppKitPlus，原因有三：

- 它是约 13 MB 的预编译二进制，app 一启动就加载；
- 它静态编进了 LGPL-2.1 授权的组件；
- 发版 CI 用的 Xcode 26.4 能不能编过它，还没有验证。

所以把这个控件搬到这里，LyricsX 改用它。控件本身不挂 trait。Music 那种颜色靠的 plus-lighter 混合是私有 API，只在
`AppleInternal` trait 下启用。

## 方案

**公开接口照搬 `NSPlaybackSlider`，去掉 NS 前缀：**

- `PlaybackSlider: NSSlider`。`cellClass` 是 `PlaybackSliderCell`；`scrubbingDelegate: PlaybackSliderDelegate?` 是弱引用，
  不设时为 `nil`。
- `PlaybackSliderCell: NSSliderCell`，负责画进度条和跟踪鼠标。
- `PlaybackSliderDelegate`（主线程），两个方法：`playbackSliderDidBeginScrubbing(_:)` 和
  `playbackSliderDidEndScrubbing(_:)`，协议扩展里给空的默认实现，所以两个都是可选的。

**行为契约全部沿用** `NSPlaybackSlider.h` 写明的那些。下面这些数值都是 AppKitPlus 从 MediaCoreUI 逆向得来，照搬，不调参：

- 尺寸：行高 16 pt，静止时胶囊 7 pt，没有内在宽度。
- 颜色：已播放部分是 45% 不透明的白色，按下时变成纯白；剩余部分是 18% 的白色。
- 按下：值立刻跳到指针所在位置。已播放部分用临界阻尼弹簧（response 0.15）滑过去；胶囊用质量 1、刚度 350、阻尼 40
  的弹簧长到 16 pt，松手后按同一个弹簧缩回。
- 拖动：离按下的位置 3 pt 以上，值才跟着指针走。
- 回调：按下、拖动的每一步、松手之后，各发一次 action（滑块是 continuous）；委托在按下和松手时各收到一次通知。
- 键盘与辅助功能：方向键和 VoiceOver 照普通滑块的规矩改值，不通知委托。
- 布局方向：任何语言下都从左到右。
- 其他：高对比度下改用 `systemGray` 和 `labelColor`；禁用时整条以 25% 不透明度绘制；焦点环沿着胶囊画；不响应滚轮。
- 胶囊形状：照 Music 的连续曲率胶囊（SwiftUI 的 `Capsule(style: .continuous)`）。

**动画**：弹簧用解析解按时间计算位置，晚到的一帧也画在正确的地方。macOS 14 及以上由 `NSView.displayLink(target:selector:)`
驱动，更早的系统用每秒 60 次的计时器；弹簧停稳、或控件离开窗口时就停。时钟可以注入，只供测试使用（internal）。

**私有 API**：plus-lighter 用的是 Core Animation 的 `plusL` 合成滤镜，放在 `#if AppleInternal` 下，写法和 TabBar 的 trait
开关相同。不开这个 trait 时用普通混合，在深色背景上比 Music 的稍暗。公开的 Core Image 叠加滤镜效果亮得多，代替不了。
高对比度下，开不开 trait 都用普通混合。

**不支持从 nib 解码**：本库的视图都在代码里创建，`init(coder:)` 标为不可用。

**测试**：从 AppKitPlus 的 `NSPlaybackSliderTests`（Objective-C，1012 行）里，把验证行为契约的用例移植成 Swift Testing，
放在 `Tests/UIFoundationTests/PlaybackSlider/`。先写测试，确认它会失败，再写实现。

**文档与随附项**，同一批提交：

- 新增指南 `Documentations/PlaybackSlider.md`：行为契约、移植来源和逆向地址、trait 下的私有混合、测试上的陷阱。登记进
  `Documentations/README.md`，并在 CLAUDE.md 的「Components」一节加一行。
- 在 `uifoundation-widgets` skill 里加上这个控件，两个 `plugin.json` 的 `version` 各加一。
- 在示例 app 的 demo browser 里加一个 `PlaybackSliderDemo`：深色背景上一条进度条，下面是两个时间标签。

**发版**：合进 `main` 后打 `0.42.0`；如果有别的功能先发版，版本号顺延。LyricsX 随后升级到这个版本。

### 落地步骤

1. [ ] 测试先行：把 `NSPlaybackSliderTests` 里验证行为契约的用例移植成 Swift Testing，对着只有接口、没有行为的空壳跑，
   确认会失败。
2. [ ] 实现 `PlaybackSlider`、`PlaybackSliderCell`、`PlaybackSliderDelegate`，第 1 步的测试全部通过；不开 trait、开
   `AppleInternal`、开全部 trait 三种构建都要通过。
3. [ ] 在示例 app 里加 `PlaybackSliderDemo`，示例 app 能构建。
4. [ ] 文档与随附项：指南、`Documentations/README.md`、CLAUDE.md 的组件一行、`uifoundation-widgets` skill 和两个
   `plugin.json` 的版本号。

## 下游影响

纯新增，不改 `Package.swift`，也不新增 trait：

- RuntimeViewer、MachOKitUI、PrivateSymbols、XCOrganizer、StarLight 都不使用这个控件，没有影响。
- LyricsX 会用它替换 AppKitPlus 的 `NSPlaybackSlider`，并打开 `AppleInternal` trait。这一步记在 LyricsX 自己的提案里。

## 决策日志

| 日期 | 决定 | 理由 |
|------|------|------|
| 2026-10-28 | Created as Draft | LyricsX 看过接入 AppKitPlus 的影响评估后，决定不再集成它，把歌词面板的进度条搬到 UIFoundation 用 Swift 实现 |
| 2026-10-28 | 接口照搬 `NSPlaybackSlider`，去掉 NS 前缀 | 用户选定。LyricsX 只需要改名字；这套行为契约已经在 AppKitPlus 里实现并测过 |
| 2026-10-28 | plus-lighter 混合只在 `AppleInternal` trait 下启用 | 用户选定。本库规定 `CAFilter` 这类私有 API 只能放在这个 trait 下 |
| 2026-10-28 | 用户批准，开始实现 | 补上了四个落地步骤，每一步都能单独构建、验证 |
