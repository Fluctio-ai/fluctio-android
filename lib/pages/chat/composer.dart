import 'package:flutter/material.dart';

import '../../chat/chat_engine.dart';
import '../../l10n/app_localizations.dart';

/// Composer row + pending-image strip. While a turn runs, the primary
/// button becomes Stop; a small send arrow stays available to steer the
/// in-flight turn (steer falls back to a normal send on 409).
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.state,
    required this.pendingImages,
    required this.onChanged,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onSend,
    required this.onSteer,
    required this.onStop,
  });

  final TextEditingController controller;
  final ChatUiState state;
  final List<String> pendingImages;
  final VoidCallback onChanged;
  final VoidCallback onPickImages;
  final void Function(int index) onRemoveImage;
  final VoidCallback onSend;
  final VoidCallback onSteer;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final turnActive = state.turnActive;
    final hasInput = controller.text.trim().isNotEmpty || pendingImages.isNotEmpty;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pendingImages.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: pendingImages.length,
                itemBuilder: (context, i) => _PendingThumb(
                  url: pendingImages[i],
                  onRemove: () => onRemoveImage(i),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: turnActive ? null : onPickImages,
                  icon: const Icon(Icons.image_outlined),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: (_) => onChanged(),
                    minLines: 1,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: l.chatEmpty, isDense: true),
                  ),
                ),
                const SizedBox(width: 4),
                if (turnActive && controller.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: l.chatSteer,
                    onPressed: onSteer,
                    icon: const Icon(Icons.send_outlined),
                  ),
                turnActive
                    ? IconButton.filledTonal(
                        tooltip: l.chatStop,
                        onPressed: state.phase == TurnPhase.stopping ? null : onStop,
                        icon: const Icon(Icons.stop_circle_outlined),
                      )
                    : IconButton.filled(
                        onPressed: hasInput ? onSend : null,
                        icon: const Icon(Icons.arrow_upward),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pending-image chip for the composer strip; data-URL only, so no cookie
/// plumbing needed here.
class _PendingThumb extends StatelessWidget {
  const _PendingThumb({required this.url, required this.onRemove});

  final String url;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 88,
              height: 88,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Container(
                width: 88,
                height: 88,
                color: scheme.secondaryContainer,
                child: Icon(Icons.broken_image_outlined, size: 20, color: scheme.outline),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                decoration: BoxDecoration(color: scheme.scrim, shape: BoxShape.circle),
                padding: const EdgeInsets.all(3),
                child: Icon(Icons.close, size: 14, color: scheme.onInverseSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
