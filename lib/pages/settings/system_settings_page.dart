import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/load_states.dart';
import '../../settings/json_form.dart';
import '../../settings/settings_repo.dart';
import '../../theme/tokens.dart';
import '../../webview/web_container.dart';

/// System settings center (ticket 09): the web's 21 pages collapsed into
/// grouped screens — 通用 (user config blob), 模型服务 (providers),
/// 向量化/隐私 (system blobs), 高级 (folded read-only lists). Common
/// items (models / vectorization / memory / workflow toggles) are
/// editable and saved server-side.
class SystemSettingsPage extends ConsumerWidget {
  const SystemSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsCenter)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          _group(context, l.settingsGeneral, LucideIcons.settings2,
              (_) => SystemBlobScreen(
                  title: l.settingsGeneral,
                  path: '/api/config',
                  method: 'POST',
                  hiddenKeys: const {
                    'providers',
                    'channels',
                    'toolProviders',
                    'hooks',
                    'mcpServers'
                  })),
          _group(context, l.settingsModels, LucideIcons.cpu,
              (_) => const ProvidersScreen()),
          _group(context, l.tabVectorization, LucideIcons.database,
              (_) => SystemBlobScreen(
                  title: l.tabVectorization, path: '/api/vectorization', method: 'PUT')),
          _group(context, l.tabPrivacy, LucideIcons.shield,
              (_) => SystemBlobScreen(title: l.tabPrivacy, path: '/api/privacy', method: 'PUT')),
          // Folded advanced lists (read-only) — sandbox/deploy class.
          _advanced(context, l),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, String title, IconData icon, WidgetBuilder screen) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: surfaceCardDecoration(theme.colorScheme),
      child: ListTile(
        leading: Icon(icon, size: 20, color: theme.colorScheme.primary),
        title: Text(title),
        trailing: const Icon(LucideIcons.chevronRight, size: 18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: screen)),
      ),
    );
  }

  Widget _advanced(BuildContext context, AppLocalizations l) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(l.settingsAdvanced,
            style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline, fontWeight: FontWeight.w600)),
        children: [
          _advancedRow(context, l.settingsBackup, '/api/backup/list', LucideIcons.hardDrive),
          _advancedRow(context, l.settingsCron, '/api/cron', LucideIcons.clock),
          _advancedRow(context, l.settingsApiKeys, '/api/apikeys', LucideIcons.keyRound),
          // Diagnostics is a full web report page — open in the container.
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(LucideIcons.bug, size: 18, color: theme.colorScheme.outline),
            title: Text(l.settingsDiag, style: theme.textTheme.bodyMedium),
            trailing: const Icon(LucideIcons.chevronRight, size: 16),
            onTap: () =>
                openWebContainer(context, l.settingsDiag, WebRoutes.diagnostics()),
          ),
        ],
      ),
    );
  }

  Widget _advancedRow(BuildContext context, String title, String path, IconData icon) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 18, color: theme.colorScheme.outline),
      title: Text(title, style: theme.textTheme.bodyMedium),
      trailing: const Icon(LucideIcons.chevronRight, size: 16),
      onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => GenericListScreen(title: title, path: path))),
    );
  }
}

/// One GET→JsonForm→(POST|PUT) blob screen for a system settings group,
/// built on the shared [BlobEditor].
class SystemBlobScreen extends ConsumerWidget {
  const SystemBlobScreen({
    super.key,
    required this.title,
    required this.path,
    required this.method,
    this.hiddenKeys = const {},
  });

  final String title;
  final String path;
  final String method;
  final Set<String> hiddenKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(settingsRepoProvider);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: BlobEditor(
          load: () => repo.scopedGet(path),
          save: (blob) =>
              method == 'POST' ? repo.postBlob(path, blob) : repo.scopedPut(path, blob),
          hiddenKeys: hiddenKeys,
        ),
      ),
    );
  }
}

/// Providers (模型服务): scoped list with test / edit / add.
class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({super.key});

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  List<Map<String, dynamic>>? _providers;
  bool _failed = false;
  String? _testing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(settingsRepoProvider).providers();
      if (!mounted) return;
      setState(() => _providers = rows);
    } catch (e) {
      if (mounted) {
        setState(() => _failed = true);
        showApiError(context, e);
      }
    }
  }

  Future<void> _test(Map<String, dynamic> p) async {
    setState(() => _testing = '${p['id']}');
    try {
      await ref.read(apiClientProvider).post('/api/test-provider',
          data: {'id': p['id'], 'name': p['name']});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OK')));
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _testing = null);
    }
  }

  Future<void> _edit(Map<String, dynamic>? existing) async {
    final l = AppLocalizations.of(context)!;
    final name = TextEditingController(text: '${existing?['name'] ?? ''}');
    final apiBase = TextEditingController(text: '${existing?['apiBase'] ?? ''}');
    final apiKey = TextEditingController();
    final model = TextEditingController(text: '${existing?['model'] ?? ''}');
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? l.settingsAdd : l.chatRename),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(hintText: 'name')),
            const SizedBox(height: 8),
            TextField(controller: apiBase, decoration: const InputDecoration(hintText: 'apiBase')),
            const SizedBox(height: 8),
            TextField(controller: apiKey, decoration: const InputDecoration(hintText: 'apiKey')),
            const SizedBox(height: 8),
            TextField(controller: model, decoration: const InputDecoration(hintText: 'model')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatSend)),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    try {
      await ref.read(settingsRepoProvider).saveProvider(
            id: existing == null ? null : '${existing['id']}',
            body: {
              'name': name.text.trim(),
              if (apiBase.text.trim().isNotEmpty) 'apiBase': apiBase.text.trim(),
              if (apiKey.text.trim().isNotEmpty) 'apiKey': apiKey.text.trim(),
              if (model.text.trim().isNotEmpty) 'model': model.text.trim(),
            },
          );
      _load();
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsModels)),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(null),
        child: const Icon(LucideIcons.plus),
      ),
      body: _failed
          ? ErrorPane(message: l.chatHistoryError)
          : _providers == null
              ? const SkeletonListView()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _providers!.isEmpty
                      ? ListView(children: [
                          Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                                child: Text(l.settingsEmpty, style: theme.textTheme.bodyMedium)),
                          ),
                        ])
                      : ListView.builder(
                          itemCount: _providers!.length,
                          itemBuilder: (context, i) {
                            final p = _providers![i];
                            return ListTile(
                              leading: Icon(LucideIcons.cpu, size: 20, color: theme.colorScheme.primary),
                              title: Text('${p['name'] ?? ''}', maxLines: 1),
                              subtitle: Text('${p['model'] ?? p['apiBase'] ?? ''}', maxLines: 1),
                              trailing: _testing == '${p['id']}'
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(LucideIcons.plugZap, size: 18),
                                          onPressed: () => _test(p),
                                        ),
                                        IconButton(
                                          icon: Icon(LucideIcons.pencil,
                                              size: 18, color: theme.colorScheme.outline),
                                          onPressed: () => _edit(p),
                                        ),
                                      ],
                                    ),
                            );
                          },
                        ),
                ),
    );
  }
}

/// Read-only generic blob for the folded advanced groups (backup / cron /
/// api keys) — rendered as key/value rows.
class GenericListScreen extends ConsumerStatefulWidget {
  const GenericListScreen({super.key, required this.title, required this.path});

  final String title;
  final String path;

  @override
  ConsumerState<GenericListScreen> createState() => _GenericListScreenState();
}

class _GenericListScreenState extends ConsumerState<GenericListScreen> {
  Map<String, dynamic>? _blob;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepoProvider).scopedGet(widget.path).then((blob) {
      if (mounted) setState(() => _blob = blob);
    }).catchError((e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: _error != null
          ? ErrorPane(message: _error!)
          : _blob == null
              ? const SkeletonProse()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: surfaceCardDecoration(theme.colorScheme),
                    child: JsonView(value: _blob!),
                  ),
                ),
    );
  }
}
