import 'package:flutter/material.dart';

import '../shell/coming_soon.dart';

/// Placeholder until the Settings phase. See `frontend/README.md`.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoon(
        icon: Icons.settings_outlined,
        title: 'Settings',
        message: 'Units, notifications and saved beaches arrive in a later phase.',
      );
}
