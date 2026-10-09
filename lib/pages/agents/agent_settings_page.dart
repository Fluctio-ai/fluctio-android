import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../chat/chat_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../ui/adaptive_tab_bar.dart';
import '../../ui/dialogs.dart';
import '../../ui/load_states.dart';
import '../../settings/json_form.dart';
import '../../settings/settings_repo.dart';
import '../../theme/tokens.dart';

/// Agent management list (from 我的 → Agent 管理).
class AgentsAdminPage extends ConsumerWidget {
  const AgentsAdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final agents = ref.watch(agentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.meAgentManage)),
      body: agents.agents.isEmpty
          ? EmptyState(icon: LucideIcons.bot, message: l.chatNoAgent)
          : ListView.builder(
              itemCount: agents.agents.length,
              itemBuilder: (context, i) {
                final a = agents.agents[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(LucideIcons.bot, size: 20, color: theme.colorScheme.outline),
                  ),
                  title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(a.model.isEmpty ? a.description : a.model,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => AgentSettingsPage(agentId: a.id, agentName: a.name),
                      )),
                );
              },
            ),
    );
  }
}

class _TabDef {
  const _TabDef(this.id, this.labelKey);
  final String id;
  final String Function(AppLocalizations l) labelKey;
}

/// Agent settings, trimmed to what a phone should do: switch the agent's
/// model (server presets only) and manage MCP / skills / plugins / regex /
/// scheduled jobs. The rest of the web's 15-tab dialog (context, tools,
/// privacy, usage, channels…) is server-side configuration done in the
/// web UI.
class AgentSettingsPage extends ConsumerStatefulWidget {
  const AgentSettingsPage({super.key, required this.agentId, required this.agentName});

  final String agentId;
  final String agentName;

  @override
  ConsumerState<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends ConsumerState<AgentSettingsPage> {
  Map<String, dynamic>? _scope;
  Map<String, dynamic>? _config;
  String _tab = 'models';
  bool _saving = false;

  // Field-tab controllers owned by the page state (a fresh controller
  // per build would reset sibling fields and the cursor on every
  // keystroke / spinner toggle).
  late final _name = TextEditingController();
  late final _description = TextEditingController();

  static final _tabs = [
    _TabDef('models', (l) => l.tabModel),
    _TabDef('profile', (l) => l.tabProfile),
    _TabDef('mcp', (l) => l.tabMcp),
    _TabDef('skills', (l) => l.tabSkills),
    _TabDef('plugins', (l) => l.tabPlugins),
    _TabDef('regex', (l) => l.tabRegexHooks),
    _TabDef('scheduler', (l) => l.tabScheduler),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  SettingsRepo get _repo => ref.read(settingsRepoProvider);

  Future<void> _load() async {
    try {
      final (scope, config) =
          await (_repo.agent(widget.agentId), _repo.agentConfig(widget.agentId)).wait;
      if (!mounted) return;
      _syncControllers(scope, config);
      setState(() {
        _scope = scope;
        _config = config;
      });
    } catch (e) {
      if (mounted) showApiError(context, e);
    }
  }

  void _syncControllers(Map<String, dynamic> scope, Map<String, dynamic> config) {
    _name.text = '${scope['name'] ?? ''}';
    _description.text = '${scope['description'] ?? ''}';
  }

  Future<void> _savePatch(Map<String, dynamic> patch) async {
    setState(() => _saving = true);
    try {
      await _repo.updateAgent(widget.agentId, patch);
      await _load();
      if (mounted) {
        ref.read(agentsProvider.notifier).load();
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return DefaultTabController(
      length: _tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.agentName.isEmpty ? l.meAgentManage : widget.agentName),
          // The app's shared tab strip (was a ChoiceChip row) — 15
          // short labels overflow a phone, so the AdaptiveTabBar scrolls
          // horizontally instead of clipping.
          bottom: AdaptiveTabBar(
            onTap: (i) => setState(() => _tab = _tabs[i].id),
            tabs: [for (final t in _tabs) Tab(text: t.labelKey(l))],
          ),
        ),
        body: _scope == null || _config == null
            ? const SkeletonListView()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _tabBody(context),
              ),
      ),
    );
  }

  Widget _tabBody(BuildContext context) {
    final agentId = widget.agentId;
    return switch (_tab) {
      'profile' => _profileTab(),
      'models' => _ModelTab(current: '${_scope!['model'] ?? ''}', onSaved: _savePatch),
      'skills' => _SkillsTab(agentId: agentId),
      'mcp' => _McpTab(config: _config!, onSaved: _savePatch),
      'plugins' => _PluginsTab(scope: _scope!, onSaved: _savePatch),
      'scheduler' => _RepoListTab(
          fetch: () => _repo.cronJobs(agentId),
          tileBuilder: (context, row, reload) => _cronTile(
              context,
              row,
              () => _repo.toggleCron(agentId, '${row['id']}').then((_) => reload()),
              () => _repo.deleteCron(agentId, '${row['id']}').then((_) => reload()))),
      'regex' => _RepoListTab(
          fetch: () => _repo.regexHooks(agentId),
          tileBuilder: (context, row, reload) => _regexTile(
              context,
              row,
              () => _repo.deleteRegexHook(agentId, '${row['id']}').then((_) => reload()))),
      _ => const SizedBox.shrink(),
    };
  }

  // ---- field tabs ----

  Widget _profileTab() {
    final l = AppLocalizations.of(context)!;
    return _FieldCard(
      onSave: () => _savePatch({
        if (_name.text.trim().isNotEmpty) 'name': _name.text.trim(),
        'description': _description.text,
      }),
      saving: _saving,
      children: [
        labeledField(context, l.tabName, TextField(controller: _name)),
        labeledField(context, l.tabDescription, TextField(controller: _description, maxLines: 3)),
      ],
    );
  }

}

/// Model + provider switch — the phone's only agent-level LLM control.
/// The agent's `model` override is a `"<providerName>/<modelId>"` string
/// (handlers_agents.go:620; the backend resolves the prefix against the
/// provider rows, provider_models.go:64). Providers and their preset
/// model lists come from the server (GET /api/providers) — the phone only
/// switches; an empty provider clears the override (follow system
/// default).
class _ModelTab extends ConsumerStatefulWidget {
  const _ModelTab({required this.current, required this.onSaved});

  final String current;
  final Future<void> Function(Map<String, dynamic> patch) onSaved;

  @override
  ConsumerState<_ModelTab> createState() => _ModelTabState();
}

class _ModelTabState extends ConsumerState<_ModelTab> {
  /// Sentinel for "no provider override" — an empty selection clears the
  /// agent's model override server-side.
  static const _inherit = '';

  List<Map<String, dynamic>>? _providers;
  List<String> _builtin = const [];
  bool _failed = false;
  bool _saving = false;

  String _provider = _inherit;
  String? _model;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_ModelTab old) {
    super.didUpdateWidget(old);
    // Re-parse once the parent's reload-after-save lands a new value.
    if (old.current != widget.current && _providers != null) {
      setState(_parseCurrent);
    }
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(settingsRepoProvider);
      final (providers, builtin) = await (repo.providers(), repo.builtinModels()).wait;
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _builtin = builtin;
        _parseCurrent();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _failed = true);
        showApiError(context, e);
      }
    }
  }

  /// Split the stored `<provider>/<model>` back into the two selections.
  void _parseCurrent() {
    final cur = widget.current.trim();
    final i = cur.indexOf('/');
    if (i <= 0) {
      _provider = _inherit;
      _model = null;
      return;
    }
    _provider = cur.substring(0, i);
    _model = cur.substring(i + 1);
  }

  List<String> get _providerNames => [
        for (final p in _providers ?? const <Map<String, dynamic>>[])
          if ('${p['name'] ?? ''}'.isNotEmpty) '${p['name']}'
      ];

  /// Preset model ids for [provider]; builtin table keys are the fallback
  /// when the provider row carries no models[].
  List<String> _modelsFor(String provider) {
    for (final p in _providers ?? const <Map<String, dynamic>>[]) {
      if ('${p['name'] ?? ''}' != provider) continue;
      final ids = [
        for (final m in (p['models'] as List?) ?? const [])
          if (m is Map && '${m['id'] ?? ''}'.isNotEmpty) '${m['id']}'
      ];
      return ids.isEmpty ? _builtin : ids;
    }
    return _builtin;
  }

  void _onProviderChanged(String? value) {
    final p = value ?? _inherit;
    setState(() {
      _provider = p;
      if (p == _inherit) {
        _model = null;
        return;
      }
      final opts = _modelsFor(p);
      if (_model == null || !opts.contains(_model)) {
        _model = opts.isEmpty ? null : opts.first;
      }
    });
  }

  Future<void> _save() async {
    final model = _provider == _inherit || (_model ?? '').isEmpty ? '' : '$_provider/$_model';
    setState(() => _saving = true);
    try {
      await widget.onSaved({'model': model});
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    if (_failed) return ErrorPane(message: l.errorNetwork);
    if (_providers == null) return const SkeletonList(itemCount: 2, leading: false);

    // A dropdown value absent from its items trips the assertion — carry
    // the current provider/model through as extra options.
    final providerOptions = [_inherit, ..._providerNames];
    if (_provider != _inherit && !providerOptions.contains(_provider)) {
      providerOptions.add(_provider);
    }
    final modelOptions = _provider == _inherit ? <String>[] : [..._modelsFor(_provider)];
    if (_provider != _inherit && (_model ?? '').isNotEmpty && !modelOptions.contains(_model)) {
      modelOptions.add(_model!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        labeledField(
          context,
          l.settingsProvider,
          DropdownButtonFormField<String>(
            // Recreated when the selection is set programmatically
            // (parse / clear) — initialValue only seeds the form state.
            key: ValueKey('provider-$_provider'),
            initialValue: _provider,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              for (final p in providerOptions)
                DropdownMenuItem(
                  value: p,
                  child: Text(p == _inherit ? l.settingsModelInherit : p,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: _onProviderChanged,
          ),
        ),
        labeledField(
          context,
          l.tabModel,
          DropdownButtonFormField<String>(
            key: ValueKey('model-$_provider-$_model'),
            initialValue: modelOptions.contains(_model) ? _model : null,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            hint: Text(_provider == _inherit ? l.settingsModelInherit : l.settingsEmpty),
            items: [
              for (final m in modelOptions)
                DropdownMenuItem(
                    value: m, child: Text(m, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _provider == _inherit ? null : (m) => setState(() => _model = m),
          ),
        ),
        const SizedBox(height: 8),
        BlobSaveBar(dirty: true, saving: _saving, onSave: _save),
      ],
    );
  }
}

/// Card wrapper for the field tabs with a save button.
class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.onSave, required this.saving, required this.children});

  final VoidCallback onSave;
  final bool saving;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...children,
        const SizedBox(height: 8),
        BlobSaveBar(dirty: true, saving: saving, onSave: onSave),
      ],
    );
  }
}

/// Skills list with the reload action (its header is what keeps it off
/// the generic [_RepoListTab]).
class _SkillsTab extends ConsumerStatefulWidget {
  const _SkillsTab({required this.agentId});

  final String agentId;

  @override
  ConsumerState<_SkillsTab> createState() => _SkillsTabState();
}

class _SkillsTabState extends ConsumerState<_SkillsTab> {
  List<Map<String, dynamic>>? _skills;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final skills =
          await ref.read(settingsRepoProvider).skills(widget.agentId);
      if (mounted) setState(() => _skills = skills);
    } catch (_) {
      if (mounted) setState(() => _skills = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final skills = _skills;
    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await ref.read(settingsRepoProvider).reloadSkills(widget.agentId);
                        await _load();
                      } catch (_) {}
                      if (mounted) setState(() => _busy = false);
                    },
              icon: const Icon(LucideIcons.refreshCw, size: 14),
              label: Text(l.settingsReload, style: const TextStyle(fontSize: AppType.secondary)),
            ),
          ],
        ),
        if (skills == null)
          const SkeletonList(itemCount: 3, leading: false)
        else if (skills.isEmpty)
          Text(l.settingsEmpty, style: theme.textTheme.bodySmall)
        else
          for (final s in skills)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(LucideIcons.sparkles, size: 18, color: theme.colorScheme.primary),
              title: Text('${s['name'] ?? s['id'] ?? ''}'),
              subtitle: s['description'] is String ? Text('${s['description']}', maxLines: 1) : null,
              trailing: IconButton(
                icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.outline),
                // Same destructive guard as every other list surface.
                onPressed: () async {
                  if (!await confirmDelete(context)) return;
                  ref
                      .read(settingsRepoProvider)
                      .deleteSkill(widget.agentId, '${s['name'] ?? s['id'] ?? ''}')
                      .then((_) => _load());
                },
              ),
            ),
      ],
    );
  }
}

/// One generic "repo list tab" (load → spinner/empty/tiles), the shared
/// state machine for scheduler / regex hooks / channels.
class _RepoListTab extends StatefulWidget {
  const _RepoListTab({required this.fetch, required this.tileBuilder});

  final Future<List<Map<String, dynamic>>> Function() fetch;
  final Widget Function(BuildContext context, Map<String, dynamic> row, void Function() reload)
      tileBuilder;

  @override
  State<_RepoListTab> createState() => _RepoListTabState();
}

class _RepoListTabState extends State<_RepoListTab> {
  List<Map<String, dynamic>>? _rows;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final rows = await widget.fetch();
      if (mounted) setState(() => _rows = rows);
    } catch (_) {
      if (mounted) setState(() => _rows = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final rows = _rows;
    if (rows == null) return const SkeletonList(itemCount: 4);
    if (rows.isEmpty) return EmptyState(icon: LucideIcons.inbox, message: l.settingsEmpty);
    return Column(
      children: [for (final row in rows) widget.tileBuilder(context, row, _reload)],
    );
  }
}

Widget _cronTile(
    BuildContext context, Map<String, dynamic> row, VoidCallback onToggle, VoidCallback onDelete) {
  final theme = Theme.of(context);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(LucideIcons.clock, size: 18, color: theme.colorScheme.primary),
    title: Text('${row['name'] ?? row['id'] ?? ''}', maxLines: 1),
    subtitle: Text('${row['schedule'] ?? row['cron'] ?? ''}', maxLines: 1),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(value: row['enabled'] == true, onChanged: (_) => onToggle()),
        IconButton(
          icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.outline),
          onPressed: onDelete,
        ),
      ],
    ),
  );
}

Widget _regexTile(BuildContext context, Map<String, dynamic> row, VoidCallback onDelete) {
  final theme = Theme.of(context);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(LucideIcons.regex, size: 18, color: theme.colorScheme.primary),
    title: Text('${row['name'] ?? row['pattern'] ?? row['id'] ?? ''}', maxLines: 1),
    subtitle: row['pattern'] is String && row['name'] != null
        ? Text('${row['pattern']}', maxLines: 1)
        : null,
            trailing: IconButton(
              icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.outline),
              // Same destructive guard as every other list surface.
              onPressed: () async {
                if (!await confirmDelete(context)) return;
                onDelete();
              },
            ),
  );
}

class _McpTab extends StatefulWidget {
  const _McpTab({required this.config, required this.onSaved});

  final Map<String, dynamic> config;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  @override
  State<_McpTab> createState() => _McpTabState();
}

class _McpTabState extends State<_McpTab> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final servers = Map<String, dynamic>.from((widget.config['mcpServers'] as Map?) ?? {});
    return Column(
      children: [
        for (final name in servers.keys)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(LucideIcons.server, size: 18, color: theme.colorScheme.primary),
            title: Text(name),
            subtitle: (servers[name] is Map && (servers[name] as Map)['url'] is String)
                ? Text('${(servers[name] as Map)['url']}', maxLines: 1)
                : null,
            trailing: IconButton(
              icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.outline),
              // Same destructive guard as every other list surface.
              onPressed: () async {
                if (!await confirmDelete(context)) return;
                widget.onSaved({'mcpServers': {...servers}..remove(name)});
              },
            ),
          ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
          ),
          onPressed: () => _add(context, servers),
          icon: const Icon(LucideIcons.plus, size: 16),
          label: Text(l.settingsAdd),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, Map<String, dynamic> servers) async {
    final l = AppLocalizations.of(context)!;
    final name = TextEditingController();
    final url = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.settingsAdd),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: InputDecoration(hintText: l.settingsName)),
            const SizedBox(height: 8),
            TextField(controller: url, decoration: const InputDecoration(hintText: 'https://…')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.chatSend)),
        ],
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    await widget.onSaved({
      'mcpServers': {
        ...servers,
        name.text.trim(): {'url': url.text.trim(), 'transport': 'http'},
      },
    });
  }
}

class _PluginsTab extends ConsumerStatefulWidget {
  const _PluginsTab({required this.scope, required this.onSaved});

  final Map<String, dynamic> scope;
  final Future<void> Function(Map<String, dynamic>) onSaved;

  @override
  ConsumerState<_PluginsTab> createState() => _PluginsTabState();
}

class _PluginsTabState extends ConsumerState<_PluginsTab> {
  List<Map<String, dynamic>>? _registry;
  Map<String, dynamic> _overlay = {};

  @override
  void initState() {
    super.initState();
    final plugins = widget.scope['plugins'];
    if (plugins is Map) _overlay = Map<String, dynamic>.from(plugins);
    ref.read(settingsRepoProvider).pluginRegistry().catchError((_) {
      return const <Map<String, dynamic>>[];
    }).then((rows) {
      if (mounted) setState(() => _registry = rows);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final registry = _registry;
    if (registry == null) return const SkeletonList(itemCount: 4);
    if (registry.isEmpty && _overlay.isEmpty) {
      return EmptyState(icon: LucideIcons.puzzle, message: l.settingsEmpty);
    }
    final names = <String>{
      ..._overlay.keys,
      for (final r in registry) '${r['id'] ?? r['name'] ?? ''}',
    };
    return Column(
      children: [
        for (final name in names)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(name),
            value: _overlay[name] == true,
            onChanged: (v) => setState(() => _overlay[name] = v),
          ),
        BlobSaveBar(
          dirty: true,
          saving: false,
          onSave: () => widget.onSaved({'plugins': _overlay}),
        ),
      ],
    );
  }
}
