import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notify/notify_hub.dart';

/// Background turn alerts: while the app is not in the foreground (but
/// its process — and with it the SSE connections — is still alive), a
/// finished turn or an auth_prompt the agent is waiting on pops an
/// OS-level heads-up notification; tapping it lands on the session.
///
/// Scope honesty: no push channel exists (project decision), so a
/// killed process can never notify — this covers the common "app
/// backgrounded while a long turn runs" case only. An explicit user
/// stop never notifies (the controller only alerts on a live `done`
/// frame, never on the stop path).
final turnNotifyProvider = Provider<TurnNotify>((ref) => TurnNotify(ref));

class TurnNotify {
  TurnNotify(this._ref);

  static const _channelId = 'chat_turns';

  final Ref _ref;

  bool get _zh => _ref.read(localNotifyHubProvider).localeIsZh;

  /// Only a genuinely backgrounded app notifies — foreground users are
  /// watching the transcript. No binding (plain unit tests) = foreground.
  bool get _backgrounded {
    try {
      final st = WidgetsBinding.instance.lifecycleState;
      return st != null && st != AppLifecycleState.resumed;
    } catch (_) {
      return false;
    }
  }

  /// Turn finished while backgrounded: session title + the reply's
  /// first line (already truncated by the caller) as the body.
  void onTurnDone({required String title, required String snippet, required String route}) =>
      _alert(
        key: 'done',
        title: title,
        body: snippet.isNotEmpty ? snippet : (_zh ? '回复已完成' : 'Reply ready'),
        route: route,
      );

  /// The agent paused mid-turn waiting for the user's decision — the
  /// most time-sensitive case (the turn sits idle until answered).
  void onAuthPrompt({required String title, required String description, required String route}) =>
      _alert(
        key: 'auth',
        title: title,
        body: _zh ? '需要你的确认：$description' : 'Needs your input: $description',
        route: route,
      );

  void _alert({required String key, required String title, required String body, required String route}) {
    if (!_backgrounded) return;
    unawaited(_ref.read(localNotifyHubProvider).show(
          id: '$key-$route'.hashCode & 0x7fffffff,
          channelId: _channelId,
          channelName: _zh ? '对话进展' : 'Chat progress',
          channelDescription:
              _zh ? '后台时回复完成 / 等待你操作的提醒' : 'Turn done / action needed while backgrounded',
          title: title,
          body: body,
          payload: route,
        ));
  }
}
