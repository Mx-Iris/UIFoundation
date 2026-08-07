# Evolution 提案索引

- **项目类型**: 库（源码分发）

SPM library product，使用方以源码依赖并重新编译，未开启 library evolution，
也不以 `binaryTarget` 分发。

**「ABI 兼容性」一节填「不适用 —— 本库以 SPM 源码分发，使用方每次重新编译」即可；
「源码兼容性」一节必填。**

本库有一条特有的注意事项：**它是多个项目的公共底座，「下游影响」一节必须逐个点名**。
已知下游包括 RuntimeViewer（`TabsControl`）、MachOKitUI（`TextFinder`）、
PrivateSymbols（全面改用本库基类）。改动一个组件的行为，等于同时改动这些项目的行为。

另外，本库既有组件的对外契约写在使用指南里（见[上级索引](../README.md)）。
提案若改动了这些契约，**必须在同一批次更新对应指南** —— 契约变了而指南没变，
比没有指南更糟。

提案格式与流程见全局 `CLAUDE.md` 的「Evolution 提案制」一节，用 `/evolution <描述>` 创建。

## 提案

尚无提案。今后的新功能与架构改动一律从这里开始，编号自 `0001` 起。
