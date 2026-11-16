# 进度快照 · 2026-11-16 · 会议（sdemo.meeting）

> 这是一份**按日期留档的快照**，不是维护中的文档；长期事实以 [product-map.md](product-map.md) 与各子仓 `AGENTS.md` 为准。
> 范围：会议从「数据管线」做到「能被 Agent 分析、能归档进 KB」的完整一轮。

---

## 1. 一句话

**会议现在是一条能自己跑完的链**：录/导入 → 转写 → 出议题/决议/候选 →（Agent 分析）→ 归档进知识库。
唯一的缺口是**真机录音**——本机 Windows 麦克风权限被拒（`0x80070005`），代码就绪但没跑过真声音。

---

## 2. 本轮完成的能力

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| 阶段 A | 录 / 导入 / 转写 / 列表 / 详情（whisper large-v3-turbo，Whisper.net） | ✅ |
| 阶段 B | VAD 分段（窗口打包）、增量落库、取消/续转、模型库（打包+导入+校验）、低配档自动回落、hotwords、质检告警、结果页 | ✅ 7/7 |
| 领域模型 | `mtg_topic` / `mtg_decision` / `mtg_action`（schema v2 → v5 就地迁移） | ✅ |
| MCP 读面 | 8 个只读工具（列表 / 详情 / 转写 / runs / 议题 / 决议 / 候选 / 分析状态） | ✅ |
| MCP 写面 | 9 个写工具（议题增改、确认决议、加候选、改候选态、分析队列 request/claim/finish），全部 medium + 审计 | ✅ |
| P0 主程序 | 单进程 `SDemo.Meeting.exe`：WPF 外壳 + BlazorWebView + 进程内 MCP；双模入口；单实例；`deploy/app.json` | ✅ |
| P1 录音 UI | 录音卡（计时 / 双轨 / 停止自动转写 / 进度 / 取消）+ 状态机可测 | 🟡 真机录音待权限；桌面小组件推迟 |
| P2 议题编辑 | 三栏 + 右栏检视（议题增删、确认决议、候选拒绝、最近改动）；段落「标为决议/候选」带 anchor | 🟡 改名 / refs 编辑 / plannerRef 回填未做 |
| P3 KB 投影 | 一次 `ingest` 直接 durable（含转写）、内容哈希幂等、离线记失败并补投 | ✅ 与真实 sdemo.kb 联调 |
| P4 分析链路 | Meeting 排队 + DesktopAgent 后台 map-reduce（claim → 分页取段 → 逐页抽 → 写回 → finish） | ✅ 两端实机跑通 |

---

## 3. 验证证据

| 项 | 结果 |
| --- | --- |
| Meeting 测试 | **129 通过 / 1 跳过** |
| DesktopAgent 测试 | **990 通过**（新增 6 个会议分析用例） |
| 构建 | `SDemo.Meeting.slnf`、`SDemo.DesktopAgent.Wpf.slnf`、`SDemo.Kb.slnf` 均 0 警告 0 错误 |
| 文档死链 | 152 篇，无死链 |
| 转写实测 | 27 秒中文，whisper turbo RTF 0.65；Qwen3-ASR-0.6B（llama.cpp）RTF 0.20 |
| KB 联调 | `/v1/docs` 可见文档：`retention=durable`、16 块、`ownerApp=sdemo.meeting` |
| Agent 分析实机 | 9 段 → **3 议题 / 3 候选**，job `done`，`provider=ds`，9/9 段 |
| 录音失败路径 | 实机点「开始录音」→ 提示去「设置 → 隐私和安全性 → 麦克风」，不留幽灵会议 |

---

## 4. 本轮踩到并修掉的问题

| 现象 | 根因 | 处理 |
| --- | --- | --- |
| 窗口能起但内容全黑 | 组件注入的 `TranscriptEditor` 漏注册，渲染器抛异常后停住 | 补注册；GUI 无控制台，加 `meeting.log`（导航/页面探查） |
| 加右栏后整页空白、日志无异常 | `DomainPanel` 在 `OnParametersSet` 里回调父组件 → 参数设置期重入渲染，渲染器静默卡死 | 父组件回调只在用户点击时发；根组件套 `ErrorBoundary` |
| 归档报 `403 kb_forbidden` | KB 的 `promote` 只允许 `sdemo.kb` / `sdemo.agent` | 归档改为**一次 ingest 带 durable**，不再有第二步 |
| 判不出 KB 在不在 | `sdemo.kb.json` 没有 `baseUrl/state`，只有 `ingestUrl/healthUrl` | 从 URL 取 origin；重复 ingest 只返回旧文档、不改 retention |
| Agent 说"队列空"却真有作业 | `meeting_claim_analysis` 有作业时**直接返回作业对象**，没作业才返回 `{job:null}` | 两种形状都认；并给 Agent 侧加作业日志 |
| 作业永远卡在 Running | Agent 崩了没人收 | Meeting 启动时把残留 Running 标 failed（`MarkRunningAnalysisInterrupted`） |

---

## 5. 提交

| 仓 | 提交 |
| --- | --- |
| `Apps/Meeting` | `a1ac4bc`（P4 收尾文档）· 本轮系列从 `2ad37c0` 起 |
| `DesktopAgent` | `a6add8f` 会议分析驱动 |
| `SDemo`（主仓） | `f647cd3`（子模块指针） |

---

## 6. 卡点与遗留

| 遗留 | 说明 |
| --- | --- |
| **真机录音** | 本机麦克风隐私被拒；需在系统设置放开后人工跑一次「录音 → 停止并转写」 |
| P1-4 桌面录音小组件 | 要单开一个置顶小窗，推迟 |
| P2 剩余 | 议题改名、refs 编辑、候选「已安排」的 plannerRef 回填界面 |
| P3 剩余 | 列表行 KB 徽章；`/v1/refs` 引用登记；KB 侧 `kb_block.origin`（跳回会议原文）待提契约 |
| 候选转待办闭环 | Agent 拿 `meeting_actions` 的 candidate 去 Planner 建待办再回写 `plannerRef`，尚未做 |
| KB dev 进程 | 联调用的是 `--data-dir %TEMP%\kb-p3 --port 18110`，退出后 `sdemo.kb.json` 仍在但已失效 |

---

## 7. 接下来按什么顺序做

1. **放开麦克风权限**，跑通「录 → 转 → 分析 → 归档」完整一条龙（成本最低、验证最全）。
2. **候选转待办闭环**：Meeting `candidate` → Planner 建待办 → 回写 `plannerRef` → `intaken`。这一步做完，「会议 → 决议 → 待办」才真正闭环。
3. **P2/P3 收尾小项**（改名、refs 编辑、列表徽章、`/v1/refs` 登记）。
