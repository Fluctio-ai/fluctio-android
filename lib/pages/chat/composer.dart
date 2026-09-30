import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_engine.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/tokens.dart';
import '../../ui/press_scale.dart';

/// Composer card per the web chat screen: multi-line field on top, tool
/// row underneath — paperclip and the chat-only chip on the left, the
/// round-cornered send/stop action on the right (lucide icons like the
/// web). Action semantics follow the web composer: idle → send;
/// streaming with empty input → stop (filled square); streaming with
/// text → steer.
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
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: AppRadius.cardBorder,
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingImages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: SizedBox(
                  height: 88,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pendingImages.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, i) => _PendingThumb(
                      url: pendingImages[i],
                      onRemove: () => onRemoveImage(i),
                    ),
                  ),
                ),
              ),
            TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              minLines: 1,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText: l.chatEmpty,
                border: InputBorder.none,
                isDense: true,
                // Web composer rhythm (px-4 py-3, min-height 24px text):
                // a comfortable touch row, not a sliver.
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ToolButton(
                  icon: LucideIcons.paperclip,
                  tooltip: l.chatAttach,
                  onTap: turnActive ? null : onPickImages,
                ),
                const SizedBox(width: 8),
                _ToolButton(
                  icon: LucideIcons.messageCircle,
                  label: l.chatOnlyChip,
                  tooltip: l.chatOnlyMode,
                  toggled: chatOnly,
                  onTap: () => onToggleChatOnly(!chatOnly),
                ),
                const Spacer(),
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

/// 36px rounded-square outline button / chip (web tool-row style).
class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.label,
    this.toggled = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final String? label;
  final bool toggled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = toggled ? theme.colorScheme.primary : theme.colorScheme.outline;
    return Tooltip(
      message: tooltip,
      child: TactileScale(
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.controlBorder,
          child: Container(
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: label == null ? 0 : 10),
            decoration: BoxDecoration(
              borderRadius: AppRadius.controlBorder,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              color: toggled ? theme.colorScheme.primaryContainer : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                if (label != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    label!,
                    style: TextStyle(fontSize: 12, color: toggled ? theme.colorScheme.onPrimaryContainer : color),
                  ),
                ],
              ],
            ),
          ),
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
        icon = LucideIcons.square;
        onPressed = null;
      } else if (hasInput) {
        enabled = true;
        icon = LucideIcons.send;
        onPressed = onSteer;
      } else {
        enabled = true;
        icon = LucideIcons.square;
        onPressed = onStop;
      }
    } else {
      icon = LucideIcons.send;
      enabled = hasInput;
      onPressed = hasInput ? onSend : null;
    }

    return Tooltip(
      message: tooltip,
      child: TactileScale(
        enabled: onPressed != null,
        child: InkWell(
          onTap: onPressed,
          borderRadius: AppRadius.controlBorder,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: AppRadius.controlBorder,
              color: enabled ? theme.colorScheme.primary : theme.colorScheme.secondaryContainer,
            ),
            child: Icon(
              icon,
              size: 16,
              fill: icon == LucideIcons.square ? 1.0 : 0.0,
              color: enabled ? theme.colorScheme.onPrimary : theme.colorScheme.outline,
            ),
          ),
        ),
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
    return Stack(
      children: [
        ClipRRect(
          borderRadius: AppRadius.controlBorder,
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
              child: Icon(LucideIcons.imageOff, size: 20, color: scheme.outline),
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
              child: Icon(LucideIcons.x, size: 14, color: scheme.onInverseSurface),
            ),
          ),
        ),
      ],
    );
  }
}
