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

  /// No description provided for @chatPickImageError.
  ///
  /// In zh, this message translates to:
  /// **'图片读取失败'**
  String get chatPickImageError;
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
