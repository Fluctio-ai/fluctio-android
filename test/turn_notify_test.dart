import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fluctio_android/chat/turn_notify.dart';
import 'package:fluctio_android/notify/notify_hub.dart';

/// Recording LocalNotifyHub: init against the plugin-less test platform
/// would leave isReady false, so fake both the gate and the sink.
class _FakeHub extends LocalNotifyHub {
  _FakeHub(super.ref);

  final shown = <({int id, String title, String body, String payload})>[];

  @override
  bool get isReady => true;

  @override
  Future<void> show({
    required int id,
    required String channelId,
    required String channelName,
    String? channelDescription,
    required String title,
    required String body,
    required String payload,
  }) async {
    shown.add((id: id, title: title, body: body, payload: payload));
  }
}

void main() {
  // The controller-wiring half lives in turn_notify_wiring_test.dart —
  // a testWidgets in the file wraps the whole suite in
  // TestWidgetsFlutterBinding, which stubs out real HTTP.
  testWidgets('turn alerts fire only while backgrounded, payload = session route',
      (tester) async {
    final binding = TestWidgetsFlutterBinding.instance;
    late _FakeHub hub;
    final container = ProviderContainer(overrides: [
      localNotifyHubProvider.overrideWith((ref) => hub = _FakeHub(ref)),
    ]);
    addTearDown(container.dispose);
    container.read(localNotifyHubProvider); // force-build the fake
    final tn = container.read(turnNotifyProvider);

    // Foreground: nothing leaves the gate.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    tn.onTurnDone(title: 't', snippet: 's', route: '/c/s-1');
    tn.onAuthPrompt(title: 't', description: 'd', route: '/c/s-1');
    expect(hub.shown, isEmpty);

    // Backgrounded: both fire, carrying the session route as payload.
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tn.onTurnDone(title: 't', snippet: 's', route: '/c/s-1');
    tn.onAuthPrompt(title: 't', description: 'd', route: '/c/s-2');
    expect(hub.shown, hasLength(2));
    expect(hub.shown[0].payload, '/c/s-1');
    expect(hub.shown[0].body, 's');
    expect(hub.shown[1].payload, '/c/s-2');
    expect(hub.shown[1].body, contains('d'));

    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
