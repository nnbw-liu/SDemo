# 跨产品联动需求

> 状态：索引 + 需求汇总，2026-10-31
> 用途：把"两个以上产品一起才能成立"的需求集中在一处，避免散落在各产品文档里。
> 关联：[工作台规划](workbench-roadmap.md) §4–§5 · [宿主协议](contracts/host-protocol.md) · [组件契约](contracts/widget-contract.md) · [落地地图](product-map.md)

---

## 0. 术语（先固定，别各叫各的）

| 术语 | 定义 | 约定 / 不要叫 |
| --- | --- | --- |
| **引用**（reference / link） | 一个实体指向 KB 某一块的 URI：`sdemo.kb/doc/<docId>@v<seq>#<blockId>` | 必须带版本；只存 `docId` 会让历史引用漂 |
| **引用登记**（reference registration） | 外部实体（Planner 待办、Meeting 议题…）把自己对 KB 的引用写进 KB 的 `kb_link`，KB 才看得到影响面 | 不是把内容复制进 KB；不做跨库合并 |
| **待归档**（staging） | KB 中 `retention=staging` 的内容：有 TTL，确认后 promote 为 durable | 界面/文档统一叫「待归档」，**不再叫「待归档收件箱」** |
| **归档**（durable） | 用户确认保留的内容：无 TTL，参与引用保护 | 不是"移动到另一个库" |
| **影响面**（impact） | 反查所有指向某文档/块的引用，标出「来源已变更」 | 结论由 Agent 解释，KB 只给清单 |
| **引用保护**（reference protection） | 被引用指向的块不参与 GC；有引用的文档不物理清理 | 保护的是块，不是"文档标题" |
| **会议收尾聚合** | 会议结束后由 Meeting/Agent 聚合议题、决议与动作项 | 由 Agent/Meeting 做，**KB 不合并各应用数据库** |

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
| X-05 | MCP 回环端点 + token 身份 | Shell + App | [hub-protocol](contracts/hub-protocol.md) §3–§4 | ✅ 已定 |
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
| X-17 | 外部引用登记（Planner/Meeting → KB） | Planner + Meeting + KB | [KB `/v1/refs`](../Kb/AGENTS.md)；本文 §3.1 | ✅ KB + Planner 已接，Meeting 待开工 |
| X-18 | 扫描件 / 图片 OCR 回写（KB pending → Agent → revise） | KB + Agent | [KB OCR](../DesktopAgent/docs/guide/kb-ocr.md)；本文 §3.3 | ✅ PDF + PNG/JPG 已接，caption 已接 |

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

### 3.1 引用登记：影响面与引用保护的里子

只把 `sdemo.kb/doc/...` 存进 Planner 的 `link` 表，KB 是**看不到**的：`kb_refs` 只会返回 KB 文档之间的引用，
回收站清理也不会因为待办引用了某块而保护它。所以外部引用必须**登记**到 KB：

```
Planner todo  ──(link 表变化 / outbox)──►  POST /v1/refs
Meeting 议题 ──(议题引用 / outbox)──────►  POST /v1/refs
                                             │
                                    kb_link(doc_id='', from_uri=实体 URI)
                                             │
                         kb_refs / 删除影响面 / 块 GC / 文档清理保护
```

| 项 | 约定 |
| --- | --- |
| 登记 | `POST /v1/refs`：`source{appId,entityUri}` + `to`（必须带版本）+ `rel` |
| 撤销 | `POST /v1/refs/retract`：按来源实体撤销（可限定 `to` / `rel`） |
| 查询 | `GET /v1/refs?fromUri=...`：返回该实体登记过的引用；普通 App 只能看自己的 |
| 身份 | `appId` 由 token 注入，`source.appId` 只用于比对，不能自报 |
| 幂等 | `(from_uri, to_uri, rel)` 唯一；重复登记只刷新 `updated_at` |
| 清理责任 | 实体删除/链接移除时撤销登记；KB 不读 App 的库 |
| KB 侧效果 | `kb_refs` inbound、`kb_delete` 影响面、块 GC、回收站物理清理都算外部引用 |

**会议收尾聚合不做跨库合并**：Meeting 负责把议题/决议聚合成候选，Agent 负责跨应用编排；
KB 只接收最终的引用登记与内容投影，不反向读取 Meeting/Planner 的数据库。

Planner 已落地 `KbRefSyncLoop`：每 30 秒读 `link` 表，把 `sdemo.kb/doc/...@v#b` 登记/撤销到 KB；
KB 未启动时自动跳过，KB 起来后下一轮补上。Meeting 尚无 `src/`，开工时按同一契约接入。

### 3.2 token 分发

KB 首次启动（Host 或 Viewer）给白名单 App 各签一个 token，写到：

```
%LOCALAPPDATA%\SDemo\Hub\apps\sdemo.kb\tokens\<appId>.token
```

- 文件内容是 token 明文（一行）；`sdemo.kb.json` 运行期文件里的 `tokenDirectory` 指向同一目录。
- `SDemo.Kb.exe --tokens` 列出 `appId / 路径 / 明文`；`--issue-token <appId>` 主动轮换并覆盖文件。
- App 从文件读取；已有且仍有效时启动不轮换，文件丢失或 DB 轮换后下次启动重新签发。
- 安全边界：文件落 `%LOCALAPPDATA%`，写入时断开 ACL 继承并只授当前用户 FullControl（Windows；非 Windows 为 600），不进仓、不进日志。

### 3.3 扫描件 OCR 回写

KB 只做确定性解析；没有文字层的 PDF 导入后是 `derived_state=pending`，不进检索：

```
KB 导入扫描 PDF / 图片 → pending + 占位块
DesktopAgent 轮询 GET /v1/derivations
  → 读 artifacts.storedPath（本机 blob）
  → PDF 渲染 / 图片解码 + Windows.Media.Ocr（按版面拆段落/表格行）
  → POST /v1/revise（replace 占位块 + add 后续块；PDF anchor=page，图片 anchor=image）
KB 自动转 ready，进入检索
```

- Agent 不引 KB 工程，只读 `%LOCALAPPDATA%\SDemo\Hub\apps\sdemo.kb.json` 与 `tokens\sdemo.agent.token`；KB 未启动时静默跳过。
- OCR 不调模型、不需要 Key；没有系统 OCR 语言包时明确失败，不退化成空正文。
- 目前处理扫描 PDF 与 PNG/JPG；图片说明（caption）已接；视觉模型 OCR 仍未接。

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
| token 文件是明文 | 同用户下的其它进程仍可读 | 已收紧到当前用户 ACL；高安全场景可改成 DPAPI 加密 |
| Planner 的登记延迟 | 刚加的链接最多延迟 30 秒 | 已加 `LinksChanged` 事件立即触发；30 秒仅兜底 |
| Meeting 尚无 `src/` | 议题引用无法登记 | 开工时把 `mtg_topic` 的外部引用按同一契约接入 |


