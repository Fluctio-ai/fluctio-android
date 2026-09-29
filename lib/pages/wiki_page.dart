import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class WikiPage extends StatelessWidget {
  const WikiPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.navWiki)),
      body: Center(child: Text(l.comingSoon)),
    );
  }
}
