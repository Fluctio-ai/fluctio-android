import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tokens.dart';

/// WeChat-style dialog action bar (user reference screenshot 2026-11-23):
/// a full-bleed strip under a top hairline, two equal-width taps split by
/// a center hairline — 取消 in ink on the left, the confirm word on the
/// right (error red when [destructive], surge cyan otherwise). No filled
/// CTA here: a filled button beside a plain text button was exactly the
/// asymmetry the user called out. Null [confirmLabel] renders the
/// single-tap (acknowledge) variant. Button copy is body 15 — the one
/// WeChat-parity exception to the app-wide 13 button rung, so the two
/// words carry the weight the screenshot shows.
Widget dialogActionsBar(
  BuildContext context, {
  required VoidCallback onCancel,
  String? confirmLabel,
  VoidCallback? onConfirm,
  bool destructive = false,
}) {
  final colors = Theme.of(context).colorScheme;
  final l = AppLocalizations.of(context)!;
  return Container(
    decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.outlineVariant))),
    child: SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onCancel,
              child: Center(
                child: Text(l.cancel,
                    style: TextStyle(
                        fontSize: AppType.body, color: colors.onSurface)),
              ),
            ),
          ),
          if (confirmLabel != null) ...[
            VerticalDivider(width: 1, thickness: 1, color: colors.outlineVariant),
            Expanded(
              child: InkWell(
                onTap: onConfirm,
                child: Center(
                  child: Text(confirmLabel,
                      style: TextStyle(
                          fontSize: AppType.body,
                          fontWeight: FontWeight.w500,
                          color:
                              destructive ? colors.error : colors.primary)),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

/// Confirmation dialog — the one chrome for the app's confirmation-class
/// popups (DESIGN.md: 弹窗只留确认类): centered copy over the WeChat
/// action bar (see [dialogActionsBar]); chrome rides the shared
/// `dialogTheme` and [destructive] turns the confirm word error-red.
Future<bool> confirmDialog(
  BuildContext context, {
  String? title,
  required String content,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final l = AppLocalizations.of(context)!;
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          clipBehavior: Clip.antiAlias,
          title: title == null ? null : Text(title, textAlign: TextAlign.center),
          content: Text(content, textAlign: TextAlign.center),
          contentPadding:
              const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xxl, AppSpace.xxl, AppSpace.xxl),
          titlePadding:
              const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xxl, AppSpace.xxl, 0),
          actionsPadding: EdgeInsets.zero,
          actions: [
            dialogActionsBar(
              context,
              onCancel: () => Navigator.of(context).pop(false),
              confirmLabel: confirmLabel ?? l.confirm,
              onConfirm: () => Navigator.of(context).pop(true),
              destructive: destructive,
            ),
          ],
        ),
      ) ==
      true;
}

/// Destructive-action confirmation — the shared copy/UX for deletes
/// across chat sessions, KB entries and notes (error-red confirm).
Future<bool> confirmDelete(BuildContext context) => confirmDialog(
      context,
      content: AppLocalizations.of(context)!.chatDeleteConfirm,
      confirmLabel: AppLocalizations.of(context)!.chatDelete,
      destructive: true,
    );
