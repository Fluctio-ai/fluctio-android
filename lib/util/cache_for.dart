import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How long a cached list surface holds its data after the last fetch:
/// re-entering within the window renders the cached copy (no refetch,
/// no skeleton); past it the provider rebuilds on the next watch.
/// Manual refreshes (pull-to-refresh, post-write invalidations) bypass
/// the window.
const cacheTtl = Duration(minutes: 5);

extension CacheFor on Ref {
  /// Keeps an autoDispose provider alive [duration] after its last
  /// build (Riverpod "cache-for" idiom): the data survives leaving the
  /// page so reopening shows the cache, and ages out instead of serving
  /// stale forever.
  void cacheFor([Duration duration = cacheTtl]) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
