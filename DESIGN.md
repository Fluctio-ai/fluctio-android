---
name: fluctio
description: "fluctio Android 客户端——自托管 AI 网关的深水工作室设计系统"
colors:
  canvas: "#FFFFFF"
  ink: "#171717"
  surge-cyan: "#0E7490"
  cyan-wash: "#ECFEFF"
  deep-cyan: "#155E75"
  surface-neutral: "#F5F5F5"
  muted-ink: "#757575"
  hairline: "#EAEAEA"
  destructive: "oklch(0.52 0.19 12)"
  success: "oklch(0.52 0.14 168)"
  warning: "oklch(0.55 0.12 68)"
typography:
  display:
    fontFamily: "system CJK sans (MiSans / Noto Sans CJK)"
    fontSize: "28sp"
    fontWeight: 400
    lineHeight: 1.3
  headline:
    fontSize: "22sp"
    fontWeight: 400
    lineHeight: 1.35
  title:
    fontSize: "17sp"
    fontWeight: 500
    lineHeight: 1.45
  body:
    fontSize: "15sp"
    fontWeight: 400
    lineHeight: 1.5
  label:
    fontSize: "13sp"
    fontWeight: 500
    lineHeight: 1.4
  caption:
    fontSize: "12sp"
    fontWeight: 400
    lineHeight: 1.4
  transcript:
    fontSize: "13.5sp"
    fontWeight: 400
    lineHeight: 1.7
rounded:
  nested: "4px"
  control: "6px"
  card: "12px"
  fullscreen: "16px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "20px"
  xxl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.surge-cyan}"
    textColor: "#FAFAFA"
    rounded: "{rounded.control}"
  button-tonal:
    backgroundColor: "{colors.surface-neutral}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
  card-grouped:
    backgroundColor: "{colors.surface-neutral}"
    rounded: "{rounded.card}"
  chip-quiet:
    backgroundColor: "{colors.surface-neutral}"
    textColor: "{colors.ink}"
    rounded: "{rounded.nested}"
---

# Design System: fluctio (Android)

> 生成/改造任何屏幕前先读本文。token 数值的单一事实源是
> `lib/theme/tokens.dart` ⇄ fluctio web 仓 `web/src/app/globals.css`
> （两端 bit 级同步）；本文是语义层——回答"什么时候用哪个、为什么、怎么动"。

## Overview

**Creative North Star: "深水工作室 (deep-water studio)"**

fluctio 的名字是流动的水：安静、可信赖、有生命力但不喧哗。像一间灯光良
好的水岸工作室——临床级的中性灰里，唯一的情绪是青色 (surge cyan)。

- **密度 5/10** — 日用平衡：消息流与列表是主表面，呼吸感优先于塞满。
- **变化 4/10** — 克制不对称：dashboard 卡片错落、大小有别，但整体结
  构可预测。工具 app 的美在于秩序，不在于惊喜。
- **动效 5/10** — 流体：两个明确的动效家族（见 Typography 之后的动效
  约定），永不为动效而动效。

中文长读界面（聊天回复）是全 app 最重要的表面，一切排版决策先服务它。

**Key Characteristics:** 单青色轴 / 字重与颜色分层而非堆字号 / zh 正文
行高 1.7 / 零负字距 / 单一 CJK 家族 / 元信息（工具卡、时间戳）用小号角
色轻声化 / 字号三档全树同步缩放。

## Colors

单一青色轴贯穿，其余纯中性。**最多一个 accent 家族，永远是青。**

### Primary
- **Surge Cyan** `#0E7490`（暗 `#22D3EE`）：唯一 accent——主按钮填充、
  活动 tab、焦点环、品牌、链接。
- **Cyan Wash** `#ECFEFF`（暗 `Cyan Abyss #083344`）：选中/hover 底。
- **Deep Cyan** `#155E75`（暗 `#22D3EE`）：Cyan Wash 上的文本；info 语义
  深档。

### Neutral
- **Canvas White** `#FFFFFF` — 页面背景。
- **Ink** `#171717` — 主文本（never `#000000`）。
- **Neutral 阶** `#F5F5F5` 面 / `#757575` 次文本 / `#EAEAEA` 发丝边框——
  纯灰零彩度。
- 暗色面必须带冷青偏色（oklch C≤0.012），不是纯灰更不是黑；边框 = 白
  10% 半透明发丝线；正文保持中性白 `#EDEDED`——长读不染色。

### Semantic（均浅/暗两档，AA 达标）
- **success** teal-green（桥接青轴）｜**warning** gold（全盘唯一暖色）
  ｜**info** 深青浅档 / `#22D3EE` 暗档｜**destructive** rosy red（青在
  色环上的补位，不是橘红）。

**The One Voice Rule.** 青色是全场唯一的声音：≤10% 的屏幕面积，用在动
作与焦点上。它的稀有是设计的一部分。紫色、任何第二个 accent 色相、纯
黑、amber 数据色——一律禁止（amber 只属于 warning）。

## Typography

**正文字族：** 系统 CJK 无衬线栈（MiSans / HarmonyOS Sans SC / Noto
Sans CJK 回落），不打包、不混用第二个中文家族。**Mono：** JetBrains
Mono（随 gpt_markdown fork 打包）——代码、时间戳、会话计数、任何并排
对比的数字；正文散文数字不用。

**Character:** 层级靠**字重与颜色**，不靠换字体、不靠堆大字号。中文去
一切负字距（letterSpacing 归零，CJK 全宽字形不允许 tracking）。

### Hierarchy（sp 阶梯，页面禁手写阶梯外字号）
- **Display** (400, 28, 1.3)：低频大数/空态主形。
- **Headline** (400→w600, 22, 1.35)：模块大标题。
- **Title** (500, 17, 1.45)：卡片头等栏目标题。**AppBar 大标题不在此档**——
  按「大标题同正文尺寸只加字重」规则（user sync call 2026-11-19）走各表面
  的正文尺寸：普通页面 AppBar = body 15 + w600；chat 头/抽屉 agent 头 =
  transcript 13.5 + w600；其下元信息行 = chatMeta 11（`AppTheme.chatMetaStyle`）。
- **Body** (400, 15, 1.5)：表单、设置、列表正文。
- **Label** (500, 13, 1.4)：分段控件、按钮、行主文案。
- **Caption** (400, 12, 1.4)：辅助说明、时间戳（配 mono）。
- **Transcript** (400, 13.5, **1.7**)：聊天 markdown 正文（web chat-md
  对齐；行高 1.7 是 zh 铁律）。聊天标题档 h1/h2/h3 = 16/15/14（既有的
  doc 阶梯内插值），h4+ 收回正文字号——聊天里层级要"低声"。
- **Data annotation** (12, `AppType.chart`)：仅图表/日历格内部刻度，是
  唯一豁免字号档同步的表面（固定几何格）。

**The Quiet Bold Rule.** 强调 = w600 的"自信的轻"（gpt_markdown 本地
fork 把硬编码 w700 降到 w600——CJK w700 是一坨黑）。层级先到 w600 为止，
更大的对比交给尺寸梯度或颜色，不到 w700。

**The One Scale Rule.** 字号三档（小 1.10 / 中 1.19 / 大 1.30，中档锚
定微信标准聊天字 16sp）经 root `TextScaler` 全树同步：正文、标题、输入
框、时间戳一起呼吸，**禁止逐点冻结**（re_editor 不读 ambient scaler——代码
查看器在 `code_viewer.dart` 输入端显式乘档）。段落间距天然同比：fork 把
spacing 渲染成 em 高度 span，TextScaler 随字一起缩，无需额外系数
（`fontLayoutScale` 只给需要膨胀的盒模型边距用），行高是字号倍数天然同比。
元信息（工具卡名 labelMedium、caption 时间戳）靠**更小的角色**保持安静，
不靠不缩放。

### 动效（两个家族，参数在 `AppMotion`）
- **Entrance（一次性）** 160ms expo-out + 4px 上浮淡入，只编排实时新内
  容；历史/首屏永不动画。reduced-motion 降级 120ms 纯淡入。
- **Flow（常驻/循环）** 打字三点 1.4s；dashboard 卡片 320ms stagger 上
  浮 10px。一屏循环动效 ≤2 个；只动 transform/opacity。

## Layout

- **手机一律单列**；平板/横屏双列（`MasterDetailScaffold` 列表+详情）。
- **导航 = 抽屉**：`/` 即新对话（web parity，无底部 tab）；全部内容列表
  页挂 `AppDrawer`；宽屏（`hasPermanentSidebar`）常驻左侧栏。手势按层级
  分配：列表页右滑呼抽屉；对话页右滑呼抽屉；日记周日历态左右滑切日期；
  三级详情不挂抽屉手势（`lib/ui/fling_detector.dart` 是唯一实现）。
- **间距阶梯** 4/8/12/16/20/24（`AppSpace.xs`–`xxl`），新代码只从阶梯取。
- **圆角一族一屏**：4px 嵌套 / 6px 控件 / 12px 卡片 / 16px 全屏容器。
- **触控目标 ≥44dp**（Android 平台规范 48dp 取 app 紧凑档 44）；无重叠无
  绝对定位堆叠；尊重 safe area。
- **阅读宽度**：聊天正文最大可读列宽（~65ch）；平板对话列不拉满。

## Elevation & Depth

**无投影的深度系统。** 深度靠色调分层（surface 链）+ 发丝边框传达，不
用 drop shadow；卡片 = tinted 次级面（secondaryContainer 40%）+ 1px 发
丝边（`surfaceCardDecoration`，唯一属主）。**The Flat-By-Default
Rule.** 表面静止即平；层级确需抬升才用分组卡，高密度列表用 border 分
隔 + 负空间，**禁止盒中盒**。

## Shapes

- 圆角家族见 Layout（4/6/12/16，混族即错）。
- 边框 = 发丝线（outlineVariant / 暗色 10% 白）；输入 focus = Surge Cyan
  环；按钮按压 scale 0.98，无外发光。
- 图标：lucide 线性 24dp、1.5–2dp 描边、圆角端点；**永不用 emoji 当图
  标**；语义色只给状态图标。

## Components

### Buttons
- **Shape:** 6px 圆角。**Primary** = Surge Cyan 实填充 + `#FAFAFA` 字；
  **tonal/ghost** 次级，不与 primary 抢。

### Inputs / Composer
- 无边框多行输入（聊天 composer）：contentPadding 10，hint 用 caption 灰；
  行高 **1.5**（有意比气泡的 1.7 紧——web composer 同样如此，
  `text-[15px] leading-6`；输入面是操作件不是阅读面，发送后落到气泡的
  1.7 是两端一致的既定行为）；focus 态 Surge Cyan 环；表单 label 在上、
  错误文本 destructive 在下。
- 编辑器类全屏（`FormEditorPage`/`KbEditorPage`），弹窗只留确认类。

### Chat 消息（签名表面）
- **助手气泡**：secondaryContainer 底 + 发丝边，发送侧内角收回；内边距
  12/10 × 字号档系数。**用户气泡**：primaryContainer 底同构。
- **markdown 渲染**（`lib/chat/markdown.dart` 单出口）：段落距 f² 呼吸；
  引用块 = 竖条 + 浅青灰底卡；行内代码 = 0.9× 浅底无边框；标题 16/15/14
  递降 + 大档阻尼（有效缩放 1+(f−1)/2）。
- **工具卡**：名字 = JetBrains Mono labelMedium（比正文小的元数据角色），
  完成态 caption + ✓；展开的输出是内容，随档缩放。

### Cards / Lists
- **分组卡** = 12px + tinted 面 + 发丝边；列表行高密度 = 分隔线 + 负空
  间，行内操作常显或长按呼出（触屏无 hover）。

### Navigation
- 抽屉（手机）/ 常驻侧栏（宽屏）：agent 头 + 工具九宫格 + 项目 + 最近对
  话 + 设置；宽度 85% 屏（露出区可点关）。

## Do's and Don'ts

### Do:
- **Do** 从 `AppType` 阶梯与 `AppSpace` 阶梯取值；字号、行高、间距先问
  token。
- **Do** 让一切文字走 root TextScaler（新表面零额外接线）；布局要呼吸就
  乘 `fontLayoutScale(context)`。
- **Do** 用 w600 表达强调、用 caption/labelMedium 表达元信息、用 Deep
  Cyan 表达 info。
- **Do** 聊天 markdown 改动走 `markdown.dart` 工厂（chat 与 reader 共用）。

### Don't:
- **Don't** 用第二个中文字族、衬线、Inter 领衔西文栈；不要纯黑 `#000`。
- **Don't** 中文负字距、正文行高 < 1.7、用颜色当唯一层级手段。
- **Don't** 逐点 `TextScaler.noScaling` 冻结文字（图表刻度是仅有的例外）；
  不要在阶梯外手写字号。
- **Don't** 三等分等宽卡片行、盒中盒嵌套、元素重叠堆叠、通用转圈
  loader（用骨架屏）、历史消息入场编排。
- **Don't** AI 腔文案（"无缝""赋能""强大"）与假数字；琥珀色进数据语境。
- **Don't** 暗色面用纯灰——必须冷青偏色（chroma ≤ 0.012）。

---

*AI 生成新屏时：颜色只从 Colors 取值，组件行为从 Components 取，动效取
两个家族——不引入本文未定义的第五个圆角、第二个 accent 或第三种缓动。*
