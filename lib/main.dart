import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:workmanager/workmanager.dart';

import 'auth/auth_controller.dart';
import 'l10n/app_localizations.dart';
import 'notify/notification_poll_worker.dart';
import 'notify/notify_hub.dart';
import 'notify/notifications_service.dart';
import 'router.dart';
import 'share/share_receiver.dart';
import 'theme/app_theme.dart';
import 'theme/font_scale.dart';
import 'theme/theme_mode.dart';
import 'todo/todo_reminders.dart';
import 'ui/row_actions_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Background notification polling (contract §11): the periodic task's
  // dispatcher runs in a headless engine — it must be registered before
  // runApp, and nothing in it may touch this container.
  await Workmanager().initialize(notificationPollDispatcher);
  // Restore (prefs → Keystore → /api/me probe) completes before the first
  // frame, so the router redirect never flashes the wrong screen.
  final container = ProviderContainer();
  await container.read(authControllerProvider.notifier).restore();
  runApp(UncontrolledProviderScope(container: container, child: const FluctioApp()));
}

class FluctioApp extends ConsumerWidget {
  const FluctioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Root-lifetime wiring: the notification hub (single plugin owner —
    // todo reminders and background turn alerts share it), the todo
    // reminder alarms, and the server-notification channel (foreground
    // SSE + background WorkManager poll) live as long as the app.
    ref.watch(localNotifyHubProvider);
    ref.watch(todoReminderServiceProvider);
    ref.watch(serverNotificationsServiceProvider);
    // Inbound shares (other apps): the picker decides the destination —
    // chat session, article ingest, bookmark. The listen also forces the
    // lazy controller to build (cold-start consume).
    ref.listen(pendingShareProvider, (_, next) {
      if (next != null) ref.read(routerProvider).push('/share-target');
    });
    return Listener(
      // Feeds the long-press action menus their anchor point — rows'
      // plain onLongPress callbacks carry no position (row_actions_menu).
      onPointerDown: (e) => lastPointerDown = e.position,
      child: MaterialApp.router(
        title: 'fluctio',
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        // Manual theme setting (drawer toggle) — falls back to system.
        themeMode: ref.watch(themeModeProvider),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: ref.watch(routerProvider),
        // Global font scale (profile → appearance): one TextScaler above
        // the whole tree — deliberate override of the device setting so
        // the three in-app levels are self-contained.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(ref.watch(fontScaleProvider).factor)),
          child: child!,
        ),
      ),
    );
  }
}
