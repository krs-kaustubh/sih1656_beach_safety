import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/data/mock_data.dart';
import 'package:beach_safety/features/alerts/alert_detail_screen.dart';
import 'package:beach_safety/features/maps/map_geometry.dart';
import 'package:beach_safety/features/maps/maps_screen.dart';
import 'package:beach_safety/features/shell/app_shell.dart';
import 'package:beach_safety/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beach_safety/settings/settings_providers.dart';

import 'support/test_settings.dart';

void main() {
  testWidgets('Home renders the beach, risk banner and alerts', (tester) async {
    final geometry = await _loadGeometry(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(await testSettingsStore()),
          repositoryProvider.overrideWithValue(
            MockBeachRepository(latency: Duration.zero),
          ),
          mapGeometryProvider.overrideWith((ref) => geometry),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Juhu Beach'), findsOneWidget);
    expect(find.text('High Risk'), findsOneWidget);
    expect(find.text('Wave Height'), findsOneWidget);
    expect(find.text('Rip Current Warning'), findsOneWidget);
  });

  testWidgets('Alert detail renders every section', (tester) async {
    // A tall surface: the detail screen stacks several panels and the designs
    // put "what's happening" and "what to do" side by side above 380px.
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final alert = MockData.alerts().first;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(await testSettingsStore()),
        ],
        child: MaterialApp(
          theme: buildAppTheme(),
          home: AlertDetailScreen(alert: alert),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rip Current Warning'), findsOneWidget);
    expect(find.text('RISK LEVEL'), findsOneWidget);
    expect(find.text('LIFEGUARD STATUS'), findsOneWidget);
    expect(find.text('Tower 3'), findsOneWidget);
    expect(find.text('CURRENT CONDITIONS'), findsOneWidget);
    expect(find.text("WHAT'S HAPPENING"), findsOneWidget);
    expect(find.text('WHAT TO DO'), findsOneWidget);
    // Severe alerts must show the urgency chip, not just the colour.
    expect(find.text('SEVERE · ACT NOW'), findsOneWidget);
  });

  testWidgets('a beach with no alerts shows the safe empty state', (tester) async {
    final geometry = await _loadGeometry(tester);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsStoreProvider.overrideWithValue(await testSettingsStore()),
          repositoryProvider.overrideWithValue(
            MockBeachRepository(latency: Duration.zero),
          ),
          mapGeometryProvider.overrideWith((ref) => geometry),
          // Om Beach (id 4) is the low-risk beach carrying no alerts, which is
          // what the low-risk Home design shows.
          selectedBeachIdProvider.overrideWith(() => _FixedBeachId(4)),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const AppShell()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No Active Alerts'), findsOneWidget);
  });
}

/// Pins the selected beach id for a test.
class _FixedBeachId extends SelectedBeachId {
  _FixedBeachId(this.id);
  final int id;

  @override
  int? build() => id;
}

/// AppShell holds every tab in an IndexedStack, so the Maps tab builds even in
/// a Home test. Its outline comes from rootBundle, which needs a real async
/// pump that pumpAndSettle cannot provide — load it up front instead.
Future<MapGeometry> _loadGeometry(WidgetTester tester) async {
  late final MapGeometry geometry;
  await tester.runAsync(() async => geometry = await MapGeometry.load());
  return geometry;
}
