# workspaces：工作区登记表

> 一份 JSON 描述一个工作区（一个子仓或一个产品线）。`tools/ws.ps1` 读这里，不读别处。

## 字段

| 字段 | 必填 | 含义 |
| --- | --- | --- |
| `id` | ✅ | 工作区 id，必须与文件名一致（`agent.json` → `agent`） |
| `title` | ✅ | 展示名 |
| `status` | ✅ | `active`（已有代码）/ `planned`（只有文档） |
| `repo` | ✅ | 子仓相对主仓的路径，如 `DesktopAgent`、`Apps/Planner` |
| `entry` | ✅ | 仓内入口文档，如 `AGENTS.md` |
| `paths` | ✅ | 仓内相对路径列表（改代码要进的目录） |
| `readOnlyPaths` | | 仓内只读目录（一般留空） |
| `build` | ✅ | 仓内构建命令 |
| `test` | ✅ | 仓内测试命令 |
| `deny` | | 仓内禁读目录（大文档 / 生成物） |

## 用法

```powershell
pwsh tools/ws.ps1 list          # 全部工作区
pwsh tools/ws.ps1 agent         # 看 agent 工作区
pwsh tools/ws.ps1 agent -Json   # 机器可读
pwsh tools/ws.ps1 planner -Sparse   # 打印仓内独立 worktree 命令
```

## 约定

- **一个子仓一个工作区**：DesktopAgent 一个、DesktopAssembly 一个、三个 App 各一个。
- 共享层（[docs/shared.md](../docs/shared.md)）暂时没有独立仓，不登记；定案后再加。
- 新增工作区：先建子仓与 `AGENTS.md`，再写 `workspaces/<id>.json`，最后在主仓 `AGENTS.md` 表格登记。
- `status` 从 `planned` 改 `active` 的条件：`src/` 有真实工程、`.slnf` 能独立构建、入口文档已换成真实说明。
