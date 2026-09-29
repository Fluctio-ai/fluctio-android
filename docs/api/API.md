# fluctio gateway HTTP API 契约（安卓客户端视角）

- 反推自 `fastclaw` dev 分支 `internal/setup/server.go`（路由注册）+ `internal/setup/handlers*.go` + `internal/auth/auth.go` + `internal/agent/loop.go`，2026-09-29。
- 本文档是 fluctio-android 的**唯一事实源**：端点失配先改这里再改码。标注 `待补` 的字段在实现对应功能时读 handler 补全。

## 0. 通用约定

- 基址：用户配置（如 `https://<domain>`），本地默认 `http://127.0.0.1:18953`。
- 全部 JSON（除文件上传/下载/SSE）。
- 错误形状统一为 `{"ok": false, "error": "<msg>"}`；chat/stream 早退路径是裸 `{"error": "<msg>"}`——**客户端解析错误时两种都要认**。
- 时间戳：Unix 毫秒（`int64`）。
- 路由使用 Go 1.22 method+path 风格；`{id}` 为路径段。

## 1. 认证

**主路径（APP 采用）：cookie session。**

- `POST /api/login` 成功后 `Set-Cookie: fluctio_session=<sid>`（HTTPS 下带 `Secure; HttpOnly`）。后续所有请求带该 cookie 即可，`internal/auth/auth.go` 的 `extract()` 优先读 cookie。
- 客户端持久化：将 sid 存加密存储（Keystore），启动时恢复为 cookie。session 可能被服务端撤销（改密/登出全部设备）→ 收到 401 即回登录屏。
- 限流：按 IP+登录名，超限 `429 {"error": "too many attempts; retry in a few minutes"}`。

**备用路径：Bearer apikey。**

- `Authorization: Bearer fc_...`，对 `apikeys` 表校验，可有 per-agent ACL（`agent_scope`）。程序化访问用；APP 不作主登录。

**query `?token=` 例外**（仅 3 处，其余必须 header/cookie）：
- `GET /api/agents/*/files*`、`GET /api/agents/*/system-files/*`、`GET /api/chat/subscribe`。

## 2. 探活与状态

| 端点 | 说明 |
|---|---|
| `GET /healthz` `/livez` `/readyz` | 无鉴权，200 `ok` 文本。**APP 连通性测试用这个** |
| `GET /api/status` | optionalAuth；onboard 状态等（形状待补，登录前界面分支用） |
| `POST /api/onboard` | 首次设置（自部署已有实例无需） |

## 3. 登录态与账号

| 端点 | Body / 响应 |
|---|---|
| `POST /api/login` | req `{"login": "...", "password": "..."}` → `200 {"ok":true,"user":{...}}` + Set-Cookie；`401` 凭证错；`429` 限流 |
| `POST /api/logout` | 吊销 session + 清 cookie → `{"ok":true}` |
| `GET /api/me` | → `{ok, user, authMethod, deployMode("self-hosted"\|"hosted")}`；user 含 `avatarURL`（可缓存图片 URL 而非 base64） |
| `PUT /api/me` | `{"displayName": ...}` 待补 |
| `POST /api/me/password` | 改密（待补；成功后会话吊销语义注意） |
| `GET/POST /api/me/avatar` | 头像读/传（传 base64，上限 256KB） |
| `POST /api/push/devices` `DELETE /api/push/devices/{token}` | APNS 设备注册（安卓不用） |

## 4. 发消息（核心）

### `POST /api/chat/stream` — SSE 流式（APP 默认）

请求体（`chatRequest`，全字段）：

```json
{
  "agentId": "agt_xxx",        // 必填
  "sessionId": "web-ui",       // 空串 = 沿用当前；新会话传新 key
  "projectId": "",             // 可选；会话行不存在时作为归属项目的 hint，行存在后被服务端覆盖
  "message": "文本",
  "images": ["data:...|https://..."],   // 视觉直显内容（data URL / HTTPS URL）
  "imageUrls": [...],                    // 同 images，web 历史拼写，二者合并
  "attachments": [{"url":"data:...","name":"report.pdf"}], // 仅落 /workspace，不进视觉；name 作为文件名
  "params": {},                // 可选透传（如 lang）
  "rollbackPendingUser": false // true = 先丢弃上一条未应答 user 再追加（失败重发流程）
}
```

语义要点（`handlers.go:1304`）：

- 附件先物化进会话工作区，正文自动追加 `[Attached: /workspace/X]` 面包屑。
- **断连不杀 turn**：agent 跑在 detached ctx（45min 上限），断线重连后用 `GET /api/chat/subscribe?since=<seq>` 补齐。**客户端绝不因网络断开把 UI 置为"已停止"**。
- 同会话旧在飞 turn 会被 supersede（用户刷新而非停止的场景）。
- 每 30s 一条 `: ping` 注释行保活；`X-Accel-Buffering: no`。

**SSE 线协议**：

```
id: 42
data: {"seq":42,"type":"content_delta","data":{"delta":"增量文本"}}
```

- 只有 `id:` 行 + `data:` 行（**无 `event:` 行**），载荷是 JSON。
- `seq` 同时在 `id:` 行与 JSON 内（fetch 解析器与并行 subscribe 去重用）。

**事件类型表**（data 形状反推自 `agent/loop.go` 各 `emitEvent` 调用点）：

| type | data 形状 | 客户端处理 |
|---|---|---|
| `content_delta` | `{"delta":"..."}` | 追加到进行中气泡。**seq=-1 且不持久化**（`loop.go:1206`）；subscribe 端点**不转发** delta（`handlers.go:1642`）——重连者收不到增量，靠最终 `content` 全文兜底 |
| `content` | `{"content":"全文"}` | 提交/替换当前流式气泡；**每轮 ReAct 迭代发一次**，多迭代 = 多个 content 段（`loop.go:3645`）。metadata 仅部分路径携带 |
| `tool_call` | `{"id","name","arguments"}` | 工具卡片区（`loop.go:3651`） |
| `tool_result` | `{"id","name","result","metadata"?}` | 按 id 配对工具卡（`loop.go:3891`） |
| `function` | — | 未观测到 wire 下发，忽略 |
| `auth_prompt` | `{"description","options":[{"cmd","label_zh","label_en"}]}`（`loop_auth.go:96`） | **持久化可回放**；应答 = 向在飞 turn steer 一条 `/yes` `/no` `/auto` `/yolo`（web 同款，`chat-screen.tsx:2553`） |
| `steer` | `{"content":"..."}`（`loop.go:2704`） | 插话回显；与本地乐观 steer 气泡按文本去重 |
| `session_title` | `{"sessionKey","title"}`（`memory.go:662`） | 更新会话列表标题 |
| `compaction_notice` | `{"content","before","after","retained_turns"}`（`loop.go:3316`） | 提示上下文压缩 |
| `reconnecting` | `{"attempt","backoffMs"}`（`loop.go:2938`） | LLM 层重连提示（从第 2 次重试起） |
| `turn_pending` | （内部信号） | **不下发到 wire**（handler 吞掉），无需处理 |
| `error` | `{"message":"..."}` | 错误提示 |
| `done` | 无 data | 结束本轮；agent 零输出时 handler 合成 `error: "agent finished without emitting a response"` + 结束 |

另：subscribe 长连上还有 **legacy bus 帧**（`handlers.go:1666`）——`id:` 行缺失、载荷为 `{"text","parseMode"}`（无 `seq`/`type` 字段）。当前 web 端**直接忽略**无 `type` 的帧；实测载荷是其他 tab 的打字指示器（`"<uid>:<ts>-0; Typing..."`，高频广播），客户端必须同样忽略，否则 transcript 会被噪声刷屏。

### 其他发送/控制端点

| 端点 | 说明 |
|---|---|
| `POST /api/chat` | 同步版本，等回复完返回 `{"reply":"..."}`（调试/降级用） |
| `POST /api/chat/stop` | **显式停止**在飞 turn。body = chatRequest（只认 `agentId`+`sessionId`）。`200 {"stopped":true}` / `409 {"stopped":false}`（无在飞 turn）（`handlers.go:1261`） |
| `POST /api/chat/steer` | 向在飞 turn 插话。body = chatRequest（`agentId`+`sessionId`+`message`）。`200 {"buffered":true}` / `409 {"buffered":false}`——客户端收 409 回退为普通发送（`handlers.go:1181`） |
| `POST /api/chat/team/stream` | 多 agent team 流（P2+） |
| `GET /api/chat/subscribe?agentId=&sessionId=&since=` | 长连 SSE：重放 `seq>since` + 实时事件 + cron 异步回复（`handlers.go:1538`）。首帧 `: ok`；`since` 缺省或 `-1` = 只实时不回放；query 优先于 `Last-Event-ID` 头；回放后实时段按 `seq<=已发最大seq` 去重；`content_delta` 不转发；30s ping |
| `POST /api/chat/recall-feedback` | 召回质量反馈（待补） |

## 5. 会话管理

| 端点 | 说明 |
|---|---|
| `GET /api/chat/sessions?agentId=` | 当前 user 的 session 列表 → `{"sessions":[WebSession]}`。WebSession 字段（`session/manager.go:1057`）：`id`/`title`/`preview`/`createdAt`/`updatedAt`（unix ms）+ omitempty 的 `chatOnly`/`projectId`/`channel`/`accountId`/`chatId`/`thumbnailUrl`。agent 不存在 → `{"sessions":[]}` |
| `PUT /api/chat/sessions/{key}` | 重命名，body `{"agentId","title"}`（agentId 也可走 query）→ `{"ok":true}` |
| `DELETE /api/chat/sessions/{key}?agentId=` | 删除。有 fork 子会话 → `409 {"error":...,"code":"has_fork_children"}` |
| `PATCH /api/chat/sessions/{key}/project` | 移动到项目 `{"projectId":...}`（空=脱离） |
| `PATCH /api/chat/sessions/{key}/chat-only` | 仅聊天模式开关，body `{"agentId","chatOnly":bool}`（agentId 也可走 query）→ `{"ok":true}`（`handlers.go:2039`，owner-only） |
| `POST /api/chat/sessions/fork` | 分叉，body `{"agentId","sourceSessionKey","forkSeq"}` → `{"sessionKey":...}` |
| `GET /api/chat/history?agentId=&sessionId=&before=&limit=` | 历史消息（`handlers.go:1834`）。`before`=earliestSeq 上翻一页（缺省=最新页）；`limit` 默认 50 上限 200。响应 `{"history":[...],"earliestSeq":n,"hasMore":bool,"latestEventSeq":n?}`。条目（`agent/loop.go:1838`）：user=`{role,content,timestamp,seq,imageUrls?,senderName?...}`；assistant=`{role,content?,toolCalls?:[{id,name,arguments}],metadata?,timestamp,seq}`；tool=`{role,content,name,toolCallId,timestamp,seq,metadata?}`；notice 条目带 `kind`（`turn_aborted_notice`\|`compaction_notice`）无 seq；fork 继承前缀 seq<0 |
| `GET /api/chat/todo?agentId=&sessionId=` | 读会话 todo.md → `{"items":[{"text","done","cancelled"?}],"raw"}`；文件缺失=空 items 非错误（`handlers.go:1701`） |
| `GET /api/chats` | chat 列表（旧，分页 page/pageSize，含跨 agent 视图） |
| `POST /api/agents/{id}/projects` (+GET/PATCH/DELETE) | 项目 CRUD；GET → `{"projects":[{id,name,description,createdAt,updatedAt}]}`（`handlers_projects.go:80`）；POST body `{"name","description"}`；POST sessions 属于「项目内新聊天」路径 |

新会话 key 约定：web 端生成 `s-<unix_ms>-<rand6>`（`chat/page.tsx:24`）；`web-ui` 是历史默认会话。`sessionId` 空串=沿用当前。

## 6. Agents

| 端点 | 说明 |
|---|---|
| `GET /api/agents` / `POST /api/agents` | 列表（`?all=true` 仅管理员）/ 创建。列表响应 `{"agents":[{id,name,description,model,avatarUrl,createdAt,userId,role}]}`（`handlers_agents.go:256`） |
| `GET/PUT/DELETE /api/agents/{id}` | 配置读/写/删（model/provider/promptMode/thinking 等） |
| `GET /api/agents/{id}/config` | 配置视图 |
| `GET /api/agents/{id}/tools/registered` | 活跃工具注册表（Tools 页勾选） |
| recall 系 | `GET/PUT .../recall-tuning`、`GET .../recall-events`、`POST .../recall-test` |
| IM 绑定 | `POST .../im-claim|im-unbind|im-rebind`、`GET .../im-claim/{channel}` |
| 文件 | `GET/POST/DELETE .../files*`、`GET .../files.zip`、`POST .../workspace/reveal`（self-hosted） |
| system-files | `GET/PUT/DELETE .../system-files/{name}` |
| 频道绑定 | `GET .../channels` + 各 IM 的 connect/status/retry/disconnect |
| usage | `GET .../usage`、`GET /api/usage`（管理员） |
| 模型 | `GET /api/models/builtin`、`POST /api/models/fetch`、`POST .../models/fetch` |
| 上下文 | `GET .../compaction/preview` |

## 7. 知识库（KB）

端点组 `/api/agents/{id}/kb/*`（`handlers_kb.go`；形状见 `internal/kb/types.go`）：

**通用形状**
- `KBSource`：`{id, agent_id, title, source_type("text"|"url"|"file"), source_ref, entry_count, total_chars, created_at, updated_at, wiki_generated_at?, type?("article"|"flash"|"todo"), status?(todo: pending/in_progress/done/cancelled), start_at?/end_at?(todo，ISO 字符串), reminded_at?}`
- `KBEntry`：`{id, source_id, chunk_index, content}`（详情 = chunks 拼接）
- `KBBookmark`：`{id, agent_id, url, title, summary, content?, fetched_at?, source?, created_at, updated_at, promoted_to_article_id?}`
- `KBResult`：`{source_id, source_title, source_kind("kb"|"wiki"), content_type?("flash"|"todo"), chunk_index, content, snippet, rank}`

**文章（type=article，默认）**
| 端点 | 说明 |
|---|---|
| `GET /kb/sources` | 全类型混合列表 `KBSource[]`（上限 50，客户端按 `type` 过滤） |
| `POST /kb/ingest/text` `{title?, content}` | → `201 {source_id, chars}` |
| `POST /kb/ingest/url` `{url, title?}` | 抓取入库 |
| `DELETE /kb/sources/{sid}` | 删除（级联清 wiki 派生页） |
| `GET /kb/sources/{sid}/entries` | → `KBEntry[]` |
| `POST /kb/search` `{query, limit?}` | → `KBResult[]`（默认 5；向量召回可选） |
| `GET /kb/sources/{sid}/insights` | 深读 → `ArticleInsights{summary{core,topics[],chapters[]}, quotes[], actions[], sprouts, generated_at}` |
| `POST /kb/sources/{sid}/insights/generate` | LLM 生成深读并返回 |
| `GET /kb/stats` | `{source_count, entry_count, total_chars}` |

**闪记（flash）**
- `POST /kb/flash` `{content}` → `201 {source_id}`；命中去重 → `200 {deduped:true, existing_source_id, existing_title, reason}`
- `PATCH /kb/flash/{sid}` `{content}` → `{status:"updated"}`（重写重嵌）
- 列表复用 `GET /kb/sources` 过滤 `type=flash`

**待办（todo）**
- `POST /kb/todo` `{content, status?("pending"), start_at?, end_at?}` → `201 {source_id}` / 去重 200
- `GET /kb/todos?status=&due_within_hours=` → `KBSource[]`（status 空全量；`active`=未完成）
- `PATCH /kb/todos/{sid}` `{content?, status?, start_at?, end_at?}` — 仅非空字段生效 → `{status:"updated"}`

**书签（bookmark）**
- `GET /kb/bookmarks` → `KBBookmark[]`（新→旧，上限 200）
- `POST /kb/bookmarks` `{url, title?, summary?}` — 保存时抓取正文防失效，失败仅存 URL → `201 {id, title, content_chars}`
- `PATCH /kb/bookmarks/{bid}` `{title?, summary?}`；`DELETE /kb/bookmarks/{bid}` → `{status:"deleted"}`
- `POST /kb/bookmarks/{bid}/promote` → `{article_source_id, bookmark_id}`（升格为文章进 wiki 生成，幂等）

（notes/cards/pending 查重留待票 06 补。）

## 8. Wiki / Diary / Workflow

- Wiki：`/api/agents/{id}/wiki/` — `stats`、`pages`、`pages/{id}`、`graph`、`generate`、`reindex-embed`、`progress`、`autogen-status`、`DELETE pages/{id}`
- Diary：`/api/agents/{id}/diary`、`diary/{date}`、`diary/generate`
- Workflow：`/api/agents/{agentID}/workflows` 全套 CRUD + `run`、`run/stream`、`runs`（list/get/del/批量删）、`runs/{runID}/resume(/stream)`（M6 表单交互）、`schedules` CRUD
- Workflow 运行流事件：NodeStart/NodeComplete/Done（形状待补，M4 时补）

## 9. 设置面（system settings）

- `GET/POST /api/config` — 用户级系统设置（providers/channels scope 内）
- providers：`/api/providers` CRUD + `/{id}/test`
- scoped-channels：`/api/scoped-channels` CRUD
- memory/向量化/隐私：`/api/memory/test-embedding|test-reranker`、`.../memory`、`.../vectorization`、`/api/vectorization`、`.../privacy`、`/api/privacy`
- 备份：`/api/backup` 系列（get/update/list/now/download/delete）
- cron：`/api/cron` CRUD + per-agent `/api/agents/{id}/cron`
- regex-hooks：`/api/agents/{id}/regex-hooks` CRUD + reorder + scripts
- apikeys：`/api/apikeys` CRUD + rotate
- users：`POST /api/users/{id}/apikeys`、`GET/POST /api/users/{id}/agents`
- skills：`/api/skills` 系列 + per-agent skills
- plugins/tools/channels/tasks/diag：`/api/plugins`、`/api/tools`、`/api/channels`、`/api/tasks`、`/api/diag/reports` 系列

## 10. OpenAI 兼容层

`POST /v1/chat/completions` 等（`internal/api`）——第三方客户端用，APP 不走。

---

## 附：版本

- 契约 v0.2（2026-09-29）：补全票 04 所需字段——事件 data 形状全表、stop/steer body 与响应、subscribe 回放/去重规则、history 分页与条目形状、WebSession/todo/chat-only/agents 列表响应（出处见各条）。KB/Wiki/Workflow body 细节按票补。
