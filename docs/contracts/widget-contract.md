# 组件契约（`widget.json`）

> 状态：V2（2026-11-02）：组件窗口只由应用进程创建；wasm 渲染器与贴桌面层作废（代码迁移见 S5）
> 关联：[总体架构](../../DesktopAssembly/docs/desktop-shell.md) · [宿主控制协议](host-protocol.md)
> 配套 Schema：`registration.schema.json`（由旧 `app.schema.json` + `widget.schema.json` 合并，S5 落地）
> 适用范围：`sdemo.planner` 及后续所有要挂到桌面上的应用

---

## 1. 这份契约解决什么

组件登记里的 `widget` 段让 **DesktopAssembly 不用认识任何具体应用**，就能知道：

- 这个组件长什么样、多大、能拖到哪里、在哪一层；
- 它需要什么权限、什么时候该拉起应用；
- 宿主版本不够时怎么优雅降级。

组件窗口**只由应用自己创建、自己绘制**；宿主不渲染、不加载页面、不提供 WebView2。

**边界**：组件清单只描述「渲染属性 + 布局意图 + 生命周期」，不含业务语义。待办有几种状态、字段怎么叫，宿主一概不知道，也不许知道。

## 2. 目录约定

```
%LOCALAPPDATA%\SDemo\DesktopAssembly\registry\<appId>.json
├─ install        ← 启动配方（定义见 host-protocol.md §2）
├─ widget         ← 本文（不再单独成文件）
└─ mcp            ← MCP 指针

<应用自己的安装目录>   ← 用户选择（Program Files / 用户目录 / 便携），宿主不复制、不持有
```

- `widget` 是登记文件里的一个**对象**，不是独立文件；应用每次启动写整份登记。
- 宿主只读这份登记和自己那份 `trust\<appId>.json`；程序目录、图标路径都由应用在登记里给出。
- 一个应用 v1 只支持**一个**组件。`widget` 写成数组直接判非法，避免过早复杂度。

## 3. 完整示例（待办小组件）

登记文件里的 `widget` 段（外层 `install` / `mcp` 见 [host-protocol.md](host-protocol.md) §2）：

```json
{
  "id": "sdemo.planner.widget",
  "name": "待办",
  "description": "桌面待办清单：随时记一条，勾掉一条。",
  "version": "0.1.0",
  "hostApiVersion": "1.0",

  "size": { "width": 320, "height": 420, "maxWidth": 640, "maxHeight": 900 },

  "layer": "floating",

  "position": {
    "mode": "anchored",
    "corner": "top-right",
    "offsetX": 24,
    "offsetY": 24,
    "snapPx": 12,
    "rememberPerMonitor": true
  },

  "behavior": {
    "alwaysOnTopDefault": true,
    "dragMode": "app",
    "clickThrough": "toggleWithHotkey",
    "hideBehindFullscreenApp": true,
    "opacity": { "default": 0.92, "min": 0.55 },
    "keepAlive": "onDemand"
  },

  "focus": {
    "stealOnShow": false,
    "activateOnClick": true
  },

  "theme": {
    "mode": "auto",
    "followAccent": true,
    "surface": "acrylic"
  },

  "activation": {
    "hotkey": "Ctrl+Alt+T",
    "launchOnStartup": false,
    "showInTray": true
  },

  "permissions": ["http-localhost", "notifications"],

  "config": {
    "type": "object",
    "properties": {
      "showCompleted": { "type": "boolean", "title": "显示已完成", "default": false },
      "maxItems": { "type": "integer", "title": "最多显示条数", "minimum": 3, "maximum": 30, "default": 8 }
    }
  }
}
```

## 4. 字段表

| 字段 | 必填 | 说明 |
| --- | --- | --- |
| `id` | ✅ | 反向域名，`^[a-z0-9]+(\.[a-z0-9-]+)+$`，全局唯一；宿主用它匹配 `register` 的 `widgetId` |
| `name` / `description` / `version` | ✅ | 展示用；`version` 是组件版本，与 exe 版本独立 |
| `hostApiVersion` | ✅ | 形如 `"1.0"`；宿主只做「主版本相同 + 次版本 ≤ 宿主」的判定 |
| `size` | ✅ | 单位为 DIP；宿主按监视器 DPI 换算 |
| `layer` | ✅ | v1 只有 `floating`（悬浮）；`desktop`（贴桌面层）随 wasm 一起作废 |
| `position` | ✅ | 默认位置与记忆策略 |
| `behavior` | ✅ | 层级、拖动、穿透、透明度、保活 |
| `focus` | ✅ | 焦点策略，见 §7 |
| `theme` | ✅ | 主题跟随与表面材质 |
| `activation` | ⬜ | 快捷键、开机自启、托盘入口 |
| `permissions` | ⬜ | 缺省为空数组 = 最小权限 |
| `config` | ⬜ | 设置表单的 JSON Schema 子集，见 §8 |

`schemaVersion` / `appId` / `install` / `mcp` 属于外层登记（host-protocol §2），不重复出现在 `widget` 段。

未知字段**一律忽略**（向前兼容）；必填缺失或类型不符 → 判非法，整份登记不加载。

## 5. 组件窗口只由应用创建（唯一形态）

| 维度 | V2 约定 |
| --- | --- |
| 窗口由谁创建 | **应用进程**：组件窗口与主窗口在同一进程里，两个窗口 |
| 宿主做的事 | 跨进程做位置 / 尺寸 / z-order / 显隐 / 穿透位切换；回读矩形并落盘 |
| 半透明 | ✅ 应用自绘（`AllowsTransparency=true`，即 `WS_EX_LAYERED`） |
| 点击穿透 | ✅ 应用自绘 + 宿主切 `WS_EX_TRANSPARENT` |
| 贴桌面层（`layer=desktop`） | ❌ v1 非目标（原由 `wasm` 提供，已作废） |
| 崩溃隔离 | 组件与主窗口同进程；应用崩溃时组件一起消失，宿主显示占位并支持代拉起 |
| 首屏 | 由应用负责；宿主只负责拉起的骨架占位，不渲染组件内容 |
| 组件 UI 的技术栈 | 应用自己的选择（WPF / Blazor Hybrid / 任意），宿主不加载、不关心 |

**为什么废除 wasm（宿主 WebView2 渲染）**：

1. 宿主不再拥有程序目录，`payload\index.html` 这类「随宿主安装目录分发」的模型直接失效；
2. 一个后台应用同时提供组件 UI 与主窗口 UI 时，两套 UI 共用同一份内存状态；宿主再渲染一份，等于把同一视图拆成两个运行时并引入同步；
3. 半透明 / 点击穿透 / 贴桌面层在 WebView2 上本就有硬限制，维护双渲染器的收益是负的。

**应用侧对应义务**：PerMonitorV2 DPI 感知；自绘半透明与穿透样式；自己处理拖动、尺寸约束与 `SC_MINIMIZE`（不要写位置 / 层级 / 显隐策略）；窗口销毁时调 `POST /v1/apps/{appId}/unregister`，但主窗口关闭而组件仍在时**不要**发。

**为什么宿主不加载应用程序集**：组件窗口由应用自己创建，宿主只发 `SetWindowPos` / `SetWindowLongPtr` / `ShowWindow`。这避免了 `AssemblyLoadContext` 版本矩阵这一整摊事——也是 V2 继续只保留这一种形态的主要原因。

## 6. 布局声明（宿主执行，应用不碰）

| 声明 | 宿主行为 |
| --- | --- |
| `layer=floating` | 窗口置顶（`alwaysOnTopDefault` 决定初始值）；用户可右键切「置顶 / 普通」 |
| `position.mode=anchored` | 首次出现在指定角 + 偏移；拖动后转为 `remember` |
| `position.mode=remember` | 用 `widgets.json` 里存的矩形；载入时校验该矩形仍落在**当前**的某个显示器上，否则回落到锚点 |
| `snapPx` | 拖动松手时距离屏幕边缘 < `snapPx` 则吸附 |
| `rememberPerMonitor` | 按「显示器标识 + 分辨率」分组记忆位置；换显示器不丢布局 |
| `size` | 宿主不做内容布局，只约束窗口最小/最大尺寸 |
| `opacity` | 组件自绘透明度，宿主只传值并按 `opacity.min` 夹紧 |
| `hideBehindFullscreenApp` | 检测到前台是全屏窗口时降低 z-order 或隐藏，退出全屏后恢复 |

**位置回写**：应用处理拖动与尺寸（不写位置策略）；宿主用 `GetWindowRect`（host-protocol §7 白名单第 2 项）轮询回读，防抖后按「monitorKey + DIP」落盘。v1 不新增 app → host 的位置上报端点。混合 DPI 的换算口径见 host-protocol §8。

## 7. 焦点与「不可最小化」

`focus.stealOnShow = false`：宿主显示组件时用 `SWP_NOACTIVATE`，不会把你正在写的字切走。
`focus.activateOnClick = true`：用户主动点击时正常激活，输入框能打字（**不要**图省事加 `WS_EX_NOACTIVATE`，那会导致组件里的输入框永远拿不到焦点）。

「不可最小化」的落地组合（按 host-protocol §7 的跨进程边界拆职责）：

- **宿主负责**：显示不抢焦点（`SW_SHOWNOACTIVATE` / `SWP_NOACTIVATE`）；用 `GWL_EXSTYLE` 保证 `WS_EX_TOOLWINDOW`（不进任务栏 / Alt+Tab）；位置、显隐、层级。
- **应用负责**：自己的窗口**不提供最小化按钮**，并忽略 `WM_SYSCOMMAND / SC_MINIMIZE`；位置与尺寸不随主窗口联动。跨进程宿主**不能**挂窗口过程、也不能装全局钩子，因此契约**不得**把「拦截 `SC_MINIMIZE`」写成宿主职责。
- **Win+D（显示桌面）**：2026-11-01 实测结论为 **A**——组件窗口（tool window + `ShowInTaskbar=false` + 不激活显示）不会被 Win+D 收起，v1 不需要恢复策略；宿主仍保留「前台轮询状态机」兜底（不装钩子、不操作其它应用窗口），但不应把它当默认依赖。

> ⚠️ Win+D 行为依赖窗口样式与系统版本；换样式或平台要复测，不要对用户承诺「在所有输入路径下永远可见」。

## 8. `config`：设置表单的 Schema 子集

宿主用描述符渲染设置表单，**不加载任何应用代码**。只支持：

| 类型 | 控件 |
| --- | --- |
| `boolean` | 开关 |
| `integer` / `number` | 数字输入（带 `minimum` / `maximum`） |
| `string` | 单行输入（可选 `enum` → 下拉） |
| `string` + `format: "path"` | 文件/目录选择器（只读展示） |

不支持 `object` / `array` / `oneOf`。需要复杂表单的应用请在自己的主窗口里做，`config` 只承载「在桌面上顺手改一两个开关」这类需求。

**不支持的结构在登记校验阶段就判非法**（`WIDGET_CONFIG_INVALID`），而不是静默砍掉表单：宿主只渲染它承诺支持的那一小组控件，写错了应显式报出来。`default` 会落进 `widgets.json` 作为初值；之后扫描只补齐缺失项、把已存值夹回 `minimum/maximum`，用户改过的值不会被重置。值只存 `widgets.json`，不下发到应用设置（DA-63）。

枚举与路径的写法：`string` + `enum`（下拉）、`string` + `format: "path"`（文件/目录选择）；数值支持 `minimum` / `maximum`。

## 9. 校验与降级

| 情况 | 宿主行为 |
| --- | --- |
| `id` 重复 | 后加载的判失败（按登记文件名顺序） |
| 登记 `schemaVersion` 更高 | 跳过并提示「需要更新 DesktopAssembly」 |
| `config` 使用 `object` / `array` / `oneOf` / `$ref` | 判非法（`WIDGET_CONFIG_INVALID`），整份登记不加载：宿主只承诺 Schema 子集 |
| `activation.hotkey` 无法解析 | 只告警、不加载该热键（组件仍可用），注册冲突在面板/托盘提示 |
| `hostApiVersion` 主版本不同 | 禁用该组件，不影响其它组件 |
| `layer` 不是 `floating` | 判非法，整份登记不加载（契约冲突必须显式报错，不要静默纠正） |
| 未信任 / exe 不存在 / 哈希与台账不符 | 不显示、不启动；面板给「信任 / 重新确认 / 忽略」入口（见 host-protocol §10） |
| 组件窗口创建失败 | 宿主显示占位卡片（图标 + 组件名 + 错误摘要），布局状态保留 |

失败一律**隔离到单个组件**，沿用 [插件系统](../../DesktopAgent/docs/architecture/detail/plugin-system.md) 「坏一个不影响整体」的既有原则。

## 10. 与现有代码的对应关系

| 现有概念 | 组件契约里的对应物 |
| --- | --- |
| `PluginHostVersion`（[PluginHostVersion.cs](../../DesktopAgent/src/Plugins/SDemo.DesktopAgent.Plugins.Abstractions/PluginHostVersion.cs)） | `hostApiVersion`，同样的「主版本相同 + 次版本 ≤ 宿主」判定 |
| `PluginValidator`（[PluginValidator.cs](../../DesktopAgent/src/Plugins/SDemo.DesktopAgent.Plugins.Runtime/PluginValidator.cs)） | 清单校验器的写法可以直接照抄：逐字段校验、错误聚合成列表、不抛异常 |
| `PluginCatalog` 的扫描与降级 | 组件登记目录的扫描与降级 |
| 设置里的作用域覆盖 | 组件 `config` 的值存 `widgets.json`，不进应用设置 |

**不要复用插件系统的目录与清单**：插件是「给聊天用的声明式能力」，组件是「挂在桌面上的独立进程 UI」。两者生命周期、权限模型、失败域都不同，混在一起会让插件加载器背上一层它不该有的责任。
