import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global font scale (mini / medium / max), persisted — mini is the
/// designed ladder at 1.0 (current sizing), medium and max ride the root
/// TextScaler so every Text in the tree scales together (profile →
/// appearance). The WebView container keeps its own web-side sizing.
enum FontScaleLevel {
  mini(1.0),
  medium(1.15),
  max(1.3);

  const FontScaleLevel(this.factor);

  /// Multiplier applied over every TextStyle.fontSize.
  final double factor;

  static FontScaleLevel fromName(String? v) => switch (v) {
        'medium' => medium,
        'max' => max,
        _ => mini,
      };
}

final fontScaleProvider =
    NotifierProvider<FontScaleController, FontScaleLevel>(FontScaleController.new);

class FontScaleController extends Notifier<FontScaleLevel> {
  static const _key = 'app_font_scale';

  @override
  FontScaleLevel build() {
    _load();
    return FontScaleLevel.mini;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_key);
    if (v == null || !ref.mounted) return;
    state = FontScaleLevel.fromName(v);
  }

  Future<void> set(FontScaleLevel level) async {
    state = level;
    (await SharedPreferences.getInstance()).setString(_key, level.name);
  }
}
