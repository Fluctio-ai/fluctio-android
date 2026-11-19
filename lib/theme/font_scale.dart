import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global font scale (mini / medium / max), persisted — the tiers ride
/// the root TextScaler so every Text in the tree scales together
/// (profile → appearance). The WebView container keeps its own web-side
/// sizing.
///
/// Anchored to WeChat's 字体大小 (user decision 2026-11-19, side-by-side
/// comparison): the transcript body (13.5sp, web chat-md parity) at
/// medium must read like WeChat's 标准 chat text (16sp), so medium =
/// 16/13.5 ≈ 1.19. The steps around the anchor were re-balanced after
/// hands-on feedback: WeChat scales only CONTENT text — its navbar and
/// metadata stay fixed, and its largest stop feels tame next to a
/// uniform UI-wide scale — so max is held at 1.30 (not 1.40) and the
/// chrome/tool-card freeze lives at the call sites (see chat_page's
/// header, message_list's tool card, markdown's damped headings).
/// Layout reflows like WeChat (line heights are fontSize multiples,
/// spacing scales together). Note: even mini now sits above the old
/// 1.0 design baseline — the dense original look is intentionally
/// traded for WeChat parity.
enum FontScaleLevel {
  mini(1.1),
  medium(1.19),
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

/// The active font tier's factor as applied to the root TextScaler.
/// Layout metrics that should breathe with the glyphs (bubble padding,
/// markdown block gaps) multiply their baseline by this — WeChat's
/// bubbles grow padding with font size; fixed dp gaps look cramped at
/// 大. Line heights need nothing (they are fontSize multiples, so the
/// TextScaler scales them automatically); CJK sets no letterSpacing by
/// design (DESIGN.md), so there is no tracking to adjust.
double fontLayoutScale(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(1.0);
