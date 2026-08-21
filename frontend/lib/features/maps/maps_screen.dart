import 'package:flutter/material.dart';

import '../shell/coming_soon.dart';

/// Placeholder until the Maps phase. See `frontend/README.md`.
class MapsScreen extends StatelessWidget {
  const MapsScreen({super.key});

  @override
  Widget build(BuildContext context) => const ComingSoon(
        icon: Icons.map_outlined,
        title: 'Maps',
        message: 'Beach markers and hazard zones arrive in the next phase.',
      );
}
