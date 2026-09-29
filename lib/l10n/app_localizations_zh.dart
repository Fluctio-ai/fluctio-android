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
  String get chatPickImageError => '图片读取失败';

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
  String get kbBookmarks => '书签';

  @override
  String get kbCards => '卡片';

  @override
  String get kbWiki => '维基';

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
}
