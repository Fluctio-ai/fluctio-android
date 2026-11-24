import 'package:flutter/material.dart';

/// Drops the IME around a search-list page: a tap on the wrapped area's
/// empty space, or the start of a user scroll drag, releases the current
/// focus (iOS `keyboardDismissMode: onDrag` semantics). Deeper
/// recognizers (row taps, buttons) still win the arena — the same
/// contract the chat transcript's unfocus tap established (chat_page,
/// user feedback 2026-11-21). Scroll notifications bubble up from any
/// descendant ListView, so one wrapper covers every list on the page.
class TapToUnfocus extends StatelessWidget {
  const TapToUnfocus({super.key, required this.child});

  final Widget child;

  static void _dismiss() => FocusManager.instance.primaryFocus?.unfocus();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _dismiss,
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // dragDetails != null = a user drag, not a programmatic scroll.
          if (n is ScrollStartNotification && n.dragDetails != null) _dismiss();
          return false;
        },
        child: child,
      ),
    );
  }
}

