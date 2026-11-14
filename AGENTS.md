# AGENTS · SDemo 主仓（多仓工作台）

> 这是**路由文件**，不是说明书。细节在各子仓的 `AGENTS.md`。
> 一次会话只读你要动的那一仓入口，不要把五个仓全读完。

## 仓结构

| 工作区 | 仓路径 | 状态 | 入口 | 门禁命令 |
| --- | --- | --- | --- | --- |
| `agent`（DesktopAgent） | `DesktopAgent/` | ✅ 已有 | `DesktopAgent/AGENTS.md` | `dotnet build SDemo.DesktopAgent.Wpf.slnf -c Release` |
| `shell`（DesktopAssembly） | `DesktopAssembly/` | ✅ P1 已实现并验收 | `DesktopAssembly/AGENTS.md` | `dotnet build SDemo.Shell.slnf -c Release` |
| `kb`（sdemo.kb） | `Kb/` | 🚧 规划 | `Kb/AGENTS.md` | `dotnet build SDemo.Kb.slnf -c Release` |
| `planner`（sdemo.planner） | `Apps/Planner/` | ✅ P2 已验收 | `Apps/Planner/AGENTS.md` | `dotnet build SDemo.Planner.slnf -c Release` |
| `meeting`（sdemo.meeting） | `Apps/Meeting/` | 🚧 规划 | `Apps/Meeting/AGENTS.md` | `dotnet build SDemo.Meeting.slnf -c Release` |

层级：**根级**=可独立部署的进程级产品（Agent / Shell / KB）· **`Apps/`**=插件式应用 · **`Shared/`**=共享类库。KB 是数据面服务（所有应用往里写），所以不在 `Apps/` 下。

`pwsh tools/ws.ps1` 列出全部；`pwsh tools/ws.ps1 agent` 看某一个（含独立 worktree 建议）。

## 铁律（改代码前先看这五条）

1. **契约改动要单独提**：`widget.json`、宿主协议、MCP 工具面、URI 规范变了，必须同时改 `docs/contracts/`、JSON Schema 与所有受影响子仓。
2. **产品之间零引用**：子仓之间不得 `ProjectReference`；Agent 不依赖任何 `App.*`；应用经 MCP 访问，不直连。
3. **应用零模型凭证**：只有 DesktopAgent 持有 Provider 与 Key。任何应用里出现 `ApiKey` / `IChatClient` 都是错的。
4. **宿主无业务数据**：`DesktopAssembly` 里不得出现 `DbContext`、SQL、业务表。
5. **删除一律软删**：`deleted_at` + 回收站，不做物理删除；MCP 写操作要落审计。

## 子模块纪律

- 代码改动在子仓里提交；主仓只改指针：`git add DesktopAgent` 后提交，message 写 `chore(submodule): bump DesktopAgent to <sha>`。
- 不要把跨产品文档复制进子仓；跨产品文档只有一个家在 `docs/`。
- 克隆用 `git clone --recursive`；已有克隆用 `git submodule update --init --recursive`。
- 子仓里跑构建/测试要在子仓目录内；主仓根没有 `.sln`。

## 常用命令

```powershell
pwsh tools/ws.ps1 list                 # 工作区清单
pwsh tools/check-doc-links.ps1         # 全仓文档死链（含子仓，按超级仓视角）
pwsh tools/contract-lint.ps1           # app.json / widget.json / 状态文件 Schema + 语义校验
dotnet build DesktopAgent/SDemo.DesktopAgent.Wpf.slnf -c Release
```

新产品的 `.slnf` 建好后，在 `workspaces/<id>.json` 与本文件表格登记。

## 不要读（会白烧 token）

| 路径 | 原因 |
| --- | --- |
| `DesktopAgent/docs/architecture/detail/` | 三份 122 KB / 97 KB / 75 KB 超大设计文档，只在改对应模块时定向读 |
| `DesktopAgent/.archify/*.html` | 74 万字节生成物；改图请改 `candidate.json` 重跑 |
| `DesktopAgent/docs/reports/`、`docs/reports/data/` | 历史验收报告与基准 JSON，按文件名定向读 |
| 子仓的 `bin/`、`obj/`、`.vs/`、`TestResults/` | 构建产物 |
| `Apps/*/docs/requirements.md`（42 KB 那份是 DesktopAssembly 基线） | 开工时通读一次，平时按需查编号 |

搜索请限定目录：`grep pattern DesktopAgent/src/App`、`grep pattern Apps/Planner/docs`。

## 文档地图（按需读）

| 想知道 | 读 |
| --- | --- |
| 五个产品要做什么、需求编号 | `docs/sdemo-brand-blueprint.md` |
| 代码/数据/文档各在哪、做到哪一步 | `docs/product-map.md` |
| 多仓与子模块规则、依赖边界、发布 | `docs/repository-layout.md` |
| 分期与工作量 | `docs/workbench-roadmap.md` |
| 跨应用联动（URI、发现、统一搜索、审批） | `docs/integration.md` |
| `widget.json` / 宿主控制协议 | `docs/contracts/` |
| 共享层怎么落 | `docs/shared.md` |
| 某个产品的开工清单 | 各子仓 `AGENTS.md` + `docs/requirements.md` |
