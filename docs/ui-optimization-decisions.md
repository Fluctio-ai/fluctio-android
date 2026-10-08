# UI 优化 · 设计决策

> 版本：v1.2 · 2026-10-08 · 状态：三期全部实施完毕并通过验证
>
> 本文档是 fluctio Android 客户端 UI 优化的完整决策记录。每条决策按"原则 → 现状证据 → 动作 → 影响面"组织，证据均标注源码位置，可逐项复核。
>
> **一期实施记录（2026-10-08，commit 2aab083）**：
> - 改动：`lib/theme/app_theme.dart`（AppBarTheme.titleTextStyle=17px）、新增 `lib/ui/settings_list.dart`（SectionHeader/SettingsGroup/SettingsTile）、收敛 `lib/pages/profile_page.dart` / `lib/pages/settings/system_settings_page.dart` / `lib/pages/app_drawer.dart`、`lib/pages/chat/message_list.dart` 通知条接 `paletteOf()`（warn=金 / info=青，底色为同色 10% tint）
> - 验证：`flutter analyze` 0 error；`flutter test` 119/119 通过；真机（23113RKC6C / Android 16）改前改后截图对比 + 独立评审一轮：**通过**
>
> **二三期实施记录（2026-10-08）**：
> - token 补层：`tokens.dart` 新增 `AppSpace`（4/8/12/16/20/24，对齐 tailwind）与 `AppMotion`（按 DESIGN.md §6 编码 entrance/press/reducedFade/stagger/staggerStep/typing/brandWave + 两条曲线 + spring），DESIGN.md §5/§6 已同步
> - 动效归源 7 处（press_scale/typing_dots/brand_wave/row_actions_menu/message_list×3/chat_dashboard×2/diary reduced 分支）；计时器、防抖、滚动刻意保持字面量
> - wiki 图谱色板：overview/selectedBorder 锚定 AppPalette（同值），其余 14 色确认是 web graphTheme 领域契约、注释写明"不是 chart 色环"
> - 间距迁移：一期触碰的 4 个文件内 {4,8,12,16,20,24} 全部换 token（值不变）；三期清理 markdown_field `Colors.grey`→tone 色、wiki_graph `fontSize:12`→`AppType.caption`
> - 验证：analyze 零新增；test 119/119；真机回归截图（`after/11-13`）与一期画面对齐，无回归
> - 证据：`docs/ui-optimization/before/` 7 张、`docs/ui-optimization/after/` 13 张（含 08 通知条 warn 金色实证、09 亮色模式、10 深色恢复）

---

## 0. 背景与范围

- **产品**：fluctio (FastClaw) Android 客户端 —— 自托管网关的 Flutter 应用。主任务是 AI 聊天，外围是知识库（articles/notes/flash/bookmarks/todos/cards/diary）、wiki、files、todo、agents 设置。
- **目标设备**：手机窄屏（Android）。页面以列表和阅读列为主，没有复杂大屏布局。
- **任务性质**：存量项目 UI 优化（非重设计、非流程改造）。可重新决定偶然形成的视觉默认值，品牌资产保留。
- **现状盘点**（2026-10-08，`lib/` 全仓）：
  - 设计 token：`lib/theme/tokens.dart`（色板 ×2、字号阶梯、圆角），与 web 端 `globals.css` 有同步契约
  - 共享组件：`lib/ui/` 8 个文件（AdaptiveTabBar、BrandWave、ChevronListTile、dialogs、FormEditorPage、load_states、TactileScale、RowActionsMenu）
  - 页面规模：chat ~3800 行、kb ~4800 行、wiki 三页、settings/agents/profile/setup/drawer 各一份
  - 硬编码现状：`Colors.` 13 处、`0xFF` 49 处（其中 31 处在 tokens 源头属正常）、`fontSize:` 字面量业务侧仅 1 处、`EdgeInsets` 244 处散落 38 文件

## 1. 总判断

这套 UI 的问题不是"丑"，而是**三层进化不同步**：

| 层 | 状态 |
|---|---|
| token 层（色、字、圆角） | ✅ 已统一，源头唯一，业务页几乎不裸写 |
| 组件层 | ⚠️ 分组列表行三份平行实现，各页自写 |
| 语义层（状态色） | ❌ warning/info 定义了却渲成灰色，从未接上 |

因此优化的本质是**把已经成立的设计决策下沉到组件层**，不是重做视觉。

**设计北极星**：移动端自托管 AI 客户端，聊天是主任务，列表是主要界面语言。克制、紧凑、信息密度优先；层级靠字重和颜色表达，不靠堆字号。

## 2. 保留不动的资产

以下已经是对的，优化中明确不动：

1. 品牌色轴 surge cyan（亮 `#0E7490` / 暗 `#22D3EE`）+ 纯中性灰阶
2. 字号阶梯 `AppType`（28/22/17/15/13/12/10 + 文档/聊天派生档）
3. 圆角族 `AppRadius`（4/6/12/16）与 `surfaceCardDecoration` 卡片装饰
4. 明暗双主题的全部色值（含 destructive/success/warning/info 语义色定义）
5. `load_states` 加载/空/错误三态出口、`TactileScale` 按压反馈、长按菜单模式
6. web_container 白底、image_viewer 黑底（刻意为之，仅记录）

## 3. 四条设计决策

### 决策一：顶栏是唯一导航锚点，规格必须唯一

**原则**：一屏一主角。用户判断"我在哪"永远看顶栏，所以顶栏标题规格只能有一个；层级变化交给内容区表达，不靠顶栏字号差异。

**现状证据**：
- 全局 `titleLarge` = 22px（`lib/theme/app_theme.dart:146`），25 个文件 36 处 `AppBar` 默认落到 22px
- chat 系页面用 17px 自定义顶栏（`lib/pages/chat/chat_page.dart:356`，`lib/pages/session_list_page.dart:80` 为 PopupMenuButton）
- 同一 App 里两个一级页面标题差 5px，层级感断裂

**动作**：
- 定死一个顶栏标题规格。建议 **17px**（titleMedium 档）：手机窄屏下 22px 顶栏挤占内容区，22px 保留给 display/headline 大标题场景（setup 页、空态）
- 在 `AppTheme.appBarTheme` 层统一，chat 系自定义顶栏对齐，业务页不再各自写

**影响面**：所有带 AppBar 的页面（36 处）。视觉变化是顶栏标题变小/统一，无结构改动。

### 决策二：列表是本项目的第一界面语言，收敛成组件契约

**原则**：这是列表驱动的 App——会话列表、设置分组、知识库条目、抽屉分节是同一种模式。同一种模式只允许一个实现，改一处不应漏两处。

**现状证据**：分组列表行三份平行实现——
- `lib/pages/profile_page.dart:229-293`：`_groupTitle` + `_card`（divider indent 56）+ `_item`，图标用 `primary` 色
- `lib/pages/settings/system_settings_page.dart:56-68`：`_group` 平行结构，advanced 行图标用 `outline` 色
- `lib/pages/app_drawer.dart:341-344`：分节标题样式与 profile `_groupTitle` 逐字重复

图标色、行高、divider 规则各自为政。

**动作**：`lib/ui/` 定义三层组件契约——
- `SectionHeader`：分节标题（labelSmall + outline + w600，一套 padding）
- `SettingsGroup`：surfaceCardDecoration 容器 + 标准分隔线（indent 规则统一）
- `SettingsTile`：图标 + 标签 + 值 + 尾标的标准行（行高、图标尺寸、间距定死）

profile、system_settings、app_drawer 三处收敛到组件；图标色统一 `primary`（全 App 的"可操作"信号）。

**影响面**：3 个页面的结构代码重写为组件调用；视觉上是行高/图标色的统一。

### 决策三：状态必须可感知——语义色全链路接通

**原则**：warning 永远金、info 永远青、success 永远绿、error 永远红，任何场景不允许退化成中性灰。状态色失效 = 用户失去判断依据。

**现状证据**：
- `NoticeTone.warn`/`info` 均映射到灰色 `scheme.outline`（`lib/pages/chat/message_list.dart:737-739`）
- `tokens.dart:80-84` 中 `warning`（金）/`info`（深青）定义后从未被消费——"已停止（警告）"与"离线缓存（提示）"视觉无法区分

**动作**：
- NoticeChip 接 `paletteOf()`：`warn → palette.warning`、`info → palette.info`
- 通知条底色由灰底改为对应色 ~10% tint（深色模式沿用既有 tint 惯例）
- 确立单一路径：token 定义 → `paletteOf()` 取用 → 组件渲染；新增状态场景禁止再映射到 outline

**影响面**：聊天页通知条（error/warn/info 三档）。全 App 目前唯一用到 warning 的是 cards 评分色，接入后语义色覆盖所有状态场景。

### 决策四：token 体系补完最后两层（space / motion）

**原则**：color / type / radius 三层已齐且有纪律，缺 spacing 和 motion。目标是"新代码没有借口硬编码"，不是一次性大扫除。

**现状证据**：
- `EdgeInsets` 244 处散落 38 文件，12/14/16/20 混用，无间距 token
- `withValues(alpha:)` 30 处手写半透明
- wiki 图谱调色板 18 个硬编码 `0xFF`（`lib/wiki/wiki_models.dart:106-132`），与 tokens 的 chart 族同源但分开维护
- 全局唯一两处业务硬编码：`lib/pages/kb/markdown_field.dart:152`（`Colors.grey`）、`lib/pages/wiki/wiki_graph_page.dart:371`（裸 `fontSize: 12`）

**动作**：
- 新增 `AppSpace` 阶梯（4/8/12/16/20/24），新代码强制走 token，存量随触碰渐进迁移，不做全仓替换
- 动效时长定基础档（press / sheet / 页面过渡），`TactileScale` 等已有动效归源
- wiki 图谱色板迁到 tokens chart 族（或声明为 wiki 领域 palette 并注明与 tokens 的同步契约），消除"同源不同步"
- 顺手清掉两处单行硬编码

**影响面**：tokens.dart 增量；wiki_models.dart 重构为 token 引用；业务页渐进。

## 4. 落地路线

| 期 | 内容 | 性质 | 风险 | 状态 |
|---|---|---|---|---|
| 一期 | 决策一 + 二 + 三（顶栏、组件收敛、语义色） | 纯收敛，不改视觉风格 | 低 | ✅ 完成（2aab083） |
| 二期 | 决策四（AppSpace、AppMotion、wiki 色板归源） | token 增补 + 渐进迁移 | 低，值保持 | ✅ 完成（待提交） |
| 三期 | 零散清理（2 处单行硬编码） | 单行修改 | 极低 | ✅ 完成（待提交） |

三期全部完成。AppSpace 存量迁移按"随触碰"原则持续推进，不设终点。

一期完成后即可看到全部可感知收益；二、三期是体系补完，可独立安排。

## 5. 验收标准

**量化（机器可查）**：
- AppBar 标题规格全仓唯一（grep 复核：业务页不再出现自定义顶栏字号）
- 分组列表行只剩一个组件实现（profile/settings/drawer 三处不再含行布局代码）
- `warn`/`info` 语义色零灰色映射（grep `NoticeTone` 确认）
- `flutter analyze` 与 lint 干净；现有 test/ 测试全绿

**观感（截图对比）**：
- 每个一级页面留改前/改后真机截图（聊天、会话列表、设置、个人页、知识库各一）
- 关键区域 200% 缩放检查中文换行与对齐
- 暗色模式同样过一遍（tint 底、双色板都验）

## 6. 关键状态与风险

- **工作区基线**：动手时有 ~40 个未提交修改（集中在 pages/kb、pages/chat、l10n 生成文件）。动手前先 commit 或明确基线，避免优化混入半成品。
- **验证环境**：flutter SDK 在 `D:\flutter`；项目仅配置 Android 平台，需真机/模拟器跑基线截图。
- **不改的部分**：视觉方向、品牌色、字号阶梯、明暗色值——本次是收敛，不是重设计。
