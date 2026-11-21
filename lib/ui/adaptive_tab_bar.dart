import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A TabBar that keeps the app's even-spread tab rhythm while the labels
/// fit the available width, and degrades to a horizontally scrolling
/// strip when they don't (many tabs, long labels, live counts). A fixed
/// TabBar clips overflowing labels to slivers and hides the rest — this
/// measures first and only scrolls when the math says it must.
///
/// Tabs are (label, count?) records: a count rides one typographic step
/// below the label (chart 10, muted) so "Due 11" reads as a label plus
/// quiet metadata, not one word (user feedback 2026-11-21). Counts at or
/// below zero don't render.
class AdaptiveTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveTabBar({super.key, required this.tabs, this.onTap});

  final List<({String label, int? count})> tabs;
  final ValueChanged<int>? onTap;

  /// AppBar.bottom wants a PreferredSizeWidget — a text TabBar's own
  /// height (M3 _kTextTabBarHeight), indicator included.
  @override
  final Size preferredSize = const Size.fromHeight(48.0);

  /// Per-tab horizontal budget: M3's 16px label padding on both sides
  /// plus a hair of indicator clearance.
  static const _perTabSlack = 34.0;

  @override
  Widget build(BuildContext context) {
    final style =
        TabBarTheme.of(context).labelStyle ?? Theme.of(context).textTheme.titleSmall;
    return LayoutBuilder(builder: (context, constraints) {
      final scrollable = _labelsOverflow(context, style, constraints.maxWidth);
      return TabBar(
        onTap: onTap,
        isScrollable: scrollable,
        tabAlignment: scrollable ? TabAlignment.start : null,
        tabs: [
          for (final t in tabs)
            Tab(
              child: Text.rich(
                TextSpan(
                  text: t.label,
                  children: [
                    if (t.count != null && t.count! > 0)
                      TextSpan(
                        text: ' ${t.count}',
                        style: TextStyle(
                            fontSize: AppType.chart,
                            color: Theme.of(context).colorScheme.outline),
                      ),
                  ],
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
        ],
      );
    });
  }

  /// Even spread gives every tab the SAME width — a short label's
  /// surplus never flows to a long one, so one label wider than its
  /// share ("学习中 112" next to "归档 4") clips. Scroll as soon as any
  /// single label outgrows its slice; if none does, the total fits too.
  /// Measured with the same spans the tabs render (count one step down).
  bool _labelsOverflow(BuildContext context, TextStyle? style, double maxWidth) {
    final scaler = MediaQuery.textScalerOf(context);
    final perTab = maxWidth / tabs.length;
    for (final t in tabs) {
      final tp = TextPainter(
        text: TextSpan(
          text: t.label,
          style: style,
          children: [
            if (t.count != null && t.count! > 0)
              const TextSpan(
                  text: ' ', style: TextStyle(fontSize: AppType.chart)),
            if (t.count != null && t.count! > 0)
              TextSpan(
                  text: '${t.count}',
                  style: const TextStyle(fontSize: AppType.chart)),
          ],
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = tp.width;
      tp.dispose();
      if (w + _perTabSlack > perTab) return true;
    }
    return false;
  }
}
