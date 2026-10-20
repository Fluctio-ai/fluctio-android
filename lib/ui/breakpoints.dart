import 'package:flutter/widgets.dart';

/// Adaptive breakpoints (tablet landscape support).
///
/// Tablet-class = shortest side ≥ 600dp (Material "expanded" tier). A
/// landscape phone is ~890dp wide but its shortest side stays ~400, so
/// the shortestSide test keeps phones out of every tablet layout.

/// Tablet-class device (phone=false regardless of orientation).
bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).shortestSide >= 600;

/// Permanent app sidebar instead of the modal drawer (web app-shell
/// parity: the web sidebar shows from its md breakpoint, 768px).
bool hasPermanentSidebar(BuildContext context) =>
    isTablet(context) && MediaQuery.sizeOf(context).width >= 768;

/// Chat split-pane: transcript left + docked workspace files panel right
/// (web WorkspacePanel parity). 1000dp keeps the transcript ≥ ~600dp
/// next to a ~400dp panel; tablet portrait (768–1024dp) stays single
/// column.
bool isChatSplit(BuildContext context) =>
    isTablet(context) && MediaQuery.sizeOf(context).width >= 1000;
