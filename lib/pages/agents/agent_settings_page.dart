import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/agents_admin_repo.dart';
import '../../settings/json_form.dart';
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
          ? Center(child: Text(l.chatNoAgent, style: theme.textTheme.bodyMedium))
          : ListView.builder(
              itemCount: agents.agents.length,
              itemBuilder: (context, i) {
                final a = agents.agents[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    child: Icon(LucideIcons.bot,
                        size: 20, color: theme.colorScheme.outline),
                  ),
                  title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(a.model.isEmpty ? a.description : a.model, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
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

/// Full-screen agent settings with a horizontally scrolling tab strip —
/// the mobile shape of the web's 15-tab dialog (ticket 08).
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
  final List<String> _models = const [];
  String _tab = 'profile';
  String? _error;
  bool _saving = false;

  static final _tabs = [
    _TabDef('profile', (l) => l.tabProfile),
    _TabDef('models', (l) => l.tabModels),
    _TabDef('context', (l) => l.tabContext),
    _TabDef('customize', (l) => l.tabCustomize),
    _TabDef('knowledge', (l) => l.tabKnowledge),
    _TabDef('skills', (l) => l.tabSkills),
    _TabDef('mcp', (l) => l.tabMcp),
    _TabDef('plugins', (l) => l.tabPlugins),
    _TabDef('scheduler', (l) => l.tabScheduler),
    _TabDef('regex', (l) => l.tabRegexHooks),
    _TabDef('recall', (l) => l.tabRecall),
    _TabDef('vectorization', (l) => l.tabVectorization),
    _TabDef('privacy', (l) => l.tabPrivacy),
    _TabDef('usage', (l) => l.tabUsage),
    _TabDef('channels', (l) => l.tabChannels),
  ];

  AgentsAdminRepo get _repo => ref.read(agentsAdminRepoProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final scope = await _repo.agent(widget.agentId);
      final config = await _repo.agentConfig(widget.agentId);
      if (!mounted) return;
      setState(() {
        _scope = scope;
        _config = config;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.agentName.isEmpty ? l.meAgentManage : widget.agentName)),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)))
          : Column(
              children: [
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    children: [
                      for (final t in _tabs)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(t.labelKey(l), style: const TextStyle(fontSize: 12)),
                            visualDensity: VisualDensity.compact,
                            selected: _tab == t.id,
                            onSelected: (_) => setState(() => _tab = t.id),
                          ),
                        ),
                    ],
                  ),
                ),
                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                Expanded(
                  child: _scope == null || _config == null
                      ? const Center(child: CircularProgressIndicator())
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: _tabBody(context),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _tabBody(BuildContext context) {
    return switch (_tab) {
      'profile' => _profileTab(),
      'models' => _modelsTab(),
      'context' => _contextTab(),
      'customize' => _customizeTab(),
      'knowledge' => _knowledgeTab(),
      'recall' => _BlobTab(
          repo: _repo,
          agentId: widget.agentId,
          path: '/api/agents/${widget.agentId}/recall-tuning'),
      'vectorization' => _BlobTab(
          repo: _repo,
          agentId: widget.agentId,
          path: '/api/agents/${widget.agentId}/vectorization'),
      'privacy' => _BlobTab(
          repo: _repo,
          agentId: widget.agentId,
          path: '/api/agents/${widget.agentId}/privacy'),
      'usage' => _UsageTab(repo: _repo, agentId: widget.agentId),
      'skills' => _SkillsTab(repo: _repo, agentId: widget.agentId),
      'mcp' => _McpTab(config: _config!, onSaved: _savePatch),
      'plugins' => _PluginsTab(
          repo: _repo, agentId: widget.agentId, scope: _scope!, onSaved: _savePatch),
      'scheduler' => _CronTab(repo: _repo, agentId: widget.agentId),
      'regex' => _RegexTab(repo: _repo, agentId: widget.agentId),
      'channels' => _ChannelsTab(repo: _repo, agentId: widget.agentId),
      _ => const SizedBox.shrink(),
    };
  }

  // ---- field tabs ----

  Widget _profileTab() {
    final l = AppLocalizations.of(context)!;
    final name = TextEditingController(text: '${_scope!['name'] ?? ''}');
    final desc = TextEditingController(text: '${_scope!['description'] ?? ''}');
    return _FieldCard(
      onSave: () => _savePatch({
        if (name.text.trim().isNotEmpty) 'name': name.text.trim(),
        'description': desc.text,
      }),
      saving: _saving,
      children: [
        _labeled(l.tabName, TextField(controller: name)),
        _labeled(l.tabDescription, TextField(controller: desc, maxLines: 3)),
      ],
    );
  }

  Widget _modelsTab() {
    final l = AppLocalizations.of(context)!;
    final current = '${_scope!['model'] ?? ''}';
    final maxTokens = TextEditingController(text: '${_scope!['maxTokens'] ?? ''}');
    final temperature = TextEditingController(text: '${_scope!['temperature'] ?? ''}');
    final iterations = TextEditingController(text: '${_scope!['maxToolIterations'] ?? ''}');
    return _FieldCard(
      onSave: () => _savePatch({
        'model': current,
        'maxTokens': int.tryParse(maxTokens.text) ?? 0,
        'temperature': double.tryParse(temperature.text) ?? 0,
        'maxToolIterations': int.tryParse(iterations.text) ?? 0,
      }),
      saving: _saving,
      children: [
        _labeled(l.tabModel, _ModelField(
          current: current,
          models: _models,
          onChanged: (m) => setState(() => _scope!['model'] = m),
        )),
        _labeled('maxTokens', TextField(controller: maxTokens, keyboardType: TextInputType.number)),
        _labeled('temperature', TextField(controller: temperature, keyboardType: const TextInputType.numberWithOptions(decimal: true))),
        _labeled('maxToolIterations', TextField(controller: iterations, keyboardType: TextInputType.number)),
      ],
    );
  }

  Widget _contextTab() {
    final cfg = _config!;
    final promptMode = '${_scope!['promptMode'] ?? cfg['promptMode'] ?? ''}';
    final guidance = '${_scope!['guidance'] ?? ''}';
    final compaction = '${cfg['compactionMode'] ?? ''}';
    final threshold = TextEditingController(text: '${cfg['compactionThreshold'] ?? ''}');
    final language = '${cfg['language'] ?? ''}';
    return _FieldCard(
      onSave: () => _savePatch({
        'promptMode': promptMode,
        'guidance': guidance,
        'compactionMode': compaction,
        'compactionThreshold': int.tryParse(threshold.text) ?? 0,
        'language': language,
      }),
      saving: _saving,
      children: [
        _labeled('promptMode', _dropdown(['agent', 'chatbot', 'customize'], promptMode, (v) => setState(() => _scope!['promptMode'] = v))),
        _labeled('guidance', _dropdown(['autonomous', 'guided'], guidance, (v) => setState(() => _scope!['guidance'] = v))),
        _labeled('compactionMode', _dropdown(['conservative', 'balanced', 'aggressive'], compaction, (v) => setState(() => _config!['compactionMode'] = v))),
        _labeled('compactionThreshold', TextField(controller: threshold, keyboardType: TextInputType.number)),
        _labeled('language', _dropdown(['zh-CN', 'en'], language, (v) => setState(() => _config!['language'] = v))),
      ],
    );
  }

  Widget _customizeTab() {
    final l = AppLocalizations.of(context)!;
    final scope = _scope!;
    final scopeCfg = _config!;
    bool b(String key, Map src) => src[key] == true || src[key] == 'true';
    return _FieldCard(
      onSave: () => _savePatch({
        'splitReplies': b('splitReplies', scope),
        'autoPersist': b('autoPersist', scope),
        'sharedIdentity': b('sharedIdentity', scope),
      }),
      saving: _saving,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('splitReplies'),
          value: b('splitReplies', scope),
          onChanged: (v) => setState(() => scope['splitReplies'] = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('autoPersist'),
          value: b('autoPersist', scope),
          onChanged: (v) => setState(() => scope['autoPersist'] = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('sharedIdentity'),
          value: b('sharedIdentity', scope),
          onChanged: (v) => setState(() => scope['sharedIdentity'] = v),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.tabCustomizeHint, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
        ),
        // keep scopeCfg referenced so analyzer sees intent when fields shift
        if (scopeCfg.isEmpty) const SizedBox.shrink(),
      ],
    );
  }

  Widget _knowledgeTab() {
    final cfg = _config!;
    final kb = Map<String, dynamic>.from((cfg['kb'] as Map?) ?? {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JsonForm(
          value: kb,
          onChanged: (next) => setState(() => cfg['kb'] = next),
        ),
        const SizedBox(height: 8),
        BlobSaveBar(
          dirty: true,
          saving: _saving,
          onSave: () => _savePatch({'kb': cfg['kb']}),
        ),
      ],
    );
  }

  Widget _dropdown(List<String> options, String current, ValueChanged<String> onChanged) {
    final valid = options.contains(current) || current.isEmpty;
    return DropdownButtonFormField<String>(
      initialValue: valid ? current : options.first,
      decoration: const InputDecoration(isDense: true),
      items: [
        for (final o in options) DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }

  Widget _labeled(String label, Widget field) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 4),
          field,
        ],
      ),
    );
  }
}

/// Text field + builtin-model suggestions for the model tab.
class _ModelField extends ConsumerStatefulWidget {
  const _ModelField({required this.current, required this.models, required this.onChanged});

  final String current;
  final List<String> models;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<_ModelField> createState() => _ModelFieldState();
}

class _ModelFieldState extends ConsumerState<_ModelField> {
  late final TextEditingController _controller = TextEditingController(text: widget.current);

  @override
  void initState() {
    super.initState();
    if (widget.models.isEmpty) {
      ref.read(agentsAdminRepoProvider).builtinModels().then((models) {
        if (mounted) setState(() => _models = models);
      }).catchError((_) {});
    }
  }

  List<String> _models = const [];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(controller: _controller, onChanged: widget.onChanged),
        if (_models.isNotEmpty)
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in _models)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text(m, style: const TextStyle(fontSize: 11)),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        _controller.text = m;
                        widget.onChanged(m);
                      },
                    ),
                  ),
              ],
            ),
          ),
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

/// GET blob → JsonForm → PUT blob tabs (recall-tuning / vectorization /
/// privacy).
class _BlobTab extends ConsumerStatefulWidget {
  const _BlobTab({required this.repo, required this.agentId, required this.path});

  final AgentsAdminRepo repo;
  final String agentId;
  final String path;

  @override
  ConsumerState<_BlobTab> createState() => _BlobTabState();
}

class _BlobTabState extends ConsumerState<_BlobTab> {
  Map<String, dynamic>? _blob;
  bool _dirty = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.repo.scopedGet(widget.path).then((blob) {
      if (mounted) setState(() => _blob = blob);
    }).catchError((e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_error != null) {
      return Center(child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)));
    }
    final blob = _blob;
    if (blob == null) return const Center(child: CircularProgressIndicator());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JsonForm(value: blob, onChanged: (next) => setState(() {_blob = next; _dirty = true;})),
        BlobSaveBar(
          dirty: _dirty,
          saving: _saving,
          onSave: () async {
            setState(() => _saving = true);
            try {
              await widget.repo.scopedPut(widget.path, _blob!);
              if (mounted) setState(() => _dirty = false);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
              }
            } finally {
              if (mounted) setState(() => _saving = false);
            }
          },
        ),
      ],
    );
  }
}

class _UsageTab extends ConsumerStatefulWidget {
  const _UsageTab({required this.repo, required this.agentId});

  final AgentsAdminRepo repo;
  final String agentId;

  @override
  ConsumerState<_UsageTab> createState() => _UsageTabState();
}

class _UsageTabState extends ConsumerState<_UsageTab> {
  Map<String, dynamic>? _data;


  @override
  void initState() {
    super.initState();
    widget.repo.scopedGet('/api/agents/${widget.agentId}/usage').then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    if (data == null) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: JsonView(value: data),
    );
  }
}

class _SkillsTab extends ConsumerStatefulWidget {
  const _SkillsTab({required this.repo, required this.agentId});

  final AgentsAdminRepo repo;
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
      final skills = await widget.repo.skills(widget.agentId);
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
    if (skills == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return Column(
      children: [
        Row(
          children: [
            TextButton.icon(
              onPressed: _busy ? null : () async {
                setState(() => _busy = true);
                try { await widget.repo.reloadSkills(widget.agentId); await _load(); } catch (_) {}
                if (mounted) setState(() => _busy = false);
              },
              icon: Icon(LucideIcons.refreshCw, size: 14),
              label: Text(l.settingsReload, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
        if (skills.isEmpty)
          Text(l.settingsEmpty, style: theme.textTheme.bodySmall)
        else
          for (final s in skills)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(LucideIcons.sparkles, size: 18, color: theme.colorScheme.primary),
              title: Text('${s['name'] ?? s['id'] ?? ''}'),
              subtitle: s['description'] is String ? Text(s['description'], maxLines: 1) : null,
              trailing: IconButton(
                icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.outline),
                onPressed: () async {
                  await widget.repo.deleteSkill(widget.agentId, '${s['name'] ?? s['id'] ?? ''}');
                  _load();
                },
              ),
            ),
      ],
    );
  }
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
              onPressed: () async {
                final next = {...servers}..remove(name);
                await widget.onSaved({'mcpServers': next});
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
            TextField(controller: name, decoration: InputDecoration(hintText: 'name')),
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
  const _PluginsTab({required this.repo, required this.agentId, required this.scope, required this.onSaved});

  final AgentsAdminRepo repo;
  final String agentId;
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
    widget.repo.pluginRegistry().then((r) {
      if (mounted) setState(() => _registry = r);
    }).catchError((_) {
      if (mounted) setState(() => _registry = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final registry = _registry;
    if (registry == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (registry.isEmpty && _overlay.isEmpty) {
      return Center(child: Text(l.settingsEmpty, style: theme.textTheme.bodySmall));
    }
    final names = <String>{..._overlay.keys, for (final r in registry) '${r['id'] ?? r['name'] ?? ''}'};
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

class _CronTab extends ConsumerStatefulWidget {
  const _CronTab({required this.repo, required this.agentId});

  final AgentsAdminRepo repo;
  final String agentId;

  @override
  ConsumerState<_CronTab> createState() => _CronTabState();
}

class _CronTabState extends ConsumerState<_CronTab> {
  List<Map<String, dynamic>>? _jobs;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final jobs = await widget.repo.cronJobs(widget.agentId);
      if (mounted) setState(() => _jobs = jobs);
    } catch (_) {
      if (mounted) setState(() => _jobs = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final jobs = _jobs;
    if (jobs == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (jobs.isEmpty) return Center(child: Text(l.settingsEmpty, style: theme.textTheme.bodySmall));
    return Column(
      children: [
        for (final j in jobs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(LucideIcons.clock, size: 18, color: theme.colorScheme.primary),
            title: Text('${j['name'] ?? j['id'] ?? ''}', maxLines: 1),
            subtitle: Text('${j['schedule'] ?? j['cron'] ?? ''}', maxLines: 1),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: j['enabled'] == true,
                  onChanged: (_) async {
                    await widget.repo.toggleCron(widget.agentId, '${j['id']}');
                    _load();
                  },
                ),
                IconButton(
                  icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.outline),
                  onPressed: () async {
                    await widget.repo.deleteCron(widget.agentId, '${j['id']}');
                    _load();
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RegexTab extends ConsumerStatefulWidget {
  const _RegexTab({required this.repo, required this.agentId});

  final AgentsAdminRepo repo;
  final String agentId;

  @override
  ConsumerState<_RegexTab> createState() => _RegexTabState();
}

class _RegexTabState extends ConsumerState<_RegexTab> {
  List<Map<String, dynamic>>? _hooks;

  @override
  void initState() {
    super.initState();
    widget.repo.regexHooks(widget.agentId).then((h) {
      if (mounted) setState(() => _hooks = h);
    }).catchError((_) {
      if (mounted) setState(() => _hooks = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hooks = _hooks;
    if (hooks == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (hooks.isEmpty) return Center(child: Text(l.settingsEmpty, style: theme.textTheme.bodySmall));
    return Column(
      children: [
        for (final h in hooks)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(LucideIcons.regex, size: 18, color: theme.colorScheme.primary),
            title: Text('${h['name'] ?? h['pattern'] ?? h['id'] ?? ''}', maxLines: 1),
            subtitle: h['pattern'] is String && h['name'] != null ? Text('${h['pattern']}', maxLines: 1) : null,
            trailing: IconButton(
              icon: Icon(LucideIcons.trash2, size: 16, color: theme.colorScheme.outline),
              onPressed: () async {
                await widget.repo.deleteRegexHook(widget.agentId, '${h['id']}');
                setState(() => _hooks!.remove(h));
              },
            ),
          ),
      ],
    );
  }
}

class _ChannelsTab extends ConsumerStatefulWidget {
  const _ChannelsTab({required this.repo, required this.agentId});

  final AgentsAdminRepo repo;
  final String agentId;

  @override
  ConsumerState<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends ConsumerState<_ChannelsTab> {
  List<Map<String, dynamic>>? _channels;

  @override
  void initState() {
    super.initState();
    widget.repo.channels(widget.agentId).then((c) {
      if (mounted) setState(() => _channels = c);
    }).catchError((_) {
      if (mounted) setState(() => _channels = []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final channels = _channels;
    if (channels == null) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    if (channels.isEmpty) return Center(child: Text(l.settingsEmpty, style: theme.textTheme.bodySmall));
    return Column(
      children: [
        for (final c in channels)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(LucideIcons.radio, size: 18, color: theme.colorScheme.primary),
            title: Text('${c['type'] ?? c['channel'] ?? c['name'] ?? ''}'),
            subtitle: c['account'] is Map ? Text('${(c['account'] as Map)['name'] ?? c['account']}', maxLines: 1) : null,
            trailing: c['connected'] == true || c['status'] == 'connected'
                ? Icon(LucideIcons.checkCircle2, size: 16, color: theme.colorScheme.primary)
                : null,
          ),
      ],
    );
  }
}
