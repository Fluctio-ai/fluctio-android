import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: Center(child: Text(l.comingSoon)),
    );
  }
}
