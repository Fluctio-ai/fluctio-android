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
  String get chatOnlyNeedsMessage =>
      'Send a message first to create the session';

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
}
