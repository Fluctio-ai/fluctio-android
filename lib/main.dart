import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth/auth_controller.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode.dart';
import 'todo/todo_reminders.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    // Root-lifetime wiring: todo reminder alarms live as long as the app.
    ref.watch(todoReminderServiceProvider);
    return MaterialApp.router(
      title: 'fluctio',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Manual theme setting (drawer toggle) — falls back to system.
      themeMode: ref.watch(themeModeProvider),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
