import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.navChat)),
      body: Center(child: Text(l.comingSoon)),
    );
  }
}
