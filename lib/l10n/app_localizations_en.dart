// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'fluctio';

  @override
  String get navChat => 'Chat';

  @override
  String get navKnowledge => 'Knowledge';

  @override
  String get navWiki => 'Wiki';

  @override
  String get navWorkflow => 'Workflows';

  @override
  String get navSettings => 'Settings';

  @override
  String get comingSoon => 'This module arrives in a later milestone';

  @override
  String get setupTitle => 'Connect to your fluctio';

  @override
  String get serverAddress => 'Server address';

  @override
  String get serverAddressHint => 'https://your-domain.com';

  @override
  String get allowSelfSigned => 'Trust self-signed certificates';

  @override
  String get allowSelfSignedSub => 'For LAN / self-hosted test addresses only';

  @override
  String get testConnection => 'Test connection';

  @override
  String get testing => 'Testing…';

  @override
  String get connectionOk => 'Connected';

  @override
  String get connectionFailed => 'Could not reach this address';

  @override
  String get saveAndContinue => 'Save and continue';

  @override
  String get loginTitle => 'Sign in';

  @override
  String get currentServer => 'Server';

  @override
  String get changeServer => 'Change server';

  @override
  String get accountLabel => 'Account';

  @override
  String get passwordLabel => 'Password';

  @override
  String get signIn => 'Sign in';

  @override
  String get signingIn => 'Signing in…';

  @override
  String get errorInvalidCredentials => 'Wrong account or password';

  @override
  String get errorRateLimited => 'Too many attempts; retry in a few minutes';

  @override
  String get errorNetwork =>
      'Network error — check the address and your connection';

  @override
  String get errorServerUnavailable =>
      'Server unavailable (gateway error) — retry later or check the server';

  @override
  String get errorInvalidFormat =>
      'Invalid address — must start with https:// (or LAN http://)';

  @override
  String get errorHttpsRequired => 'Public addresses must use https';

  @override
  String get errorLanNeedsTrust =>
      'LAN http addresses need \"trust self-signed\" enabled';

  @override
  String get sectionServer => 'Server';

  @override
  String get sectionAccount => 'Account';

  @override
  String get signedInAs => 'Signed in';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get signOut => 'Sign out';

  @override
  String get switchServer => 'Switch server';

  @override
  String get confirmSignOut => 'Sign out of the current account?';

  @override
  String get cancel => 'Cancel';

  @override
  String get chatNew => 'New chat';

  @override
  String get chatSessions => 'Chats';

  @override
  String get chatTodo => 'Session todo';

  @override
  String get chatTodoEmpty => 'No todo items for this session';

  @override
  String get chatStop => 'Stop';

  @override
  String get chatStopped => 'Stopped';

  @override
  String get chatResend => 'Resend';

  @override
  String get chatRegenerate => 'Regenerate';

  @override
  String get chatReconnecting => 'Reconnecting';

  @override
  String get chatCompacted => 'Context compacted';

  @override
  String get chatHistoryError => 'Failed to load history';

  @override
  String get chatEmpty => 'Type a message to start';

  @override
  String get chatAuthTitle => 'Approval needed';

  @override
  String get chatToolCalling => 'Tool call';

  @override
  String get chatToolRunning => 'running';

  @override
  String get chatToolDone => 'done';

  @override
  String get chatNoAgent => 'No agents available';

  @override
  String get chatLoadAgents => 'Retry';

  @override
  String get chatNoSessions => 'No chats yet';

  @override
  String get chatRename => 'Rename';

  @override
  String get chatDelete => 'Delete';

  @override
  String get chatDeleteConfirm => 'Delete this chat? This cannot be undone';

  @override
  String get chatOnlyMode => 'Chat-only mode';

  @override
  String get chatThinking => 'Thinking…';

  @override
  String get chatSteer => 'Steer the running turn';

  @override
  String get chatToday => 'Today';

  @override
  String get chatYesterday => 'Yesterday';

  @override
  String get chatPickImageError => 'Could not read the image';

  @override
  String get navProjects => 'Projects';

  @override
  String get navMe => 'Me';

  @override
  String get drawerRole => 'Your AI assistant';

  @override
  String get drawerChatHistory => 'Chat history';

  @override
  String get projectsEmpty => 'No projects yet';

  @override
  String get kbSearchHint => 'Search knowledge…';

  @override
  String get kbArticles => 'Articles';

  @override
  String get kbNotes => 'Notes';

  @override
  String get kbIdeas => 'Ideas';

  @override
  String get kbTodos => 'Todos';

  @override
  String get kbDiary => 'Diary';

  @override
  String get kbBookmarks => 'Bookmarks';

  @override
  String get kbCards => 'Cards';

  @override
  String get kbWiki => 'Wiki';

  @override
  String get meAgents => 'Agents';

  @override
  String get meGeneral => 'General';

  @override
  String get meAbout => 'About';

  @override
  String get meAgentManage => 'Agent management';

  @override
  String get meVersion => 'Version';

  @override
  String get chatSuggest1 => 'Summarize the recent conversation';

  @override
  String get chatSuggest2 => 'Draft today\'s todo list';

  @override
  String get chatSuggest3 => 'Just chat';

  @override
  String get chatSend => 'Send';

  @override
  String get chatAttach => 'Attach image';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatOnlyChip => 'Chat only';

  @override
  String get kbEmpty => 'Nothing here yet';

  @override
  String get kbTomorrow => 'Tomorrow';

  @override
  String get kbNoDate => 'No date';

  @override
  String get kbAddTodo => 'New todo';

  @override
  String get kbTodoHint => 'Todo content';

  @override
  String get kbDueDate => 'Date';

  @override
  String get kbAddFlash => 'Capture a flash';

  @override
  String get kbFlashHint => 'A fleeting thought…';

  @override
  String get kbDeduped => 'Duplicate of an existing entry — skipped';

  @override
  String get kbAddBookmark => 'Save bookmark';

  @override
  String get kbTitleOptional => 'Title (optional)';

  @override
  String get kbSummary => 'Summary';

  @override
  String get kbPromote => 'Promote to article';

  @override
  String get kbPromoted => 'Promoted to article';

  @override
  String get kbGenerateInsights => 'Generate deep reading';

  @override
  String get kbInsights => 'Deep reading';

  @override
  String get kbOriginal => 'Original';

  @override
  String get kbCoreSummary => 'Summary';

  @override
  String get kbChapters => 'Chapters';

  @override
  String get kbSprouts => 'Sprouts';

  @override
  String get kbArchive => 'Archive';

  @override
  String get kbEdit => 'Edit';

  @override
  String get chatFiles => 'Files';

  @override
  String get fileNoPreview => 'Preview not supported for this type';

  @override
  String get mediaPlayFailed => 'Playback failed';

  @override
  String get themeTitle => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get kbQuotes => 'Quotes';

  @override
  String get kbActions => 'Actions';

  @override
  String get kbGenerating => 'Generating…';

  @override
  String get cardAdd => 'New card';

  @override
  String get cardQuestion => 'Question (front)';

  @override
  String get cardAnswer => 'Answer (back)';

  @override
  String get cardDue => 'Due';

  @override
  String get cardActive => 'Active';

  @override
  String get cardMastered => 'Mastered';

  @override
  String get cardArchived => 'Archived';

  @override
  String cardReviewCount(Object count) {
    return '$count reviews';
  }

  @override
  String cardLapseCount(Object count) {
    return '$count lapses';
  }

  @override
  String get cardStreak => 'Streak';

  @override
  String get cardStart => 'Start review';

  @override
  String get cardAllDone => 'Today\'s review is clear';

  @override
  String get cardReview => 'Card review';

  @override
  String get cardForgot => 'Forgot';

  @override
  String get cardFuzzy => 'Fuzzy';

  @override
  String get cardRemembered => 'Got it';

  @override
  String get cardTapToReveal => 'Tap to reveal';

  @override
  String get cardDone => 'Review complete!';

  @override
  String get cardBack => 'Back';

  @override
  String get noteUntitled => 'Untitled note';

  @override
  String get noteNew => 'New note';

  @override
  String get noteDiscard => 'Discard unsaved changes?';

  @override
  String get noteBodyHint => 'Body (Markdown)';

  @override
  String get noteAttachments => 'Attachments (read-only)';

  @override
  String get tabProfile => 'Profile';

  @override
  String get tabModels => 'Models';

  @override
  String get tabContext => 'Context';

  @override
  String get tabCustomize => 'Replies';

  @override
  String get tabKnowledge => 'Knowledge';

  @override
  String get tabSkills => 'Skills';

  @override
  String get tabMcp => 'MCP';

  @override
  String get tabPlugins => 'Plugins';

  @override
  String get tabScheduler => 'Scheduler';

  @override
  String get tabRegexHooks => 'Regex hooks';

  @override
  String get tabRecall => 'Recall';

  @override
  String get tabVectorization => 'Vectorization';

  @override
  String get tabPrivacy => 'Privacy';

  @override
  String get tabUsage => 'Usage';

  @override
  String get tabChannels => 'Channels';

  @override
  String get tabName => 'Name';

  @override
  String get tabDescription => 'Description';

  @override
  String get tabModel => 'Model';

  @override
  String get tabCustomizeHint => 'Toggles take effect once saved';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsReload => 'Reload';

  @override
  String get settingsAdd => 'Add';

  @override
  String get settingsEmpty => 'Nothing here yet';

  @override
  String get settingsCenter => 'System settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsModels => 'Models & providers';

  @override
  String get settingsAdvanced =>
      'Advanced (backup / cron / keys / diagnostics)';

  @override
  String get settingsBackup => 'Backups';

  @override
  String get settingsCron => 'Scheduled jobs';

  @override
  String get settingsApiKeys => 'API keys';

  @override
  String get settingsDiag => 'Diagnostic reports';

  @override
  String get webLoading => 'Loading…';

  @override
  String get webLoadFailed => 'Page failed to load';

  @override
  String get webReloginHint =>
      'If the session expired, sign in again and retry';

  @override
  String get mermaidHint => 'Mermaid diagram — tap to view full screen';

  @override
  String get noteWhiteboard => 'Whiteboard';

  @override
  String get chatOfflineHint => 'Offline cache — refreshes when back online';

  @override
  String get updateCheck => 'Check for updates';

  @override
  String get updateNone => 'You are up to date';

  @override
  String get updateAvailable => 'Update available';

  @override
  String get updateDownload => 'Download update';

  @override
  String get confirm => 'OK';

  @override
  String get drawerGroupAgent => 'Agent';

  @override
  String get drawerChats => 'Chats';

  @override
  String get seeAllChats => 'See all chats';

  @override
  String get noProjects => 'No projects yet';

  @override
  String get newProject => 'New project';

  @override
  String get newChatInProject => 'New chat in project';

  @override
  String get editProject => 'Edit project';

  @override
  String get deleteProject => 'Delete project';

  @override
  String get deleteProjectTitle => 'Delete project';

  @override
  String deleteProjectConfirm(Object name) {
    return 'Delete project \"$name\"?';
  }

  @override
  String projectDeleteBlocked(Object count) {
    return 'This project still has $count chats — delete or move them first.';
  }

  @override
  String get projectNameLabel => 'Name';

  @override
  String get projectDescriptionLabel => 'Description (optional)';

  @override
  String get dashHeroHint => 'Send a message to start';

  @override
  String get dashCardsTitle => 'Today\'s cards';

  @override
  String dashCardsDue(Object n) {
    return '$n due';
  }

  @override
  String get dashCardsNone => 'No cards due today';

  @override
  String dashCardsStreak(Object n) {
    return '$n-day streak';
  }

  @override
  String get dashCardsBrowse => 'Browse cards →';

  @override
  String get dashTodoTitle => 'Todos';

  @override
  String get dashTodoNone => 'Nothing open';

  @override
  String get dashTodoView => 'View todos →';

  @override
  String get dashTodoOverdue => 'Overdue';

  @override
  String get dashRecentTitle => 'Recent chats';

  @override
  String get dashRecentNone => 'No chats yet';

  @override
  String get dashCronTitle => 'Scheduled jobs';

  @override
  String get dashCronNone => 'No jobs enabled';
}
