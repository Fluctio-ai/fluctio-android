import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../update/update_service.dart';
import 'agents/agent_settings_page.dart';
import 'settings/system_settings_page.dart';
import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// Me tab per the prototype: profile header + grouped settings. Absorbs
/// the old settings page; agent management arrives with M3.
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  String _version = '';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  Future<void> _checkUpdate() async {
    final l = AppLocalizations.of(context)!;
    setState(() => _checkingUpdate = true);
    try {
      final update = await ref.read(updateServiceProvider).check();
      if (!mounted) return;
      if (update == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.updateNone)));
        return;
      }
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${l.updateAvailable} ${update.tag}'),
          content: Text(update.notes.isEmpty
              ? '${update.current} → ${update.tag.substring(1)}'
              : update.notes, maxLines: 6, overflow: TextOverflow.ellipsis),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
            if (update.apkUrl != null)
              FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.updateDownload)),
          ],
        ),
      );
      if (go == true && update.apkUrl != null) {
        await ref.read(updateServiceProvider).openDownload(update.apkUrl!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.errorNetwork)));
      }
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.navMe)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Profile header.
          Container(
            padding: const EdgeInsets.all(20),
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
            child: Row(
              children: [
                _UserAvatar(),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(auth.userLabel ?? l.appName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(l.signedInAs,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.outline)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _groupTitle(context, l.meAgents),
          _card(
            context,
            [
              _item(
                context,
                icon: LucideIcons.workflow,
                label: l.navWorkflow,
                onTap: () => context.push('/workflow'),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
              _item(
                context,
                icon: LucideIcons.bot,
                label: l.meAgentManage,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AgentsAdminPage())),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
            ],
          ),
          _groupTitle(context, l.meGeneral),
          _card(
            context,
            [
              _item(
                context,
                icon: LucideIcons.server,
                label: l.currentServer,
                value: auth.baseUrl,
              ),
              _item(
                context,
                icon: LucideIcons.slidersHorizontal,
                label: l.settingsCenter,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const SystemSettingsPage())),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
              if (auth.allowSelfSigned)
                _item(
                  context,
                  icon: LucideIcons.shieldCheck,
                  label: l.allowSelfSigned,
                  value: '✓',
                ),
              _item(
                context,
                icon: LucideIcons.arrowLeftRight,
                label: l.switchServer,
                onTap: () => ref.read(authControllerProvider.notifier).clearServer(),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
              _item(
                context,
                icon: LucideIcons.logOut,
                label: l.signOut,
                onTap: () => _confirmSignOut(context, ref, l),
              ),
            ],
          ),
          _groupTitle(context, l.meAbout),
          _card(
            context,
            [
              _item(
                context,
                icon: LucideIcons.info,
                label: l.meVersion,
                value: _version,
              ),
              _item(
                context,
                icon: LucideIcons.download,
                label: l.updateCheck,
                onTap: _checkUpdate,
                trailing: _checkingUpdate
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(LucideIcons.chevronRight, size: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _groupTitle(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _card(BuildContext context, List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 56, color: theme.colorScheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
            if (value != null)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
                ),
              ),
            if (trailing != null)
              Padding(padding: const EdgeInsets.only(left: 4), child: trailing),
          ],
        ),
      ),
    );
  }

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

class _UserAvatar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final auth = ref.watch(authControllerProvider);
    final label = auth.userLabel;
    final initial = (label == null || label.isEmpty) ? '?' : label.characters.first.toUpperCase();
    return CircleAvatar(
      radius: 30,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
  }
}
