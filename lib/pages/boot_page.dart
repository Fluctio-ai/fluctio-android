import 'package:flutter/material.dart';

import '../brand/logo_mark.dart';

/// Boot gate shown while the auth state machine restores the session.
/// The vector mark starts settled (matching the static system splash),
/// unwinds layer by layer, then fades out once.
class BootPage extends StatelessWidget {
  const BootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: LogoMarkLoader(size: 192)),
    );
  }
}
