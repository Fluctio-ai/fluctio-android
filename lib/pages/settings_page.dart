import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
          _header(context, l.sectionAccount),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(auth.userLabel ?? l.notSignedIn),
            subtitle: Text(l.signedInAs),
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l.signOut),
            onTap: () => _confirmSignOut(context, ref, l),
          ),
          _header(context, l.sectionServer),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(auth.baseUrl.isEmpty ? '—' : auth.baseUrl),
            subtitle: auth.allowSelfSigned ? Text(l.allowSelfSigned) : null,
          ),
          ListTile(
            leading: const Icon(Icons.swap_horiz),
            title: Text(l.switchServer),
            onTap: () => ref.read(authControllerProvider.notifier).clearServer(),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.confirmSignOut),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.signOut)),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }
}
