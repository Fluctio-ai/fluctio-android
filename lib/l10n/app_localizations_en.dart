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
  String get navTools => 'Tools';

  @override
  String get workflowNew => 'New workflow';

  @override
  String get workflowNewHint => 'Workflow id (letters, digits, - and _)';

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
  String get chatSearchHint => 'Search chats';

  @override
  String get chatNoMatch => 'No matching chats';

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
  String get chatPullForLatest => 'Pull up for the latest';

  @override
  String get chatFetchingLatest => 'Fetching the latest…';

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
  String get chatPickAttachmentError => 'Could not read the attachment';

  @override
  String get chatAttachLimit => 'Up to 8 attachments';

  @override
  String chatFileTooLarge(String name) {
    return 'File too large (50MB max): $name';
  }

  @override
  String get chatAttachTotalTooLarge =>
      'Attachments exceed the 100MB total cap';

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
  String get kbViewList => 'List';

  @override
  String get kbViewCalendar => 'Calendar';

  @override
  String get kbViewGantt => 'Gantt';

  @override
  String get kbViewMonth => 'Month';

  @override
  String get kbViewWeek => 'Week';

  @override
  String get kbViewDay => 'Day';

  @override
  String get kbScopeMonth => 'This month';

  @override
  String get kbScopeWeek => 'This week';

  @override
  String get kbScopeDay => 'Today';

  @override
  String get kbNoTodos => 'No todos';

  @override
  String kbGanttCount(int n) {
    return '$n items';
  }

  @override
  String get kbBookmarks => 'Bookmarks';

  @override
  String get kbCards => 'Cards';

  @override
  String get kbWiki => 'Wiki';

  @override
  String get diaryOverview => 'Overview';

  @override
  String get diaryThemes => 'What you talked about';

  @override
  String get diaryNoThemes => 'No themes to summarize';

  @override
  String get diaryBlindspots => 'Points you may have missed';

  @override
  String get diaryArchives => 'Archived today';

  @override
  String get diaryGenerate => 'Generate';

  @override
  String get diaryGenerating => 'Generating…';

  @override
  String get diaryNoDiary => 'No diary for this date yet';

  @override
  String get diaryNoDiaryMonth => 'No diary this month yet';

  @override
  String get diaryHeatHint => 'Darker means more content that day';

  @override
  String get diaryPrevMonth => 'Previous month';

  @override
  String get diaryNextMonth => 'Next month';

  @override
  String diaryListMeta(Object date, int themes, int blindspots) {
    return '$date · $themes themes · $blindspots blindspots';
  }

  @override
  String get diaryShelved => 'Shelved topics';

  @override
  String diaryShelvedSince(Object date, int n) {
    return 'Shelved $date · ${n}d ago';
  }

  @override
  String get diaryShelvedResolved => 'Picked up';

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
  String get chatAttach => 'Attach files';

  @override
  String get chatCopy => 'Copy';

  @override
  String get chatFork => 'Fork conversation from here';

  @override
  String get kbClear => 'Clear';

  @override
  String get wikiEntity => 'Entities';

  @override
  String get wikiConcept => 'Concepts';

  @override
  String get wikiSource => 'Sources';

  @override
  String get wikiSearchHint => 'Search pages…';

  @override
  String get wikiNoPages =>
      'No wiki pages yet. Generate them in knowledge settings.';

  @override
  String get wikiNoMatch => 'No matching pages';

  @override
  String wikiStats(Object pages, Object links) {
    return '$pages pages · $links links';
  }

  @override
  String get wikiDeleteTitle => 'Delete page';

  @override
  String wikiDeleteConfirm(Object name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String get wikiKnowledgeGraph => 'Knowledge graph';

  @override
  String get wikiFit => 'Reset view';

  @override
  String get wikiOpen => 'Open';

  @override
  String get wikiViewInGraph => 'View in graph';

  @override
  String get wikiEditPage => 'Edit page';

  @override
  String get wikiTitleLabel => 'Title';

  @override
  String get wikiLoadFailed => 'Failed to load';

  @override
  String get chatOnlyChip => 'Chat only';

  @override
  String get chatImReadOnlyHint =>
      'Read-only — this chat came in from an IM channel';

  @override
  String get chatImChannelBadge => 'IM channel session (read-only)';

  @override
  String get kbEmpty => 'Nothing here yet';

  @override
  String get kbSelectToView => 'Select an item on the left';

  @override
  String get kbTomorrow => 'Tomorrow';

  @override
  String get kbNoDate => 'No date';

  @override
  String get kbAddTodo => 'New todo';

  @override
  String get kbTodoHint => 'Todo content';

  @override
  String get todoStatusPending => 'Pending';

  @override
  String get todoStatusInProgress => 'In progress';

  @override
  String get todoStatusDone => 'Done';

  @override
  String get todoStatusCancelled => 'Cancelled';

  @override
  String get kbStatus => 'Status';

  @override
  String get kbNotSet => 'Not set';

  @override
  String get kbDueDate => 'Date';

  @override
  String get kbStartDate => 'Start';

  @override
  String get kbEndDate => 'End';

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
  String get chatWorkspace => 'Workspace';

  @override
  String get chatRefresh => 'Refresh';

  @override
  String get fileNoPreview => 'Preview not supported for this type';

  @override
  String get mediaPlayFailed => 'Playback failed';

  @override
  String get themeTitle => 'Appearance';

  @override
  String get fontSizeTitle => 'Font size';

  @override
  String get fontSmall => 'Small';

  @override
  String get fontMedium => 'Medium';

  @override
  String get fontLarge => 'Large';

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
  String get cardSource => 'Source';

  @override
  String get shareTargetTitle => 'Share to';

  @override
  String get shareToNote => 'Save as note';

  @override
  String get shareToNoteHint => 'Full text into a KB note';

  @override
  String get shareToChat => 'Send to chat';

  @override
  String get shareToChatHint => 'New or existing conversation';

  @override
  String get shareToArticle => 'Save as article';

  @override
  String get shareToArticleHint => 'Fetch & ingest the page';

  @override
  String get shareToBookmark => 'Save as bookmark';

  @override
  String get shareToBookmarkHint => 'Save the link to bookmarks';

  @override
  String get shareText => 'Text';

  @override
  String get shareLink => 'Link';

  @override
  String shareFiles(Object n) {
    return '$n files';
  }

  @override
  String get shareArticleDone =>
      'Saved as an article — see it in the knowledge base';

  @override
  String get shareNoteDone => 'Note saved';

  @override
  String get shareBookmarkDone => 'Bookmark added';

  @override
  String shareImages(Object n) {
    return '$n images';
  }

  @override
  String get shareFileOut => 'Share';

  @override
  String get sharePreparing => 'Preparing to share…';

  @override
  String get downloadFile => 'Download';

  @override
  String get downloadPreparing => 'Downloading…';

  @override
  String get downloadDone => 'Saved to Downloads';

  @override
  String get cardExcerpt => 'Original text';

  @override
  String get cardExplanation => 'Explanation';

  @override
  String cardFromDiary(Object date) {
    return 'From the $date diary';
  }

  @override
  String get cardViewWiki => 'View wiki page';

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
  String get cardStart => 'Start review';

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
  String get exitAgain => 'Press back again to exit';

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
  String get settingsProvider => 'Provider';

  @override
  String get settingsModelInherit => 'Follow system default';

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
  String get dashRecentAll => 'More chats →';

  @override
  String get dashRecentNone => 'No chats yet';

  @override
  String get dashCronTitle => 'Scheduled jobs';

  @override
  String get dashCronNone => 'No jobs enabled';

  @override
  String get dashShelvedNone => 'Nothing shelved';

  @override
  String dashShelvedDaysAgo(int n) {
    return '${n}d ago';
  }

  @override
  String get dashShelvedView => 'Open diary →';

  @override
  String editorIssues(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count issues',
      one: '1 issue',
    );
    return '⚠ $_temp0';
  }

  @override
  String editorIssueGo(Object line) {
    return 'Line $line';
  }

  @override
  String get editorLintUnclosedCodeFence => 'Unclosed code fence (```)';

  @override
  String get editorLintUnclosedMathFence => 'Unclosed math block (\$\$)';

  @override
  String get editorLintOddDollars => 'Unpaired inline math delimiter (\$)';

  @override
  String get editorLintTableColumns =>
      'Table separator column count differs from header';

  @override
  String get settingsMaxTokens => 'Max tokens';

  @override
  String get settingsTemperature => 'Temperature';

  @override
  String get settingsMaxToolIterations => 'Max tool iterations';

  @override
  String get settingsPromptMode => 'Prompt mode';

  @override
  String get settingsGuidance => 'Guidance';

  @override
  String get settingsCompactionMode => 'Compaction mode';

  @override
  String get settingsCompactionThreshold => 'Compaction threshold';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsSplitReplies => 'Split replies';

  @override
  String get settingsAutoPersist => 'Auto persist';

  @override
  String get settingsSharedIdentity => 'Shared identity';

  @override
  String get settingsName => 'Name';

  @override
  String get settingsLangZh => '中文';

  @override
  String get settingsLangEn => 'English';

  @override
  String articleCharsCount(Object count) {
    return '$count chars';
  }

  @override
  String articleCharsWan(Object count) {
    return '${count}k chars';
  }
}
