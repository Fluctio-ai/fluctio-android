# fluctio-android

fluctio (FastClaw) 的 Android 客户端（Flutter）。后端参考仓：`D:\backup\Desktop\fastclaw`（用绝对路径 Read/Grep 查证，不修改）。

## 纪律

- **API 契约是唯一事实源**：`docs/api/API.md`。发现客户端与后端不一致 → 先改契约（附 fastclaw 侧 handler 出处），再改码。标"待补"的字段实现对应功能时读 handler 补全。
- 需求/决策/票：fastclaw 仓 `specs/android-app/{REQ,ADR,TICKETS}.md`（本地私有，不上 git）。
- Commit message 用英文。
- Windows + PowerShell 环境；真机 Android 16。

## 技术栈决策（见 ADR）

- 状态：Riverpod；路由：go_router（底部 5 tab：对话/知识库/Wiki/工作流/设置）
- 网络：dio + cookie_jar（认证 = cookie `fluctio_session`，登录端点不返回 token）；凭据 flutter_secure_storage
- 认证流程：服务器地址（HTTPS）→ `/healthz` 连通测试 → `POST /api/login` → cookie 持久化 → 401 全局回登录
- SSE：POST `/api/chat/stream`，帧 = `id:<seq>` + `data:{"seq","type","data"}`（无 event: 行）；30s `: ping` 心跳；**断连≠Stop**（turn 在服务端 detached 继续跑，重连走 subscribe?since=seq）
- 昂贵功能（白板/图谱/Workflow 编辑器/mermaid/诊断页）走通用 WebView 降级容器（token 注入方式待 spike）
- 轻缓存：会话列表+最近消息进本地 SQLite；流式内容不落缓存
- minSdk 24 / targetSdk 36；不做推送/离线/iOS

## 设计 token（复刻 web 青色轴）

- 实现：Dart oklch→sRGB 运行时转换函数 + token 表（字面量与 `fastclaw/web/src/app/globals.css` 一一对应）
- surge cyan：浅色 primary `#0e7490` / 暗色 `#22d3ee`；accent `#ecfeff`/`#083344`
- 圆角家族：4px 嵌套 / **6px 控件** / 12px 卡片 / 16px 全屏
- 暗色面带冷青偏色（oklch C≤0.012），不是纯灰
- zh 作用域：行高 1.7 正文、去 negative tracking；消息入场 160ms 上浮淡入 + reduced-motion 纯淡入
- 语义色（success/warning/info/destructive）达 AA，均配过浅暗两档

## 环境状态（2026-09-29）

- Java 17 ✓；Android SDK ✓（`%LOCALAPPDATA%\Android\Sdk`：platform-tools + android-36 + build-tools 36.0.0）；真机 `844c5bbb`（Android 16）
- Flutter 3.47.5 stable ✓ 在 `D:\flutter`（未进系统 PATH，命令用 `/d/flutter/bin/flutter`）；pub 走镜像：命令前 `export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn`
- 项目脚手架已建（票 01）：go_router + Riverpod + dio/cookie_jar/secure_storage 依赖；5 tab 壳；主题 token 两套；zh/en arb；analyze/test 全绿
- `D:\dev\flutter_3.47.5-stable.zip` 是废弃半截下载，可删
