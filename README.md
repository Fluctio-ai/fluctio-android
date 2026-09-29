# fluctio-android

fluctio (FastClaw) 的 Android 客户端。Flutter 编写，对接自部署 gateway 的 HTTP API（cookie session 认证 + SSE 流式）。

- 需求/决策/排期见部署仓 `specs/android-app/`（REQ / ADR / TICKETS）
- API 契约：[docs/api/API.md](docs/api/API.md) —— 唯一事实源，端点失配先改契约再改码
- 目标：minSdk 24 / targetSdk 36；zh/en 双语；深浅色；设计复刻 web 青色轴（surge cyan）
- 昂贵 web 功能（白板/图谱/Workflow 编辑器/mermaid/诊断页）走通用 WebView 降级容器

## 开发

```powershell
flutter pub get
flutter run          # 真机连接 adb 后
flutter analyze
```

服务器默认本地 `http://127.0.0.1:18953`（`adb reverse tcp:18953 tcp:18953`），生产填自部署 HTTPS 域名。
