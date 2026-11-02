# 宿主控制协议（DesktopAssembly ⇄ 应用）

> 状态：V2（2026-11-02）：应用自安装 + 自登记 + 宿主收养；`app.json` / `widget.json` 合并为组件登记，wasm 移除。代码迁移见 S5
> 关联：[总体架构](../../DesktopAssembly/docs/desktop-shell.md) · [组件契约](widget-contract.md)
> 适用范围：DesktopAssembly 与所有已安装应用之间的登记、进程、IPC、窗口管控约定

---

## 1. 角色与边界

| 角色 | 位置 | 权限 |
| --- | --- | --- |
| **宿主** `DesktopAssembly.exe` | 常驻；只拥有 `%LOCALAPPDATA%\SDemo\DesktopAssembly\` 下的指针与台账 | 发现登记、用户确认后收养、按登记代拉起 / 停止（仅自己拉起的实例）、跨进程管控组件窗口 |
| **应用** `<app>.exe` | 用户自行安装到任意目录；用户自启或由宿主按登记代拉起 | 拥有程序目录与数据；启动时写组件登记；暴露本机 HTTP；自建主窗口与组件窗口 |

协议的硬线：**宿主不安装应用、不持有程序目录，也永远不读应用的数据库；应用永远不改自己的 z-order / 屏幕坐标 / 显隐策略。** 两侧沟通只经过本机的回环 HTTP 与登记文件，不共享内存、不注入 DLL、不挂全局钩子。

## 2. 组件登记（`registry\<appId>.json`）

登记由**应用**在每次启动时写，持久保留（进程退出不删）。它把旧的 `app.json`（怎么跑进程）与 `widget.json`（窗口长什么样）合并成一份：上半是启动配方，下半是组件声明。

> Schema：`registration.schema.json`（由旧 `app.schema.json` + `widget.schema.json` 合并，落点见 S5）。
> 位置：`%LOCALAPPDATA%\SDemo\DesktopAssembly\registry\<appId>.json`，文件名取 `appId`。

```json
{
  "schemaVersion": 2,
  "appId": "sdemo.planner",
  "name": "待办",
  "appVersion": "0.1.0",
  "updatedAt": "2026-11-02T21:58:48+08:00",
  "install": {
    "executable": "C:\\Program Files\\SDemo\\Planner\\Planner.exe",
    "arguments": ["--ipc"],
    "sha256": "<64 位小写十六进制>",
    "singleInstanceMutex": "SDemo.App.sdemo.planner",
    "startupTimeoutMs": 8000,
    "idleTimeoutMs": 300000,
    "startup": "onDemand"
  },
  "icon": "C:\\Program Files\\SDemo\\Planner\\icon.png",
  "widget": { "…": "字段见 widget-contract.md §4" },
  "mcp": { "transport": "http", "path": "/mcp", "port": "runtime", "token": "runtime" }
}
```

| 字段 | 说明 |
| --- | --- |
| `schemaVersion` | 本文版本，当前 `2`。更高版本 → 不猜测，判 `unsupported` |
| `install.executable` | **绝对路径**，必须是存在的文件；不接受 `..`；解析符号链接 / junction 后与信任台账比对 |
| `arguments` | 数组，逐项传给进程，**不经 shell 拼接** |
| `sha256` | 应用自己算的可执行文件哈希；宿主只有与信任台账一致时才启动 |
| `singleInstanceMutex` | 应用自己的单实例互斥量，宿主不抢 |
| `startupTimeoutMs` | 拉起后等待 `runtime.json` 出现 + 健康检查通过的上限 |
| `idleTimeoutMs` | 仅对宿主拉起的实例生效；`0` = 常驻不退出 |
| `startup` | `onDemand`（默认）/ `host`（壳启动后拉起）/ `manual`（只由用户或 Agent 拉起）；用户可用 `widgets.json.startupOverride` 覆盖（Q16） |
| `icon` | 可选，绝对路径 PNG / ICO；缺省时宿主用占位图标 |
| `widget` | 组件声明，字段见 [widget-contract.md](widget-contract.md) §4 |
| `mcp` | 仅供 MainAgent 发现，宿主只透传、不解析工具语义 |

**为什么合并**：旧结构拆分的前提是宿主持有安装目录、要分别校验两份清单；V2 里两份都由应用写、都在登记目录，再拆只会多一次读写和一次不一致窗口。

**写入时序**：应用完成内核启动（DB / HTTP 绑定）→ 写 `runtime\<appId>.json` → 写 `registry\<appId>.json` → `POST /v1/apps/{appId}/register`。启动失败时应用应删掉自己的运行时文件；登记可以保留，让宿主显示「启动失败」。

## 3. 发现与启动状态机

```
Discovered → Untrusted → Trusted → Launching → Handshaking → Ready ⇄ Idle → Stopped
                  │          │          │             │
                  │          │          └──────► Failed ◄┘
                  │          └──────► Changed（路径/哈希不符，待重新确认）
                  └──────► Ignored（用户选择不接管）
```

| 状态 | 判定 | 失败处理 |
| --- | --- | --- |
| Discovered | 扫描到 `registry\*\*.json` 且语法/必填通过 | 语法错 → 跳过并记录，不删应用的文件 |
| Untrusted | 登记存在，但 `trust\<appId>.json` 没有 | **不显示、不拉起**；面板/托盘显示「发现新组件，是否信任」（附路径 + 哈希） |
| Changed | 有台账，但 exe 路径或 sha256 与台账/磁盘不符 | **不显示、不拉起**；提示「应用已更新或移动，需要重新确认」 |
| Trusted | 用户确认过；登记可解析、exe 存在 | — |
| Launching | 宿主已按登记拉起，等待 `runtime.json`；或发现用户已启动的实例 | 超时 → 退避重启（只限自己拉起的实例） |
| Handshaking | `GET /v1/health` + `POST /v1/handshake` | 401 / 版本不符 → Failed（不重试） |
| Ready | 握手通过、组件窗口已通过 `register` 上报 hwnd | — |
| Idle | 仅宿主拉起的实例：组件隐藏且超过 `idleTimeoutMs` 无调用 | 发 `POST /v1/shutdown`，超时后 `TerminateProcess`；用户自启的实例只发请求，不强杀 |
| Stopped | 无存活实例，登记仍在 | 组件显示占位；按 `startup` 策略可代拉起 |

> 应用可通过 `POST /v1/widgets/{id}/request { "kind": "idleHold", "value": true }` 声明「暂不空闲退出」；宿主只存内存标志，进程退出即清（见 [host-endpoints](../../DesktopAssembly/docs/host-endpoints.md) §6、DA-95）。

**接管（DA-22，V2 修订）**：拉起或接管前先读该应用的 `runtime.json`。若 pid 仍存活、**该进程的真实 exe 路径等于信任台账里的路径**、且用文件里的 token 完成 `/v1/health` 与 `/v1/handshake`，则**直接接管**（不产生第二个进程）；否则按 §4 处理残留指针。**只校验 pid 存活和进程名是不够的**：必须比对 exe 路径，避免接管一个同名的无关进程。

**首次发现**：登记只是「应用说我在这里」，不是「宿主批准安装」。宿主必须等用户在面板/托盘确认路径与哈希后写信任台账，才允许显示组件或拉起进程。

启动顺序：宿主先显示**骨架态**（组件外框 + 图标 + 「正在启动」），进程就绪后再切换到真实窗口。绝不允许白窗或无提示的 1 秒空白。

## 4. 单实例与 `runtime.json`

应用启动后立即：

1. 打开命名互斥量 `SDemo.App.<appId>`；已存在则**不新建窗口**，直接读既有 `runtime.json` 连上去；
2. 绑定 `127.0.0.1:0`（系统分配端口，**不写死**）；若所用 HTTP 服务器不接受端口 0，可先探测空闲端口再绑定。
3. 写 `%LOCALAPPDATA%\SDemo\DesktopAssembly\runtime\<appId>.json`，ACL 设为仅当前用户。

```json
{
  "pid": 24812,
  "port": 51423,
  "token": "…",
  "startedAt": "2026-10-28T23:40:12+08:00",
  "appVersion": "0.1.0",
  "hostApiVersion": "1.0"
}
```

- 宿主每隔 2s 轮询该文件（最长 `startupTimeoutMs`）；文件里的 `pid` 已退出时删除残留文件再重试。
- **token 来源**：宿主拉起时通过环境变量 `SDEMO_APP_TOKEN` 传入（32 字节 base64url），应用写进 `runtime.json` 供宿主读回；用户自行启动时由应用生成。两种路径下 token 都**只在本机、只在本次进程存活期间有效**，重启即换。
- **一致性校验**：宿主拉起下发的 token 必须原样写入 `runtime.json`；宿主读回时逐次比对，不一致视为 `HOST_TOKEN_INVALID`，**不重试**（防止旧实例或串线实例被误接管）。
- **自启实例的接受条件（V2）**：只有「该 pid 的真实 exe 路径 == 信任台账里的路径」时，宿主才读这份 `runtime.json` 并握手；路径不符则忽略并记日志，**不杀进程**。
- **与登记的关系**：`runtime.json` 只在进程存活期存在，退出（含崩溃）后由应用或宿主删除；`registry\<appId>.json` 是持久登记，退出后**保留**。
- 端口与 token 必须写在 `%LOCALAPPDATA%`：它们绑定本机进程，**不可随 `%APPDATA%` 漫游**；文件 ACL 依赖用户配置目录继承（仅当前用户），壳不额外改写 ACL。

> 宿主自身的监听器、`host.json`、`client-token` 与 Agent 使用的 client 面端点，见 [host-endpoints.md](../../DesktopAssembly/docs/host-endpoints.md)；本节只定义每个应用的 `runtime.json`。

## 5. 握手与鉴权

- 所有请求带 `Authorization: Bearer <token>`；除 `/v1/health` 外全部校验。
- 只监听 `127.0.0.1`，禁止 `0.0.0.0` / `::`；不设 CORS（浏览器不该访问到它）。
- 失败 3 次以上，宿主视为被劫持，直接停止该应用并把组件置为错误态。

```
POST /v1/handshake
{ "hostVersion": "0.1.0", "hostApiVersion": "1.0", "widgetId": "sdemo.planner.widget" }

200 OK
{ "appVersion": "0.1.0", "hostApiVersion": "1.0", "capabilities": ["native-window", "notifications"] }
```

`capabilities` 用来做**双向降级**：宿主认识但应用不支持的能力（例如后续的悬浮角标），宿主自行关闭，不问用户。

## 6. 端点表

### 6.1 宿主 → 应用（`http://127.0.0.1:{port}`）

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| GET | `/v1/health` | 存活探测，返回 `{ ok, pid, since }` |
| POST | `/v1/handshake` | 交换版本与能力 |
| POST | `/v1/shutdown` | 优雅退出 `{ graceMs: 2000 }` |
| POST | `/v1/widgets/{id}/command` | 宿主指令：`show` / `hide` / `focus` / `refresh` / `themeChanged` / `configChanged` |
| GET | `/v1/widgets/{id}/state` | 组件状态（用于宿主显示占位与诊断） |

`POST /v1/widgets/{id}/command` 的 body（C3：此前未定义，这里补全）：

```json
{
  "command": "show",
  "opacity": 0.92,
  "theme": "dark",
  "config": { "maxItems": 8 }
}
```

| 字段 | 说明 |
| --- | --- |
| `command` | 必填，`show` / `hide` / `focus` / `refresh` / `themeChanged` / `configChanged`；未知指令 → 400 |
| `opacity` | 可选，0–1；组件自绘透明度，宿主只传值（运行时由宿主按登记里 `opacity.min` 夹紧） |
| `theme` | 可选，`dark` / `light`；与 `themeChanged` 一起用 |
| `config` | 可选，`widgets.json` 里该组件的 config 值快照；与 `configChanged` 一起用 |

成功返回 200（body 可为空或 `{ "accepted": true }`）；宿主不读取应用返回值，只按状态码判断。

### 6.2 应用 → 宿主（`SDEMO_HOST_URL`）

| 方法 | 路径 | 用途 |
| --- | --- | --- |
| POST | `/v1/apps/{appId}/register` | 组件窗口上报：`{ widgetId, hwnd, dpiAware: "per-monitor-v2", registrationRev }`；未信任 / 哈希不符 → `403 APP_UNTRUSTED` |
| POST | `/v1/apps/{appId}/unregister` | 窗口销毁（主窗口关闭但组件仍可显示时**不要**发） |
| POST | `/v1/notify` | 请求宿主弹通知 `{ title, body, level }`；需清单声明 `notifications`，首次使用弹一次授权（DA-66） |
| POST | `/v1/widgets/{id}/request` | 声明意图：`layer` / `alwaysOnTop` / `clickThrough` 的**切换请求**（宿主可拒绝） |
| GET | `/v1/host/info` | 宿主版本、主题、强调色、语言、当前显示器集合 |

**注意**：`request` 是「请求」不是「设置」。宿主是唯一的策略执行者，收到越界请求（例如让宿主显示/关闭主窗口、改显隐策略）返回 `403 HOST_POLICY_DENIED`，并在日志里记一条。

> 以上是 **app 面**（应用 token）。**client 面**（Agent 的 `GET /v1/host`、`GET /v1/apps`、`POST ensure`）与两类 token 的配对规则见 [host-endpoints.md](../../DesktopAssembly/docs/host-endpoints.md) §5–§7。

## 7. 窗口管控白名单（组件窗口 = 应用自绘）

宿主对别的进程的窗口**只允许**做以下 6 件事：

| # | Win32 操作 | 用途 |
| --- | --- | --- |
| 1 | `SetWindowPos` | 位置、尺寸、z-order（`HWND_TOPMOST` / `HWND_NOTOPMOST` / `HWND_BOTTOM`） |
| 2 | `GetWindowRect` | 读取实际矩形（拖动后回写布局状态） |
| 3 | `SetWindowLongPtr(GWL_EXSTYLE)` | 只允许改 `WS_EX_TOOLWINDOW`（不进任务栏/Alt+Tab）与 `WS_EX_TRANSPARENT`（穿透开关） |
| 4 | `ShowWindow` | `SW_HIDE` / `SW_SHOWNOACTIVATE`（显示但不抢焦点） |
| 5 | `PostMessage(WM_CLOSE)` | 优雅关窗 |
| 6 | `SetWindowDisplayAffinity` | 可选：用户开启「截屏隐藏」时 |

**明令禁止**：

- `SetParent` / 修改 `GWLP_HWNDPARENT` —— 跨进程改父窗或属主在 Windows 上会导致 DPI、输入法、焦点的一系列问题；
- 改 `WS_CHILD` 等窗口本质样式；
- `SetWindowsHookEx` 全局钩子、`SendMessage` 跨进程同步阻塞调用；
- 接管应用的消息循环、替应用处理 `WM_DPICHANGED`。

> 宿主不再有「自己的组件窗口」：V2 取消了 wasm 渲染器，组件窗口一律是应用的窗口，因此 `SetParent` / WorkerW / 桌面层相关的同进程豁免**一并作废**。宿主对组件窗口只走这张白名单。

应用侧对应义务：**必须** PerMonitorV2 DPI 感知；自己处理拖动与尺寸约束（**不要**写入位置/层级/穿透策略），宿主用 `GetWindowRect` 回读矩形并独占写 `widgets.json`。

**位置回写（v1）**：宿主每 250ms 读取已登记窗口的实际矩形，松手/停止变化 500ms 后把「monitorKey + DIP 矩形」落盘；v1 **不引入** app → host 的「上报位置」端点。需要更精确的双向回写时再走契约变更，不要私加隐式接口。

## 8. 位置、多屏与 DPI

| 规则 | 说明 |
| --- | --- |
| 存储单位 | DIP（设备无关像素），不是物理像素 |
| 存储键 | `显示器标识 + 分辨率 + DPI` 的三元组哈希 |
| 载入校验 | 存的矩形必须与**当前**某个显示器至少有 80×80 可见；否则回落到组件登记里 `position` 的锚点位置 |
| 显示器变更 | 监听 `WM_DISPLAYCHANGE`，重新校验全部组件 |
| 显示器拔插 | 消失的那块上的组件迁到主屏右下角，不叠在一起（按 `id` 排序错开 24px） |
| 吸附 | 松手时距边 < `snapPx` 吸附；吸附值本身也持久化 |

**混合 DPI 坐标口径（C8）**：v1 的 DIP 换算以「组件所在显示器的有效 DPI」为基准；跨屏拖动到不同缩放比例的显示器时，按**目标屏**的 DPI 重映射并重新落盘。混合 DPI 下跨多屏的全局绝对 DIP 精确往返不在 v1 承诺（验收覆盖单屏 100%/125%/150% 与同缩放多屏）。

## 9. 生命周期与退出顺序

1. 宿主退出 → 只对**宿主自己拉起**的实例发 `shutdown`（等 2s）→ 超时 `TerminateProcess` → 保存 `widgets.json` → 退出。用户自启的实例不碰。
2. 应用崩溃（宿主拉起的）→ 占位卡片 + §3 退避重启；重启成功后组件回到原位。用户自启实例崩溃 → 只显示占位，等应用自己重启或用户手动启动。
3. 应用主动退出 → 删除自己的 `runtime.json`，组件转占位、布局保留，下次启动/拉起后恢复。
4. 应用卸载（由应用自己的卸载器执行）→ 删除 `registry\<appId>.json`；宿主发现登记消失后清理信任台账与窗口，**保留** `widgets.json` 里的布局和 `%APPDATA%\SDemo\Apps\<appId>\` 数据。

## 10. 安全模型（V2：登记可伪造，信任台账是唯一锚点）

| 面 | 措施 |
| --- | --- |
| 组件登记 | 登记目录本机用户可写，**任何登记默认不可信**；未信任状态不显示、不拉起 |
| 首次收养 | 用户必须在面板里看过 exe 绝对路径 + sha256 后才确认；确认结果写 `trust\<appId>.json` |
| 可执行文件 | 每次启动 / 接管前比对台账哈希；不符 → `APP_BINARY_CHANGED`，要求重新确认（不提供「仍然启动」） |
| 路径 | `executable` 是绝对路径，但解析符号链接 / junction 后的真实路径必须与台账一致；不一致 → `APP_PATH_MISMATCH` |
| 接管 | 必须比对 pid 对应进程的真实 exe 路径；只比对 pid 存活或进程名会误接管同名进程 |
| 传输 | 仅回环、随机端口、随机 token、进程级有效 |
| 权限 | 组件 `permissions` 里的每项由宿主在设置页展示与授权（`http-localhost` 默认给，`notifications` 首次用时询问） |
| 升级 | 应用自行升级后哈希变化 → 宿主提示「应用已更新，是否允许新版本」；旧哈希保留一条以便回滚 |
| 数据 | 宿主不接触应用数据目录；应用数据权限继承用户目录 ACL |

## 11. 错误码

| 码 | 含义 | 宿主行为 |
| --- | --- | --- |
| `HOST_POLICY_DENIED` | 应用请求了非法策略（如让宿主显示主窗口） | 拒绝，记日志，不改状态 |
| `APP_UNTRUSTED` | 登记未获用户确认 / register 被拒 | 不显示、不拉起，面板给「信任 / 忽略」 |
| `APP_BINARY_CHANGED` | exe 哈希与台账不符 | 不启动，提示重新确认 |
| `APP_PATH_MISMATCH` | exe 真实路径与台账不符 | 不启动 / 不接管，记日志 |
| `HOST_VERSION_MISMATCH` | 握手版本不符 | Failed，不重试，提示升级 |
| `HOST_TOKEN_INVALID` | 鉴权失败（累计 3 次） | 停止应用并置错误态 |
| `APP_START_TIMEOUT` | 启动超时 | 退避重启 |
| `APP_CRASHED` | 启动后异常退出 | 退避重启，3 次后转错误态 |
| `APP_HEALTH_FAILED` | 健康检查连续失败 | 同上 |
| `WIDGET_WINDOW_LOST` | 组件窗口句柄失效（`IsWindow` 为假） | 通知应用重建窗口，保留布局 |
| `TODO_CONFLICT` 等业务码 | 见 [todo-mcp-surface.md](../../Apps/Planner/docs/planner-mcp-surface.md) | 宿主透传，不解释 |

## 12. 日志与诊断

- 宿主日志：`%LOCALAPPDATA%\SDemo\logs\desktop-assembly\yyyy-MM-dd.log`，按天分文件、单文件上限 10MB。
- 每个应用在自己的日志里记 `requestId`，宿主记录的 `requestId` 与之对应，排障时可以串起一次调用。
- 托盘菜单提供「组件诊断」：列出每个组件的状态、最后错误、端口与 pid、一键复制诊断信息。
