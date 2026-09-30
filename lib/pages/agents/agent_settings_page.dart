import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/api_client.dart';
import '../../chat/chat_controller.dart';
import '../../l10n/app_localizations.dart';
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
          ? Center(child: Text(l.chatNoAgent, style: theme.textTheme.bodyMedium))
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
  String _tab = 'profile';
  bool _saving = false;

  // Field-tab controllers owned by the page state (a fresh controller
  // per build would reset sibling fields and the cursor on every
  // keystroke / spinner toggle).
  late final _name = TextEditingController();
  late final _description = TextEditingController();
  late final _maxTokens = TextEditingController();
  late final _temperature = TextEditingController();
  late final _iterations = TextEditingController();
  late final _threshold = TextEditingController();

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _maxTokens, _temperature, _iterations, _threshold]) {
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
    _maxTokens.text = '${scope['maxTokens'] ?? ''}';
    _temperature.text = '${scope['temperature'] ?? ''}';
    _iterations.text = '${scope['maxToolIterations'] ?? ''}';
    _threshold.text = '${config['compactionThreshold'] ?? ''}';
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.agentName.isEmpty ? l.meAgentManage : widget.agentName)),
      body: Column(
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
                ? const SkeletonListView()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _tabBody(context),
                  ),
          ),
        ],
      ),
    );
  }

  /// `/api/agents/<id>/<leaf>` for the blob subresources.
  String _scopedPath(String leaf) => '/api/agents/${widget.agentId}/$leaf';

  Widget _tabBody(BuildContext context) {
    final agentId = widget.agentId;
    return switch (_tab) {
      'profile' => _profileTab(),
      'models' => _modelsTab(),
      'context' => _contextTab(),
      'customize' => _customizeTab(),
      'knowledge' => _knowledgeTab(),
      'recall' => BlobEditor(
          load: () => _repo.scopedGet(_scopedPath('recall-tuning')),
          save: (blob) => _repo.scopedPut(_scopedPath('recall-tuning'), blob)),
      'vectorization' => BlobEditor(
          load: () => _repo.scopedGet(_scopedPath('vectorization')),
          save: (blob) => _repo.scopedPut(_scopedPath('vectorization'), blob)),
      'privacy' => BlobEditor(
          load: () => _repo.scopedGet(_scopedPath('privacy')),
          save: (blob) => _repo.scopedPut(_scopedPath('privacy'), blob)),
      'usage' => _UsageTab(path: _scopedPath('usage')),
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
      'channels' => _RepoListTab(
          fetch: () => _repo.channels(agentId),
          tileBuilder: (context, row, _) => _channelTile(context, row)),
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

  Widget _modelsTab() {
    final l = AppLocalizations.of(context)!;
    return _FieldCard(
      onSave: () => _savePatch({
        'model': '${_scope!['model'] ?? ''}',
        'maxTokens': int.tryParse(_maxTokens.text) ?? 0,
        'temperature': double.tryParse(_temperature.text) ?? 0,
        'maxToolIterations': int.tryParse(_iterations.text) ?? 0,
      }),
      saving: _saving,
      children: [
        labeledField(
          context,
          l.tabModel,
          _ModelField(
            current: '${_scope!['model'] ?? ''}',
            onChanged: (m) => setState(() => _scope!['model'] = m),
          ),
        ),
        labeledField(
            context,
            'maxTokens',
            TextField(controller: _maxTokens, keyboardType: TextInputType.number)),
        labeledField(
            context,
            'temperature',
            TextField(
                controller: _temperature,
                keyboardType: const TextInputType.numberWithOptions(decimal: true))),
        labeledField(
            context,
            'maxToolIterations',
            TextField(controller: _iterations, keyboardType: TextInputType.number)),
      ],
    );
  }

  Widget _contextTab() {
    final cfg = _config!;
    return _FieldCard(
      onSave: () => _savePatch({
        'promptMode': '${_scope!['promptMode'] ?? cfg['promptMode'] ?? ''}',
        'guidance': '${_scope!['guidance'] ?? ''}',
        'compactionMode': '${cfg['compactionMode'] ?? ''}',
        'compactionThreshold': int.tryParse(_threshold.text) ?? 0,
        'language': '${cfg['language'] ?? ''}',
      }),
      saving: _saving,
      children: [
        labeledField(
            context,
            'promptMode',
            _dropdown(['agent', 'chatbot', 'customize'],
                '${_scope!['promptMode'] ?? cfg['promptMode'] ?? ''}',
                (v) => setState(() => _scope!['promptMode'] = v))),
        labeledField(
            context,
            'guidance',
            _dropdown(['autonomous', 'guided'], '${_scope!['guidance'] ?? ''}',
            (v) => setState(() => _scope!['guidance'] = v))),
        labeledField(
            context,
            'compactionMode',
            _dropdown(['conservative', 'balanced', 'aggressive'], '${cfg['compactionMode'] ?? ''}',
                (v) => setState(() => _config!['compactionMode'] = v))),
        labeledField(
            context,
            'compactionThreshold',
            TextField(controller: _threshold, keyboardType: TextInputType.number)),
        labeledField(
            context,
            'language',
            _dropdown(['zh-CN', 'en'], '${cfg['language'] ?? ''}',
            (v) => setState(() => _config!['language'] = v))),
      ],
    );
  }

  Widget _customizeTab() {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scope = _scope!;
    bool b(String key) => scope[key] == true || scope[key] == 'true';
    return _FieldCard(
      onSave: () => _savePatch({
        'splitReplies': b('splitReplies'),
        'autoPersist': b('autoPersist'),
        'sharedIdentity': b('sharedIdentity'),
      }),
      saving: _saving,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('splitReplies'),
          value: b('splitReplies'),
          onChanged: (v) => setState(() => scope['splitReplies'] = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('autoPersist'),
          value: b('autoPersist'),
          onChanged: (v) => setState(() => scope['autoPersist'] = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('sharedIdentity'),
          value: b('sharedIdentity'),
          onChanged: (v) => setState(() => scope['sharedIdentity'] = v),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l.tabCustomizeHint,
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
        ),
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
        for (final o in options)
          DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))),
      ],
      onChanged: (v) => v == null ? null : onChanged(v),
    );
  }
}

/// Text field + builtin-model suggestions for the model tab.
class _ModelField extends ConsumerStatefulWidget {
  const _ModelField({required this.current, required this.onChanged});

  final String current;
  final ValueChanged<String> onChanged;

  @override
  ConsumerState<_ModelField> createState() => _ModelFieldState();
}

class _ModelFieldState extends ConsumerState<_ModelField> {
  late final TextEditingController _controller = TextEditingController(text: widget.current);
  List<String> _models = const [];

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepoProvider).builtinModels().then((models) {
      if (mounted) setState(() => _models = models);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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

/// Read-only usage blob in a card.
class _UsageTab extends ConsumerStatefulWidget {
  const _UsageTab({required this.path});

  final String path;

  @override
  ConsumerState<_UsageTab> createState() => _UsageTabState();
}

class _UsageTabState extends ConsumerState<_UsageTab> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    ref.read(settingsRepoProvider).scopedGet(widget.path).then((d) {
      if (mounted) setState(() => _data = d);
    }).catchError((_) {
      if (mounted) setState(() => _data = {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = _data;
    if (data == null) {
      return const SkeletonList(itemCount: 3, leading: false);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: surfaceCardDecoration(theme.colorScheme),
      child: JsonView(value: data),
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
              label: Text(l.settingsReload, style: const TextStyle(fontSize: 13)),
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
                onPressed: () => ref
                    .read(settingsRepoProvider)
                    .deleteSkill(widget.agentId, '${s['name'] ?? s['id'] ?? ''}')
                    .then((_) => _load()),
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
    final theme = Theme.of(context);
    final rows = _rows;
    if (rows == null) return const SkeletonList(itemCount: 4);
    if (rows.isEmpty) return Center(child: Text(l.settingsEmpty, style: theme.textTheme.bodySmall));
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
      onPressed: onDelete,
    ),
  );
}

Widget _channelTile(BuildContext context, Map<String, dynamic> row) {
  final theme = Theme.of(context);
  return ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(LucideIcons.radio, size: 18, color: theme.colorScheme.primary),
    title: Text('${row['type'] ?? row['channel'] ?? row['name'] ?? ''}'),
    subtitle: row['account'] is Map
        ? Text('${(row['account'] as Map)['name'] ?? row['account']}', maxLines: 1)
        : null,
    trailing: row['connected'] == true || row['status'] == 'connected'
        ? Icon(LucideIcons.checkCircle2, size: 16, color: theme.colorScheme.primary)
        : null,
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
              onPressed: () => widget.onSaved({'mcpServers': {...servers}..remove(name)}),
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
            TextField(controller: name, decoration: const InputDecoration(hintText: 'name')),
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
    final theme = Theme.of(context);
    final registry = _registry;
    if (registry == null) return const SkeletonList(itemCount: 4);
    if (registry.isEmpty && _overlay.isEmpty) {
      return Center(child: Text(l.settingsEmpty, style: theme.textTheme.bodySmall));
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
