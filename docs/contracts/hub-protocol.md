# SDemo Hub 连接与组件契约（v1.0）

> 状态：**已冻结**（2026-11-08）。适用于 Hub `0.2.x` 与所有接入 SDemo Hub 的应用。
> 关联：[需求 v2](../../DesktopAssembly/docs/requirements-v2.md) · [UI v2](../../DesktopAssembly/docs/ui-v2.md) · [连接配置 Schema](hub-app.schema.json) · [M0 验证](../../DesktopAssembly/docs/m0-spike.md)
> 变更规则：向后兼容的字段只能追加；破坏性变更必须提升 `schemaVersion` 并保留旧版解析。

---

## 1. 范围

本契约规定：

1. 应用如何把自己的**运行时连接信息**写到公共目录；
2. Hub 如何发现、连接、握手、展示应用；
3. 应用如何向 Hub 提供 **Blazor 桌面组件**；
4. Hub 如何向 Agent 提供 **应用 / Agent / MCP 地址目录**。

不在本契约内：应用业务数据、MCP 工具语义、应用间直接通信、模型调用、账号与云同步。

### 1.1 角色

| 角色 | 说明 |
| --- | --- |
| 应用 | 任何 SDemo 应用；可以是普通应用、Agent，或两者兼有 |
| Hub | `SDemo.Hub.App`；控制面，负责发现、连接、呈现、目录 |
| Agent | 需要发现其他应用/MCP 的智能体；可独立运行，不强制接入 Hub |

### 1.2 信任模型

同用户的本机进程**不互信**。公共目录中的配置是不可信输入；Hub 只相信：

- 回环 HTTP 上的 `/v1/info` 握手（带 Bearer token）；
- 用户显式确认过的可执行文件路径。

---

## 2. 公共目录

| 项 | 约定 |
| --- | --- |
| 根目录 | `%LOCALAPPDATA%\SDemo\Hub\` |
| 应用配置 | `%LOCALAPPDATA%\SDemo\Hub\apps\<appId>.json` |
| Hub 配置 | `%LOCALAPPDATA%\SDemo\Hub\apps\sdemo.hub.json` |
| 编码 | UTF-8，无 BOM |
| 单文件上限 | 256 KB |
| 写入方式 | 同目录临时文件 + `File.Move(tmp, target, overwrite: true)` |
| 生命周期 | 启动写入；正常退出改为 `state=stopped`；**不删除** |
| 写者 | 只有应用自己；Hub 只读 |

`appId` 规则：`^[a-z0-9]+(\.[a-z0-9_-]+)+$`，最长 128；文件名必须等于 `<appId>.json`。

---

## 3. 连接配置

### 3.1 示例

```json
{
  "schemaVersion": 1,
  "appId": "sdemo.planner",
  "displayName": "事序",
  "version": "0.5.0",
  "kind": "app",
  "executable": "C:\\SDemo\\Apps\\Planner\\SDemo.Planner.exe",
  "arguments": [],
  "workingDirectory": "C:\\SDemo\\Apps\\Planner",
  "port": 51234,
  "baseUrl": "http://127.0.0.1:51234",
  "token": "9f2c4d1e7a8b0c3d5e6f708192a3b4c5d6e7f8091a2b3c4d",
  "pid": 12345,
  "startedAt": "2026-11-08T18:00:00+08:00",
  "state": "running",
  "startupTimeoutMs": 8000,
  "icon": "/icon.png",
  "mcp": { "transport": "http", "path": "/mcp" },
  "agent": null,
  "mainWindow": { "title": "事序", "width": 1180, "height": 760 },
  "widgets": [
    {
      "id": "today",
      "displayName": "今日",
      "description": "今天的任务与日程",
      "entry": "/widgets/today",
      "size": { "width": 320, "height": 420 },
      "minSize": { "width": 240, "height": 200 },
      "defaultVisible": false,
      "defaultHotkey": null,
      "icon": "/widgets/today/icon.png"
    }
  ]
}
```

### 3.2 顶层字段

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `schemaVersion` | int | 是 | 当前 `1`；大于 1 时 Hub 标记「不兼容」，不连接 |
| `appId` | string | 是 | 反向域名，见 §2 |
| `displayName` | string | 是 | 1–64 字符，用户可见名称 |
| `version` | string | 是 | 应用版本，1–32 字符 |
| `kind` | enum | 是 | `app` / `agent` / `both` / `hub` |
| `executable` | string | 否 | 绝对路径；缺失则只能附着，不能由 Hub 启动 |
| `arguments` | string[] | 否 | 最多 64 项；逐项传参，不经 shell 拼接 |
| `workingDirectory` | string | 否 | 绝对路径；缺省为 exe 目录 |
| `port` | int | 运行中必填 | 实际监听端口，1–65535 |
| `baseUrl` | string | 运行中必填 | 必须等于 `http://127.0.0.1:<port>` |
| `token` | string | 运行中必填 | 32–256 字符；Bearer 与组件 cookie 共用 |
| `pid` | int | 运行中必填 | 进程号 |
| `startedAt` | string | 运行中必填 | RFC3339 时间 |
| `state` | enum | 否 | `running` / `stopped`；仅作提示，以探测为准 |
| `startupTimeoutMs` | int | 否 | 1000–60000，默认 8000 |
| `icon` | string | 否 | 回环相对路径，如 `/icon.png` |
| `mcp` | object\|null | 否 | `{ "transport": "http", "path": "/mcp" }` 或 `{ "transport": "http", "url": "http://127.0.0.1:<mcpPort>/mcp" }` |
| `agent` | object\|null | 否 | `{ "path": "/agent" }` 或 `{ "url": "http://127.0.0.1:<agentPort>/agent", "name": "…" }` |
| `mainWindow` | object\|null | 否 | `{ "title", "width", "height" }`，仅展示用 |
| `widgets` | array | 否 | 最多 32 个；无组件为 `[]` |

约束：

- `baseUrl` 只接受 `127.0.0.1`，不接受 `localhost`，避免 IPv6 解析歧义。
- `baseUrl` 的端口必须等于 `port`。
- `token` 每次进程启动必须更换；不得写日志、不得在 UI 明文展示。
- 运行中字段缺失 → Hub 视为离线，等待应用更新文件。
- `state=stopped` 时允许省略 `token/pid/startedAt`，但保留 `port/baseUrl/widgets` 供离线展示。
- `mcp` / `agent` 的 `path` 相对 `baseUrl`；若服务监听在另一个端口，用绝对 `url`（仍只允许 `127.0.0.1`）。`path` 与 `url` 至少有一个。
- `agent` 字段只声明智能体入口地址，契约不规定该地址上的服务形态。本仓约定：`GET /agent` 返回与 `/v1/info` 同形的身份/能力描述（限回环、免鉴权、不含 token），供本机其它 Agent 发现；`list_agents` 只信配置 / info 里的 `agent` 字段，不会去探测该地址。

### 3.3 组件条目

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `id` | string | 是 | `^[a-z0-9][a-z0-9_-]{0,63}$`，应用内唯一 |
| `displayName` | string | 是 | 1–32 字符 |
| `description` | string | 否 | 最多 200 字符 |
| `entry` | string | 是 | 以 `/` 开头；禁止 `..`、`://`、外部跳转 |
| `size` | object | 是 | `{ width, height }`，DIP，80–4096 |
| `minSize` | object | 否 | 默认 `{ "width": 200, "height": 120 }` |
| `defaultVisible` | bool | 否 | 默认 `false`；仅首次添加时参考 |
| `defaultHotkey` | string\|null | 否 | 建议热键；冲突时 Hub 不采用 |
| `icon` | string | 否 | 回环相对路径 |
| `config` | object | 否 | 组件设置表单的 Schema 子集（同 [widget-contract §8](widget-contract.md)，只支持 `boolean` / `integer` / `number` / `string`）；Hub 存值进 `widgets.json`，并把已存值作为查询参数拼到 `entry`（例如 `entry=/widgets/tasks` + `rows=10` → `/widgets/tasks?rows=10`）。未知字段忽略 |

### 3.4 校验与降级

| 情况 | 处理 |
| --- | --- |
| JSON 解析失败 / Schema 不符 | 保留「配置无效」卡片，跳过该应用；其他应用不受影响 |
| `appId` 与文件名不一致 | 无效，`HUB_CFG_APPID_MISMATCH` |
| `baseUrl` 非回环或端口不符 | 无效，`HUB_CFG_NOT_LOOPBACK` |
| `schemaVersion > 1` | 标记「不兼容」，不连接 |
| `token` 长度不足 | 无效 |
| `widgets` 超 32 个 / `entry` 非法 | 整个文件判无效 |
| `executable` 不存在 | 仍显示；用户点启动时报 `HUB_LAUNCH_FAILED` |
| `pid` 对应进程不存在 | 显示离线「进程已退出」，不发请求 |

---

## 4. 应用 HTTP 面

所有接口位于 `baseUrl`。除 `/v1/health` 外都要求：

```
Authorization: Bearer <token>
Cache-Control: no-store
```

只监听回环；Hub 拒绝非回环地址。

### 4.1 `GET /v1/health`

无鉴权，仅探活。超时 1s。

```json
{ "status": "ok", "appId": "sdemo.planner", "version": "0.5.0", "pid": 12345 }
```

非 200、`appId` 不符、或 `pid` 不符 → 不可达。

### 4.2 `GET /v1/info`

鉴权；握手与能力的**唯一真相源**。超时 3s。

```json
{
  "schemaVersion": 1,
  "appId": "sdemo.planner",
  "displayName": "事序",
  "version": "0.5.0",
  "kind": "app",
  "pid": 12345,
  "startedAt": "2026-11-08T18:00:00+08:00",
  "capabilities": ["mcp", "mainWindow", "widgets"],
  "mcp": { "transport": "http", "url": "http://127.0.0.1:51234/mcp" },
  "agent": null,
  "mainWindow": { "title": "事序", "width": 1180, "height": 760 },
  "widgets": [
    {
      "id": "today",
      "displayName": "今日",
      "description": "今天的任务与日程",
      "entry": "/widgets/today",
      "size": { "width": 320, "height": 420 },
      "minSize": { "width": 240, "height": 200 },
      "icon": "/widgets/today/icon.png"
    }
  ]
}
```

规则：

- `appId` 必须与配置一致，否则 Hub 拒绝连接（防端口串台）。
- `capabilities` 是字符串数组，取值 `mcp` / `agent` / `mainWindow` / `widgets`。
- **能力以 `capabilities` 为准**：数组里没有的能力，对应字段必须为 `null` 或省略；字段存在但数组未声明时，Hub 按不支持处理。
- `mcp.url`、`agent.url` 必须是回环绝对 URL；`mainWindow` 只描述标题与默认尺寸，实际入口固定为 §4.3。
- `widgets` 以 info 为准；配置里的清单只用于离线展示。
- 响应 `appId` 与配置不符 → `HUB_APP_AUTH_FAILED`，不覆盖现有状态。

### 4.3 `POST /v1/main-window/open`

鉴权；无 body；把应用主窗口显示并激活（已显示则置前）。

| 状态 | 含义 |
| --- | --- |
| 204 | 已打开 |
| 401/403 | token 无效 |
| 404 | 不支持（`capabilities` 无 `mainWindow` 时 Hub 不显示按钮） |
| 409 | 当前无法显示（例如正在退出） |

---

## 5. 组件承载

### 5.1 渲染方式

组件由**应用自己渲染**（Blazor Server circuit），Hub 只负责窗口、导航、位置与层级。Hub 不加载应用 DLL，不复制应用的 DI。

应用必须提供可交互的 Blazor Server 页面。仅使用 `BlazorWebView`、仅用 `HttpListener` 无法满足本契约。

### 5.2 主机别名与 cookie

1. 组件页 origin 固定为 `http://<appId>.localhost:<port>`，例如 `http://sdemo.planner.localhost:51234`。`baseUrl` 只用于控制面 HTTP。
2. 导航前 Hub 通过 WebView2 `CookieManager` 写入 host-only cookie：

| 属性 | 值 |
| --- | --- |
| 名称 | `sdemo_session` |
| 值 | 应用 token |
| Domain | 不设置（host-only） |
| Path | `/` |
| HttpOnly | 是 |
| SameSite | `Lax` |
| Secure | 否（回环 http） |

3. Hub 导航到 `http://<appId>.localhost:<port><entry>`，可附加 `?theme=dark|light`。
4. 应用必须校验 `Request.Host.Host == "<appId>.localhost"` 且 cookie 等于 token；失败返回 `401`。
5. Hub 收到 `401/403` → 显示「连接已失效」占位，并重试一次 `/v1/info`。

禁止用 URL 查询参数传 token。

约束：

- `appId` 已满足 §2 正则，直接拼 `.localhost`。
- 应用必须接受任意 Host：Kestrel `AllowedHosts` 设为 `*` 或 `*.localhost`。
- 每个组件窗口是独立 origin；禁止导航到其他 origin，禁止打开新窗口。
- M0 已实测 WebView2 可解析 `*.localhost` 且 cookie 隔离成立；回退方案见 §5.5。

### 5.3 页面要求

- 服务端渲染入口 HTML，引用 `/_framework/blazor.server.js`。
- 根节点 `#app`，不依赖应用主窗布局与全局样式。
- 页面铺满视口（`100dvh`），背景由应用自绘；Hub 不保证窗口级透明。
- 支持 `prefers-color-scheme: dark`；Hub 设置 `PreferredColorScheme`。
- 不加载外网资源；静态资源走应用自己的回环地址。
- 每个组件一个 circuit；scoped 服务按 circuit 隔离。
- 应用退出/重启后由 Hub 重新导航；页面无需跨进程恢复。

### 5.4 失败处理

| 情况 | Hub 行为 |
| --- | --- |
| 应用离线 | 离线占位 + 「启动应用」；不导航 |
| 401/403 | 占位「鉴权失败」+ 重试 info |
| 5xx / 导航失败 | 占位 + 「重试」；3 次后错误态 |
| WebView2 进程崩溃 | 重建 WebView2，保留窗口位置 |
| 应用重启 | 配置变化触发重新导航 |

### 5.5 回退（仅当主机别名不可用）

- 使用 `http://127.0.0.1:<port><entry>`；
- cookie 名改为 `sdemo_<appId 中 . 替换为 _>`，host-only；
- 接受「同主机跨端口共享 cookie」的第一方信任模型，并在诊断页标注。

M0 已验证主机别名可用，回退默认不启用。

---

## 6. 生命周期

```
应用启动
  → 绑定回环端口（推荐 port=0，由系统分配）
  → 原子写配置（state=running, port/pid/token）
  → 开始服务

应用正常退出
  → 改配置 state=stopped，清 token/pid
  → 停止服务（先停止接受请求，再停 circuit）

应用崩溃
  → 配置仍是 running
  → Hub 探测 pid/健康失败 → offline（不改文件）
```

规则：

- 应用是配置文件的唯一写者；Hub 只读。
- Hub 不因离线删除文件；「从列表移除」只写 Hub 自己的设置。
- 应用重启后 token 必须更换。
- Hub 启动应用只允许用户显式触发；首次启动需确认可执行文件完整路径。
- Hub 等待上线最长 `startupTimeoutMs`；超时 `HUB_LAUNCH_TIMEOUT`。
- 同一 `appId` 只允许一个实例；多实例不在 v1 范围。

---

## 7. 目录 MCP

### 7.1 传输与鉴权

- 地址：`http://127.0.0.1:<hubPort>/mcp`
- 传输：HTTP POST，JSON-RPC 2.0；协议版本 `2025-06-18`
- 方法：`initialize`、`notifications/initialized`、`ping`、`tools/list`、`tools/call`
- 鉴权：`Authorization: Bearer <hub token>` 或 Hub 签发的短期 ticket
- 仅回环；校验 Host/Origin；不要求 SSE
- **任何响应都不得包含应用 token、cookie 或密钥**

`initialize` 返回：

```json
{
  "protocolVersion": "2025-06-18",
  "capabilities": { "tools": {} },
  "serverInfo": { "name": "sdemo-hub", "version": "0.2.0" }
}
```

### 7.2 工具

所有工具结果使用 MCP 标准 `content`：

```json
{
  "content": [{ "type": "text", "text": "{ ...JSON... }" }],
  "isError": false
}
```

#### `list_apps`

入参：

```json
{ "includeOffline": false, "kind": "all" }
```

`kind`：`all` / `app` / `agent` / `both`，默认 `all`。

结果 `text`：

```json
{
  "apps": [
    {
      "appId": "sdemo.planner",
      "displayName": "事序",
      "version": "0.5.0",
      "kind": "app",
      "state": "online",
      "mcpUrl": "http://127.0.0.1:51234/mcp",
      "agentUrl": null,
      "widgets": [{ "id": "today", "displayName": "今日" }]
    }
  ]
}
```

#### `list_agents`

入参：`{ "includeOffline": false }`

```json
{
  "agents": [
    {
      "appId": "sdemo.assistant",
      "displayName": "SDemo 助理",
      "version": "0.3.0",
      "agentUrl": "http://127.0.0.1:51240/agent",
      "state": "online"
    }
  ]
}
```

#### `list_mcp_servers`

入参：`{ "includeOffline": false }`

```json
{
  "servers": [
    {
      "appId": "sdemo.planner",
      "displayName": "事序",
      "mcpUrl": "http://127.0.0.1:51234/mcp",
      "transport": "http",
      "state": "online"
    }
  ]
}
```

#### `get_app`

入参：`{ "appId": "sdemo.planner" }`

返回单个应用详情，含 `widgets`、`capabilities`，不含 token。

### 7.3 规则

- 默认只列在线；`includeOffline=true` 时离线项 `state="offline"`。
- 地址由 Hub 规范化；拒绝应用声明的非回环地址。
- 未知工具 `-32601`；参数错误 `-32602`。
- Hub 不可用时 Agent 必须能独立工作；目录是可选增强。

### 7.4 HTTP 镜像

`GET /v1/directory?includeOffline=false`，Bearer Hub token 或 ticket，返回与 `list_apps` 相同结构；供诊断与非 MCP 调用方使用。

### 7.5 短期 ticket

`POST /v1/directory/tickets`，Bearer Hub token，无 body。

```json
{ "ticket": "…", "expiresAt": "2026-11-08T18:05:00+08:00" }
```

- TTL 300 秒；仅内存；scope `directory:read`；最多 32 张；Hub 重启失效。
- 使用：`Authorization: Bearer <ticket>` 访问 `/mcp` 与 `/v1/directory`。
- 用途：宿主进程读 `sdemo.hub.json` 换 ticket，注入沙箱 Agent；ticket 不落盘、不可续期。
- 审计：记录签发/使用时间与调用方地址，不记录凭证本身。
- 失败：401（Hub token 无效）、429（ticket 超限）。

### 7.6 Hub 自己的配置

Hub 启动后写 `sdemo.hub.json`，退出改 `state=stopped`：

```json
{
  "schemaVersion": 1,
  "appId": "sdemo.hub",
  "displayName": "SDemo Hub",
  "version": "0.2.0",
  "kind": "hub",
  "port": 51235,
  "baseUrl": "http://127.0.0.1:51235",
  "token": "…",
  "pid": 9999,
  "startedAt": "2026-11-08T18:00:00+08:00",
  "state": "running",
  "mcp": { "transport": "http", "path": "/mcp" }
}
```

Agent 通过它发现 Hub 的 MCP 地址与 token；不用 Hub 的 Agent 忽略即可。

---

## 8. 错误码

| 码 | 场景 |
| --- | --- |
| `HUB_CFG_INVALID` | 配置解析 / Schema 失败 |
| `HUB_CFG_APPID_MISMATCH` | appId 与文件名不一致 |
| `HUB_CFG_NOT_LOOPBACK` | baseUrl 非回环或端口不符 |
| `HUB_APP_UNREACHABLE` | 健康检查失败 |
| `HUB_APP_AUTH_FAILED` | 401/403 或 appId 不匹配 |
| `HUB_APP_INCOMPATIBLE` | schemaVersion 过高 |
| `HUB_LAUNCH_NOT_APPROVED` | 用户未确认可执行文件 |
| `HUB_LAUNCH_FAILED` | 进程启动失败 |
| `HUB_LAUNCH_TIMEOUT` | 等待 info 超时 |
| `HUB_WIDGET_LOAD_FAILED` | 组件页导航失败 |
| `HUB_MAIN_WINDOW_UNSUPPORTED` | 应用不支持打开主窗 |
| `HUB_DIRECTORY_UNAVAILABLE` | 目录服务未就绪 |
| `HUB_DIRECTORY_AUTH_FAILED` | 目录 token/ticket 无效或过期 |

---

## 9. 安全

- **配置不可信**：任何同用户进程都能写公共目录；Hub 必须做 Schema、回环、appId、端口校验。
- **启动**：只允许用户显式触发；首次确认可执行文件完整路径；不自动拉起。
- **网络**：只连回环；拒绝非回环 `baseUrl`；WebView2 禁止导航到应用 origin 之外；禁止新窗口。
- **token**：不写日志、不进 MCP 响应、不在 UI 明文展示；依赖 `%LOCALAPPDATA%` 用户 ACL。
- **cookie**：host-only；绑定 `<appId>.localhost`；不设 `Domain`；`HttpOnly`；不发送到其他应用主机。
- **组件 origin**：只允许 `http://<appId>.localhost:<port>`。
- **WebView2**：组件页禁用下载、外部协议、开发者工具（调试构建除外）。
- **目录**：绝不返回 token；ticket 短 TTL、只读、仅内存。

---

## 10. 版本与兼容

- `schemaVersion=1` 是本冻结版本。
- 新增可选字段不升版本；Hub 忽略未知字段。
- 删除/改义字段、改变必填性、改变鉴权方式 → `schemaVersion=2`。
- Hub 遇到更高版本：显示「不兼容」，不连接、不启动。
- 应用应容忍 Hub 不认识新字段；Hub 应容忍应用返回多余字段。

---

## 11. 验收清单

| 编号 | 场景 | 期望 |
| --- | --- | --- |
| C-01 | 应用写入合法配置 | 5s 内出现在 Hub 列表 |
| C-02 | 配置文件损坏 | 只显示一张无效卡片，其他应用正常 |
| C-03 | 应用退出（state=stopped） | 列表保留，显示离线 |
| C-04 | 应用崩溃（state=running，pid 不存在） | 显示离线「进程已退出」 |
| C-05 | token 错误 | 显示鉴权失败，不显示能力 |
| C-06 | `/v1/info` 的 appId 与配置不一致 | 拒绝连接 |
| C-07 | 点「打开主窗」 | 应用主窗显示并置前 |
| C-08 | 添加组件 | WebView2 打开 `<appId>.localhost`，页面可交互 |
| C-09 | 两个应用的同名 cookie | 互不覆盖 |
| C-10 | 删除/改坏组件页 | 占位 + 重试，不崩溃 |
| C-11 | Agent 调 `list_agents` | 只返回在线 Agent，无 token |
| C-12 | 无 Hub token 调目录 | 401 |
