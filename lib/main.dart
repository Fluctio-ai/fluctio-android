import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: FluctioApp()));
}

class FluctioApp extends StatelessWidget {
  const FluctioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'fluctio',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Follow the system theme; a manual toggle arrives with the
      // settings ticket.
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
    );
  }
}
