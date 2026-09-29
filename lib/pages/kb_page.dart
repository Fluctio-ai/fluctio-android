import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class KbPage extends StatelessWidget {
  const KbPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.navKnowledge)),
      body: Center(child: Text(l.comingSoon)),
    );
  }
}
