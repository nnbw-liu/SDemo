# SDemo

> 一张自己的桌面，上面住着一个会做事的助理。
> 本仓是**主仓（superproject）**：放跨产品文档、工作区登记与子模块指针；每个产品是独立子仓。

## 产品与仓库

| 产品 | 子仓 | 状态 | 入口 | 独立构建 |
| --- | --- | --- | --- | --- |
| **DesktopAgent**（智能体客户端） | `DesktopAgent/` · [SDemo.DesktopAgent](https://github.com/nnbw-liu/SDemo.DesktopAgent) | ✅ 已有 | [AGENTS](DesktopAgent/AGENTS.md) | `dotnet build SDemo.DesktopAgent.Wpf.slnf -c Release` |
| **DesktopAssembly**（常驻桌面外壳） | `DesktopAssembly/` · [SDemo.DesktopAssembly](https://github.com/nnbw-liu/SDemo.DesktopAssembly) | 🚧 规划（P1） | [AGENTS](DesktopAssembly/AGENTS.md) | `dotnet build SDemo.Shell.slnf -c Release` |
| **sdemo.planner**（待办 + 日历） | `Apps/Planner/` · [SDemo.Apps.Planner](https://github.com/nnbw-liu/SDemo.Apps.Planner) | 🚧 规划（P2） | [AGENTS](Apps/Planner/AGENTS.md) | `dotnet build SDemo.Planner.slnf -c Release` |
| **sdemo.kb**（知识库） | `Apps/Kb/` · [SDemo.Apps.Kb](https://github.com/nnbw-liu/SDemo.Apps.Kb) | 🚧 规划（P4） | [AGENTS](Apps/Kb/AGENTS.md) | `dotnet build SDemo.Kb.slnf -c Release` |
| **sdemo.meeting**（会议） | `Apps/Meeting/` · [SDemo.Apps.Meeting](https://github.com/nnbw-liu/SDemo.Apps.Meeting) | 🚧 规划（P6） | [AGENTS](Apps/Meeting/AGENTS.md) | `dotnet build SDemo.Meeting.slnf -c Release` |

三条跨产品不变式：**宿主无业务数据**、**应用零模型凭证**、**应用之间不直连**（只存 `sdemo.<app>/<entity>/<id>` URI，跨应用动作由 DesktopAgent 编排）。

## 克隆

```powershell
git clone --recursive git@github.com:nnbw-liu/SDemo.git
# 已克隆过则：
git submodule update --init --recursive
```

## 目录

```
SDemo/
├─ README.md                   ← 本文件：产品矩阵与上手
├─ AGENTS.md                   ← 路由：五条铁律、子模块纪律、命令、禁区
├─ docs/                       ← 跨产品文档（唯一事实源）
│  ├─ sdemo-brand-blueprint.md ← 品牌蓝图 + DA / PL / KB / MT 需求清单
│  ├─ product-map.md           ← 每个产品的仓 / 数据 / 文档 / 分期
│  ├─ repository-layout.md     ← 多仓布局、子模块纪律、依赖与发布
│  ├─ workbench-roadmap.md     ← 分期、里程碑、风险
│  ├─ integration.md           ← 跨产品联动需求（URI / MCP 发现 / 统一搜索 / 审批）
│  ├─ shared.md                ← 共享层在多仓下怎么落（待拍板）
│  └─ contracts/               ← 跨产品契约：widget.json、宿主控制协议
├─ workspaces/                 ← 工作区登记表（tools/ws.ps1 读取）
├─ tools/                      ← ws.ps1、check-doc-links.ps1
├─ DesktopAgent/               ← submodule
├─ DesktopAssembly/            ← submodule
└─ Apps/
   ├─ Planner/                 ← submodule
   ├─ Kb/                      ← submodule
   └─ Meeting/                 ← submodule
```

## 文档在哪

| 想知道 | 读 |
| --- | --- |
| 五个产品各自做什么、需求编号 | [sdemo-brand-blueprint.md](docs/sdemo-brand-blueprint.md) |
| 代码放哪个仓、数据存哪、现在做到哪 | [product-map.md](docs/product-map.md) |
| 为什么拆多仓、子模块怎么用、怎么发版 | [repository-layout.md](docs/repository-layout.md) |
| 什么时候做什么、多少工作量 | [workbench-roadmap.md](docs/workbench-roadmap.md) |
| 应用之间怎么联动（引用、发现、统一搜索、审批） | [integration.md](docs/integration.md) |
| `widget.json` / 宿主控制协议 | [contracts/](docs/contracts/) |
| DesktopAgent 的目录、命令、坑 | [DesktopAgent/AGENTS.md](DesktopAgent/AGENTS.md) |
| 某个产品的开工前必读 | 各子仓的 `AGENTS.md` 与 `docs/requirements.md` |

## 改子模块的正确姿势

1. 在子仓里改代码、提交、推送（`git -C DesktopAgent ...`）。
2. 回主仓更新指针：`git add DesktopAgent` → 提交，message 写清 pin 到哪个 sha/为什么。
3. 只改主仓文档（`docs/`、本 README、`workspaces/`）时，不碰子模块指针。

> 子仓文档里指向其它仓的链接用超级仓的相对路径（如 `../../docs/...`）。单独 clone 某个子仓时这些链接会失效，属预期；完整视图以本主仓为准。

## 当前状态（2026-10-31）

- 由单仓 `SDemo.DesktopAgent` 拆为「主仓 + 五个子模块」；DesktopAgent 的 git 历史与分支原样保留。
- 各产品需求、设计文档已按归属落位；跨产品文档集中在 `docs/`。
- 四个新产品仓目前只有文档，尚无代码；`AGENTS.md` 里写明了开工第一步。
