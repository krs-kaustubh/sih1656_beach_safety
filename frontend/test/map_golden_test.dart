@Tags(['golden'])
library;

import 'package:beach_safety/core/theme/app_theme.dart';
import 'package:beach_safety/data/mock_beach_repository.dart';
import 'package:beach_safety/features/maps/map_geometry.dart';
import 'package:beach_safety/features/maps/maps_screen.dart';
import 'package:beach_safety/state/providers.dart';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders the Maps tab so the India outline, projection and markers can be
/// reviewed without a device. See dart_test.yaml for how to run it.
void main() {
  testWidgets('maps tab renders India with beach markers', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // rootBundle needs a real async pump, which pumpAndSettle cannot provide.
    // Load the outline up front and hand the provider the finished value.
    late final MapGeometry geometry;
    late final ui.Image terrain;
    await tester.runAsync(() async {
      geometry = await MapGeometry.load();
      final data = await rootBundle.load('assets/geo/terrain.jpg');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      terrain = (await codec.getNextFrame()).image;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(
            MockBeachRepository(latency: Duration.zero),
          ),
          mapGeometryProvider.overrideWith((ref) => geometry),
          terrainImageProvider.overrideWith((ref) => terrain),
        ],
        child: MaterialApp(theme: buildAppTheme(), home: const MapsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MapsScreen),
      matchesGoldenFile('goldens/maps_india.png'),
    );
  });
}
