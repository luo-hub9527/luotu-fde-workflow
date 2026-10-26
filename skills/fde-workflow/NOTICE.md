# 来源与许可声明

本 skill 的部分方法根据 [FDEOps](https://github.com/suboss87/FDEOps) 改写为中文轻量工作流。

- 上游版本：[`30e3f6c92dadbc013337e7ebdae14087d43bd126`](https://github.com/suboss87/FDEOps/tree/30e3f6c92dadbc013337e7ebdae14087d43bd126)。
- 上游版权：Copyright (c) 2026 Subash Natarajan。
- 上游许可：[完整 MIT 许可证](licenses/FDEOps-MIT.txt)，随本目录保留。
- 原文件路径、Git blob 及下载内容 SHA-256 记录于 [upstream-lock.json](upstream-lock.json)。SHA-256 是原始上游文件校验值，不是改写文件的校验值。

## 改写范围

| 本地内容 | 主要参考的上游文件 |
| --- | --- |
| `SKILL.md`、`references/context.md` | `skills/fde/SKILL.md`、`references/task-context.md` |
| `references/discovery-demo.md` | `references/land.md`、`references/poc.md` |
| `references/feasibility.md` | `references/poc.md`、`references/business-case.md`、`references/three-options.md` |
| `references/commercial.md` | `references/business-case.md`、`references/hold-scope.md` |
| `references/build-deliver.md`、交接中的证据规则 | `references/build.md`、`references/ship.md` |

表中简写的 `references/` 均位于上游 `skills/fde/` 下。保留了按需选择方法、复用客户约定、依据实际证据推进，以及区分实现／验证／部署／客户接受的做法。

本版改为独立项目文件记录，不包含上游 CLI、掩码系统或完整任务库；既有 FDEOps 客户记录仍受其隐私接口协议约束。增加了全周期商业判断、利润和现金流、前置整改、早期演示、新手指导及服务责任，删除了固定页面数和固定选项数等不适合普遍约束的表达。

空白模板及仓库合成案例按本项目设计编写，未复制客户项目材料。其他定价仓库在设计讨论中作为研究线索，首版没有复制其文件，也没有继承其默认费率或比例。

## 本项目新增内容

新增原创内容由 luo-hub9527 按 [MIT 许可证](LICENSE) 发布。上游 MIT 内容继续适用其原许可和版权声明；本项目的许可不删除或替代上游声明。单独复制 skill 目录时，请同时保留本目录中的 LICENSE、NOTICE.md 及 licenses/FDEOps-MIT.txt。
