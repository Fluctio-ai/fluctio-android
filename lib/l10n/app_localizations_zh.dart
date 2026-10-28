// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'fluctio';

  @override
  String get navChat => '对话';

  @override
  String get navKnowledge => '知识库';

  @override
  String get navWiki => 'Wiki';

  @override
  String get navWorkflow => '工作流';

  @override
  String get navTools => '工具';

  @override
  String get workflowNew => '新建工作流';

  @override
  String get workflowNewHint => '工作流 ID（字母、数字、- 、_）';

  @override
  String get navSettings => '设置';

  @override
  String get comingSoon => '此模块将在后续里程碑提供';

  @override
  String get setupTitle => '连接你的 fluctio';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get serverAddressHint => 'https://your-domain.com';

  @override
  String get allowSelfSigned => '信任自签名证书';

  @override
  String get allowSelfSignedSub => '仅用于局域网 / 自部署测试地址';

  @override
  String get testConnection => '测试连接';

  @override
  String get testing => '测试中…';

  @override
  String get connectionOk => '连接成功';

  @override
  String get connectionFailed => '无法连接到该地址';

  @override
  String get saveAndContinue => '保存并继续';

  @override
  String get loginTitle => '登录';

  @override
  String get currentServer => '服务器';

  @override
  String get changeServer => '更改服务器';

  @override
  String get accountLabel => '账号';

  @override
  String get passwordLabel => '密码';

  @override
  String get signIn => '登录';

  @override
  String get signingIn => '登录中…';

  @override
  String get errorInvalidCredentials => '账号或密码错误';

  @override
  String get errorRateLimited => '尝试次数过多，请几分钟后再试';

  @override
  String get errorNetwork => '网络错误，请检查地址与连接';

  @override
  String get errorServerUnavailable => '服务器不可用（网关错误），请稍后再试或检查服务端';

  @override
  String get errorInvalidFormat => '地址无效，需以 https://（或局域网 http://）开头';

  @override
  String get errorHttpsRequired => '公网地址必须使用 https';

  @override
  String get errorLanNeedsTrust => '局域网 http 地址需开启「信任自签名证书」';

  @override
  String get sectionServer => '服务器';

  @override
  String get sectionAccount => '账号';

  @override
  String get signedInAs => '已登录';

  @override
  String get notSignedIn => '未登录';

  @override
  String get signOut => '登出';

  @override
  String get switchServer => '切换服务器';

  @override
  String get confirmSignOut => '确定要登出当前账号吗？';

  @override
  String get cancel => '取消';

  @override
  String get chatNew => '新对话';

  @override
  String get chatSearchHint => '搜索对话';

  @override
  String get chatNoMatch => '没有匹配的对话';

  @override
  String get chatSessions => '会话';

  @override
  String get chatTodo => '会话待办';

  @override
  String get chatTodoEmpty => '本会话暂无待办';

  @override
  String get chatStop => '停止';

  @override
  String get chatStopped => '已停止';

  @override
  String get chatResend => '重发';

  @override
  String get chatRegenerate => '重新生成';

  @override
  String get chatReconnecting => '重连中';

  @override
  String get chatPullForLatest => '上拉获取最新';

  @override
  String get chatFetchingLatest => '正在获取最新…';

  @override
  String get chatCompacted => '上下文已压缩';

  @override
  String get chatHistoryError => '历史消息加载失败';

  @override
  String get chatEmpty => '输入消息开始对话';

  @override
  String get chatAuthTitle => '需要授权';

  @override
  String get chatToolCalling => '工具调用';

  @override
  String get chatToolRunning => '进行中';

  @override
  String get chatToolDone => '完成';

  @override
  String get chatNoAgent => '没有可用的 Agent';

  @override
  String get chatLoadAgents => '重新加载';

  @override
  String get chatNoSessions => '暂无会话';

  @override
  String get chatRename => '重命名';

  @override
  String get chatDelete => '删除';

  @override
  String get chatDeleteConfirm => '删除该会话？删除后不可恢复';

  @override
  String get chatOnlyMode => '仅聊天模式';

  @override
  String get chatThinking => '思考中…';

  @override
  String get chatSteer => '插话到当前回合';

  @override
  String get chatToday => '今天';

  @override
  String get chatYesterday => '昨天';

  @override
  String get chatPickAttachmentError => '附件读取失败';

  @override
  String get chatAttachLimit => '最多 8 个附件';

  @override
  String chatFileTooLarge(String name) {
    return '文件过大（上限 50MB）：$name';
  }

  @override
  String get chatAttachTotalTooLarge => '附件总大小超过 100MB 上限';

  @override
  String get navProjects => '项目';

  @override
  String get navMe => '我的';

  @override
  String get drawerRole => '你的智能助理';

  @override
  String get drawerChatHistory => '对话历史';

  @override
  String get projectsEmpty => '暂无项目';

  @override
  String get kbSearchHint => '搜索知识库内容…';

  @override
  String get kbArticles => '文章';

  @override
  String get kbNotes => '笔记';

  @override
  String get kbIdeas => '灵感';

  @override
  String get kbTodos => '待办';

  @override
  String get kbDiary => '日记';

  @override
  String get kbViewList => '列表';

  @override
  String get kbViewCalendar => '日历';

  @override
  String get kbViewGantt => '甘特';

  @override
  String get kbViewMonth => '月';

  @override
  String get kbViewWeek => '周';

  @override
  String get kbViewDay => '日';

  @override
  String get kbScopeMonth => '本月';

  @override
  String get kbScopeWeek => '本周';

  @override
  String get kbScopeDay => '今天';

  @override
  String get kbNoTodos => '暂无待办';

  @override
  String kbGanttCount(int n) {
    return '$n 项';
  }

  @override
  String get kbBookmarks => '书签';

  @override
  String get kbCards => '卡片';

  @override
  String get kbWiki => '维基';

  @override
  String get diaryOverview => '今日概要';

  @override
  String get diaryThemes => '今天聊了什么';

  @override
  String get diaryNoThemes => '没有可归纳的主题';

  @override
  String get diaryBlindspots => '你可能忽略的重点';

  @override
  String get diaryArchives => '今日归档';

  @override
  String get diaryGenerate => '生成';

  @override
  String get diaryGenerating => '生成中…';

  @override
  String get diaryNoDiary => '该日期还没有日记';

  @override
  String get diaryNoDiaryMonth => '本月还没有日记';

  @override
  String get diaryHeatHint => '颜色越深，当天内容越多';

  @override
  String get diaryPrevMonth => '上一月';

  @override
  String get diaryNextMonth => '下一月';

  @override
  String diaryListMeta(Object date, int themes, int blindspots) {
    return '$date · $themes 主题 · $blindspots 盲区';
  }

  @override
  String get diaryShelved => '搁浅话题';

  @override
  String diaryShelvedSince(Object date, int n) {
    return '搁浅于 $date · $n 天前';
  }

  @override
  String get diaryShelvedResolved => '已捡起';

  @override
  String get meAgents => '智能体';

  @override
  String get meGeneral => '通用';

  @override
  String get meAbout => '关于';

  @override
  String get meAgentManage => 'Agent 管理';

  @override
  String get meVersion => '版本';

  @override
  String get chatSuggest1 => '总结一下最近的对话';

  @override
  String get chatSuggest2 => '帮我列一个今日待办';

  @override
  String get chatSuggest3 => '随便聊点什么';

  @override
  String get chatSend => '发送';

  @override
  String get chatAttach => '添加附件';

  @override
  String get chatCopy => '复制';

  @override
  String get chatFork => '从此处分叉对话';

  @override
  String get kbClear => '清除';

  @override
  String get wikiEntity => '实体';

  @override
  String get wikiConcept => '概念';

  @override
  String get wikiSource => '来源';

  @override
  String get wikiSearchHint => '搜索页面…';

  @override
  String get wikiNoPages => '暂无 Wiki 页面。请在知识库设置中生成。';

  @override
  String get wikiNoMatch => '没有匹配的页面';

  @override
  String wikiStats(Object pages, Object links) {
    return '$pages 页 · $links 链接';
  }

  @override
  String get wikiDeleteTitle => '删除页面';

  @override
  String wikiDeleteConfirm(Object name) {
    return '确定删除「$name」？此操作无法撤销。';
  }

  @override
  String get wikiKnowledgeGraph => '知识图谱';

  @override
  String get wikiFit => '重置视图';

  @override
  String get wikiOpen => '打开';

  @override
  String get wikiViewInGraph => '在图谱中查看';

  @override
  String get wikiEditPage => '编辑页面';

  @override
  String get wikiTitleLabel => '标题';

  @override
  String get wikiLoadFailed => '加载失败';

  @override
  String get chatOnlyChip => '仅对话';

  @override
  String get chatImReadOnlyHint => '只读——此对话来自 IM 渠道';

  @override
  String get chatImChannelBadge => 'IM 渠道会话（只读）';

  @override
  String get kbEmpty => '暂无内容';

  @override
  String get kbSelectToView => '选择左侧条目查看';

  @override
  String get kbTomorrow => '明天';

  @override
  String get kbNoDate => '无日期';

  @override
  String get kbAddTodo => '新建待办';

  @override
  String get kbTodoHint => '待办内容';

  @override
  String get todoStatusPending => '待执行';

  @override
  String get todoStatusInProgress => '执行中';

  @override
  String get todoStatusDone => '已完成';

  @override
  String get todoStatusCancelled => '已取消';

  @override
  String get kbStatus => '状态';

  @override
  String get kbNotSet => '未设置';

  @override
  String get kbDueDate => '日期';

  @override
  String get kbStartDate => '开始时间';

  @override
  String get kbEndDate => '结束时间';

  @override
  String get kbAddFlash => '记一笔';

  @override
  String get kbFlashHint => '一闪而过的灵感…';

  @override
  String get kbDeduped => '与已有内容重复，未保存';

  @override
  String get kbAddBookmark => '保存书签';

  @override
  String get kbTitleOptional => '标题（可选）';

  @override
  String get kbSummary => '摘要';

  @override
  String get kbPromote => '升格为文章';

  @override
  String get kbPromoted => '已升格为文章';

  @override
  String get kbGenerateInsights => '生成深度解读';

  @override
  String get kbInsights => '深度解读';

  @override
  String get kbOriginal => '原文';

  @override
  String get kbCoreSummary => '概要';

  @override
  String get kbChapters => '章节';

  @override
  String get kbSprouts => '新芽';

  @override
  String get kbArchive => '归档';

  @override
  String get kbEdit => '编辑';

  @override
  String get chatFiles => '文件';

  @override
  String get chatWorkspace => '工作区';

  @override
  String get chatRefresh => '刷新';

  @override
  String get fileNoPreview => '该类型暂不支持预览';

  @override
  String get mediaPlayFailed => '播放失败';

  @override
  String get themeTitle => '外观';

  @override
  String get fontSizeTitle => '字体大小';

  @override
  String get fontSmall => '小';

  @override
  String get fontMedium => '中';

  @override
  String get fontLarge => '大';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get kbQuotes => '金句';

  @override
  String get kbActions => '行动';

  @override
  String get kbGenerating => '生成中…';

  @override
  String get cardAdd => '新建卡片';

  @override
  String get cardQuestion => '问题（正面）';

  @override
  String get cardAnswer => '答案（背面）';

  @override
  String get cardSource => '来源';

  @override
  String get shareTargetTitle => '分享到';

  @override
  String get shareToNote => '存为笔记';

  @override
  String get shareToNoteHint => '全文存入知识库笔记';

  @override
  String get shareToChat => '发送到对话';

  @override
  String get shareToChatHint => '新对话或选择会话';

  @override
  String get shareToArticle => '存为文章';

  @override
  String get shareToArticleHint => '抓取原文入库';

  @override
  String get shareToBookmark => '存为书签';

  @override
  String get shareToBookmarkHint => '保存链接到书签';

  @override
  String get shareText => '文本';

  @override
  String get shareLink => '链接';

  @override
  String shareFiles(Object n) {
    return '$n 个文件';
  }

  @override
  String get shareArticleDone => '已入库为文章，稍后可在知识库查看';

  @override
  String get shareNoteDone => '已存为笔记';

  @override
  String get shareBookmarkDone => '已加入书签';

  @override
  String shareImages(Object n) {
    return '$n 张图片';
  }

  @override
  String get shareFileOut => '分享';

  @override
  String get sharePreparing => '正在准备分享…';

  @override
  String get downloadFile => '下载';

  @override
  String get downloadPreparing => '正在下载…';

  @override
  String get downloadDone => '已保存到系统下载目录';

  @override
  String get cardExcerpt => '原始内容';

  @override
  String get cardExplanation => '解释';

  @override
  String cardFromDiary(Object date) {
    return '来自 $date 的日记';
  }

  @override
  String get cardViewWiki => '查看 Wiki 原文';

  @override
  String get cardDue => '待复习';

  @override
  String get cardActive => '学习中';

  @override
  String get cardMastered => '已掌握';

  @override
  String get cardArchived => '已归档';

  @override
  String cardReviewCount(Object count) {
    return '复习 $count 次';
  }

  @override
  String cardLapseCount(Object count) {
    return '失败 $count 次';
  }

  @override
  String get cardStart => '开始复习';

  @override
  String get cardReview => '卡片复习';

  @override
  String get cardForgot => '忘了';

  @override
  String get cardFuzzy => '模糊';

  @override
  String get cardRemembered => '记得';

  @override
  String get cardTapToReveal => '点击显示答案';

  @override
  String get cardDone => '复习完成！';

  @override
  String get cardBack => '返回';

  @override
  String get noteUntitled => '无标题笔记';

  @override
  String get noteNew => '新建笔记';

  @override
  String get noteDiscard => '放弃未保存的修改？';

  @override
  String get exitAgain => '再按一次返回退出';

  @override
  String get noteBodyHint => '正文（Markdown）';

  @override
  String get noteAttachments => '附件（只读）';

  @override
  String get tabProfile => '资料';

  @override
  String get tabModels => '模型';

  @override
  String get tabContext => '上下文';

  @override
  String get tabCustomize => '回复';

  @override
  String get tabKnowledge => '知识库';

  @override
  String get tabSkills => '技能';

  @override
  String get tabMcp => 'MCP';

  @override
  String get tabPlugins => '插件';

  @override
  String get tabScheduler => '定时';

  @override
  String get tabRegexHooks => '正则钩子';

  @override
  String get tabRecall => '召回';

  @override
  String get tabVectorization => '向量化';

  @override
  String get tabPrivacy => '隐私';

  @override
  String get tabUsage => '用量';

  @override
  String get tabChannels => '频道';

  @override
  String get tabName => '名称';

  @override
  String get tabDescription => '描述';

  @override
  String get tabModel => '模型';

  @override
  String get settingsProvider => '服务商';

  @override
  String get settingsModelInherit => '跟随系统默认';

  @override
  String get tabCustomizeHint => '开关保存后立即生效';

  @override
  String get settingsSave => '保存';

  @override
  String get settingsReload => '重载';

  @override
  String get settingsAdd => '添加';

  @override
  String get settingsEmpty => '暂无内容';

  @override
  String get settingsCenter => '系统设置';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsModels => '模型服务';

  @override
  String get settingsAdvanced => '高级（备份 / 定时 / 密钥 / 诊断）';

  @override
  String get settingsBackup => '备份';

  @override
  String get settingsCron => '定时任务';

  @override
  String get settingsApiKeys => 'API 密钥';

  @override
  String get settingsDiag => '诊断报告';

  @override
  String get webLoading => '加载中…';

  @override
  String get webLoadFailed => '页面加载失败';

  @override
  String get webReloginHint => '若会话已过期，请重新登录后再试';

  @override
  String get mermaidHint => 'Mermaid 图表，点击全屏查看';

  @override
  String get noteWhiteboard => '白板';

  @override
  String get chatOfflineHint => '离线缓存内容，联网后自动刷新';

  @override
  String get updateCheck => '检查更新';

  @override
  String get updateNone => '已是最新版本';

  @override
  String get updateAvailable => '发现新版本';

  @override
  String get updateDownload => '下载更新';

  @override
  String get confirm => '确定';

  @override
  String get drawerGroupAgent => '智能体';

  @override
  String get drawerChats => '对话';

  @override
  String get seeAllChats => '查看更多对话';

  @override
  String get noProjects => '暂无项目';

  @override
  String get newProject => '新建项目';

  @override
  String get newChatInProject => '在项目中新建对话';

  @override
  String get editProject => '编辑项目';

  @override
  String get deleteProject => '删除项目';

  @override
  String get deleteProjectTitle => '删除项目';

  @override
  String deleteProjectConfirm(Object name) {
    return '确定删除项目“$name”？';
  }

  @override
  String projectDeleteBlocked(Object count) {
    return '该项目仍有 $count 个对话，请先删除或移动。';
  }

  @override
  String get projectNameLabel => '名称';

  @override
  String get projectDescriptionLabel => '描述（可选）';

  @override
  String get dashHeroHint => '发送消息开始对话';

  @override
  String get dashCardsTitle => '今日卡片';

  @override
  String dashCardsDue(Object n) {
    return '$n 张到期';
  }

  @override
  String get dashCardsNone => '今天没有到期卡片';

  @override
  String dashCardsStreak(Object n) {
    return '已连续 $n 天';
  }

  @override
  String get dashCardsBrowse => '前往卡片库 →';

  @override
  String get dashTodoTitle => '待办';

  @override
  String get dashTodoNone => '暂无待办';

  @override
  String get dashTodoView => '前往待办 →';

  @override
  String get dashTodoOverdue => '已过期';

  @override
  String get dashRecentTitle => '最近对话';

  @override
  String get dashRecentAll => '查看更多对话 →';

  @override
  String get dashRecentNone => '还没有对话';

  @override
  String get dashCronTitle => '定时任务';

  @override
  String get dashCronNone => '没有启用的定时任务';

  @override
  String get dashShelvedNone => '没有搁浅的话题';

  @override
  String dashShelvedDaysAgo(int n) {
    return '$n 天前';
  }

  @override
  String get dashShelvedView => '查看日记 →';

  @override
  String editorIssues(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 个问题',
      one: '1 个问题',
    );
    return '⚠ $_temp0';
  }

  @override
  String editorIssueGo(Object line) {
    return '第 $line 行';
  }

  @override
  String get editorLintUnclosedCodeFence => '代码围栏未闭合（```）';

  @override
  String get editorLintUnclosedMathFence => '公式块未闭合（\$\$）';

  @override
  String get editorLintOddDollars => '行内公式定界符不配对（\$）';

  @override
  String get editorLintTableColumns => '表格分隔行列数与表头不一致';

  @override
  String get settingsMaxTokens => '最大 Token 数';

  @override
  String get settingsTemperature => '温度';

  @override
  String get settingsMaxToolIterations => '最大工具迭代数';

  @override
  String get settingsPromptMode => '提示词模式';

  @override
  String get settingsGuidance => '引导模式';

  @override
  String get settingsCompactionMode => '上下文压缩模式';

  @override
  String get settingsCompactionThreshold => '压缩阈值';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsSplitReplies => '分条回复';

  @override
  String get settingsAutoPersist => '自动持久化';

  @override
  String get settingsSharedIdentity => '共享身份';

  @override
  String get settingsName => '名称';

  @override
  String get settingsLangZh => '中文';

  @override
  String get settingsLangEn => 'English';

  @override
  String articleCharsCount(Object count) {
    return '$count 字';
  }

  @override
  String articleCharsWan(Object count) {
    return '$count 万字';
  }
}
