import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../chat/models.dart' show PendingAttachment;

/// Destination targets in the app-wide fixed order (note → chat →
/// article → bookmark); each share kind filters this list, so every
/// picker shows its targets in the same relative order:
/// - images/files (with or without text) → chat only
/// - link in the text → chat, article, bookmark
/// - plain text ≥ 60 chars → note, chat, article
/// - short text → chat only
enum ShareTarget { note, chat, article, bookmark }

/// One inbound share handed over by the platform (MainActivity's
/// share intent): text lands in the composer input, images/files ride
/// the pending strip as data URLs — the same in-memory shape the file
/// picker produces, so the send path needs no new cases.
///
/// [targetKey] marks the chosen destination session (`agentId|sid`) —
/// the picker (ShareTargetPage) stamps it; ChatPage absorbs the payload
/// once its active session matches. Null = still awaiting a choice.
class PendingShare {
  const PendingShare(
      {this.text = '', this.images = const [], this.files = const [], this.targetKey});

  final String text;
  final List<String> images;
  final List<PendingAttachment> files;
  final String? targetKey;

  PendingShare withTarget(String key) =>
      PendingShare(text: text, images: images, files: files, targetKey: key);

  /// First http(s) link in the text — drives the picker's link targets
  /// (ingest as article / save as bookmark).
  String? get link {
    final m = RegExp(r'https?://\S+').firstMatch(text);
    return m?.group(0);
  }

  List<ShareTarget> get targets {
    if (images.isNotEmpty || files.isNotEmpty) return const [ShareTarget.chat];
    if (link != null) return const [ShareTarget.chat, ShareTarget.article, ShareTarget.bookmark];
    if (text.length >= 60) return const [ShareTarget.note, ShareTarget.chat, ShareTarget.article];
    return const [ShareTarget.chat];
  }
}

final pendingShareProvider =
    NotifierProvider<PendingShareController, PendingShare?>(PendingShareController.new);

/// Bridges the Android share intent onto the app: a cold-start share is
/// consumed on build (the launch intent already carries it), a warm one
/// arrives via the channel's `available` callback (onNewIntent). The
/// result is stashed in state; main routes to the chat surface and
/// ChatPage absorbs it into its composer exactly once.
class PendingShareController extends Notifier<PendingShare?> {
  static const _channel = MethodChannel('fluctio/share');

  @override
  PendingShare? build() {
    unawaited(check());
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'available') await check();
    });
    return null;
  }

  Future<void> check() async {
    try {
      final raw = await _channel.invokeMethod('consume');
      final map = raw is Map ? raw : const {};
      final text = map['text'] as String? ?? '';
      final rawItems = map['items'];
      final items = rawItems is List ? rawItems : const [];
      final images = <String>[];
      final files = <PendingAttachment>[];
      for (final o in items) {
        if (o is! Map) continue;
        final dataUrl = o['dataUrl'] as String? ?? '';
        if (dataUrl.isEmpty) continue; // unreadable source — dropped
        final mime = o['mime'] as String? ?? '';
        if (mime.startsWith('image/')) {
          images.add(dataUrl);
        } else {
          files.add(PendingAttachment(name: o['name'] as String? ?? '', url: dataUrl));
        }
      }
      if (text.isEmpty && images.isEmpty && files.isEmpty) return;
      state = PendingShare(text: text, images: images, files: files);
    } on PlatformException {
      // Channel not ready yet — nothing to consume.
    }
  }

  /// Stamp the destination session picked in ShareTargetPage; ChatPage
  /// absorbs the payload once its active session matches.
  void target(String key) => state = state?.withTarget(key);

  void clear() => state = null;
}
