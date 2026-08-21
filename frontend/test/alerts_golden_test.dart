@Tags(['golden'])
library;

import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/features/alerts/alerts_screen.dart';
import 'package:beach_safety/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beach_safety/settings/settings_providers.dart';

import 'support/test_settings.dart';

/// Renders the Alerts tab at each severity so the gradient backdrops can be
/// reviewed without a device. See dart_test.yaml for how to run it.
void main() {
  for (final (name, beachId) in const [
    ('low', 3),
    ('moderate', 2),
    ('high', 1),
    ('none', 4),
  ]) {
    testWidgets('alerts backdrop - $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(await testSettingsStore()),
            repositoryProvider.overrideWithValue(
              MockBeachRepository(latency: Duration.zero),
            ),
            selectedBeachIdProvider.overrideWith(() => _Fixed(beachId)),
          ],
          child: MaterialApp(theme: buildAppTheme(), home: const AlertsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AlertsScreen),
        matchesGoldenFile('goldens/alerts_$name.png'),
      );
    });
  }
}

class _Fixed extends SelectedBeachId {
  _Fixed(this.id);
  final int id;

  @override
  int? build() => id;
}
