# 转写中继契约（asr-relay）

> 状态：**草案 v0.1（2026-11-15）· 未启用**。v1 只跑本地引擎；本契约只为"云端转写"预留形状，实现前必须走完 [契约改动流程](../integration.md) §5。
> 关联：[ASR 运行时](../../Apps/Meeting/docs/asr-runtime.md) · [hub-protocol](hub-protocol.md) §2/§9（鉴权与回环模式）· [integration.md](../integration.md) §4（审批矩阵）
> 一句话：**应用不出网、不持凭证；需要出网的长任务写成"请求"，由 DesktopAgent 执行并回写。**

---

## 0. 为什么需要这份契约

本地转写不需要任何跨进程协议——引擎在 Meeting 进程里，权重是资产不是凭证。

但云端转写不行：它需要 API Key，而「应用零模型凭证」是铁律。所以云端那条路必须是：

```
Meeting 写请求  →  DesktopAgent 持 Key 执行  →  回写结果
```

本契约定义这条通道的形状。**它同时是会议分析（map-reduce）那条通道的模板**——两者结构完全一样，只是 `kind` 不同。

### 0.1 为什么不做成 MCP 工具

| 问题 | 后果 |
| --- | --- |
| 工具调用是同步的、有结果预算（默认 2000 字符/条） | 1 小时音频要 4–10 分钟，卡在一个对话轮里必然超时 |
| 工具面是给"模型看"的 | 转写是应用发起的，不该由模型决定要不要转 |
| 工具面随 Agent 演化 | 排序 / toolHints / 审批一改，写入方全受影响 |

**结论：长任务走内部 HTTP 中继（回环 + token），不走 MCP。**

---

## 1. 角色

| 角色 | 谁 | 职责 |
| --- | --- | --- |
| **派发方**（producer） | 应用（v1 只有 `sdemo.meeting`） | 建请求、给音频、收结果、建 `transcript_run` |
| **执行方**（relay） | `sdemo.agent` | 轮询请求、取音频、调云端 ASR、回报进度与结果 |
| **不做** | KB、宿主 | 不参与；KB 不读转写正文 |

执行方**必须**是持有凭证的那个进程。今天它是 Agent；将来若出现 ModelHost，云端仍归 Agent（ModelHost 只管本地权重）。

---

## 2. 传输与鉴权

| 项 | 约定 |
| --- | --- |
| 地址 | `http://127.0.0.1:<port>/v1/asr/...`，端口写入 `%LOCALAPPDATA%\SDemo\Hub\apps\sdemo.meeting.json` |
| 监听 | 仅回环，拒绝非 127.0.0.1 |
| 鉴权 | `Authorization: Bearer <agent token>`；token 由 Meeting 签发，落 `tokens\sdemo.agent.token`（与 KB 的分发方式同构） |
| 主体 | token 绑定 `appId = sdemo.agent`；服务端不接受自报 appId |
| 出站 | Agent 只出站到用户配置的 ASR 端点，不向其它地址发数据 |

与 [kb-ocr](../../DesktopAgent/docs/guide/kb-ocr.md) 的区别：KB 是 Agent **拉**（`GET /v1/derivations`），这里也是 Agent 拉（`GET /v1/asr/requests`），方向一致——**永远是 Agent 主动，应用从不反向调用**。

---

## 3. 端点

| 动词 | 路径 | 说明 |
| --- | --- | --- |
| `GET` | `/v1/asr/requests?status=queued&limit=4` | 取待执行请求（Agent 轮询） |
| `POST` | `/v1/asr/requests/{runId}/claim` | 认领，状态 `queued → running`（防并发重复执行） |
| `GET` | `/v1/asr/audio/{runId}` | 受限下载音频（`audio/m4a`，单次 ≤ 100 MB） |
| `POST` | `/v1/asr/progress` | 进度回报（`{runId, percent, etaSeconds}`），可高频 |
| `POST` | `/v1/asr/result` | 最终结果（分段 + 可选字级时间戳 + warnings） |
| `POST` | `/v1/asr/fail` | 失败回报（错误码 + 可读消息 + 是否可重试） |
| `POST` | `/v1/asr/cancel` | 应用侧取消（用户点了取消） |

**没有** `POST /v1/asr/requests`（应用不能替 Agent 建请求，也不需要）。请求由应用在建 run 时产生。

---

## 4. 状态机

```
queued ──claim──► running ──result──► done
  │                  │
  │                  ├──fail(retryable)──► queued（指数退避，最多 3 次）
  │                  ├──fail(fatal)──────► failed
  │                  └──cancel───────────► cancelled
  └──timeout(10min)─────────────────────► expired（回到 queued 或标记放弃）
```

规则：

1. **认领超时 90 秒**：`running` 但没有 progress 心跳，自动回到 `queued`（Agent 崩溃后不会卡死）。
2. **执行上限**：同机并发 2 个转写任务，超出返回 `409 busy`，Agent 下一轮再来。
3. **重试上限 3 次**，第 3 次仍失败标 `failed` 并保留原因，UI 显示"可重试"。
4. `cancelled` / `failed` 的 run 保留已完成分段（`partial = true`）。

---

## 5. 数据结构

### 5.1 请求（`GET /v1/asr/requests` 返回）

```jsonc
{
  "runId": "01HA7K…",
  "meetingId": "01HA2Q…",
  "backend": {                       // 应用侧选的 backend，Agent 只校验不采信
    "id": "deepseek.asr",
    "kind": "remote",
    "providerId": "deepseek",
    "apiShape": "deepseek-asr",      // openai-audio | deepseek-asr | volc-asr
    "modelId": "deepseek-asr"
  },
  "audio": {
    "url": "/v1/asr/audio/01HA7K…",
    "mime": "audio/m4a",
    "bytes": 19327352,
    "durationMs": 2838000
  },
  "languageHint": "zh",              // zh | en | ja | auto
  "hotwords": ["SDemo", "Qwen3-ASR"],
  "relayVersion": 1
}
```

**`apiShape` 是必须的**：DeepSeek 的 ASR 是独立接口、火山 ASR 2.0 是 WebSocket，都不是 OpenAI 形状。把它做成枚举，适配器写在 Agent 侧，应用永远不感知。

### 5.2 结果（`POST /v1/asr/result`）

```jsonc
{
  "runId": "01HA7K…",
  "engine": "deepseek.asr",
  "model": "deepseek-asr",
  "timestamps": "segment",           // segment | word
  "usage": { "audioSeconds": 2838, "costCny": 0.31 },
  "segments": [
    { "startMs": 750000, "endMs": 783000, "text": "…", "confidence": 0.92, "lang": "zh" }
  ],
  "warnings": [
    { "code": "LANG_SWITCH", "atMs": 1820000, "detail": "zh→en" }
  ]
}
```

### 5.3 字段约束

| 字段 | 约束 |
| --- | --- |
| `runId` | 应用生成（UUIDv7），全局唯一，**所有回报按它幂等** |
| `segments[].startMs/endMs` | 相对音频起点，单调不减；越界直接拒绝 |
| `timestamps` | 应用按此决定 KB anchor 精度（`word` 才允许"跳到那句话"） |
| `usage.costCny` | 有价才知道贵；缺失时 UI 显示"未知"而不是 0 |
| `warnings` | 不阻断，但**必须透传到 UI**（语言切换、低置信、可能幻觉） |

---

## 6. 幂等、超时与重试

| 场景 | 约定 |
| --- | --- |
| 同一 `runId` 重复 `result` | 只接受第一次，后续返回 `200 {duplicate: true}`，不覆盖 |
| Agent 重启 | 启动时把本机所有 `running` 且无心跳的请求重置为 `queued` |
| 音频过大 | `bytes > 100MB` 直接 `413`，应用侧提示"请分段或改用本地" |
| 网络失败 | Agent 侧退避 5s/30s/2min，三次后 `fail(retryable=true)` |
| 应用重启 | `run` 表与请求表同库同事务，重启后状态一致 |

---

## 7. 错误码

| code | HTTP | 含义 | 应用侧表现 |
| --- | --- | --- | --- |
| `ASR_NO_BACKEND` | 400 | 用户没配这个云端 backend | 提示去 Agent 设置里配 |
| `ASR_AUTH_FAILED` | 401 | 上游 Key 无效 | 提示 Key 失效，不自动重试 |
| `ASR_QUOTA` | 429 | 上游限流/欠费 | 退避重试，UI 显示原因 |
| `ASR_AUDIO_TOO_BIG` | 413 | 超 100MB | 建议分段或改本地 |
| `ASR_UNSUPPORTED_FORMAT` | 415 | 上游不收这个格式 | 应用侧转码后重试一次 |
| `ASR_BUSY` | 409 | 本机并发已满 | 排队，不算失败 |
| `ASR_UPSTREAM_ERROR` | 502 | 上游 5xx | 可重试 |
| `ASR_PARTIAL` | 200 | 只完成一部分（用户取消） | 建 partial run |

---

## 8. 隐私与审计

1. **逐场显式确认**：切云端不是全局开关，是"这一场 47 分钟 / 18.4 MB 将上传，约 0.31 元"的一次确认（可勾选记住）。
2. **审计落库**：`kb_audit` 同构的 `mtg_audit` 记录 `{runId, backend, bytes, durationMs, costCny, at}`，**不记正文**。
3. **不静默降级**：云端失败**不许**偷偷改用另一个云端厂商；只允许回落本地，且必须在 UI 标注。
4. **日志**：正文永不进日志；`runId` 可查。

---

## 9. 版本

| 项 | 约定 |
| --- | --- |
| `relayVersion` | 整数，随破坏性改动 +1；服务端不接受高于自己的版本 |
| `apiShape` | 新增形状只增不改；未知形状返回 `400 UNSUPPORTED_SHAPE` |
| 工具面 | 与 MCP 工具面**完全解耦**，不共享版本号 |

---

## 10. 未决

| # | 问题 | 说明 |
| --- | --- | --- |
| Q1 | 是否与"会议分析请求"合并成一份 `agent-relay.md` | 两者结构相同（请求-认领-进度-结果），合并后加一个 `kind: asr \| analysis` 字段。**实现阶段 E 时优先做这个判断**，能少一份契约就少一份 |
| Q2 | 音频给 URL 还是给本机路径 | 本版用受限下载端点（更严）；KB 的 OCR 用的是裸 `storedPath`（同机同用户信任边界），两者不一致，需要统一口径 |
| Q3 | 是否允许 Agent 在无 Meeting UI 时自动续转 | 影响"隔夜转写"体验，依赖 asr-runtime Q2 |
| Q4 | `hotwords` 上限与长度 | 取决于上游 API 限制，需按 `apiShape` 分别定义 |
