import 'package:flutter/services.dart';

/// Android system toast, bridged over the `fluctio/toast` channel
/// (MainActivity.kt). Reserved for fire-and-forget confirmations
/// ("deduped", "promoted", "press back again") — errors stay on SnackBar,
/// which keeps theme colors and readable long text; the system toast is a
/// ROM-styled pill we can't customize. Unlike SnackBar it renders above
/// scrims/drawers and survives leaving the app (share flow pops back to
/// the sender). Silently no-ops when no handler is installed (host tests).
class AppToast {
  static const _channel = MethodChannel('fluctio/toast');

  static Future<void> show(String message, {bool long = false}) async {
    try {
      await _channel.invokeMethod<void>(
          'show', {'message': message, 'long': long});
    } catch (_) {
      // Missing handler on this host — a dropped confirmation is harmless.
    }
  }
}
