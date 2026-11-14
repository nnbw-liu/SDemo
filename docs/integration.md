# 跨产品联动需求

> 状态：索引 + 需求汇总，2026-10-31
> 用途：把"两个以上产品一起才能成立"的需求集中在一处，避免散落在各产品文档里。
> 关联：[工作台规划](workbench-roadmap.md) §4–§5 · [宿主协议](contracts/host-protocol.md) · [组件契约](contracts/widget-contract.md) · [落地地图](product-map.md)

---

## 1. 联动全景

```
用户 ──► DesktopAgent（唯一有模型）
            │  MCP（回环 + token）
            ├──► sdemo.planner   待办 / 日历
            ├──► sdemo.kb        文档 / 检索 / 引用
            └──► sdemo.meeting   录音 / 转写 / 决议 / 候选
            ▲
            │ 发现注册表（DA-90–92）、组件点击、深链
DesktopAssembly（宿主：拉起进程、摆放组件、窗口管控，不存业务数据）
```

四个方向的联动：

| 方向 | 机制 | 约束 |
| --- | --- | --- |
| Agent → App | MCP server（`http://127.0.0.1:{port}/mcp`） | 回环 + 进程级 token；高风险写操作必须审批 |
| App → Agent | 不做反向调用；应用只产草稿/候选 | 候选 ≠ 入库，必须由 Agent 或用户确认 |
| App ↔ App | **禁止**；只存 URI 字符串 | `sdemo.<app>/<entity>/<id>`；解析责任在 Agent |
| Host ↔ App | 组件契约 + 控制协议 | 宿主只做窗口/进程，无业务数据 |

## 2. 跨产品需求清单

| # | 需求 | 归属 | 细节 | 状态 |
| --- | --- | --- | --- | --- |
| X-01 | 应用 URI 规范 `sdemo.<app>/<entity>/<id>` | 全部 | 品牌蓝图 §3 | ✅ 已定 |
| X-02 | 应用注册与清单校验（`app.json`/`widget.json`/sha256） | Shell + 全部 App | [widget-contract](contracts/widget-contract.md) | ✅ 已定 |
| X-03 | 宿主按需拉起 + 单实例 + 空闲退出 + 崩溃退避 | Shell | [host-protocol](contracts/host-protocol.md) | ✅ 已定 |
| X-04 | 组件窗口管控（位置/层级/显隐/穿透） | Shell | 同上 §窗口 | ✅ 已定（Win+D 待实测） |
| X-05 | MCP 回环端点 + token 身份 | Shell + App | [host-endpoints](../DesktopAssembly/docs/host-endpoints.md) | ✅ 已定 |
| X-06 | MCP 发现注册表与 `ensure`（Agent 冷启动也能找到应用） | Shell + Agent | DA-90–92 | ✅ 需求已立 |
| X-07 | Agent 侧 MCP client、工具预算、审批映射、断线降级 | Agent | [agent-mcp-client](../DesktopAgent/docs/architecture/agent-mcp-client.md) | ✅ v1 已实现（网关式） |
| X-08 | 统一搜索 fan-out（一次意图并发查多个应用） | Agent | [workbench-roadmap](workbench-roadmap.md) §4.2 | ✅ 已定 |
| X-09 | 跨应用引用解析与跳转（含 `docId@version#block`） | Agent + KB | [kb-versioning](../Kb/docs/kb-versioning.md) §引用 | ✅ 已定 |
| X-10 | 会议候选 → planner 待办的审阅中转 | Agent + Meeting + Planner | [meeting-design](../Apps/Meeting/docs/meeting-design.md) §7 | ✅ 已定 |
| X-11 | 风险分级与审批不可关闭项（删除/批量≥5/清空） | 全部 App | [planner-mcp-surface](../Apps/Planner/docs/planner-mcp-surface.md) §6 | ✅ 已定 |
| X-12 | 工具面膨胀控制（同池竞争 + 应用开关 + toolHints） | Agent | [workbench-roadmap](workbench-roadmap.md) §5 | ✅ 已定 |
| X-13 | 组件设置表单 Schema 子集渲染（boolean/integer/string-enum） | Shell + App | [widget-contract](contracts/widget-contract.md) §settings | ✅ 已定 |
| X-14 | 应用零模型凭证（出现 `ApiKey`/`IChatClient` 即错） | 全部 App | 铁律 | ✅ 铁律 |
| X-15 | 宿主零业务数据（不得出现 `DbContext`/SQL） | Shell | 铁律 | ✅ 铁律 |
| X-16 | 软删除 + 回收站 + 审计落库 | 全部 App | 铁律 | ✅ 铁律 |

## 3. 一次跨应用动作的流程（以"把会议候选转成待办"为例）

```
1. Meeting 产出 mtg_action(candidate)          ← 不建待办
2. 用户在 Meeting 里选中候选，点"转待办"
3. Agent 收到意图 → 调 planner 的 todo_create_draft（低风险）
4. Planner 返回草稿（不入库）
5. 用户审阅 → Agent 调 todo_accept_draft（中风险）
6. Planner 入库并写 provenance（source + 会话 + 原文片段）
7. Agent 回复并给引用 chip → 点击跳回会议原文
```

每一步的失败都要可降级：应用未启动（`ensure` 拉起）、端口/ token 失效（重新握手）、断线（Agent 提示而非静默失败）。

## 4. 审批矩阵（跨应用统一）

| 风险 | 操作示例 | 审批 |
| --- | --- | --- |
| 低 | 新建草稿、查询、搜索、读片段 | 不审批 |
| 中 | 采纳草稿、改期、勾完成、写引用 | 一次确认（可记住会话内） |
| 高 | 删除、批量 ≥5、清空、覆盖版本 | **不可关闭**，每次确认 + 审计 |

各应用在自己的 MCP 工具面里声明风险等级，Agent 只按等级执行，不硬编码具体工具名。

## 5. 契约改动流程（跨仓）

1. 主仓改 `docs/contracts/*.md` + JSON Schema。
2. 列出受影响子仓与字段。
3. 子仓分别改解析/生成代码并提交。
4. 主仓 bump 各子仓指针，写一条 pin 记录。
5. 全部子仓推上去之后，别人的 `submodule update` 才能拿到一致的一套。

## 6. 已知的联动缺口

| 缺口 | 影响 | 下一步 |
| --- | --- | --- |
| 发现注册表只有需求、没有 schema | Shell 与 Agent 各自理解 | P1 先出 `discovery.json` schema |
| 没有跨应用集成测试 | 契约快照只覆盖单应用 | P3 加一条端到端：起 3 个 fake server + Agent 调通 |
| 统一搜索的排序规则 | fan-out 结果可能乱序 | 先按时间 + 相关度，规则写进 Agent 文档 |
