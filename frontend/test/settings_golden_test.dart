@Tags(['golden'])
library;

import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/features/settings/settings_screen.dart';
import 'package:beach_safety/settings/settings_providers.dart';
import 'package:beach_safety/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_settings.dart';

void main() {
  testWidgets('settings screen', (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(await testSettingsStore()),
          repositoryProvider.overrideWithValue(
            MockBeachRepository(latency: Duration.zero),
          ),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(SettingsScreen),
      matchesGoldenFile('goldens/settings.png'),
    );
  });
}
