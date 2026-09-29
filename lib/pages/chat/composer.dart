import 'package:flutter/material.dart';

import '../../chat/chat_engine.dart';
import '../../l10n/app_localizations.dart';

/// Composer per the prototype: paperclip button, capsule input, round
/// action button — all 40/44px, bottom-aligned. Action semantics follow
/// the web composer: idle → send; streaming with empty input → stop
/// (filled square); streaming with text → steer (paper plane).
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.state,
    required this.pendingImages,
    required this.chatOnly,
    required this.onToggleChatOnly,
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

  /// Pure-conversation mode of the open session (no tools sent to the
  /// LLM); toggled in-place like the web composer.
  final bool chatOnly;
  final ValueChanged<bool> onToggleChatOnly;
  final VoidCallback onChanged;
  final VoidCallback onPickImages;
  final void Function(int index) onRemoveImage;
  final VoidCallback onSend;
  final VoidCallback onSteer;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final turnActive = state.turnActive;
    final hasInput = controller.text.trim().isNotEmpty || pendingImages.isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingImages.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: pendingImages.length,
                  itemBuilder: (context, i) => _PendingThumb(
                    url: pendingImages[i],
                    onRemove: () => onRemoveImage(i),
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox.square(
                  dimension: 40,
                  child: IconButton.filledTonal(
                    tooltip: l.chatAttach,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: theme.colorScheme.outline,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                      shape: const CircleBorder(),
                    ),
                    onPressed: turnActive ? null : onPickImages,
                    icon: const Icon(Icons.attach_file, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    // Capsule like the prototype's .input-wrapper (radius
                    // = half the 44px min height). The field's own content
                    // padding fills the capsule so the focus / cursor
                    // region matches the visible height.
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        // Chat-only toggle lives in the capsule like the
                        // web composer's tool row (icon + label, primary
                        // tint when active).
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => onToggleChatOnly(!chatOnly),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: chatOnly
                                    ? theme.colorScheme.primaryContainer
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 15,
                                    color: chatOnly
                                        ? theme.colorScheme.onPrimaryContainer
                                        : theme.colorScheme.outline,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    l.chatOnlyChip,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: chatOnly
                                          ? theme.colorScheme.onPrimaryContainer
                                          : theme.colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            onChanged: (_) => onChanged(),
                            minLines: 1,
                            maxLines: 6,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: l.chatEmpty,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _ActionButton(
                  turnActive: turnActive,
                  stopping: state.phase == TurnPhase.stopping,
                  hasInput: hasInput,
                  tooltip: turnActive ? (hasInput ? l.chatSteer : l.chatStop) : l.chatSend,
                  onSend: onSend,
                  onSteer: onSteer,
                  onStop: onStop,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.turnActive,
    required this.stopping,
    required this.hasInput,
    required this.tooltip,
    required this.onSend,
    required this.onSteer,
    required this.onStop,
  });

  final bool turnActive;
  final bool stopping;
  final bool hasInput;
  final String tooltip;
  final VoidCallback onSend;
  final VoidCallback onSteer;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool enabled;
    final IconData icon;
    final VoidCallback? onPressed;

    if (turnActive) {
      if (stopping) {
        enabled = false;
        icon = Icons.stop_rounded;
        onPressed = null;
      } else if (hasInput) {
        enabled = true;
        icon = Icons.send;
        onPressed = onSteer;
      } else {
        enabled = true;
        icon = Icons.stop_rounded;
        onPressed = onStop;
      }
    } else {
      icon = Icons.send;
      enabled = hasInput;
      onPressed = hasInput ? onSend : null;
    }

    return SizedBox.square(
      dimension: 40,
      child: IconButton.filled(
        tooltip: tooltip,
        style: IconButton.styleFrom(
          backgroundColor: enabled ? theme.colorScheme.primary : theme.colorScheme.secondaryContainer,
          foregroundColor:
              enabled ? theme.colorScheme.onPrimary : theme.colorScheme.outline,
          disabledBackgroundColor: theme.colorScheme.secondaryContainer,
          disabledForegroundColor: theme.colorScheme.outline,
          shape: const CircleBorder(),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
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
