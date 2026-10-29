import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/auth_controller.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../update/update_service.dart';
import 'agents/agent_settings_page.dart';
import '../l10n/app_localizations.dart';
import '../notify/notify_service_controller.dart';
import '../theme/font_scale.dart';
import '../theme/theme_mode.dart';
import '../theme/tokens.dart';
import 'chat/chat_image.dart';
import '../ui/settings_list.dart';
import '../util/app_toast.dart';

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
        AppToast.show(l.updateNone);
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
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.navMe)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpace.xxl),
        children: [
          // Profile header.
          Container(
            padding: const EdgeInsets.all(AppSpace.xl),
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
          SectionHeader(l.themeTitle),
          SettingsGroup(
            children: [
              Consumer(builder: (context, ref, _) {
                final mode = ref.watch(themeModeProvider);
                return SettingsSegmentedTile<ThemeMode>(
                  icon: LucideIcons.palette,
                  label: l.themeTitle,
                  segments: [
                    ButtonSegment(value: ThemeMode.system, tooltip: l.themeSystem, icon: const Icon(LucideIcons.monitor, size: 16)),
                    ButtonSegment(value: ThemeMode.light, tooltip: l.themeLight, icon: const Icon(LucideIcons.sun, size: 16)),
                    ButtonSegment(value: ThemeMode.dark, tooltip: l.themeDark, icon: const Icon(LucideIcons.moon, size: 16)),
                  ],
                  selected: mode,
                  onSelectionChanged: (s) => ref.read(themeModeProvider.notifier).set(s.first),
                );
              }),
              // Same surface as the theme picker — a local appearance
              // preference, not a server blob.
              Consumer(builder: (context, ref, _) {
                final level = ref.watch(fontScaleProvider);
                return SettingsSegmentedTile<FontScaleLevel>(
                  icon: LucideIcons.type,
                  label: l.fontSizeTitle,
                  segments: [
                    ButtonSegment(value: FontScaleLevel.mini, label: Text(l.fontSmall)),
                    ButtonSegment(value: FontScaleLevel.medium, label: Text(l.fontMedium)),
                    ButtonSegment(value: FontScaleLevel.max, label: Text(l.fontLarge)),
                  ],
                  selected: level,
                  onSelectionChanged: (s) => ref.read(fontScaleProvider.notifier).set(s.first),
                );
              }),
            ],
          ),
          SectionHeader(l.meAgents),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: LucideIcons.bot,
                label: l.meAgentManage,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const AgentsAdminPage())),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
            ],
          ),
          SectionHeader(l.meGeneral),
          SettingsGroup(
            children: [
              // Opt-in always-on delivery. Off by default: polling is free
              // while idle, this costs a persistent notification but makes
              // delivery immediate (see NotifyForegroundService).
              SettingsTile(
                icon: LucideIcons.radio,
                label: l.notifyServiceMode,
                subtitle: l.notifyServiceModeDesc,
                trailing: Switch(
                  value: ref.watch(notifyServiceModeProvider),
                  onChanged: (v) async {
                    final ok = await ref.read(notifyServiceModeProvider.notifier).set(v);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.notifyServiceModeFailed)),
                      );
                    }
                  },
                ),
              ),
              SettingsTile(
                icon: LucideIcons.server,
                label: l.currentServer,
                value: auth.baseUrl,
              ),
              if (auth.allowSelfSigned)
                SettingsTile(
                  icon: LucideIcons.shieldCheck,
                  label: l.allowSelfSigned,
                  trailing: Icon(LucideIcons.check,
                      size: 16, color: theme.colorScheme.primary),
                ),
              SettingsTile(
                icon: LucideIcons.arrowLeftRight,
                label: l.switchServer,
                onTap: () => ref.read(authControllerProvider.notifier).clearServer(),
                trailing: const Icon(LucideIcons.chevronRight, size: 18),
              ),
              SettingsTile(
                icon: LucideIcons.logOut,
                label: l.signOut,
                onTap: () => _confirmSignOut(context, ref, l),
              ),
            ],
          ),
          SectionHeader(l.meAbout),
          SettingsGroup(
            children: [
              SettingsTile(
                icon: LucideIcons.info,
                label: l.meVersion,
                value: _version,
              ),
              SettingsTile(
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
    Widget fallback = CircleAvatar(
      radius: 30,
      backgroundColor: scheme.primaryContainer,
      child: Text(
        initial,
        style: theme.textTheme.titleMedium?.copyWith(color: scheme.onPrimaryContainer),
      ),
    );
    if (auth.sid == null || auth.sid!.isEmpty) return fallback;
    // GET /api/me/avatar — cookie-gated, same loading path as chat images.
    return ClipOval(
      child: Image(
        image: chatImageProvider('${auth.baseUrl}/api/me/avatar',
            baseUrl: auth.baseUrl, cookie: auth.sid),
        width: 60,
        height: 60,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
