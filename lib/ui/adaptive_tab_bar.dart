import 'package:flutter/material.dart';

/// A TabBar that keeps the app's even-spread tab rhythm while the labels
/// fit the available width, and degrades to a horizontally scrolling
/// strip when they don't (many tabs, long labels, live counts). A fixed
/// TabBar clips overflowing labels to slivers and hides the rest — this
/// measures first and only scrolls when the math says it must.
///
/// Text tabs only (the app's tab bars are all `Tab(text:)`); a child
/// tab keeps the fixed spread, as its width can't be estimated.
class AdaptiveTabBar extends StatelessWidget implements PreferredSizeWidget {
  const AdaptiveTabBar({super.key, required this.tabs, this.onTap});

  final List<Tab> tabs;
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
    return LayoutBuilder(builder: (context, constraints) {
      final scrollable = _labelsOverflow(context, constraints.maxWidth);
      return TabBar(
        onTap: onTap,
        isScrollable: scrollable,
        tabAlignment: scrollable ? TabAlignment.start : null,
        tabs: tabs,
      );
    });
  }

  /// Even spread gives every tab the SAME width — a short label's
  /// surplus never flows to a long one, so one label wider than its
  /// share ("学习中 112" next to "归档 4") clips. Scroll as soon as any
  /// single label outgrows its slice; if none does, the total fits too.
  bool _labelsOverflow(BuildContext context, double maxWidth) {
    final style =
        TabBarTheme.of(context).labelStyle ?? Theme.of(context).textTheme.titleSmall;
    final perTab = maxWidth / tabs.length;
    for (final t in tabs) {
      final text = t.text;
      if (text == null) return false;
      final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final w = tp.width;
      tp.dispose();
      if (w + _perTabSlack > perTab) return true;
    }
    return false;
  }
}
