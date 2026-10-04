# Design System: fluctio (FastClaw Android)

> 生成/改造任何屏幕前先读本文。token 数值的单一事实源是
> `fastclaw/web/src/app/globals.css` 与 `lib/theme/tokens.dart`(两端 bit 级同步);
> 本文是它们的语义层——回答"什么时候用哪个、为什么、怎么动"。

## 1. Visual Theme & Atmosphere

**深水工作室(deep-water studio)。** fluctio 的名字是流动的水:安静、可信赖、
有生命力但不喧哗。像一间灯光良好的水岸工作室——临床级的中性灰里,
唯一的情绪是青色(surge cyan)。

- **密度 5/10** — 日用平衡:消息流与列表是主表面,呼吸感优先于塞满。
- **变化 4/10** — 克制不对称:dashboard 卡片错落、大小有别,但整体结构可预测。
  工具 app 的美在于秩序,不在于惊喜。
- **动效 5/10** — 流体:有两个明确的动效家族(见 §6),永不为动效而动效。

中文长读界面(聊天回复)是全 app 最重要的表面,一切排版决策先服务它。

## 2. Color Palette & Roles

单一青色轴贯穿,其余纯中性。**最多一个 accent 家族,永远是青。**
色值以 token 表为准,此处列语义角色。

### 浅色(默认)

- **Canvas White** `#FFFFFF` — 页面背景。
- **Ink** `#171717` — 主文本(never `#000000`)。
- **Surge Cyan** `#0E7490` — 唯一 accent:主按钮填充、活动 tab、焦点环、品牌、logo。
- **Cyan Wash** `#ECFEFF` (cyan-50) — 选中态/hover 底色、列表高亮条。
- **Deep Cyan** `#155E75` (cyan-800) — Cyan Wash 上的文本;info 语义的深档。
- **Neutral 阶** `#F5F5F5` 面 / `#757575` 次文本 / `#EAEAEA` 发丝边框 — 纯灰,零彩度。

### 暗色("deep water")

- **Deep Water 底** `oklch(0.145 0.008 230)` — 背景:带冷青偏色的深灰,**不是纯灰更不是黑**。
- **Glowing Cyan** `#22D3EE` (cyan-400) — primary:比浅色档亮一阶,在深底上发光。
- **Cyan Abyss** `#083344` (cyan-950) — 选中底;其上文本 `#67E8F9` (cyan-300)。
- 表面链 `oklch(0.178/0.22, 0.01/0.012, 230)` — 卡片/次级面同偏色升一阶(chroma ≤ 0.012)。
- 边框 = 白 10% 半透明发丝线,不是实色。
- 正文保持中性白 `#EDEDED`——长读不染色。

### 语义色(均浅/暗两档,AA 达标)

| 语义 | 观感 | 用途 |
|---|---|---|
| **success** | teal-green(桥接青轴) | 完成、在线、同步成功 |
| **warning** | gold(全盘唯一暖色对位) | 降级、需注意 |
| **info** | 深青浅档 / `#22D3EE` 暗档 | 提示、非破坏说明 |
| **destructive** | rosy red(青在色环上的补位,不是橘红) | 删除、失败、错误文本 |

**禁**:紫色、霓虹渐变、任何第二个 accent 色相、纯黑 `#000000`、
amber 当数据色(amber 只属于 warning——chart 色环特意绕开它)。

## 3. Typography Rules

- **一个中文无衬线家族到底**:系统栈(MiSans / HarmonyOS Sans SC / Noto Sans CJK
  回落),不打包、不混用第二个中文家族。层级靠**字重与颜色**,不靠换字体、
  不靠堆大字号。
- **zh 作用域铁律**:正文行高 **1.7**(`height: 1.7`);中文**去一切负字距**
  (letter-spacing 归零,CJK 全宽字形不允许 tracking-tight)。
- **字号阶梯(sp,触屏密度)**:display 28 / headline 22 / title 17 /
  body 15 / secondary 13 / caption 12,全部经 `AppTheme._textTheme` 映射到
  Material 角色,页面上禁止手写阶梯外字号。例外:① 数据注记 10
  (`AppType.chart`),仅限图表/日历格内部的刻度与 chip 标题,不用于可读文本;
  ② 聊天 markdown 文档标题档 22/18/16/15/14/13(阶梯内的文档插值,靠字重递降)。
  聊天回复用 body 15、行高 1.7。
- **Mono 数字**:代码、时间戳、会话计数、token 用量、任何会并排对比的数字,
  用 mono(JetBrains Mono 系)。正文里的散文数字不用。
- **阅读宽度**:聊天消息正文最大可读列宽(~65ch);平板/横屏居中收束,
  两侧留白,绝不拉满。
- **禁**:衬线字体、Inter 领衔的西文栈、中文负字距、用颜色当唯一层级手段
  (字重先行)。

## 4. Component Stylings

- **按钮** — 6px 圆角。primary = Surge Cyan 实填充 + 白字(浅)/ cyan 填充 +
  cyan-950 字(暗);次级 = ghost/outline,不与 primary 抢。按压反馈:
  scale 0.98(触觉上的"按下"),**无外发光、无 neon shadow**。
- **卡片** — 12px 圆角。分组卡片 = tinted 次级面 + 发丝边框
  (`surfaceCardDecoration`)。卡片只在**层级确需抬升**时用;高密度列表
  (设置组、知识库行)用 border-top 分隔 + 负空间,不嵌套卡片。
  **禁止盒中盒**。
- **输入/表单** — label 在上、helper 可选、错误文本在下(destructive 色);
  focus 态 Surge Cyan 环。不用浮动 label。
- **加载** — 骨架屏严格匹配目标布局的尺寸与节奏;流式回复期间用
  三点打字指示(typing-dot,1.4s flow 循环)。**不用通用转圈**。
- **空态** — 构图式:一线性图形 + 一句动作指引(带入口按钮),
  不是一行"No data"。
- **行操作** — 触屏无 hover:行内操作(复制/删除/重命名)常显或长按呼出,
  不做仅 hover 可见的悬停工具(这是 web 端 `hover:none` 规则的 app 版)。
- **图标** — 24dp 线性(lucide 语义),1.5–2dp 描边,圆角端点;
  **永不用 emoji 当图标**。语义色只给状态图标,不给装饰图标。

## 5. Layout Principles

- **手机一律单列**;平板/横屏才允许双列(列表 + 详情)。
- **抽屉随处可达**:所有内容列表页(文章/笔记/灵感/待办/日记/书签/卡片)
  与 Wiki 壳都挂 `AppDrawer`,手势区 55% 屏宽(`drawerEdgeDragWidth`),
  与对话页一致;二级页 AppBar 仍是返回箭头。编辑器类 WebView
  (工作流)不挂——左缘拖拽属于画布。
- **编辑即全屏**:添加/编辑表单走 `FormEditorPage`/`KbEditorPage`
  (键盘有容身之处、dirty 返回守卫、AppBar 保存),弹窗只留给
  确认类(删除/登出/放弃修改)。
- **底部 5 tab**(对话/知识库/Wiki/工作流/设置),tab 图标 + 短标签;
  活动 tab 用 Surge Cyan,其余 neutral。
- **触控目标 ≥ 44dp**,含行内 chip 与图标按钮。
- **圆角一族一屏**:4px 只用于嵌套(卡片内的 chip/pill)、6px 控件、
  12px 卡片/菜单/弹层、16px 全屏容器。混族即错。
- **无重叠、无绝对定位堆叠**:每个元素占自己的空间带,信息靠分组与留白
  分层,不靠遮盖。
- **dashboard 用错落**:2 列不对称网格(宽卡 + 窄卡)或横向滚动,
  **禁三等分等宽卡片行**。
- 尊重 safe area(手势条、挖孔);全屏容器 16px 圆角只配全屏 sheet/bottom sheet。

## 6. Motion & Interaction

两个家族,参数精确,不发明第三个:

- **Entrance(一次性入场)** — 160ms,`Cubic(0.16, 1, 0.3, 1)`(expo-out),
  translateY(4px) + 淡入。"快,不炫"。**只对实时到达的内容编排**:
  新消息入场;历史消息、首屏加载**永不动画**。
- **Flow(常驻/循环)** — `Cubic(0.45, 0, 0.25, 1)`(flow easing,近似
  ease-in-out 但两端更缓):三点打字 1.4s 循环;dashboard 卡片
  **320ms 依次 stagger 上浮 10px**(像牌落到水面);品牌波纹 3.9s 相位错开
  (仅登录/空态等低频场景,不在常驻栏常开)。
- **交互物理** — 需要弹性时 spring:`stiffness 100, damping 20`
  (Flutter `SpringDescription`,有重量感、不振颤)。按压即刻 scale 0.98,
  无延迟。
- **硬性约束**:只动 `transform` 与 `opacity`(Flutter: 位移/缩放/透明,
  不动画 padding/尺寸/布局);一屏同时进行的循环动效 ≤ 2 个;
  **reduced-motion**:入场降级为 120ms 纯淡入,循环动画全部停止——
  反馈语义保留,空间位移删除。

## 7. Anti-Patterns(Banned — AI 味清单)

- ❌ emoji 当图标;❌ 紫色 / neon 渐变 / 外发光 shadow
- ❌ 纯黑 `#000000`;❌ 任何第二个 accent 色相
- ❌ 三等分等宽卡片行(用错落双列或横滚)
- ❌ 盒中盒卡片嵌套;❌ 元素重叠/绝对定位堆叠
- ❌ 通用转圈 loader(用匹配布局的骨架屏)
- ❌ 历史消息/首屏也做入场编排
- ❌ 中文负字距、正文行高 < 1.7
- ❌ AI 腔文案:"无缝""赋能""强大""轻松搞定""智能体验"
- ❌ 假数字("99.99%""提升 500%")与通用占位名("Acme""示例用户")
- ❌ "下拉探索""滑动的箭头"类填充性 UI 文案
- ❌ amber 出现在数据/图表语境(amber 只属于 warning)
- ❌ 暗色面用纯灰(必须带冷青偏色,chroma ≤ 0.012)

---

*Stitch / AI 生成新屏时:本文整体作为 style reference;颜色只从 §2 取值,
组件状态从 §4 取行为,动效从 §6 取曲线——不引入本文未定义的第五个圆角、
第二个 accent 或第三种缓动。*
