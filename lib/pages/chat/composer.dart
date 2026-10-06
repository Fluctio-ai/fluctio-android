import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../chat/chat_engine.dart';
import '../../chat/models.dart';
import '../../chat/slash_commands.dart';
import '../../l10n/app_localizations.dart';
import 'typing_dots.dart';
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
    required this.pendingFiles,
    required this.chatOnly,
    required this.readOnly,
    required this.onToggleChatOnly,
    required this.onChanged,
    required this.onPickAttachments,
    required this.onRemoveImage,
    required this.onRemoveFile,
    required this.onSend,
    required this.onSteer,
    required this.onStop,
  });

  final TextEditingController controller;
  final ChatUiState state;
  final List<String> pendingImages;
  final List<PendingAttachment> pendingFiles;

  /// Pure-conversation mode of the open session (no tools sent to the
  /// LLM); toggled in-place like the web composer.
  final bool chatOnly;

  /// Open session belongs to an IM channel — the app can't deliver into
  /// upstream messengers, so input/attach/toggle go inert and only the
  /// read-only-safe slash commands still send (web parity,
  /// chat-screen.tsx:1408-1414). This card alone carries the notice (its
  /// hint text plus inert controls); a dedicated banner above it was
  /// dropped as redundant (user feedback).
  final bool readOnly;
  final ValueChanged<bool> onToggleChatOnly;
  final VoidCallback onChanged;
  final VoidCallback onPickAttachments;
  final void Function(int index) onRemoveImage;
  final void Function(int index) onRemoveFile;
  final VoidCallback onSend;
  final VoidCallback onSteer;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = AppLocalizations.of(context)!;
    final turnActive = state.turnActive;
    final hasInput =
        controller.text.trim().isNotEmpty || pendingImages.isNotEmpty || pendingFiles.isNotEmpty;

    return SafeArea(
      top: false,
      child: Container(
        // Margins match the transcript's 12px list padding, so the card's
        // edges line up with the message bubbles above (user feedback).
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
            if (pendingImages.isNotEmpty || pendingFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                child: SizedBox(
                  height: 88,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (var i = 0; i < pendingImages.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: i == pendingImages.length - 1 && pendingFiles.isEmpty ? 0 : 8),
                          child: _PendingThumb(
                            url: pendingImages[i],
                            onRemove: () => onRemoveImage(i),
                          ),
                        ),
                      for (var i = 0; i < pendingFiles.length; i++)
                        Padding(
                          padding: EdgeInsets.only(right: i == pendingFiles.length - 1 ? 0 : 8),
                          child: _PendingFileChip(
                            name: pendingFiles[i].name,
                            onRemove: () => onRemoveFile(i),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              readOnly: readOnly,
              minLines: 1,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: AppType.body, height: 1.4),
              decoration: InputDecoration(
                hintText: readOnly ? l.chatImReadOnlyHint : l.chatEmpty,
                border: InputBorder.none,
                isDense: true,
                // Web composer rhythm (px-4 py-3, min-height 24px text):
                // a comfortable touch row, not a sliver. Horizontal
                // matches the 10px vertical — borderless inputs default
                // to 0 and the text hugs the card edge.
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _ToolButton(
                  icon: LucideIcons.paperclip,
                  tooltip: l.chatAttach,
                  onTap: (turnActive || readOnly) ? null : onPickAttachments,
                ),
                const SizedBox(width: 8),
                _ToolButton(
                  icon: LucideIcons.messageCircle,
                  label: l.chatOnlyChip,
                  tooltip: l.chatOnlyMode,
                  toggled: chatOnly,
                  onTap: readOnly ? null : () => onToggleChatOnly(!chatOnly),
                ),
                // "Thinking…" while the turn runs but the first delta
                // hasn't arrived — lives in the tool row next to the
                // chat-only chip (user feedback: every layered take
                // above the card read as a bar behind the text; here
                // it's plain text inside the card, clear of the fade
                // band).
                if (turnActive && state.awaitingFirstDelta) ...[
                  const SizedBox(width: 10),
                  const TypingDots(),
                  const SizedBox(width: 6),
                  Text(l.chatThinking,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.outline)),
                ],
                const Spacer(),
                _ActionButton(
                  turnActive: turnActive,
                  stopping: state.phase == TurnPhase.stopping,
                  hasInput: hasInput,
                  sendAllowed: !readOnly || isReadOnlySafeSlashCommand(controller.text),
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
      // Disabled must read inert — a full-strength control that does
      // nothing looks broken (paperclip mid-turn).
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1.0,
        child: TactileScale(
          enabled: onTap != null,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.controlBorder,
            child: Container(
              height: 36,
              // Equal horizontal padding with or without a label — the
              // bare paperclip shouldn't collapse into a narrow strip.
              padding: const EdgeInsets.symmetric(horizontal: 10),
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
                      style: TextStyle(fontSize: AppType.caption, color: toggled ? theme.colorScheme.onPrimaryContainer : color),
                    ),
                  ],
                ],
              ),
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
    required this.sendAllowed,
    required this.tooltip,
    required this.onSend,
    required this.onSteer,
    required this.onStop,
  });

  final bool turnActive;
  final bool stopping;
  final bool hasInput;

  /// Idle-send gate for read-only (IM channel) sessions — false unless
  /// the current text is a read-only-safe slash command. Steering/stopping
  /// an in-flight turn stays available (server-side turn control).
  final bool sendAllowed;
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
        icon = Icons.stop;
        onPressed = null;
      } else if (hasInput) {
        enabled = true;
        icon = LucideIcons.send;
        onPressed = onSteer;
      } else {
        enabled = true;
        // Filled stop square — lucide is an outline-only font, so the
        // previous fill:1.0 on LucideIcons.square silently did nothing.
        icon = Icons.stop;
        onPressed = onStop;
      }
    } else {
      icon = LucideIcons.send;
      enabled = hasInput && sendAllowed;
      onPressed = enabled ? onSend : null;
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

/// Pending non-image file chip for the composer strip — same 88px row
/// height as the image thumbs so mixed strips stay aligned.
class _PendingFileChip extends StatelessWidget {
  const _PendingFileChip({required this.name, required this.onRemove});

  final String name;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.secondaryContainer,
            borderRadius: AppRadius.controlBorder,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.fileText, size: 20, color: scheme.onSecondaryContainer),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 104),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppType.caption,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
            ],
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
