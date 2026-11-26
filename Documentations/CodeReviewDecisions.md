# 已裁决的代码审查发现

代码审查（包括 agent 做完功能后的自审）里判为误报或不修的发现记在这里，每条写明结论、理由和什么时候该重审。
每次审查先对照这份清单：已裁决、理由仍然成立的直接跳过；新证据推翻了理由，就在这里改结论，重新裁决。

| 日期 | 发现 | 结论 | 理由 | 何时重审 |
|------|------|------|------|----------|
| 2026-11-15 | 示例 App 的 `NSApp.activate(ignoringOtherApps: true)`（`AppDelegate.swift`）在部署目标提到 14 之后会多一条废弃警告，而且不再强制把 App 带到前台 | 误报 | SDK 把它标成 `API_TO_BE_DEPRECATED`，任何部署目标下都不警告，示例 App 构建实测 0 条；它在 macOS 14 以上怎么激活，取决于运行的系统，与部署目标无关，提下限前后一样 | SDK 把它改成真正的 `API_DEPRECATED` 时 |
| 2026-11-15 | 下限提到 14 之后，`if #available(macOS 14.0, *)` 的 else 支路成了死代码，还调着要废弃的 `activate(ignoringOtherApps:)`（QuickActionBar、SpotlightPanel、QuickActionBar 的临时窗口） | 不修（这次） | 属于提案 `raise-deployment-target-to-macos-14` 有意不清理的恒真可用性判断：没有行为影响，编译器也不警告。清理是独立的技术债，已记为那份提案的后续项 | 做那次清理时 |
| 2026-11-15 | `MainMenu.md` 与菜单工厂里「macOS 13 之前叫 Preferences…」的退路走不到了 | 不修（这次） | 同上。指南描述的是旧系统上的行为，没有说错，随那次清理一起改 | 同上 |
| 2026-11-15 | PlaybackSlider 为 macOS 12、13 留的计时器帧路径，只剩测试开关 `animationFramesUseTimer` 走得到 | 不修（这次） | 同上。这条路径还被测试拿来替代离屏窗口里不触发的 display link，删不删要在清理时和测试一起定 | 同上 |
| 2026-11-15 | 对 AppKitPlus 的约束仍是 `from: "0.6.0"`，提下限之后 0.6.0–0.23.0 还解析得到 | 误报 | 提下限不要求收窄版本范围：本库的下限 14 高于这些版本要求的 12，照常能用。swiftlang/swift#94329 只在使用方部署目标低于 13.3 时出现，AppKitPlus 那边实测：部署目标 15.0 的使用方用 0.23.0 全部正常。0.6.0 这个下限的理由见 [`AppKitPlus.md`](AppKitPlus.md#61-why-the-floor-is-0240) 第 6.1 节。**2026-11-26 补注**：就这条发现而言结论不变（部署目标 14 不要求收窄范围），但下限已因另一个原因提到 0.24.0——0.24.0 给 `NSLayerBackedView` 加了外观成员，`LayerBackedView` 在 trait 下要用它们（提案 `appkitplus-owns-layer-backed-view-appearance`），0.6.0–0.23.0 从此不在范围内 | 要提 AppKitPlus 的版本下限时 |
