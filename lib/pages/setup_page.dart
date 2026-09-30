import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api_client.dart';
import '../auth/auth_controller.dart';
import '../auth/auth_state.dart';
import '../core/server_url.dart';
import '../l10n/app_localizations.dart';
import '../ui/brand_wave.dart';

/// First-run / logged-out screen: server address (with health probe),
/// then credentials. One route serves both `needSetup` and `loggedOut`.
class SetupPage extends ConsumerStatefulWidget {
  const SetupPage({super.key});

  @override
  ConsumerState<SetupPage> createState() => _SetupPageState();
}

enum _ProbeState { idle, running, ok, failed }

class _SetupPageState extends ConsumerState<SetupPage> {
  final _addressCtrl = TextEditingController();
  final _loginCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _allowSelfSigned = false;
  bool _editingServer = false;
  bool _busy = false;
  String? _formError;
  _ProbeState _probe = _ProbeState.idle;

  @override
  void dispose() {
    _addressCtrl.dispose();
    _loginCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _showAddressForm => ref.read(authControllerProvider).status == AuthStatus.needSetup || _editingServer;

  String? _serverUrlErrorText(AppLocalizations l) {
    if (_addressCtrl.text.trim().isEmpty) return null;
    return switch (validateServerUrl(_addressCtrl.text, allowSelfSigned: _allowSelfSigned)) {
      ServerUrlError.invalidFormat => l.errorInvalidFormat,
      ServerUrlError.httpsRequired => l.errorHttpsRequired,
      ServerUrlError.lanNeedsTrust => l.errorLanNeedsTrust,
      null => null,
    };
  }

  Future<void> _runProbe() async {
    setState(() {
      _probe = _ProbeState.running;
      _formError = null;
    });
    final url = normalizeServerUrl(_addressCtrl.text);
    final ok = await probeHealth(url, allowSelfSigned: _allowSelfSigned);
    if (!mounted) return;
    setState(() => _probe = ok ? _ProbeState.ok : _ProbeState.failed);
  }

  Future<void> _saveServer() async {
    final url = normalizeServerUrl(_addressCtrl.text);
    if (validateServerUrl(url, allowSelfSigned: _allowSelfSigned) != null) return;
    await ref.read(authControllerProvider.notifier).saveServer(url, allowSelfSigned: _allowSelfSigned);
    if (mounted) setState(() => _editingServer = false);
  }

  Future<void> _signIn() async {
    if (_busy || _loginCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(_loginCtrl.text, _passwordCtrl.text);
      // Router redirect takes over on success; no local navigation.
    } catch (e) {
      if (mounted) {
        // Debug builds append the raw error so field diagnoses don't
        // depend on logcat (some OEM ROMs throttle it).
        final raw = kDebugMode ? '\n$e' : '';
        setState(() => _formError = '${apiErrorMessage(e, AppLocalizations.of(context)!)}$raw');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final auth = ref.watch(authControllerProvider);
    final showingAddress = _showAddressForm;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: BrandWave(size: 48)),
                  const SizedBox(height: 16),
                  Text(l.setupTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 24),
                  if (showingAddress) _addressForm(l) else _loginForm(l, auth),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _addressForm(AppLocalizations l) {
    final urlError = _serverUrlErrorText(l);
    final canSave = _addressCtrl.text.trim().isNotEmpty && urlError == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _addressCtrl,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l.serverAddress,
            hintText: l.serverAddressHint,
            errorText: urlError,
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l.allowSelfSigned),
          subtitle: Text(l.allowSelfSignedSub),
          value: _allowSelfSigned,
          onChanged: (v) => setState(() => _allowSelfSigned = v),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton(
              onPressed: _probe == _ProbeState.running || _addressCtrl.text.trim().isEmpty ? null : _runProbe,
              child: Text(_probe == _ProbeState.running ? l.testing : l.testConnection),
            ),
            const SizedBox(width: 12),
            if (_probe == _ProbeState.ok)
              Text(l.connectionOk, style: TextStyle(color: Theme.of(context).colorScheme.tertiary))
            else if (_probe == _ProbeState.failed)
              Text(l.connectionFailed, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: canSave ? _saveServer : null, child: Text(l.saveAndContinue)),
      ],
    );
  }

  Widget _loginForm(AppLocalizations l, AuthState auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.currentServer, style: Theme.of(context).textTheme.bodySmall),
                  Text(auth.baseUrl, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            TextButton(onPressed: () => setState(() => _editingServer = true), child: Text(l.changeServer)),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _loginCtrl,
          autocorrect: false,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: l.accountLabel),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _passwordCtrl,
          obscureText: true,
          onSubmitted: (_) => _signIn(),
          decoration: InputDecoration(labelText: l.passwordLabel),
        ),
        if (_formError != null) ...[
          const SizedBox(height: 12),
          Text(_formError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _signIn,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(l.signIn),
        ),
      ],
    );
  }
}
