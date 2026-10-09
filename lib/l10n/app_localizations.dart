import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @appName.
  ///
  /// In zh, this message translates to:
  /// **'fluctio'**
  String get appName;

  /// No description provided for @navChat.
  ///
  /// In zh, this message translates to:
  /// **'对话'**
  String get navChat;

  /// No description provided for @navKnowledge.
  ///
  /// In zh, this message translates to:
  /// **'知识库'**
  String get navKnowledge;

  /// No description provided for @navWiki.
  ///
  /// In zh, this message translates to:
  /// **'Wiki'**
  String get navWiki;

  /// No description provided for @navWorkflow.
  ///
  /// In zh, this message translates to:
  /// **'工作流'**
  String get navWorkflow;

  /// No description provided for @navTools.
  ///
  /// In zh, this message translates to:
  /// **'工具'**
  String get navTools;

  /// No description provided for @workflowNew.
  ///
  /// In zh, this message translates to:
  /// **'新建工作流'**
  String get workflowNew;

  /// No description provided for @workflowNewHint.
  ///
  /// In zh, this message translates to:
  /// **'工作流 ID（字母、数字、- 、_）'**
  String get workflowNewHint;

  /// No description provided for @navSettings.
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get navSettings;

  /// No description provided for @comingSoon.
  ///
  /// In zh, this message translates to:
  /// **'此模块将在后续里程碑提供'**
  String get comingSoon;

  /// No description provided for @setupTitle.
  ///
  /// In zh, this message translates to:
  /// **'连接你的 fluctio'**
  String get setupTitle;

  /// No description provided for @serverAddress.
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// No description provided for @serverAddressHint.
  ///
  /// In zh, this message translates to:
  /// **'https://your-domain.com'**
  String get serverAddressHint;

  /// No description provided for @allowSelfSigned.
  ///
  /// In zh, this message translates to:
  /// **'信任自签名证书'**
  String get allowSelfSigned;

  /// No description provided for @allowSelfSignedSub.
  ///
  /// In zh, this message translates to:
  /// **'仅用于局域网 / 自部署测试地址'**
  String get allowSelfSignedSub;

  /// No description provided for @testConnection.
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// No description provided for @testing.
  ///
  /// In zh, this message translates to:
  /// **'测试中…'**
  String get testing;

  /// No description provided for @connectionOk.
  ///
  /// In zh, this message translates to:
  /// **'连接成功'**
  String get connectionOk;

  /// No description provided for @connectionFailed.
  ///
  /// In zh, this message translates to:
  /// **'无法连接到该地址'**
  String get connectionFailed;

  /// No description provided for @saveAndContinue.
  ///
  /// In zh, this message translates to:
  /// **'保存并继续'**
  String get saveAndContinue;

  /// No description provided for @loginTitle.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get loginTitle;

  /// No description provided for @currentServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get currentServer;

  /// No description provided for @changeServer.
  ///
  /// In zh, this message translates to:
  /// **'更改服务器'**
  String get changeServer;

  /// No description provided for @accountLabel.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get accountLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In zh, this message translates to:
  /// **'登录'**
  String get signIn;

  /// No description provided for @signingIn.
  ///
  /// In zh, this message translates to:
  /// **'登录中…'**
  String get signingIn;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In zh, this message translates to:
  /// **'账号或密码错误'**
  String get errorInvalidCredentials;

  /// No description provided for @errorRateLimited.
  ///
  /// In zh, this message translates to:
  /// **'尝试次数过多，请几分钟后再试'**
  String get errorRateLimited;

  /// No description provided for @errorNetwork.
  ///
  /// In zh, this message translates to:
  /// **'网络错误，请检查地址与连接'**
  String get errorNetwork;

  /// No description provided for @errorServerUnavailable.
  ///
  /// In zh, this message translates to:
  /// **'服务器不可用（网关错误），请稍后再试或检查服务端'**
  String get errorServerUnavailable;

  /// No description provided for @errorInvalidFormat.
  ///
  /// In zh, this message translates to:
  /// **'地址无效，需以 https://（或局域网 http://）开头'**
  String get errorInvalidFormat;

  /// No description provided for @errorHttpsRequired.
  ///
  /// In zh, this message translates to:
  /// **'公网地址必须使用 https'**
  String get errorHttpsRequired;

  /// No description provided for @errorLanNeedsTrust.
  ///
  /// In zh, this message translates to:
  /// **'局域网 http 地址需开启「信任自签名证书」'**
  String get errorLanNeedsTrust;

  /// No description provided for @sectionServer.
  ///
  /// In zh, this message translates to:
  /// **'服务器'**
  String get sectionServer;

  /// No description provided for @sectionAccount.
  ///
  /// In zh, this message translates to:
  /// **'账号'**
  String get sectionAccount;

  /// No description provided for @signedInAs.
  ///
  /// In zh, this message translates to:
  /// **'已登录'**
  String get signedInAs;

  /// No description provided for @notSignedIn.
  ///
  /// In zh, this message translates to:
  /// **'未登录'**
  String get notSignedIn;

  /// No description provided for @signOut.
  ///
  /// In zh, this message translates to:
  /// **'登出'**
  String get signOut;

  /// No description provided for @switchServer.
  ///
  /// In zh, this message translates to:
  /// **'切换服务器'**
  String get switchServer;

  /// No description provided for @confirmSignOut.
  ///
  /// In zh, this message translates to:
  /// **'确定要登出当前账号吗？'**
  String get confirmSignOut;

  /// No description provided for @cancel.
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// No description provided for @chatNew.
  ///
  /// In zh, this message translates to:
  /// **'新对话'**
  String get chatNew;

  /// No description provided for @chatSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索对话'**
  String get chatSearchHint;

  /// No description provided for @chatNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的对话'**
  String get chatNoMatch;

  /// No description provided for @chatSessions.
  ///
  /// In zh, this message translates to:
  /// **'会话'**
  String get chatSessions;

  /// No description provided for @chatTodo.
  ///
  /// In zh, this message translates to:
  /// **'会话待办'**
  String get chatTodo;

  /// No description provided for @chatTodoEmpty.
  ///
  /// In zh, this message translates to:
  /// **'本会话暂无待办'**
  String get chatTodoEmpty;

  /// No description provided for @chatStop.
  ///
  /// In zh, this message translates to:
  /// **'停止'**
  String get chatStop;

  /// No description provided for @chatStopped.
  ///
  /// In zh, this message translates to:
  /// **'已停止'**
  String get chatStopped;

  /// No description provided for @chatResend.
  ///
  /// In zh, this message translates to:
  /// **'重发'**
  String get chatResend;

  /// No description provided for @chatRegenerate.
  ///
  /// In zh, this message translates to:
  /// **'重新生成'**
  String get chatRegenerate;

  /// No description provided for @chatReconnecting.
  ///
  /// In zh, this message translates to:
  /// **'重连中'**
  String get chatReconnecting;

  /// No description provided for @chatCompacted.
  ///
  /// In zh, this message translates to:
  /// **'上下文已压缩'**
  String get chatCompacted;

  /// No description provided for @chatHistoryError.
  ///
  /// In zh, this message translates to:
  /// **'历史消息加载失败'**
  String get chatHistoryError;

  /// No description provided for @chatEmpty.
  ///
  /// In zh, this message translates to:
  /// **'输入消息开始对话'**
  String get chatEmpty;

  /// No description provided for @chatAuthTitle.
  ///
  /// In zh, this message translates to:
  /// **'需要授权'**
  String get chatAuthTitle;

  /// No description provided for @chatToolCalling.
  ///
  /// In zh, this message translates to:
  /// **'工具调用'**
  String get chatToolCalling;

  /// No description provided for @chatToolRunning.
  ///
  /// In zh, this message translates to:
  /// **'进行中'**
  String get chatToolRunning;

  /// No description provided for @chatToolDone.
  ///
  /// In zh, this message translates to:
  /// **'完成'**
  String get chatToolDone;

  /// No description provided for @chatNoAgent.
  ///
  /// In zh, this message translates to:
  /// **'没有可用的 Agent'**
  String get chatNoAgent;

  /// No description provided for @chatLoadAgents.
  ///
  /// In zh, this message translates to:
  /// **'重新加载'**
  String get chatLoadAgents;

  /// No description provided for @chatNoSessions.
  ///
  /// In zh, this message translates to:
  /// **'暂无会话'**
  String get chatNoSessions;

  /// No description provided for @chatRename.
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get chatRename;

  /// No description provided for @chatDelete.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get chatDelete;

  /// No description provided for @chatDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'删除该会话？删除后不可恢复'**
  String get chatDeleteConfirm;

  /// No description provided for @chatOnlyMode.
  ///
  /// In zh, this message translates to:
  /// **'仅聊天模式'**
  String get chatOnlyMode;

  /// No description provided for @chatThinking.
  ///
  /// In zh, this message translates to:
  /// **'思考中…'**
  String get chatThinking;

  /// No description provided for @chatSteer.
  ///
  /// In zh, this message translates to:
  /// **'插话到当前回合'**
  String get chatSteer;

  /// No description provided for @chatToday.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get chatToday;

  /// No description provided for @chatYesterday.
  ///
  /// In zh, this message translates to:
  /// **'昨天'**
  String get chatYesterday;

  /// No description provided for @chatPickAttachmentError.
  ///
  /// In zh, this message translates to:
  /// **'附件读取失败'**
  String get chatPickAttachmentError;

  /// No description provided for @chatAttachLimit.
  ///
  /// In zh, this message translates to:
  /// **'最多 8 个附件'**
  String get chatAttachLimit;

  /// No description provided for @chatFileTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'文件过大（上限 50MB）：{name}'**
  String chatFileTooLarge(String name);

  /// No description provided for @chatAttachTotalTooLarge.
  ///
  /// In zh, this message translates to:
  /// **'附件总大小超过 100MB 上限'**
  String get chatAttachTotalTooLarge;

  /// No description provided for @navProjects.
  ///
  /// In zh, this message translates to:
  /// **'项目'**
  String get navProjects;

  /// No description provided for @navMe.
  ///
  /// In zh, this message translates to:
  /// **'我的'**
  String get navMe;

  /// No description provided for @drawerRole.
  ///
  /// In zh, this message translates to:
  /// **'你的智能助理'**
  String get drawerRole;

  /// No description provided for @drawerChatHistory.
  ///
  /// In zh, this message translates to:
  /// **'对话历史'**
  String get drawerChatHistory;

  /// No description provided for @projectsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无项目'**
  String get projectsEmpty;

  /// No description provided for @kbSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索知识库内容…'**
  String get kbSearchHint;

  /// No description provided for @kbArticles.
  ///
  /// In zh, this message translates to:
  /// **'文章'**
  String get kbArticles;

  /// No description provided for @kbNotes.
  ///
  /// In zh, this message translates to:
  /// **'笔记'**
  String get kbNotes;

  /// No description provided for @kbIdeas.
  ///
  /// In zh, this message translates to:
  /// **'灵感'**
  String get kbIdeas;

  /// No description provided for @kbTodos.
  ///
  /// In zh, this message translates to:
  /// **'待办'**
  String get kbTodos;

  /// No description provided for @kbDiary.
  ///
  /// In zh, this message translates to:
  /// **'日记'**
  String get kbDiary;

  /// No description provided for @kbViewList.
  ///
  /// In zh, this message translates to:
  /// **'列表'**
  String get kbViewList;

  /// No description provided for @kbViewCalendar.
  ///
  /// In zh, this message translates to:
  /// **'日历'**
  String get kbViewCalendar;

  /// No description provided for @kbViewGantt.
  ///
  /// In zh, this message translates to:
  /// **'甘特'**
  String get kbViewGantt;

  /// No description provided for @kbViewMonth.
  ///
  /// In zh, this message translates to:
  /// **'月'**
  String get kbViewMonth;

  /// No description provided for @kbViewWeek.
  ///
  /// In zh, this message translates to:
  /// **'周'**
  String get kbViewWeek;

  /// No description provided for @kbViewDay.
  ///
  /// In zh, this message translates to:
  /// **'日'**
  String get kbViewDay;

  /// No description provided for @kbScopeMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月'**
  String get kbScopeMonth;

  /// No description provided for @kbScopeWeek.
  ///
  /// In zh, this message translates to:
  /// **'本周'**
  String get kbScopeWeek;

  /// No description provided for @kbScopeDay.
  ///
  /// In zh, this message translates to:
  /// **'今天'**
  String get kbScopeDay;

  /// No description provided for @kbNoTodos.
  ///
  /// In zh, this message translates to:
  /// **'暂无待办'**
  String get kbNoTodos;

  /// No description provided for @kbGanttCount.
  ///
  /// In zh, this message translates to:
  /// **'{n} 项'**
  String kbGanttCount(int n);

  /// No description provided for @kbBookmarks.
  ///
  /// In zh, this message translates to:
  /// **'书签'**
  String get kbBookmarks;

  /// No description provided for @kbCards.
  ///
  /// In zh, this message translates to:
  /// **'卡片'**
  String get kbCards;

  /// No description provided for @kbWiki.
  ///
  /// In zh, this message translates to:
  /// **'维基'**
  String get kbWiki;

  /// No description provided for @diaryOverview.
  ///
  /// In zh, this message translates to:
  /// **'今日概要'**
  String get diaryOverview;

  /// No description provided for @diaryThemes.
  ///
  /// In zh, this message translates to:
  /// **'今天聊了什么'**
  String get diaryThemes;

  /// No description provided for @diaryNoThemes.
  ///
  /// In zh, this message translates to:
  /// **'没有可归纳的主题'**
  String get diaryNoThemes;

  /// No description provided for @diaryBlindspots.
  ///
  /// In zh, this message translates to:
  /// **'你可能忽略的重点'**
  String get diaryBlindspots;

  /// No description provided for @diaryArchives.
  ///
  /// In zh, this message translates to:
  /// **'今日归档'**
  String get diaryArchives;

  /// No description provided for @diaryGenerate.
  ///
  /// In zh, this message translates to:
  /// **'生成'**
  String get diaryGenerate;

  /// No description provided for @diaryGenerating.
  ///
  /// In zh, this message translates to:
  /// **'生成中…'**
  String get diaryGenerating;

  /// No description provided for @diaryNoDiary.
  ///
  /// In zh, this message translates to:
  /// **'该日期还没有日记'**
  String get diaryNoDiary;

  /// No description provided for @diaryNoDiaryMonth.
  ///
  /// In zh, this message translates to:
  /// **'本月还没有日记'**
  String get diaryNoDiaryMonth;

  /// No description provided for @diaryHeatHint.
  ///
  /// In zh, this message translates to:
  /// **'颜色越深，当天内容越多'**
  String get diaryHeatHint;

  /// No description provided for @diaryPrevMonth.
  ///
  /// In zh, this message translates to:
  /// **'上一月'**
  String get diaryPrevMonth;

  /// No description provided for @diaryNextMonth.
  ///
  /// In zh, this message translates to:
  /// **'下一月'**
  String get diaryNextMonth;

  /// No description provided for @diaryListMeta.
  ///
  /// In zh, this message translates to:
  /// **'{date} · {themes} 主题 · {blindspots} 盲区'**
  String diaryListMeta(Object date, int themes, int blindspots);

  /// No description provided for @meAgents.
  ///
  /// In zh, this message translates to:
  /// **'智能体'**
  String get meAgents;

  /// No description provided for @meGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get meGeneral;

  /// No description provided for @meAbout.
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get meAbout;

  /// No description provided for @meAgentManage.
  ///
  /// In zh, this message translates to:
  /// **'Agent 管理'**
  String get meAgentManage;

  /// No description provided for @meVersion.
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get meVersion;

  /// No description provided for @chatSuggest1.
  ///
  /// In zh, this message translates to:
  /// **'总结一下最近的对话'**
  String get chatSuggest1;

  /// No description provided for @chatSuggest2.
  ///
  /// In zh, this message translates to:
  /// **'帮我列一个今日待办'**
  String get chatSuggest2;

  /// No description provided for @chatSuggest3.
  ///
  /// In zh, this message translates to:
  /// **'随便聊点什么'**
  String get chatSuggest3;

  /// No description provided for @chatSend.
  ///
  /// In zh, this message translates to:
  /// **'发送'**
  String get chatSend;

  /// No description provided for @chatAttach.
  ///
  /// In zh, this message translates to:
  /// **'添加附件'**
  String get chatAttach;

  /// No description provided for @chatCopy.
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get chatCopy;

  /// No description provided for @chatFork.
  ///
  /// In zh, this message translates to:
  /// **'从此处分叉对话'**
  String get chatFork;

  /// No description provided for @kbClear.
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get kbClear;

  /// No description provided for @wikiEntity.
  ///
  /// In zh, this message translates to:
  /// **'实体'**
  String get wikiEntity;

  /// No description provided for @wikiConcept.
  ///
  /// In zh, this message translates to:
  /// **'概念'**
  String get wikiConcept;

  /// No description provided for @wikiSource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get wikiSource;

  /// No description provided for @wikiSearchHint.
  ///
  /// In zh, this message translates to:
  /// **'搜索页面…'**
  String get wikiSearchHint;

  /// No description provided for @wikiNoPages.
  ///
  /// In zh, this message translates to:
  /// **'暂无 Wiki 页面。请在知识库设置中生成。'**
  String get wikiNoPages;

  /// No description provided for @wikiNoMatch.
  ///
  /// In zh, this message translates to:
  /// **'没有匹配的页面'**
  String get wikiNoMatch;

  /// No description provided for @wikiStats.
  ///
  /// In zh, this message translates to:
  /// **'{pages} 页 · {links} 链接'**
  String wikiStats(Object pages, Object links);

  /// No description provided for @wikiDeleteTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除页面'**
  String get wikiDeleteTitle;

  /// No description provided for @wikiDeleteConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除「{name}」？此操作无法撤销。'**
  String wikiDeleteConfirm(Object name);

  /// No description provided for @wikiKnowledgeGraph.
  ///
  /// In zh, this message translates to:
  /// **'知识图谱'**
  String get wikiKnowledgeGraph;

  /// No description provided for @wikiFit.
  ///
  /// In zh, this message translates to:
  /// **'重置视图'**
  String get wikiFit;

  /// No description provided for @wikiOpen.
  ///
  /// In zh, this message translates to:
  /// **'打开'**
  String get wikiOpen;

  /// No description provided for @wikiViewInGraph.
  ///
  /// In zh, this message translates to:
  /// **'在图谱中查看'**
  String get wikiViewInGraph;

  /// No description provided for @wikiEditPage.
  ///
  /// In zh, this message translates to:
  /// **'编辑页面'**
  String get wikiEditPage;

  /// No description provided for @wikiTitleLabel.
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get wikiTitleLabel;

  /// No description provided for @wikiLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get wikiLoadFailed;

  /// No description provided for @chatOnlyChip.
  ///
  /// In zh, this message translates to:
  /// **'仅对话'**
  String get chatOnlyChip;

  /// No description provided for @chatImReadOnlyHint.
  ///
  /// In zh, this message translates to:
  /// **'只读——此对话来自 IM 渠道'**
  String get chatImReadOnlyHint;

  /// No description provided for @chatImChannelBadge.
  ///
  /// In zh, this message translates to:
  /// **'IM 渠道会话（只读）'**
  String get chatImChannelBadge;

  /// No description provided for @kbEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get kbEmpty;

  /// No description provided for @kbTomorrow.
  ///
  /// In zh, this message translates to:
  /// **'明天'**
  String get kbTomorrow;

  /// No description provided for @kbNoDate.
  ///
  /// In zh, this message translates to:
  /// **'无日期'**
  String get kbNoDate;

  /// No description provided for @kbAddTodo.
  ///
  /// In zh, this message translates to:
  /// **'新建待办'**
  String get kbAddTodo;

  /// No description provided for @kbTodoHint.
  ///
  /// In zh, this message translates to:
  /// **'待办内容'**
  String get kbTodoHint;

  /// No description provided for @todoStatusPending.
  ///
  /// In zh, this message translates to:
  /// **'待执行'**
  String get todoStatusPending;

  /// No description provided for @todoStatusInProgress.
  ///
  /// In zh, this message translates to:
  /// **'执行中'**
  String get todoStatusInProgress;

  /// No description provided for @todoStatusDone.
  ///
  /// In zh, this message translates to:
  /// **'已完成'**
  String get todoStatusDone;

  /// No description provided for @todoStatusCancelled.
  ///
  /// In zh, this message translates to:
  /// **'已取消'**
  String get todoStatusCancelled;

  /// No description provided for @kbStatus.
  ///
  /// In zh, this message translates to:
  /// **'状态'**
  String get kbStatus;

  /// No description provided for @kbNotSet.
  ///
  /// In zh, this message translates to:
  /// **'未设置'**
  String get kbNotSet;

  /// No description provided for @kbDueDate.
  ///
  /// In zh, this message translates to:
  /// **'日期'**
  String get kbDueDate;

  /// No description provided for @kbStartDate.
  ///
  /// In zh, this message translates to:
  /// **'开始时间'**
  String get kbStartDate;

  /// No description provided for @kbEndDate.
  ///
  /// In zh, this message translates to:
  /// **'结束时间'**
  String get kbEndDate;

  /// No description provided for @kbAddFlash.
  ///
  /// In zh, this message translates to:
  /// **'记一笔'**
  String get kbAddFlash;

  /// No description provided for @kbFlashHint.
  ///
  /// In zh, this message translates to:
  /// **'一闪而过的灵感…'**
  String get kbFlashHint;

  /// No description provided for @kbDeduped.
  ///
  /// In zh, this message translates to:
  /// **'与已有内容重复，未保存'**
  String get kbDeduped;

  /// No description provided for @kbAddBookmark.
  ///
  /// In zh, this message translates to:
  /// **'保存书签'**
  String get kbAddBookmark;

  /// No description provided for @kbTitleOptional.
  ///
  /// In zh, this message translates to:
  /// **'标题（可选）'**
  String get kbTitleOptional;

  /// No description provided for @kbSummary.
  ///
  /// In zh, this message translates to:
  /// **'摘要'**
  String get kbSummary;

  /// No description provided for @kbPromote.
  ///
  /// In zh, this message translates to:
  /// **'升格为文章'**
  String get kbPromote;

  /// No description provided for @kbPromoted.
  ///
  /// In zh, this message translates to:
  /// **'已升格为文章'**
  String get kbPromoted;

  /// No description provided for @kbGenerateInsights.
  ///
  /// In zh, this message translates to:
  /// **'生成深度解读'**
  String get kbGenerateInsights;

  /// No description provided for @kbInsights.
  ///
  /// In zh, this message translates to:
  /// **'深度解读'**
  String get kbInsights;

  /// No description provided for @kbOriginal.
  ///
  /// In zh, this message translates to:
  /// **'原文'**
  String get kbOriginal;

  /// No description provided for @kbCoreSummary.
  ///
  /// In zh, this message translates to:
  /// **'概要'**
  String get kbCoreSummary;

  /// No description provided for @kbChapters.
  ///
  /// In zh, this message translates to:
  /// **'章节'**
  String get kbChapters;

  /// No description provided for @kbSprouts.
  ///
  /// In zh, this message translates to:
  /// **'新芽'**
  String get kbSprouts;

  /// No description provided for @kbArchive.
  ///
  /// In zh, this message translates to:
  /// **'归档'**
  String get kbArchive;

  /// No description provided for @kbEdit.
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get kbEdit;

  /// No description provided for @chatFiles.
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get chatFiles;

  /// No description provided for @fileNoPreview.
  ///
  /// In zh, this message translates to:
  /// **'该类型暂不支持预览'**
  String get fileNoPreview;

  /// No description provided for @mediaPlayFailed.
  ///
  /// In zh, this message translates to:
  /// **'播放失败'**
  String get mediaPlayFailed;

  /// No description provided for @themeTitle.
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get themeTitle;

  /// No description provided for @fontSizeTitle.
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSizeTitle;

  /// No description provided for @fontSmall.
  ///
  /// In zh, this message translates to:
  /// **'小'**
  String get fontSmall;

  /// No description provided for @fontMedium.
  ///
  /// In zh, this message translates to:
  /// **'中'**
  String get fontMedium;

  /// No description provided for @fontLarge.
  ///
  /// In zh, this message translates to:
  /// **'大'**
  String get fontLarge;

  /// No description provided for @themeSystem.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// No description provided for @kbQuotes.
  ///
  /// In zh, this message translates to:
  /// **'金句'**
  String get kbQuotes;

  /// No description provided for @kbActions.
  ///
  /// In zh, this message translates to:
  /// **'行动'**
  String get kbActions;

  /// No description provided for @kbGenerating.
  ///
  /// In zh, this message translates to:
  /// **'生成中…'**
  String get kbGenerating;

  /// No description provided for @cardAdd.
  ///
  /// In zh, this message translates to:
  /// **'新建卡片'**
  String get cardAdd;

  /// No description provided for @cardQuestion.
  ///
  /// In zh, this message translates to:
  /// **'问题（正面）'**
  String get cardQuestion;

  /// No description provided for @cardAnswer.
  ///
  /// In zh, this message translates to:
  /// **'答案（背面）'**
  String get cardAnswer;

  /// No description provided for @cardSource.
  ///
  /// In zh, this message translates to:
  /// **'来源'**
  String get cardSource;

  /// No description provided for @shareTargetTitle.
  ///
  /// In zh, this message translates to:
  /// **'分享到'**
  String get shareTargetTitle;

  /// No description provided for @shareToNote.
  ///
  /// In zh, this message translates to:
  /// **'存为笔记'**
  String get shareToNote;

  /// No description provided for @shareToNoteHint.
  ///
  /// In zh, this message translates to:
  /// **'全文存入知识库笔记'**
  String get shareToNoteHint;

  /// No description provided for @shareToChat.
  ///
  /// In zh, this message translates to:
  /// **'发送到对话'**
  String get shareToChat;

  /// No description provided for @shareToChatHint.
  ///
  /// In zh, this message translates to:
  /// **'新对话或选择会话'**
  String get shareToChatHint;

  /// No description provided for @shareToArticle.
  ///
  /// In zh, this message translates to:
  /// **'存为文章'**
  String get shareToArticle;

  /// No description provided for @shareToArticleHint.
  ///
  /// In zh, this message translates to:
  /// **'抓取原文入库'**
  String get shareToArticleHint;

  /// No description provided for @shareToBookmark.
  ///
  /// In zh, this message translates to:
  /// **'存为书签'**
  String get shareToBookmark;

  /// No description provided for @shareToBookmarkHint.
  ///
  /// In zh, this message translates to:
  /// **'保存链接到书签'**
  String get shareToBookmarkHint;

  /// No description provided for @shareText.
  ///
  /// In zh, this message translates to:
  /// **'文本'**
  String get shareText;

  /// No description provided for @shareLink.
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get shareLink;

  /// No description provided for @shareFiles.
  ///
  /// In zh, this message translates to:
  /// **'{n} 个文件'**
  String shareFiles(Object n);

  /// No description provided for @shareArticleDone.
  ///
  /// In zh, this message translates to:
  /// **'已入库为文章，稍后可在知识库查看'**
  String get shareArticleDone;

  /// No description provided for @shareNoteDone.
  ///
  /// In zh, this message translates to:
  /// **'已存为笔记'**
  String get shareNoteDone;

  /// No description provided for @shareBookmarkDone.
  ///
  /// In zh, this message translates to:
  /// **'已加入书签'**
  String get shareBookmarkDone;

  /// No description provided for @shareImages.
  ///
  /// In zh, this message translates to:
  /// **'{n} 张图片'**
  String shareImages(Object n);

  /// No description provided for @shareFileOut.
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get shareFileOut;

  /// No description provided for @sharePreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在准备分享…'**
  String get sharePreparing;

  /// No description provided for @downloadFile.
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get downloadFile;

  /// No description provided for @downloadPreparing.
  ///
  /// In zh, this message translates to:
  /// **'正在下载…'**
  String get downloadPreparing;

  /// No description provided for @downloadDone.
  ///
  /// In zh, this message translates to:
  /// **'已保存到系统下载目录'**
  String get downloadDone;

  /// No description provided for @cardExcerpt.
  ///
  /// In zh, this message translates to:
  /// **'原始内容'**
  String get cardExcerpt;

  /// No description provided for @cardExplanation.
  ///
  /// In zh, this message translates to:
  /// **'解释'**
  String get cardExplanation;

  /// No description provided for @cardFromDiary.
  ///
  /// In zh, this message translates to:
  /// **'来自 {date} 的日记'**
  String cardFromDiary(Object date);

  /// No description provided for @cardViewWiki.
  ///
  /// In zh, this message translates to:
  /// **'查看 Wiki 原文'**
  String get cardViewWiki;

  /// No description provided for @cardDue.
  ///
  /// In zh, this message translates to:
  /// **'待复习'**
  String get cardDue;

  /// No description provided for @cardActive.
  ///
  /// In zh, this message translates to:
  /// **'学习中'**
  String get cardActive;

  /// No description provided for @cardMastered.
  ///
  /// In zh, this message translates to:
  /// **'已掌握'**
  String get cardMastered;

  /// No description provided for @cardArchived.
  ///
  /// In zh, this message translates to:
  /// **'已归档'**
  String get cardArchived;

  /// No description provided for @cardReviewCount.
  ///
  /// In zh, this message translates to:
  /// **'复习 {count} 次'**
  String cardReviewCount(Object count);

  /// No description provided for @cardLapseCount.
  ///
  /// In zh, this message translates to:
  /// **'失败 {count} 次'**
  String cardLapseCount(Object count);

  /// No description provided for @cardStart.
  ///
  /// In zh, this message translates to:
  /// **'开始复习'**
  String get cardStart;

  /// No description provided for @cardReview.
  ///
  /// In zh, this message translates to:
  /// **'卡片复习'**
  String get cardReview;

  /// No description provided for @cardForgot.
  ///
  /// In zh, this message translates to:
  /// **'忘了'**
  String get cardForgot;

  /// No description provided for @cardFuzzy.
  ///
  /// In zh, this message translates to:
  /// **'模糊'**
  String get cardFuzzy;

  /// No description provided for @cardRemembered.
  ///
  /// In zh, this message translates to:
  /// **'记得'**
  String get cardRemembered;

  /// No description provided for @cardTapToReveal.
  ///
  /// In zh, this message translates to:
  /// **'点击显示答案'**
  String get cardTapToReveal;

  /// No description provided for @cardDone.
  ///
  /// In zh, this message translates to:
  /// **'复习完成！'**
  String get cardDone;

  /// No description provided for @cardBack.
  ///
  /// In zh, this message translates to:
  /// **'返回'**
  String get cardBack;

  /// No description provided for @noteUntitled.
  ///
  /// In zh, this message translates to:
  /// **'无标题笔记'**
  String get noteUntitled;

  /// No description provided for @noteNew.
  ///
  /// In zh, this message translates to:
  /// **'新建笔记'**
  String get noteNew;

  /// No description provided for @noteDiscard.
  ///
  /// In zh, this message translates to:
  /// **'放弃未保存的修改？'**
  String get noteDiscard;

  /// No description provided for @exitAgain.
  ///
  /// In zh, this message translates to:
  /// **'再按一次返回退出'**
  String get exitAgain;

  /// No description provided for @noteBodyHint.
  ///
  /// In zh, this message translates to:
  /// **'正文（Markdown）'**
  String get noteBodyHint;

  /// No description provided for @noteAttachments.
  ///
  /// In zh, this message translates to:
  /// **'附件（只读）'**
  String get noteAttachments;

  /// No description provided for @tabProfile.
  ///
  /// In zh, this message translates to:
  /// **'资料'**
  String get tabProfile;

  /// No description provided for @tabModels.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get tabModels;

  /// No description provided for @tabContext.
  ///
  /// In zh, this message translates to:
  /// **'上下文'**
  String get tabContext;

  /// No description provided for @tabCustomize.
  ///
  /// In zh, this message translates to:
  /// **'回复'**
  String get tabCustomize;

  /// No description provided for @tabKnowledge.
  ///
  /// In zh, this message translates to:
  /// **'知识库'**
  String get tabKnowledge;

  /// No description provided for @tabSkills.
  ///
  /// In zh, this message translates to:
  /// **'技能'**
  String get tabSkills;

  /// No description provided for @tabMcp.
  ///
  /// In zh, this message translates to:
  /// **'MCP'**
  String get tabMcp;

  /// No description provided for @tabPlugins.
  ///
  /// In zh, this message translates to:
  /// **'插件'**
  String get tabPlugins;

  /// No description provided for @tabScheduler.
  ///
  /// In zh, this message translates to:
  /// **'定时'**
  String get tabScheduler;

  /// No description provided for @tabRegexHooks.
  ///
  /// In zh, this message translates to:
  /// **'正则钩子'**
  String get tabRegexHooks;

  /// No description provided for @tabRecall.
  ///
  /// In zh, this message translates to:
  /// **'召回'**
  String get tabRecall;

  /// No description provided for @tabVectorization.
  ///
  /// In zh, this message translates to:
  /// **'向量化'**
  String get tabVectorization;

  /// No description provided for @tabPrivacy.
  ///
  /// In zh, this message translates to:
  /// **'隐私'**
  String get tabPrivacy;

  /// No description provided for @tabUsage.
  ///
  /// In zh, this message translates to:
  /// **'用量'**
  String get tabUsage;

  /// No description provided for @tabChannels.
  ///
  /// In zh, this message translates to:
  /// **'频道'**
  String get tabChannels;

  /// No description provided for @tabName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get tabName;

  /// No description provided for @tabDescription.
  ///
  /// In zh, this message translates to:
  /// **'描述'**
  String get tabDescription;

  /// No description provided for @tabModel.
  ///
  /// In zh, this message translates to:
  /// **'模型'**
  String get tabModel;

  /// No description provided for @settingsProvider.
  ///
  /// In zh, this message translates to:
  /// **'服务商'**
  String get settingsProvider;

  /// No description provided for @settingsModelInherit.
  ///
  /// In zh, this message translates to:
  /// **'跟随系统默认'**
  String get settingsModelInherit;

  /// No description provided for @tabCustomizeHint.
  ///
  /// In zh, this message translates to:
  /// **'开关保存后立即生效'**
  String get tabCustomizeHint;

  /// No description provided for @settingsSave.
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get settingsSave;

  /// No description provided for @settingsReload.
  ///
  /// In zh, this message translates to:
  /// **'重载'**
  String get settingsReload;

  /// No description provided for @settingsAdd.
  ///
  /// In zh, this message translates to:
  /// **'添加'**
  String get settingsAdd;

  /// No description provided for @settingsEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无内容'**
  String get settingsEmpty;

  /// No description provided for @settingsCenter.
  ///
  /// In zh, this message translates to:
  /// **'系统设置'**
  String get settingsCenter;

  /// No description provided for @settingsGeneral.
  ///
  /// In zh, this message translates to:
  /// **'通用'**
  String get settingsGeneral;

  /// No description provided for @settingsModels.
  ///
  /// In zh, this message translates to:
  /// **'模型服务'**
  String get settingsModels;

  /// No description provided for @settingsAdvanced.
  ///
  /// In zh, this message translates to:
  /// **'高级（备份 / 定时 / 密钥 / 诊断）'**
  String get settingsAdvanced;

  /// No description provided for @settingsBackup.
  ///
  /// In zh, this message translates to:
  /// **'备份'**
  String get settingsBackup;

  /// No description provided for @settingsCron.
  ///
  /// In zh, this message translates to:
  /// **'定时任务'**
  String get settingsCron;

  /// No description provided for @settingsApiKeys.
  ///
  /// In zh, this message translates to:
  /// **'API 密钥'**
  String get settingsApiKeys;

  /// No description provided for @settingsDiag.
  ///
  /// In zh, this message translates to:
  /// **'诊断报告'**
  String get settingsDiag;

  /// No description provided for @webLoading.
  ///
  /// In zh, this message translates to:
  /// **'加载中…'**
  String get webLoading;

  /// No description provided for @webLoadFailed.
  ///
  /// In zh, this message translates to:
  /// **'页面加载失败'**
  String get webLoadFailed;

  /// No description provided for @webReloginHint.
  ///
  /// In zh, this message translates to:
  /// **'若会话已过期，请重新登录后再试'**
  String get webReloginHint;

  /// No description provided for @mermaidHint.
  ///
  /// In zh, this message translates to:
  /// **'Mermaid 图表，点击全屏查看'**
  String get mermaidHint;

  /// No description provided for @noteWhiteboard.
  ///
  /// In zh, this message translates to:
  /// **'白板'**
  String get noteWhiteboard;

  /// No description provided for @chatOfflineHint.
  ///
  /// In zh, this message translates to:
  /// **'离线缓存内容，联网后自动刷新'**
  String get chatOfflineHint;

  /// No description provided for @updateCheck.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get updateCheck;

  /// No description provided for @updateNone.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get updateNone;

  /// No description provided for @updateAvailable.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get updateAvailable;

  /// No description provided for @updateDownload.
  ///
  /// In zh, this message translates to:
  /// **'下载更新'**
  String get updateDownload;

  /// No description provided for @confirm.
  ///
  /// In zh, this message translates to:
  /// **'确定'**
  String get confirm;

  /// No description provided for @drawerGroupAgent.
  ///
  /// In zh, this message translates to:
  /// **'智能体'**
  String get drawerGroupAgent;

  /// No description provided for @drawerChats.
  ///
  /// In zh, this message translates to:
  /// **'对话'**
  String get drawerChats;

  /// No description provided for @seeAllChats.
  ///
  /// In zh, this message translates to:
  /// **'查看更多对话'**
  String get seeAllChats;

  /// No description provided for @noProjects.
  ///
  /// In zh, this message translates to:
  /// **'暂无项目'**
  String get noProjects;

  /// No description provided for @newProject.
  ///
  /// In zh, this message translates to:
  /// **'新建项目'**
  String get newProject;

  /// No description provided for @newChatInProject.
  ///
  /// In zh, this message translates to:
  /// **'在项目中新建对话'**
  String get newChatInProject;

  /// No description provided for @editProject.
  ///
  /// In zh, this message translates to:
  /// **'编辑项目'**
  String get editProject;

  /// No description provided for @deleteProject.
  ///
  /// In zh, this message translates to:
  /// **'删除项目'**
  String get deleteProject;

  /// No description provided for @deleteProjectTitle.
  ///
  /// In zh, this message translates to:
  /// **'删除项目'**
  String get deleteProjectTitle;

  /// No description provided for @deleteProjectConfirm.
  ///
  /// In zh, this message translates to:
  /// **'确定删除项目“{name}”？'**
  String deleteProjectConfirm(Object name);

  /// No description provided for @projectDeleteBlocked.
  ///
  /// In zh, this message translates to:
  /// **'该项目仍有 {count} 个对话，请先删除或移动。'**
  String projectDeleteBlocked(Object count);

  /// No description provided for @projectNameLabel.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get projectNameLabel;

  /// No description provided for @projectDescriptionLabel.
  ///
  /// In zh, this message translates to:
  /// **'描述（可选）'**
  String get projectDescriptionLabel;

  /// No description provided for @dashHeroHint.
  ///
  /// In zh, this message translates to:
  /// **'发送消息开始对话'**
  String get dashHeroHint;

  /// No description provided for @dashCardsTitle.
  ///
  /// In zh, this message translates to:
  /// **'今日卡片'**
  String get dashCardsTitle;

  /// No description provided for @dashCardsDue.
  ///
  /// In zh, this message translates to:
  /// **'{n} 张到期'**
  String dashCardsDue(Object n);

  /// No description provided for @dashCardsNone.
  ///
  /// In zh, this message translates to:
  /// **'今天没有到期卡片'**
  String get dashCardsNone;

  /// No description provided for @dashCardsStreak.
  ///
  /// In zh, this message translates to:
  /// **'已连续 {n} 天'**
  String dashCardsStreak(Object n);

  /// No description provided for @dashCardsBrowse.
  ///
  /// In zh, this message translates to:
  /// **'前往卡片库 →'**
  String get dashCardsBrowse;

  /// No description provided for @dashTodoTitle.
  ///
  /// In zh, this message translates to:
  /// **'待办'**
  String get dashTodoTitle;

  /// No description provided for @dashTodoNone.
  ///
  /// In zh, this message translates to:
  /// **'暂无待办'**
  String get dashTodoNone;

  /// No description provided for @dashTodoView.
  ///
  /// In zh, this message translates to:
  /// **'前往待办 →'**
  String get dashTodoView;

  /// No description provided for @dashTodoOverdue.
  ///
  /// In zh, this message translates to:
  /// **'已过期'**
  String get dashTodoOverdue;

  /// No description provided for @dashRecentTitle.
  ///
  /// In zh, this message translates to:
  /// **'最近对话'**
  String get dashRecentTitle;

  /// No description provided for @dashRecentAll.
  ///
  /// In zh, this message translates to:
  /// **'查看更多对话 →'**
  String get dashRecentAll;

  /// No description provided for @dashRecentNone.
  ///
  /// In zh, this message translates to:
  /// **'还没有对话'**
  String get dashRecentNone;

  /// No description provided for @dashCronTitle.
  ///
  /// In zh, this message translates to:
  /// **'定时任务'**
  String get dashCronTitle;

  /// No description provided for @dashCronNone.
  ///
  /// In zh, this message translates to:
  /// **'没有启用的定时任务'**
  String get dashCronNone;

  /// No description provided for @editorIssues.
  ///
  /// In zh, this message translates to:
  /// **'⚠ {count, plural, =1{1 个问题} other{{count} 个问题}}'**
  String editorIssues(num count);

  /// No description provided for @editorIssueGo.
  ///
  /// In zh, this message translates to:
  /// **'第 {line} 行'**
  String editorIssueGo(Object line);

  /// No description provided for @editorLintUnclosedCodeFence.
  ///
  /// In zh, this message translates to:
  /// **'代码围栏未闭合（```）'**
  String get editorLintUnclosedCodeFence;

  /// No description provided for @editorLintUnclosedMathFence.
  ///
  /// In zh, this message translates to:
  /// **'公式块未闭合（\$\$）'**
  String get editorLintUnclosedMathFence;

  /// No description provided for @editorLintOddDollars.
  ///
  /// In zh, this message translates to:
  /// **'行内公式定界符不配对（\$）'**
  String get editorLintOddDollars;

  /// No description provided for @editorLintTableColumns.
  ///
  /// In zh, this message translates to:
  /// **'表格分隔行列数与表头不一致'**
  String get editorLintTableColumns;

  /// No description provided for @settingsMaxTokens.
  ///
  /// In zh, this message translates to:
  /// **'最大 Token 数'**
  String get settingsMaxTokens;

  /// No description provided for @settingsTemperature.
  ///
  /// In zh, this message translates to:
  /// **'温度'**
  String get settingsTemperature;

  /// No description provided for @settingsMaxToolIterations.
  ///
  /// In zh, this message translates to:
  /// **'最大工具迭代数'**
  String get settingsMaxToolIterations;

  /// No description provided for @settingsPromptMode.
  ///
  /// In zh, this message translates to:
  /// **'提示词模式'**
  String get settingsPromptMode;

  /// No description provided for @settingsGuidance.
  ///
  /// In zh, this message translates to:
  /// **'引导模式'**
  String get settingsGuidance;

  /// No description provided for @settingsCompactionMode.
  ///
  /// In zh, this message translates to:
  /// **'上下文压缩模式'**
  String get settingsCompactionMode;

  /// No description provided for @settingsCompactionThreshold.
  ///
  /// In zh, this message translates to:
  /// **'压缩阈值'**
  String get settingsCompactionThreshold;

  /// No description provided for @settingsLanguage.
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get settingsLanguage;

  /// No description provided for @settingsSplitReplies.
  ///
  /// In zh, this message translates to:
  /// **'分条回复'**
  String get settingsSplitReplies;

  /// No description provided for @settingsAutoPersist.
  ///
  /// In zh, this message translates to:
  /// **'自动持久化'**
  String get settingsAutoPersist;

  /// No description provided for @settingsSharedIdentity.
  ///
  /// In zh, this message translates to:
  /// **'共享身份'**
  String get settingsSharedIdentity;

  /// No description provided for @settingsName.
  ///
  /// In zh, this message translates to:
  /// **'名称'**
  String get settingsName;

  /// No description provided for @settingsLangZh.
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get settingsLangZh;

  /// No description provided for @settingsLangEn.
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get settingsLangEn;

  /// No description provided for @articleCharsCount.
  ///
  /// In zh, this message translates to:
  /// **'{count} 字'**
  String articleCharsCount(Object count);

  /// No description provided for @articleCharsWan.
  ///
  /// In zh, this message translates to:
  /// **'{count} 万字'**
  String articleCharsWan(Object count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
