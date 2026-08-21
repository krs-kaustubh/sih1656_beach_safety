import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/features/maps/india_geometry.dart';
import 'package:beach_safety/features/maps/map_projection.dart';
import 'package:beach_safety/features/maps/maps_screen.dart';
import 'package:beach_safety/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const surface = Size(360, 800);

  Future<ProviderContainer> pumpMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    late final IndiaGeometry geometry;
    await tester.runAsync(() async => geometry = await IndiaGeometry.load());

    final container = ProviderContainer(
      overrides: [
        repositoryProvider.overrideWithValue(
          MockBeachRepository(latency: Duration.zero),
        ),
        indiaGeometryProvider.overrideWith((ref) => geometry),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildAppTheme(), home: const MapsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renders the map and its controls', (tester) async {
    await pumpMap(tester);

    expect(find.text('Monitored Beaches'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Fit India'), findsOneWidget);
  });

  testWidgets('starts fully zoomed out, so zoom-out is disabled', (tester) async {
    await pumpMap(tester);

    final zoomOut = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('Zoom out'),
        matching: find.byType(InkWell),
      ),
    );
    expect(zoomOut.onTap, isNull);

    final zoomIn = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('Zoom in'),
        matching: find.byType(InkWell),
      ),
    );
    expect(zoomIn.onTap, isNotNull);
  });

  testWidgets('zooming in enables zoom-out, and reset returns to the fit',
      (tester) async {
    await pumpMap(tester);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();

    final zoomOut = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('Zoom out'),
        matching: find.byType(InkWell),
      ),
    );
    expect(zoomOut.onTap, isNotNull, reason: 'zoom-out should now be available');

    await tester.tap(find.byTooltip('Fit India'));
    await tester.pumpAndSettle();

    final afterReset = tester.widget<InkWell>(
      find.descendant(
        of: find.byTooltip('Zoom out'),
        matching: find.byType(InkWell),
      ),
    );
    expect(afterReset.onTap, isNull, reason: 'reset should restore the fit');
  });

  testWidgets('tapping a marker selects that beach', (tester) async {
    final container = await pumpMap(tester);

    final beaches = await container.read(beachesProvider.future);
    // Marina Beach, Chennai — a different beach from the default selection.
    final marina = beaches.firstWhere((b) => b.id == 2);

    final projection = MapProjection.fit(
      bounds: (await IndiaGeometry.load()).bounds,
      size: surface,
    );
    final target = projection.toCanvas(marina.longitude, marina.latitude);

    await tester.tapAt(target);
    await tester.pumpAndSettle();

    expect(container.read(selectedBeachIdProvider), marina.id);
    expect(find.text('Marina Beach'), findsOneWidget);
    expect(find.text('Moderate Risk'), findsOneWidget);
  });

  testWidgets('tapping empty ocean does not change the selection',
      (tester) async {
    final container = await pumpMap(tester);
    final before = container.read(selectedBeachIdProvider);

    // Well out in the Arabian Sea, away from every marker.
    final projection = MapProjection.fit(
      bounds: (await IndiaGeometry.load()).bounds,
      size: surface,
    );
    await tester.tapAt(projection.toCanvas(69.5, 9.0));
    await tester.pumpAndSettle();

    expect(container.read(selectedBeachIdProvider), before);
  });

  testWidgets('the selected beach card names the risk, not just its colour',
      (tester) async {
    final container = await pumpMap(tester);
    final beaches = await container.read(beachesProvider.future);
    final juhu = beaches.firstWhere((b) => b.id == 1);

    final projection = MapProjection.fit(
      bounds: (await IndiaGeometry.load()).bounds,
      size: surface,
    );
    await tester.tapAt(projection.toCanvas(juhu.longitude, juhu.latitude));
    await tester.pumpAndSettle();

    expect(find.text('Juhu Beach'), findsOneWidget);
    expect(find.text('High Risk'), findsOneWidget);
  });
}
