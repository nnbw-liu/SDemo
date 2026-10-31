# Apps：三个桌面应用

> 状态：全部规划中（2026-10-31）
> 每个应用一个独立子仓，各自发布；它们之间**不直连**，只通过 DesktopAgent 编排。

## 三个应用

| 应用 | 子仓 | 数据 | 分期 | 需求 |
| --- | --- | --- | --- | --- |
| `sdemo.planner`（待办 + 日历） | [`Planner/`](Planner) | `%APPDATA%\SDemo\Apps\sdemo.planner\planner.db` | P2 | [PL-01–14](../docs/sdemo-brand-blueprint.md) · [requirements](Planner/docs/requirements.md) |
| `sdemo.kb`（知识库） | [`Kb/`](Kb) | `%APPDATA%\SDemo\Apps\sdemo.kb\kb.db` | P4 | [KB-01–13](../docs/sdemo-brand-blueprint.md) · [requirements](Kb/docs/requirements.md) |
| `sdemo.meeting`（会议） | [`Meeting/`](Meeting) | `%APPDATA%\SDemo\Apps\sdemo.meeting\` | P6 | [MT-01–14](../docs/sdemo-brand-blueprint.md) · [requirements](Meeting/docs/requirements.md) |

## 应用共有的五条

1. **零模型凭证**：不引入 `IChatClient` / `ApiKey`；需要模型时经 MCP 请求 DesktopAgent。
2. **零横向引用**：不引用其它 `App.*`，也不引用 Agent；跨应用只存 `sdemo.<app>/<entity>/<id>` 字符串。
3. **MCP 工具面**：每个应用至少一个 `*_mcp` 工程，工具声明风险等级（低/中/高），高风险不可关闭审批。
4. **组件 + 主窗口**：组件走 [widget 契约](../docs/contracts/widget-contract.md)，主窗口由各应用自己的 Host 进程渲染。
5. **数据目录**：`%APPDATA%\SDemo\Apps\<appId>\`；卸载不删数据；迁移用真实 EF migrations。

## 新应用的入场券（三条全满足才立项）

1. 有独立持久数据（不是别的应用数据的视图）；
2. 有独立后台生命周期（索引 / 同步 / 目录监控，需要常驻或定时跑）；
3. 有能被 AI 调用的能力面（MCP），且这个能力面别处给不了。

只满足一条的，做成现有应用的**页面或组件**，不新开仓。

## 改应用时的联动纪律

- 改 MCP 工具签名 / 组件字段 / URI 格式：先改主仓 [`docs/integration.md`](../docs/integration.md) 与 [契约](../docs/contracts/)，再改应用，最后回主仓 bump 指针。
- 应用要产"待办候选"（会议）或"文档引用"（知识库）时，**只产草稿/候选**，入库由 DesktopAgent 编排 + 用户审阅。
- 统一的审批矩阵见 [integration.md §4](../docs/integration.md)。
