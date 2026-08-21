import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/features/maps/map_geometry.dart';
import 'package:beach_safety/features/maps/maps_screen.dart';
import 'package:beach_safety/features/shell/app_shell.dart';
import 'package:beach_safety/settings/app_settings.dart';
import 'package:beach_safety/settings/settings_providers.dart';
import 'package:beach_safety/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_settings.dart';

/// Settings are only worth having if they reach the screen. These drive the
/// real widget tree rather than asserting on the formatter in isolation.
void main() {
  Future<ProviderContainer> pumpApp(
    WidgetTester tester, [
    AppSettings? initial,
  ]) async {
    late final MapGeometry geometry;
    await tester.runAsync(() async => geometry = await MapGeometry.load());

    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider
            .overrideWithValue(await testSettingsStore(initial)),
        repositoryProvider.overrideWithValue(
          MockBeachRepository(latency: Duration.zero),
        ),
        mapGeometryProvider.overrideWith((ref) => geometry),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('wave height and wind follow the chosen units', (tester) async {
    // Marina: 1.4 m, 18 km/h, UV 6. Chosen because none of its converted
    // values collide with another reading on the same screen — on Juhu, wave
    // height in feet is 9 and so is the UV index.
    const marina = 2;

    await pumpApp(tester, const AppSettings(defaultBeachId: marina));
    expect(find.text('1.4'), findsOneWidget);
    expect(find.text('m'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('km/h SW'), findsOneWidget);

    await pumpApp(
      tester,
      const AppSettings(
        waveHeightUnit: DistanceUnit.feet,
        windSpeedUnit: SpeedUnit.knots,
        defaultBeachId: marina,
      ),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.text('ft'), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('kn SW'), findsOneWidget);
  });

  testWidgets('the tide readout uses the same clock as the header',
      (tester) async {
    // Juhu's next tide is 12:30. Before settings existed the header was
    // 12-hour and the tide 24-hour on this very screen.
    await pumpApp(tester, const AppSettings(timeFormat: TimeFormat.twelveHour));
    expect(find.text('12:30 PM'), findsOneWidget);

    await pumpApp(
      tester,
      const AppSettings(timeFormat: TimeFormat.twentyFourHour),
    );
    expect(find.text('12:30'), findsOneWidget);
  });

  testWidgets('the severity filter hides lower-risk alerts', (tester) async {
    // Marina has a moderate rip current advisory and a moderate UV warning.
    var container = await pumpApp(
      tester,
      const AppSettings(defaultBeachId: 2),
    );
    expect(container.read(alertsProvider).value, hasLength(2));

    container = await pumpApp(
      tester,
      const AppSettings(
        defaultBeachId: 2,
        alertFilter: AlertSeverityFilter.severeOnly,
      ),
    );
    expect(container.read(alertsProvider).value, isEmpty);
    expect(find.text('No Active Alerts'), findsOneWidget);
  });

  testWidgets('the filter never hides the beach\'s own risk rating',
      (tester) async {
    // Hiding the alerts must not soften the headline: Marina is still
    // Moderate Risk even when its advisories are filtered out.
    await pumpApp(
      tester,
      const AppSettings(
        defaultBeachId: 2,
        alertFilter: AlertSeverityFilter.severeOnly,
      ),
    );
    expect(find.text('Moderate Risk'), findsOneWidget);
  });

  testWidgets('the app opens on the configured default beach', (tester) async {
    await pumpApp(tester);
    expect(find.text('Juhu Beach'), findsOneWidget);

    await pumpApp(tester, const AppSettings(defaultBeachId: 3));
    expect(find.text('Radhanagar Beach'), findsOneWidget);
    expect(find.text('Juhu Beach'), findsNothing);
  });
}
