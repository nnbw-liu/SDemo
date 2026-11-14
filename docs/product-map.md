# 五个产品的落地地图

> 状态：索引文档，2026-10-31（多仓化之后更新）
> 用途：回答"这个产品的代码在哪、数据存哪、文档在哪、什么时候做"。
> 关联：[品牌蓝图与需求](sdemo-brand-blueprint.md) · [多仓布局](repository-layout.md) · [工作台规划](workbench-roadmap.md) · [跨产品联动](integration.md)

---

## 1. 一屏总表

| 产品 | 代码位置 | 数据位置 | 设计文档 | 需求编号 | 分期 |
| --- | --- | --- | --- | --- | --- |
| **DesktopAgent**（已有） | 子仓 [`DesktopAgent/`](../DesktopAgent) | `%APPDATA%\SDemo\DesktopAgent\` | [guide/projects](../DesktopAgent/docs/guide/projects.md) | — | 已交付 |
| **DesktopAssembly** | 子仓 [`DesktopAssembly/`](../DesktopAssembly) | `%APPDATA%\SDemo\DesktopAssembly\`（仅 `apps\` `widgets.json` `settings.json`，**无业务数据**） | [desktop-shell](../DesktopAssembly/docs/desktop-shell.md) · [requirements](../DesktopAssembly/docs/requirements.md) · [widget-contract](contracts/widget-contract.md) · [host-protocol](contracts/host-protocol.md) | DA-01–11、DA-90–92 | P1 |
| **sdemo.planner** | 子仓 [`Apps/Planner/`](../Apps/Planner) | `%APPDATA%\SDemo\Apps\sdemo.planner\`（`planner.db` + `exports\`） | [planner-design](../Apps/Planner/docs/planner-design.md) · [p2-verification](../Apps/Planner/docs/p2-verification.md) · [planner-mcp-surface](../Apps/Planner/docs/planner-mcp-surface.md) | PL-01–14 | P2 已验收 |
| **sdemo.kb**（数据面服务） | 子仓 [`Kb/`](../Kb)（**不在 `Apps/` 下**） | `%APPDATA%\SDemo\Apps\sdemo.kb\`（`kb.db` + `blobs\`） | [kb-design](../Kb/docs/kb-design.md) · [kb-ui](../Kb/docs/kb-ui.md) · [kb-versioning](../Kb/docs/kb-versioning.md) · [requirements](../Kb/docs/requirements.md) | KB-01–13 | P4 |
| **sdemo.meeting** | 子仓 [`Apps/Meeting/`](../Apps/Meeting) | `%APPDATA%\SDemo\Apps\sdemo.meeting\`（`meeting.db` + `meetings\{id}\audio\`） | [meeting-design](../Apps/Meeting/docs/meeting-design.md) · [requirements](../Apps/Meeting/docs/requirements.md) | MT-01–14 | P6 |
| **共享层**（非产品） | 还没有独立仓；方案见 [shared.md](shared.md) | 无 | [repository-layout](repository-layout.md) §7 | — | M1 |

进程级数据（端口 / token / 锁）一律在 `%LOCALAPPDATA%\SDemo\DesktopAssembly\runtime\`，不放漫游目录。

## 2. 数据与进程分布

```
%APPDATA%\SDemo\
├─ DesktopAgent\                 ← 已有：settings.json / chats\ / skills\ / plugins\
├─ DesktopAssembly\              ← 外壳（P1）
│  ├─ apps\<appId>\              ← 安装目录：app.json + widget.json + payload\
│  ├─ widgets.json               ← 组件布局（位置/层级/显隐）
│  └─ settings.json
└─ Apps\
   ├─ sdemo.planner\planner.db   ← todo + event（P2）
   ├─ sdemo.kb\kb.db + blobs\    ← 版本链 + 块 + 索引 + 原件（P4）
   └─ sdemo.meeting\             ← meeting.db + meetings\{id}\audio\（P6）

> 注意：`%APPDATA%\SDemo\Apps\` 是**运行时数据**约定（按 `appId` 分目录，所有产品一致），
> 与仓库层级无关。KB 的代码仓在根级 `Kb/`，数据仍落 `Apps\sdemo.kb\`。

%LOCALAPPDATA%\SDemo\
├─ DesktopAssembly\runtime\      ← runtime.json（pid/端口/token），不可漫游
└─ logs\
```

**安装与数据分离**：程序在 `apps\`，数据在 `Apps\`；卸载不删数据，升级不动库。

## 3. 各产品：已定 / 未定 / 缺口

### DesktopAssembly（P1）

- **已定**：常驻托盘、按需拉起、单实例、空闲退出、崩溃退避重启；`widget.json` 字段与两种 renderer；宿主只做 6 个 Win32 窗口操作（native 组件禁止 `SetParent`；wasm 窗口是宿主自己的，桌面层才允许）；位置按 DIP + 显示器标识记忆；组件上限默认 8（可配置）、壳自启默认开；`idleHold`、`startup` 策略、壳单实例、空态安装入口、Win10 19041+/Win11 x64、面板只做组件管理 + 设置 + 诊断（Q1/Q3）；**P2 已补 wasm / 桌面层（Win11 回落 z-order 底部）**。
- **已补**：回环端点与 token 身份（[host-endpoints](../DesktopAssembly/docs/host-endpoints.md)）、壳状态文件 Schema（[shell-storage](../DesktopAssembly/docs/shell-storage.md)）、MCP 发现注册表与 `ensure`（需求 DA-90–92）。
- **已实现（2026-11-01）**：四工程 + `SDemo.Shell.slnf`、宿主 MVP（托盘 / 扫描 / 拉起 / 单实例 / 空闲退出 / 崩溃退避 / 定位 / 多屏 / 持久化 / 回环端点）与 native Hello Widget 样例；P2 补 wasm 渲染器（共享 WebView2 环境）、config 表单、主题/权限/热键/托盘入口/完整诊断/截屏隐藏/`tools/pack.ps1`。实现取舍与契约缺口见 [implementation-notes](../DesktopAssembly/docs/implementation-notes.md)，验收清单见 [s1-verification](../DesktopAssembly/docs/s1-verification.md) 与 [s2-verification](../DesktopAssembly/docs/s2-verification.md)。
- **已验收**：窗口管控实现细节已落到代码（`GetWindowRect` 轮询回写、多屏迁移算法）；**Win+D 实测结论 A**（native 组件不会被 Win+D 收起，2026-11-01；状态机兜底保留）；wasm 首屏 / 桌面层 / 热键见 S2。

### sdemo.planner（P2）

- **已实现（2026-11-01）**：五工程 + `SDemo.Planner.slnf`；`todo`/`event` 同库不同表、真实 EF migrations + FTS5；主窗口待办 CRUD、日/周/月日历与拖拽改期、回收站、草稿审阅、ICS 导出；13 个 `todo_*` MCP 工具 + 风险元数据 + 审计；桌面组件 ≤8 条。设计见 [planner-design](../Apps/Planner/docs/planner-design.md)，验证见 [p2-verification](../Apps/Planner/docs/p2-verification.md)。
- **宿主联调（2026-11-01）**：装到 `%APPDATA%\SDemo\DesktopAssembly\apps` 后被宿主发现，sha256 通过、ensure 拉起、runtime + MCP 13 工具可用、组件由宿主显示、主窗口按需打开；`tools/accept-host.ps1` 可复跑。过程中修掉安装目录误用 LOCALAPPDATA 与组件 command 路由段数错误。
- **验收（2026-11-01）**：宿主联调、组件 UIA、日历真实拖拽、ICS 导出→Outlook 真实导入全部通过；待办默认导出 `VEVENT`（Outlook 忽略 `VTODO`），`VTODO` 保留为可选任务模式。P2 已验收。
- **已定**：软删 + 7 天回收站；高风险（删除/批量≥5/清空）不可关闭审批；ICS v1 只导出、不导出 RRULE；来源由 MCP 服务端注入。
- **未做**：PL-06 只读订阅、PL-08 提醒、`calendar_*` 工具（P3/P5）；清单/标签管理 UI、事件跨天显示留后续迭代。

### sdemo.kb（P4）

- **已定**：文档实体 + 不可变版本链（DAG）+ 块级内容寻址；块级与词级 diff；变更理由 `rationale` 三入口；三个索引面（当前态 / 历史态 / 变更事实）+ 查询路由；**不向量化差异**；引用存 `docId@version#block` 以支持影响面反查；零模型凭证。
- **未定**：文档的 `kind` 分类（note / reference / requirement / decision）默认行为；导入源优先级（md / docx / pdf 谁先）。
- **缺口**：MCP 工具面仍是草案（§10），需要随 P4 细化。

### sdemo.meeting（P6）

- **已定**：会议不隶属任何项目，用 `mtg_topic` 拆分议题、各自挂 URI；录音与转写全本地（whisper）；**候选 ≠ 待办**，转待办经 DesktopAgent 中转；分析存档带 `model` + `prompt_version` 可重跑；说话人 v1 手动标注 + `IDiarizationProvider` 预留自动；录音存应用数据目录但可导出。
- **未定**：云端 ASR 作为用户显式例外是否要提供；会议类型枚举是否够用。
- **缺口**：ASR 运行时（whisper 模型分发与校验）没有落地文档；`meeting_*` 工具面仍是草案（§8）。

## 4. 还缺哪几份设计文档

| 待写 | 服务于 | 什么时候需要 | 建议落位 |
| --- | --- | --- | --- |
| `planner-design.md`（event / 日历视图 / ICS / RRULE / 组件布局） | P2 | P2 开工前 | `Apps/Planner/docs/` |
| `calendar_*` 扩进 `planner-mcp-surface.md` | P2 / P3 | P2 中后期 | `Apps/Planner/docs/` |
| `shared-foundation.md`（UUIDv7 / HLC / outbox / FTS 助手 / MCP 信封） | M1 | 定共享层方案时 | `docs/`（见 [shared.md](shared.md)） |
| `sync-design.md`（op-log 格式、合并规则、冲突呈现） | P5 | P5 开工前 | `Apps/Planner/docs/` |
| `asr-runtime.md`（whisper 模型分发、校验、耗时档位） | P6 | P6 开工前 | `Apps/Meeting/docs/` |

已写齐、可直接用的：`desktop-shell` / `widget-contract` / `host-protocol` / `kb-versioning` / `meeting-design` / `repository-layout` / `agent-workspace` / `sdemo-brand-blueprint` / `workbench-roadmap`。

## 5. 分期与依赖

```
M0 基建（已做）──► M1 共享层 ──┬──► P1 Shell ──► P2 Planner ──► P3 Agent 接 MCP
                               │                                   │
                               └───────────────────────────────────┴──► P4 KB ──► P5 同步 ──► P6 Meeting
```

- **P1** 是唯一有技术不确定性的（窗口管控 + Win+D），先做它，失败就得改口径。
- **P3** 是横切的一步：DesktopAgent 学会连 MCP server、按风险审批、解析跨应用引用。它做完之后，P4/P6 的产品才真正"可用"。
- **P5** 可以在 P4 之后任意时点插入；schema 已经预留 `revision` / 墓碑 / outbox。
- 多仓之后每个期次对应一个子仓的主线，跨仓联动需求见 [integration.md](integration.md)。

## 6. 想知道什么去哪找

| 问题 | 去哪 |
| --- | --- |
| 这个产品到底要做哪些功能 | [sdemo-brand-blueprint](sdemo-brand-blueprint.md)（DA / PL / KB / MT 编号） |
| 什么时候做、多少工作量 | [workbench-roadmap](workbench-roadmap.md) §6 |
| 代码放哪个仓、几个工程 | [repository-layout](repository-layout.md) §3–§5 |
| 现在有没有开始建 | `pwsh tools/ws.ps1 list` 与 `workspaces/<id>.json` 的 `status` |
| 数据写在哪、能不能备份 | 本文 §2 |
| 组件清单长什么样、宿主怎么拉起 | [contracts/widget-contract](contracts/widget-contract.md) / [contracts/host-protocol](contracts/host-protocol.md) |
| 某个应用的工具有哪些、谁要审批 | 各产品设计文档 + [integration](integration.md) §4 |
