@Tags(['golden'])
library;

import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/features/shell/app_shell.dart';
import 'package:beach_safety/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beach_safety/settings/settings_providers.dart';

import 'support/test_settings.dart';

/// Renders Home at each risk level so the painted backdrops can be reviewed
/// without booting a device. Regenerate with:
///   flutter test --update-goldens test/backdrop_golden_test.dart
void main() {
  for (final (name, beachId) in const [
    ('low', 3),
    ('moderate', 2),
    ('high', 1),
    ('low_no_alerts', 4),
  ]) {
    testWidgets('home backdrop - $name', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      // Image.asset decodes asynchronously. Without a real async pump the
      // photo is still undecoded when the golden is captured, and only the
      // painted fallback would be recorded.
      await tester.runAsync(() async {
        final data = await rootBundle.load(
          'assets/backdrops/${name.split('_').first}.jpg',
        );
        await decodeImageFromList(data.buffer.asUint8List());
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            settingsStoreProvider.overrideWithValue(await testSettingsStore()),
            repositoryProvider.overrideWithValue(
              MockBeachRepository(latency: Duration.zero),
            ),
            selectedBeachIdProvider.overrideWith(() => _Fixed(beachId)),
          ],
          child: MaterialApp(theme: buildAppTheme(), home: const AppShell()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(
            const Duration(milliseconds: 120),
          ));
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(AppShell),
        matchesGoldenFile('goldens/home_$name.png'),
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
