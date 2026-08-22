// File: test/maps_interaction_test.dart
// Description: Widget interaction test suite verifying map zoom controls, bounds fitting, marker taps, and beach selection updates.

import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/features/maps/map_geometry.dart';
import 'package:beach_safety/features/maps/map_projection.dart';
import 'package:beach_safety/features/maps/maps_screen.dart';
import 'package:beach_safety/state/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:beach_safety/settings/settings_providers.dart';

import 'support/test_settings.dart';

void main() {

  const surface = Size(360, 800);

  Future<ProviderContainer> pumpMap(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    late final MapGeometry geometry;
    await tester.runAsync(() async => geometry = await MapGeometry.load());

    final container = ProviderContainer(
      overrides: [
        settingsStoreProvider.overrideWithValue(await testSettingsStore()),
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
        child: MaterialApp(theme: buildAppTheme(), home: const MapsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  // Converts a map-space point into a screen point.
  Offset screenPoint(WidgetTester tester, Offset scene) {

    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    return MatrixUtils.transformPoint(
      viewer.transformationController!.value,
      scene,
    );
  }

  bool enabled(WidgetTester tester, String tooltip) =>
      tester
          .widget<InkWell>(find.descendant(
            of: find.byTooltip(tooltip),
            matching: find.byType(InkWell),
          ))
          .onTap !=
      null;

  testWidgets('renders the map and its controls', (tester) async {
    await pumpMap(tester);

    expect(find.text('Monitored Beaches'), findsOneWidget);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);
    expect(find.byTooltip('Fit India'), findsOneWidget);
  });

  testWidgets('opens framed on India, not on the whole region', (tester) async {
    await pumpMap(tester);

    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    final scale = viewer.transformationController!.value.getMaxScaleOnAxis();

    // The mapped region runs well past India so the neighbours are reachable;
    // the opening view zooms past that to frame India itself.
    expect(scale, greaterThan(1.05));
    expect(scale, lessThanOrEqualTo(12.0));

    // Both directions are therefore available from the start.
    expect(enabled(tester, 'Zoom in'), isTrue);
    expect(enabled(tester, 'Zoom out'), isTrue);
  });

  testWidgets('zooming out past the India fit reaches the neighbours',
      (tester) async {
    await pumpMap(tester);

    for (var i = 0; i < 4; i++) {
      if (!enabled(tester, 'Zoom out')) break;
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
    }

    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    expect(viewer.transformationController!.value.getMaxScaleOnAxis(),
        closeTo(1.0, 0.01));
    expect(enabled(tester, 'Zoom out'), isFalse);
  });

  testWidgets('Fit India returns to the opening framing', (tester) async {
    await pumpMap(tester);

    final opening = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value
        .clone();

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();

    final zoomed = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;
    expect(zoomed.getMaxScaleOnAxis(),
        greaterThan(opening.getMaxScaleOnAxis() + 0.5));

    await tester.tap(find.byTooltip('Fit India'));
    await tester.pumpAndSettle();

    final restored = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!
        .value;
    expect(restored.getMaxScaleOnAxis(),
        closeTo(opening.getMaxScaleOnAxis(), 0.01));
  });

  testWidgets('tapping a marker selects that beach', (tester) async {
    final container = await pumpMap(tester);

    final beaches = await container.read(beachesProvider.future);
    // Marina Beach, Chennai — a different beach from the default selection.
    final marina = beaches.firstWhere((b) => b.id == 2);

    final projection = MapProjection.fit(
      bounds: (await MapGeometry.load()).region,
      size: surface,
    );
    await tester.tapAt(screenPoint(
      tester,
      projection.toCanvas(marina.longitude, marina.latitude),
    ));
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
      bounds: (await MapGeometry.load()).region,
      size: surface,
    );
    await tester.tapAt(screenPoint(tester, projection.toCanvas(69.5, 9.0)));
    await tester.pumpAndSettle();

    expect(container.read(selectedBeachIdProvider), before);
  });

  testWidgets('the selected beach card names the risk, not just its colour',
      (tester) async {
    final container = await pumpMap(tester);
    final beaches = await container.read(beachesProvider.future);
    final juhu = beaches.firstWhere((b) => b.id == 1);

    final projection = MapProjection.fit(
      bounds: (await MapGeometry.load()).region,
      size: surface,
    );
    await tester.tapAt(screenPoint(
      tester,
      projection.toCanvas(juhu.longitude, juhu.latitude),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Juhu Beach'), findsOneWidget);
    expect(find.text('High Risk'), findsOneWidget);
  });
}
