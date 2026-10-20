# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# fluctio-android

fluctio (FastClaw) 的 Android 客户端（Flutter）。后端参考仓：`D:\codes\fluctio`（用绝对路径 Read/Grep 查证，不修改）。

## 纪律

- **API 契约是唯一事实源**：`docs/api/API.md`。发现客户端与后端不一致 → 先改契约（附 fastclaw 侧 handler 出处），再改码。标"待补"的字段实现对应功能时读 handler 补全。
- 需求/决策/票：fastclaw 仓 `specs/android-app/{REQ,ADR,TICKETS}.md`（本地私有，不上 git）。
- Commit message 用英文。
- Windows 环境（bash/PowerShell 皆可）；真机 Android 16。

## 常用命令

Flutter 未进系统 PATH：用 `D:\flutter\bin\flutter`（或 bash 下 `/d/flutter/bin/flutter`）。本机直连 pub.dev 很慢，命令前带镜像：

```bash
export PUB_HOSTED_URL=https://pub.flutter-io.cn FLUTTER_STORAGE_BASE_URL=https://storage.flutter-io.cn
```

- `flutter pub get` / `flutter analyze` / `flutter test`（全量，门槛：analyze 0 error、test 全绿）
- 单测：`flutter test test/sse_parser_test.dart`（test/ 平铺，按被测模块命名，无目录分层）
- 真机：`flutter run -d <serial>`；连本地 gateway 先 `adb reverse tcp:18953 tcp:18953`（adb 在 `D:\Android\Sdk\platform-tools`）
- l10n 再生成：`flutter gen-l10n`——**template 是 `app_zh.arb`**（中文为模板语言）；产物 `app_localizations*.dart` 检入在 `lib/l10n/`，禁手改
- 内置 webui 资源：`python tool/sync_webui.py`（先把 fastclaw web build 出 `D:\codes\fluctio\web\out`）→ 打进 `assets/webui.zip`

## 架构大图

**认证**（`lib/auth/` + `lib/api/api_client.dart`）：`AuthController` 是状态机（loading / needSetup / loggedOut / loggedIn），`main()` 在首帧前 await `restore()`（prefs 读地址 → Keystore 读 sid → `/api/me` 探测；网络失败保持乐观登录态，仅显式 401 吊销）。Auth 必须用自己的 Dio——`apiClientProvider` watch 本控制器，互读即成 Riverpod 循环依赖。业务 Dio 由 interceptor 盖 `fluctio_session` cookie，任何 401 触发全局回登录（登录调用自身的 401 是表单错误，由 `onUnauthorized` 的空 session 判断豁免）。

**Chat 流式**（`lib/api/sse.dart` + `lib/chat/`）：线协议见契约 §4（`id:<seq>` + `data:{...}`，30s `: ping`）。核心不变量：**断连≠Stop**——turn 在服务端 detached 继续跑（45min 上限），UI 用 `GET /api/chat/subscribe?since=<seq>` 重锚，绝不因网络断开把 UI 置"已停止"。`chat_engine.dart` 的 `TurnPhase`（idle/sending/streaming/reconnecting/stopping）与 `UiEntry` sealed 层级（User/Assistant/Tool/Notice）是 transcript 的单一模型；seq 锚点驱动 `#seq-N` 深链（日记 segment chips → 精确消息）。ChatPage 经 `routeObserver`（挂 ShellRoute 的内层 Navigator）感知返回前台并重锚在飞 turn。

**WebView 降级 Route A**（`lib/webview/`）：昂贵 web 功能不重写，嵌 web app。`tool/sync_webui.py` 把 `D:\codes\fluctio\web\out` 打成单 zip（排除 excalidraw ~14MB）→ `assets/webui.zip`；`LocalWebServer` 起 loopback HttpServer 伺服解压产物（WebView 秒开、无自签 TLS），并把 `/api/*` 代理到 gateway（带 cookie）；无快照时回退线上 baseUrl + cookie 注入。`web_container.dart` 的 `WebRoutes` 唯一登记合法内嵌路由——web 侧重命名只断这一处；`path` 必须根相对。当前仅 workflow 编辑器与 workspace html 预览两个调用点（wiki/笔记已是原生）。

**导航壳**（`lib/router.dart` + `lib/pages/app_shell.dart`）：web parity，**无底部 tab**——`/` 就是新对话页（对应 web `/agents/<id>/chat/`），其余全部从抽屉（手机）或常驻左侧栏（宽屏，`ui/breakpoints.dart hasPermanentSidebar`，master-detail 见 `ui/master_detail.dart`）进入。单个 `ShellRoute` 包全部路由：侧栏实例跨导航存活、双击返回退出守卫在壳上（`/setup`、`/workflow` 是 bare path 不守卫——workflow 编辑器需要全宽）。

**功能模块**：`lib/kb/`（文章/灵感/待办/书签/卡片/日记/笔记，repo+model 分层）；`lib/wiki/`（原生 wiki 模块，含图谱力导仿真 `force_sim.dart`）；`lib/files/`（agent 文件 / workspace 文件 / 媒体查看、进度轮询与代理）；`lib/share/`（接收他端分享 → `/share-target` 目的地选择器，可冷启动消费）；`lib/todo/`（本地通知提醒，provider 挂 root 生命周期）；`lib/update/`（GitHub Release 检查更新，自带裸 Dio——不同信任域：不盖 session cookie、不触发全局 401 副作用）。

**缓存**（`lib/cache/chat_cache.dart`）：SQLite 轻缓存（会话列表 + 每会话近期消息，存渲染后条目形状，命中即 1:1 重建），流式内容不落缓存；schema 版本 3。

## 技术栈决策（见 ADR）

- 状态：Riverpod 3；路由：go_router（web parity：对话即根、无底部 tab；宽屏常驻侧栏）
- 网络：dio + cookie（认证 = cookie `fluctio_session`，登录端点不返回 token）；凭据 flutter_secure_storage
- 认证流程：服务器地址（HTTPS，可允许自签）→ `/healthz` 连通测试 → `POST /api/login` → cookie 持久化 → 401 全局回登录
- SSE：POST `/api/chat/stream`，帧 = `id:<seq>` + `data:{"seq","type","data"}`（无 event: 行）；30s `: ping` 心跳；**断连≠Stop**（turn 在服务端 detached 继续跑，重连走 subscribe?since=seq）
- 昂贵功能（workflow 编辑器 / 诊断页等）走通用 WebView 降级容器（cookie 注入 + Route A 本地伺服）
- 轻缓存：会话列表+最近消息进本地 SQLite；流式内容不落缓存
- minSdk 24 / targetSdk 36；不做推送/离线/iOS

## 设计 token（复刻 web 青色轴）

- **改/造任何屏幕前先读 `DESIGN.md`**（语义层：token 用法、两个动效家族、anti-patterns 清单）；数值事实源 = `fastclaw/web/src/app/globals.css` ⇄ `lib/theme/tokens.dart`（两端 bit 级同步）
- surge cyan：浅色 primary `#0e7490` / 暗色 `#22d3ee`；accent `#ecfeff`/`#083344`
- 间距/动效只从 token 取：`AppSpace`（4–24 六档，对齐 tailwind）/ `AppMotion`（entrance 160ms expo-out、flow 曲线、spring 100/20）；存量字面量随触碰渐进迁移，不搞一次性大扫除
- 圆角家族：4px 嵌套 / **6px 控件** / 12px 卡片 / 16px 全屏
- 暗色面带冷青偏色（oklch C≤0.012），不是纯灰
- zh 作用域：行高 1.7 正文、去 negative tracking；消息入场 160ms 上浮淡入 + reduced-motion 纯淡入；历史/首屏不做入场编排
- 字号阶梯走 `AppTheme._textTheme`（display 28 / title 17 / body 15 / secondary 13 / caption 12），页面禁手写阶梯外字号；并排对比的数字用 mono
- 语义色（success/warning/info/destructive）达 AA，均配浅暗两档；**琥珀只属于 warning**，不进数据/图表色环
- 触控目标 ≥44dp；行内操作常显或长按呼出（触屏无 hover）；lucide 线性图标，永不用 emoji 当图标

## 环境状态（2026-10-20）

- Java 17 ✓；Android SDK ✓ 在 `D:\Android\Sdk`（已从 `%LOCALAPPDATA%\Android\Sdk` 迁移）；platform-tools + android-36 + build-tools 36.0.0；真机 Android 16（机器换代过，串号以 `adb devices` 为准）
- Flutter 3.47.5 stable ✓ 在 `D:\flutter`（未进 PATH）；Dart 3.13.4。注意 `flutter --version` 会先 git fetch，离线时卡 ~21s 失败——版本看 `D:\flutter\bin\cache\flutter.version.json`
- 本机 pub cache 随账号迁移清空过：analyze/test 前确保 `flutter pub get` 已成功拉全依赖（镜像偶发 TLS 错误，换源或重试）；`.dart_tool/package_config.json` 在而 cache 缺失时 analyze 会报上千 uri_does_not_exist，勿当代码问题修
- `D:\dev\flutter_3.47.5-stable.zip` 仍是废弃半截下载，可删
- 工作树长期有未提交改动属常态（开发中），动手前先 `git status`
