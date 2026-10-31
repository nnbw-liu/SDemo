# 仓库规划（主仓 + 多仓子模块）

> 状态：**已定稿并执行**，2026-10-31
> 关联：[品牌蓝图](sdemo-brand-blueprint.md) · [工作台规划](workbench-roadmap.md) · [落地地图](product-map.md) · [共享层](shared.md)
> 变更记录：原方案是"单仓多产品"。2026-10-31 由用户拍板改为**主仓 + 五个子仓**，本文按新口径重写。

---

## 1. 结论

**一个主仓 + 五个可独立发布的子仓，用 git submodule 串联。**

| 判断 | 结论 |
| --- | --- |
| 仓库数量 | **1 个主仓 + 5 个子仓**：`SDemo` / `SDemo.DesktopAgent` / `SDemo.DesktopAssembly` / `SDemo.Apps.Planner` / `SDemo.Apps.Kb` / `SDemo.Apps.Meeting` |
| 产品数量 | 5 个可部署物（Agent / Shell / 3 个 App） |
| 关联方式 | git submodule；主仓只存指针与跨产品文档 |
| 契约位置 | 跨产品契约与 JSON Schema 固定在主仓 `docs/contracts/`，子仓只引用 |
| 构建入口 | 每个子仓一个自包含 `.slnf`；主仓根不放 `.sln` |
| 版本 | 产品级独立版本；跨产品兼容用 `hostApiVersion` 单独管 |

## 2. 为什么改成多仓（以及代价）

改成多仓的理由（用户判断，2026-10-31）：

1. **独立发布与独立权限**：DesktopAssembly 是宿主，三个 App 是插件式产品，将来可能单独分发、单独授权。
2. **构建隔离**：Agent 仓已有 20 个工程与大量评测工具，新产品不需要拉全量依赖才能构建。
3. **边界强制**：物理拆仓让"应用之间零引用""Agent 不依赖 App"从口头纪律变成编译期不可能。
4. **仓库体积**：Agent 仓带大量评测产物与历史；新仓从零开始，clone 更快。

代价与对策（必须执行，否则多仓会腐烂）：

| 代价 | 对策 |
| --- | --- |
| 契约漂移（`widget.json` 改字段要跨 5 仓） | 契约只住主仓 `docs/contracts/` + JSON Schema；改契约单独一个主仓 PR，并列出受影响子仓的 pin |
| 跨仓原子改动 | 用主仓 issue 记录"这次联动改了哪几个子仓的哪个 commit"，按 pin 顺序提交 |
| 共享代码无法 `ProjectReference` | 见 [shared.md](shared.md)：优先做 `SDemo.Contracts` NuGet 包，其次子模块 |
| CI 变成 6 套 | 各仓自带最小 CI（build + test）；主仓 CI 只做文档链、子模块 pin 与契约 schema 校验 |
| 子模块指针遗忘更新 | 主仓 `git status` 里子仓显示 modified 时必须 `git add <子仓>` 再提交；PR 模板要求写 pin |

## 3. 目录树（实际）

```
SDemo/                              ← 主仓（git@github.com:nnbw-liu/SDemo.git）
├─ README.md                        ← 产品矩阵、克隆、改子模块姿势
├─ AGENTS.md                        ← 路由：铁律、子模块纪律、命令、禁区
├─ .gitmodules                      ← 五个子仓的 URL
├─ docs/
│  ├─ sdemo-brand-blueprint.md      ← 品牌蓝图 + DA/PL/KB/MT 需求清单
│  ├─ product-map.md                ← 仓 / 数据 / 文档 / 分期
│  ├─ repository-layout.md          ← 本文
│  ├─ workbench-roadmap.md          ← 分期与工作量
│  ├─ integration.md                ← 跨产品联动需求
│  ├─ shared.md                     ← 共享层怎么落
│  └─ contracts/
│     ├─ widget-contract.md         ← widget.json 契约
│     └─ host-protocol.md           ← 宿主控制协议
├─ workspaces/                      ← 工作区登记表（*.json + README）
├─ tools/
│  ├─ ws.ps1                        ← 列工作区、给 worktree 建议
│  └─ check-doc-links.ps1           ← 全仓文档死链（超级仓视角）
├─ DesktopAgent/                    ← submodule
├─ DesktopAssembly/                 ← submodule
└─ Apps/
   ├─ Planner/                      ← submodule
   ├─ Kb/                           ← submodule
   └─ Meeting/                      ← submodule
```

每个子仓的标准形态（以 App 为例）：

```
Apps/Planner/
├─ README.md
├─ AGENTS.md                        ← 工作区入口（≤120 行）
├─ .gitignore
├─ docs/
│  ├─ requirements.md               ← 需求计划（编号、分期、验收）
│  └─ planner-mcp-surface.md        ← 设计 / 工具面
├─ src/
│  └─ SDemo.App.Planner.{Contracts,Storage,Core,Mcp,Host}/
├─ tests/
│  └─ SDemo.App.Planner.{Storage,Mcp}.Tests/
└─ SDemo.Planner.slnf
```

## 4. 子模块机制

- `.gitmodules` 记录 path ↔ URL；主仓 `git ls-tree` 里子仓是 gitlink（commit sha）。
- **pin 规则**：主仓提交只改指针；指针必须指向子仓**已推送**的 commit（否则别人 `submodule update` 会失败）。
- **日常流程**：
  ```powershell
  git -C DesktopAgent checkout -b feature/x     # 在子仓里开发
  git -C DesktopAgent commit -am "feat: ..."
  git -C DesktopAgent push origin feature/x
  git add DesktopAgent                          # 回主仓更新指针
  git commit -m "chore(submodule): bump DesktopAgent to <sha>"
  ```
- **克隆**：`git clone --recursive`。
- **状态**：`git submodule status` 显示 `-`（未初始化）/ 空格（一致）/ `+`（指针与工作区不同）。
- 不建议 `git submodule foreach git pull`：会脱离 pin，改成显式 bump。

## 5. 每个应用的标准模板（5 个工程）

三个应用必须长得一样，否则三个月后各自演化成三种架构。

| 工程 | 职责 | 允许依赖 | 禁止 |
| --- | --- | --- | --- |
| `SDemo.App.<x>.Contracts` | 领域模型、服务接口、MCP 工具 DTO、错误码 | 契约包（见 [shared](shared.md)） | 任何实现、EF、UI |
| `SDemo.App.<x>.Storage` | `DbContext`、迁移、仓储、outbox | `Contracts`、SQLite 基建 | 业务规则、MCP |
| `SDemo.App.<x>.Core` | 应用服务：去重、重复规则、草稿流水线、影响面计算 | `Storage`、`Contracts` | Http、UI、进程 |
| `SDemo.App.<x>.Mcp` | MCP server 装配：工具签名 → Core 调用 → 结果信封 | `Core`、MCP 基建 | 领域逻辑 |
| `SDemo.App.<x>.Host` | exe：单实例、内核模式、主窗口（Blazor/native 组件窗口） | `Core`、`Mcp`、`Shell.Contracts` | 直接写 SQL |

Why 拆开 `.Mcp`：工具面是给模型看的**对外契约**，把它和领域逻辑混在一个工程里，最后一定出现"为了工具方便改了领域模型"。物理隔离是最便宜的约束。

## 6. 依赖规则

物理拆仓后，跨仓**不可能** `ProjectReference`，规则变成：

1. **Agent 不依赖任何 `App.*`**：跨仓引用在编译期就失败，不需要守卫。
2. **`App.*` 不依赖 Agent，也不依赖另一个 `App.*`**：只存 URI 字符串，跨应用动作由 Agent 经 MCP 编排。
3. **Shell 只依赖 `Shell.Contracts`**：不认识任何具体应用。
4. **共享代码只能来自契约包或子模块**：禁止复制源码（见 [shared.md](shared.md)）。

仓内仍保留守卫脚本：扫描 `.csproj` 的 `ProjectReference`，命中禁止边就失败。规则清单见各仓 `AGENTS.md`。

## 7. 共享层与契约（多仓下唯一的额外设计）

单仓时 `src/Shared/*` 是普通工程；多仓下它必须有独立交付形态。三种方案对比：

| 方案 | 做法 | 代价 | 结论 |
| --- | --- | --- | --- |
| **A. NuGet 契约包**（推荐） | 新增 `SDemo.Contracts`（或 `SDemo.Shared.*`）包，子仓按版本引用 | 需要私有 feed 与发版纪律 | 首选 |
| B. 契约子模块 | 再加一个 `SDemo.Contracts` 子仓，各仓 submodule 引用 | 指针管理成本 ×1，且 C# 仍要 `ProjectReference` | 备选 |
| C. 源码复制 | 各仓各自维护一份 | 必然漂移，禁止 | ❌ |

**v1 的折中**：跨产品契约以**文档 + JSON Schema** 形式住主仓 `docs/contracts/` 与 `DesktopAgent/contracts/schemas/`；C# 契约包等 P1 需要写共享类型时再立（待拍板 Q1）。

## 8. 解决方案与 slnf 矩阵

| 仓 | 解决方案文件 | 用途 |
| --- | --- | --- |
| `DesktopAgent` | `SDemo.DesktopAgent.sln` + `SDemo.DesktopAgent.Wpf.slnf` | 现有门禁，路径不变 |
| `DesktopAssembly` | `SDemo.Shell.slnf` | Shell 独立构建/发布 |
| `Apps/Planner` | `SDemo.Planner.slnf` | 独立构建/发布 |
| `Apps/Kb` / `Apps/Meeting` | `SDemo.Kb.slnf` / `SDemo.Meeting.slnf` | 同上 |
| 主仓 | 不建 `.sln` | 需要跨仓联调时用 `dotnet build` 多项目或临时 slnx |

每个 `.slnf` 必须**自包含可构建**——这是"能独立发布"的技术前提。

## 9. 版本与发布

| 对象 | 版本来源 | 递增时机 |
| --- | --- | --- |
| Agent | `DesktopAgent/Directory.Build.props` 的 `Version` | 功能发布 |
| Shell | `DesktopAssembly` 自己的 `Directory.Build.props` | 功能发布 |
| 每个 App | 各自 `.csproj` 的 `Version` | 各自功能发布 |
| `hostApiVersion` | 主仓 `docs/contracts/` 里的独立常量 | **只在破坏兼容时**主版本 +1 |
| `schemaVersion`（manifest / db） | 各清单内常量 | 清单或表结构不兼容变更 |
| MCP `toolsVersion` | 各 App 常量 | 工具签名破坏性变化 |

**关键：产品版本 ≠ 兼容版本。** App 可以从 0.1 升到 0.9，只要没破坏协议，`hostApiVersion` 一直是 1.0。

产物（各仓 `tools/pack.ps1`）：

```
dist/SDemo-Agent-1.2.0.zip
dist/SDemo-Shell-1.2.0.zip
dist/SDemo-Planner-0.3.0.zip      ← apps/sdemo.planner/（app.json + widget.json + payload + exe）
dist/SDemo-Kb-0.1.0.zip
dist/SDemo-Meeting-0.1.0.zip
```

打包脚本做三件事：`dotnet publish`（win-x64）→ 生成/校验清单并回填 sha256 → `Compress-Archive`。sha256 必须由脚本回填。

## 10. 数据库与迁移边界

| 规则 | 说明 |
| --- | --- |
| 每个应用一个 DbContext、一个迁移目录 | 禁止跨应用共享 DbContext |
| 迁移策略不统一 | Agent 沿用现有 `EnsureCreated` + 补列；**新应用一律用真实 EF migrations** |
| 迁移在应用启动时执行 | 加应用级互斥锁，保证只有一个进程迁移 |
| CI 检查 | `dotnet ef migrations has-pending-model-changes`（EF 9+） |
| 数据目录 | `%APPDATA%\SDemo\Apps\<appId>\`；卸载不删 |

Agent 与 App 的迁移策略不同是**故意的**：Agent 已有大量线上库不能重来，新应用没有历史包袱，直接上正规迁移。

## 11. 测试分层

| 层 | 归属 | 内容 |
| --- | --- | --- |
| 单元 | 各工程 | 纯算法、`Core` 规则、outbox |
| 存储 | `tests/<App>.Storage` | 临时 sqlite 文件（不用 InMemory，因为要验 FTS5 与迁移） |
| 契约快照 | `tests/<App>.Mcp` | 工具 schema 与 `widget.json` 序列化后比对快照 |
| 协议 | Shell 仓 `tests/` | 起 fake app server，验握手/鉴权/超时/降级 |
| 文档 | 主仓 | `pwsh tools/check-doc-links.ps1` |
| UI | bUnit | 沿用现有套路 |

**契约快照测试是多仓的安全网**：三个应用 + 宿主 + Agent 之间的隐性约定，靠快照比对暴露"我不小心改了对外形状"。

## 12. 工具

| 工具 | 位置 | 作用 |
| --- | --- | --- |
| `ws.ps1` | 主仓 `tools/` | 工作区清单、入口、命令、worktree 建议 |
| `check-doc-links.ps1` | 主仓 `tools/` | 全仓（含子仓）相对链接必须可解析 |
| `check-repo-guards.ps1` | Agent 仓 `tools/` | 体量、脏文件、依赖边、契约同改 |
| `contract-lint` | 待做（主仓） | JSON Schema 校验 `widget.json` / `app.json` / MCP 工具面 |
| `pack` | 待做（各仓） | 打包 + 回填 sha256 |

## 13. 本次迁移记录（2026-10-31）

| 动作 | 结果 |
| --- | --- |
| `DesktopAgent` 仓 | 从 `F:\AI\Code\SDemo` 移到 `F:\Code\SDemo\DesktopAgent`；git 历史、33 个本地分支原样保留；origin 改为 `SDemo.DesktopAgent.git` |
| 文档归属 | 跨产品文档 → 主仓 `docs/`；Shell 文档 → `DesktopAssembly/docs/`；应用文档 → `Apps/<App>/docs/`；Agent 自己的文档留在原处 |
| 工作区登记 | `workspaces/*.json` 移到主仓，增加 `repo` 字段（工作区入口 `entry` 改为仓内相对路径） |
| 子模块 | 五个子仓以 gitlink 形式纳入主仓，`.gitmodules` 记录 URL |
| 未搬内容 | `F:\AI\Code\SDemo` 下的 `_scratch`、`p6-eval`（Agent 的 linked worktree，指针已修复）、`p7-bench`、旧实验目录原样留在原地 |

## 14. 风险与待拍板

| # | 风险 / 议题 | 缓解 / 建议 |
| --- | --- | --- |
| R1 | 子模块指针忘记 bump，别人拿到旧代码 | PR 模板 + 主仓 CI 检查 `git submodule status` 无 `+`/`-` |
| R2 | 契约改字段要跨 5 仓 | 契约只住主仓；一次改动一个主仓 PR + 子仓 pin 清单 |
| R3 | 共享类型重复实现 | [shared.md](shared.md) 三方案，优先 NuGet 契约包 |
| R4 | 三个 App 各自跑偏 | 同一模板 + 契约快照 + 各仓 AGENTS 铁律 |
| R5 | 2 GB 级评测产物进新仓 | 新仓 `.gitignore` 排除 `bin/obj/TestResults/*.db`；模型文件不入库 |
| Q1 | 共享契约包什么时候立 | P1 写共享类型前定；建议 M1 就立 `SDemo.Contracts` |
| Q2 | 子仓分支策略（master / trunk / release） | 建议五仓统一 `master` + tag 发布，主仓 pin tag 落地版本 |
| Q3 | 主仓是否需要跨仓 `.slnx` 联调入口 | 等 P3 联调时按需要建，不提前 |
