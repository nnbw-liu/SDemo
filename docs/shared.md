# 共享层：多仓下怎么落

> 状态：待拍板（Q1），2026-10-31
> 关联：[多仓布局](repository-layout.md) §7 · [跨产品联动](integration.md) · [组件契约](contracts/widget-contract.md)

---

## 1. 问题

单仓方案里，跨产品共享代码放在 `src/Shared/*`（Contracts / Foundation / Sqlite / Mcp），各产品直接 `ProjectReference`。
改成多仓后，这条路径**物理上不存在了**：子仓之间不能互相引用工程，也没有"公共目录"可放。

必须先定共享层的交付形态，否则三个应用会各自复制一份 DTO、错误码、FTS 助手，三份必然漂移。

## 2. 需要共享的东西

| 类别 | 内容 | 不稳定度 | 谁用 |
| --- | --- | --- | --- |
| **契约 DTO** | `widget.json` / `app.json` 模型、宿主协议消息、MCP 信封 | 高（会随协议变） | Shell + 3 App + Agent |
| **URI 规范** | `sdemo.<app>/<entity>/<id>` 解析与校验 | 低 | 3 App + Agent |
| **错误码** | `HOST_POLICY_DENIED`、`APP_NOT_READY`、审批拒绝等 | 中 | Shell + 3 App + Agent |
| **Foundation** | UUIDv7、HLC、内容哈希、JSON 选项、时间 | 低 | 3 App |
| **SQLite 基建** | 连接工厂、FTS5 建表、2-gram 分词、outbox 序列化 | 中 | 3 App |
| **MCP 宿主** | server 装配、工具签名、结果信封、token 校验 | 中 | 3 App |
| **JSON Schema** | `widget.schema.json`、`app.schema.json`、`settings.schema.json` | 高 | Shell + 工具链 |

## 3. 三种方案

| 方案 | 做法 | 优点 | 代价 |
| --- | --- | --- | --- |
| **A. NuGet 契约包**（推荐） | 新建 `SDemo.Contracts`（契约）与 `SDemo.Shared.*`（基建）包，发布到 GitHub Packages；子仓用 `PackageReference` + 版本 | 版本显式、可回滚、CI 可缓存；子仓独立 clone 也能构建 | 需要私有 feed、发版纪律；改契约要多一步发包 |
| B. 契约子模块 | 再建一个 `SDemo.Contracts` 子仓，各子仓 submodule 引用源码 | 改动即时可见，无需发版 | 子模块套子模块，指针管理 ×6；仍需相对路径引用工程 |
| C. 各仓复制 | 每仓维护一份 | 零基础设施 | **禁止**：三份必然漂移 |

## 4. 建议的落地顺序

1. **M1 先立 JSON Schema（零成本）**：`docs/contracts/*.md` 与 schema 已在主仓，Shell 与 App 的清单校验直接引用，不需要 C# 包。
2. **P1 需要写共享 DTO 时立 `SDemo.Contracts` 包**：先只放 widget/app/协议消息与错误码；Foundation / Sqlite / Mcp 暂不包，等第二个应用真正复用时再下沉（Rule of Three）。
3. **包版本与 `hostApiVersion` 分开**：包版本按语义化递增，`hostApiVersion` 只在破坏兼容时变。
4. **主仓记录兼容矩阵**：`docs/contracts/` 里维护"包版本 ↔ hostApiVersion ↔ 子仓 pin"表。

## 5. 共享代码准入规则（沿用原单仓方案）

| 层 | 准入 | 反例 |
| --- | --- | --- |
| Contracts | 只有 DTO、接口、枚举、错误码常量；**零依赖、零实现** | 放一个 `Helper` 类 |
| Foundation | 纯算法/基础设施，可独立单测（UUIDv7、HLC、内容哈希） | 依赖 EF 或 Http |
| Sqlite | 连接与索引基建（FTS5 建表、2-gram 分词、outbox 序列化） | 建具体业务表 |
| Mcp | MCP 协议封装 | 认识任何具体工具名 |

三条纪律：

- **禁止 `SDemo.Common` / `SDemo.Utils` / `SDemo.Helpers`**——出现即评审。没有主语的工程必然变成垃圾场。
- **Rule of Three**：同一个类型要被第 3 处使用时才下沉；两处时复制粘贴更便宜，因为两处会分叉演化。
- **下沉必须伴随单测**：进共享层的代码没有测试就不许进。

## 6. 待拍板

| # | 议题 | 选项 | 建议 |
| --- | --- | --- | --- |
| Q1 | 共享层交付形态 | NuGet 包 / 契约子模块 / 暂不共享 | NuGet 包，M1 只立契约 |
| Q2 | 私有 feed 用哪个 | GitHub Packages / 本地目录 feed | GitHub Packages（与仓库同权限） |
| Q3 | 是否允许"临时复制" | 允许两处、禁止三处 | 允许（Rule of Three），但要在文档里登记 |
