// File: lib/features/maps/maps_screen.dart
// Description: Interactive map tab screen rendering vector region boundaries, dark terrain texture overlays, risk-coded beach markers, and zoom controls.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_theme.dart';
import '../../models/beach.dart';
import '../../state/providers.dart';
import 'map_geometry.dart';
import 'map_projection.dart';
import 'terrain_map_painter.dart';

// Loads the bundled outlines once for the app.
final mapGeometryProvider = FutureProvider<MapGeometry>(
  (ref) => MapGeometry.load(),
);

// Decodes the relief texture once separately from geometry.
final terrainImageProvider = FutureProvider<ui.Image>((ref) async {
  final data = await rootBundle.load('assets/geo/terrain.jpg');
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
});

// The Maps tab plotting monitored beaches on an interactive map.
class MapsScreen extends ConsumerStatefulWidget {

  const MapsScreen({super.key});

  @override
  ConsumerState<MapsScreen> createState() => _MapsScreenState();
}

class _MapsScreenState extends ConsumerState<MapsScreen> {
  final _controller = TransformationController();
  double _zoom = 1;

  static const _minZoom = 1.0;
  static const _maxZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    super.dispose();
  }

  void _onTransform() {
    // The x-scale of the transform is the current zoom; markers and stroke
    // widths divide by it to stay a constant size on screen.
    final next = _controller.value.getMaxScaleOnAxis();
    if ((next - _zoom).abs() > 0.001) {
      setState(() => _zoom = next);
    }
  }

  void _zoomBy(double factor) {
    final target = (_zoom * factor).clamp(_minZoom, _maxZoom);
    if (target == _zoom) return;

    // Zoom about the viewport centre rather than the origin, which is what
    // the buttons imply and what keeps the current view in frame.
    final size = context.size;
    if (size == null) return;
    final centre = Offset(size.width / 2, size.height / 2);
    final scene = _controller.toScene(centre);

    _controller.value = Matrix4.identity()
      ..translateByDouble(centre.dx, centre.dy, 0, 1)
      ..scaleByDouble(target, target, target, 1)
      ..translateByDouble(-scene.dx, -scene.dy, 0, 1);
  }

  // Frames India inside viewport.
  Matrix4 _indiaView(
    Size viewport,
    MapProjection projection,
    MapGeometry geometry,
  ) {

    final rect = projection.rectFor(geometry.indiaBounds);
    if (rect.width <= 0 || rect.height <= 0) return Matrix4.identity();

    const padding = 0.90;
    final scale =
        (viewport.width / rect.width) < (viewport.height / rect.height)
        ? viewport.width / rect.width * padding
        : viewport.height / rect.height * padding;
    final clamped = scale.clamp(_minZoom, _maxZoom);

    return Matrix4.identity()
      ..translateByDouble(viewport.width / 2, viewport.height / 2, 0, 1)
      ..scaleByDouble(clamped, clamped, clamped, 1)
      ..translateByDouble(-rect.center.dx, -rect.center.dy, 0, 1);
  }

  void _fitIndia(
    Size viewport,
    MapProjection projection,
    MapGeometry geometry,
  ) {
    _controller.value = _indiaView(viewport, projection, geometry);
  }

  void _handleTap(
    Offset localPosition,
    MapProjection projection,
    List<Beach> beaches,
  ) {
    // localPosition is already in child coordinates, so it can be compared
    // directly against projected marker centres.
    const slopPixels = 22.0;
    final slop = slopPixels / _zoom;

    Beach? nearest;
    var nearestDistance = double.infinity;
    for (final beach in beaches) {
      final centre = projection.toCanvas(beach.longitude, beach.latitude);
      final distance = (centre - localPosition).distance;
      if (distance < slop && distance < nearestDistance) {
        nearest = beach;
        nearestDistance = distance;
      }
    }

    if (nearest != null) {
      ref.read(selectedBeachIdProvider.notifier).select(nearest.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final geometryAsync = ref.watch(mapGeometryProvider);
    final beachesAsync = ref.watch(beachesProvider);
    final selectedId = ref.watch(selectedBeachProvider).value?.id;

    return ColoredBox(
      color: TerrainPalette.dark.oceanDeep,
      child: switch ((geometryAsync, beachesAsync)) {
        (AsyncData(value: final geometry), AsyncData(value: final beaches)) =>
          _MapView(
            geometry: geometry,
            terrain: ref.watch(terrainImageProvider).value,
            beaches: beaches,
            selectedId: selectedId,
            controller: _controller,
            zoom: _zoom,
            minZoom: _minZoom,
            maxZoom: _maxZoom,
            onTapAt: _handleTap,
            onZoomIn: () => _zoomBy(1.6),
            onZoomOut: () => _zoomBy(1 / 1.6),
            onFitIndia: _fitIndia,
          ),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => _MapMessage(
          message: error.toString().replaceFirst(
            'BeachRepositoryException: ',
            '',
          ),
          onRetry: () {
            ref.invalidate(mapGeometryProvider);
            ref.invalidate(beachesProvider);
          },
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.geometry,
    required this.terrain,
    required this.beaches,
    required this.selectedId,
    required this.controller,
    required this.zoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onTapAt,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onFitIndia,
  });

  final MapGeometry geometry;
  final ui.Image? terrain;
  final List<Beach> beaches;
  final int? selectedId;
  final TransformationController controller;
  final double zoom;
  final double minZoom;
  final double maxZoom;
  final void Function(Offset, MapProjection, List<Beach>) onTapAt;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final void Function(Size, MapProjection, MapGeometry) onFitIndia;

  @override
  Widget build(BuildContext context) {
    final selected = beaches.where((b) => b.id == selectedId).firstOrNull;

    // One LayoutBuilder for the whole screen: the map and the controls both
    // need the same viewport size and projection, and computing them twice
    // risks the "Fit India" button framing something the map is not showing.
    return SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final projection = MapProjection.fit(
            bounds: geometry.region,
            size: size,
          );

          // The opening framing needs a laid-out viewport, which is not
          // available until here.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.value.isIdentity()) {
              onFitIndia(size, projection, geometry);
            }
          });

          return Stack(
            children: [
              InteractiveViewer(
                transformationController: controller,
                minScale: minZoom,
                maxScale: maxZoom,
                // constrained + zero margin is what bounds the map: the child
                // is exactly viewport-sized, so panning can never take the
                // country off screen.
                constrained: true,
                boundaryMargin: EdgeInsets.zero,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) =>
                      onTapAt(details.localPosition, projection, beaches),
                  child: CustomPaint(
                    size: size,
                    painter: TerrainMapPainter(
                      geometry: geometry,
                      projection: projection,
                      terrain: terrain,
                      beaches: beaches,
                      zoom: zoom,
                      selectedBeachId: selectedId,
                      palette: TerrainPalette.dark,
                    ),
                  ),
                ),
              ),
              const _MapHeader(),
              // One bottom stack for the controls, the card and the credit. They
              // used to be positioned independently and the card landed on top of
              // the zoom buttons. AppShell also sets extendBody, so the nav bar
              // floats over this body and has to be cleared explicitly.
              Positioned(
                left: Insets.lg,
                right: Insets.lg,
                // AppShell sets extendBody, so its Scaffold folds the nav bar
                // height into the body's bottom padding. Reading it here beats
                // hard-coding a clearance that drifts when the bar changes.
                bottom: MediaQuery.paddingOf(context).bottom + Insets.md,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ZoomControls(
                      onZoomIn: onZoomIn,
                      onZoomOut: onZoomOut,
                      onReset: () => onFitIndia(size, projection, geometry),
                      canZoomIn: zoom < maxZoom - 0.01,
                      canZoomOut: zoom > minZoom + 0.01,
                    ),
                    if (selected != null) ...[
                      const SizedBox(height: Insets.md),
                      SizedBox(
                        width: double.infinity,
                        child: _SelectedBeachCard(beach: selected),
                      ),
                    ],
                    const SizedBox(height: Insets.sm),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: _Attribution(),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MapHeader extends StatelessWidget {
  const _MapHeader();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: Insets.lg,
      top: Insets.lg,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B1B2C).withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(Radii.chip),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: Insets.md,
            vertical: Insets.sm,
          ),
          child: Text(
            'Monitored Beaches',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFFEAF2F8),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
    required this.canZoomIn,
    required this.canZoomOut,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;
  final bool canZoomIn;
  final bool canZoomOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapButton(
          icon: Icons.add_rounded,
          tooltip: 'Zoom in',
          onPressed: canZoomIn ? onZoomIn : null,
        ),
        const SizedBox(height: Insets.sm),
        _MapButton(
          icon: Icons.remove_rounded,
          tooltip: 'Zoom out',
          onPressed: canZoomOut ? onZoomOut : null,
        ),
        const SizedBox(height: Insets.sm),
        _MapButton(
          icon: Icons.center_focus_strong_rounded,
          tooltip: 'Fit India',
          onPressed: onReset,
        ),
      ],
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.95),
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 22,
              color: enabled
                  ? const Color(0xFF15242E)
                  : const Color(0xFFB3BEC6),
            ),
          ),
        ),
      ),
    );
  }
}

// Details for the tapped marker.
class _SelectedBeachCard extends StatelessWidget {
  const _SelectedBeachCard({required this.beach});

  final Beach beach;

  @override
  Widget build(BuildContext context) {
    final accent = RiskTheme.accentFor(beach.riskLevel, onDark: false);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(Radii.card),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(Insets.md),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    beach.name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF15242E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    beach.region,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF5B6B77),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: Insets.sm),
            Text(
              beach.riskLevel.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Attribution label for map boundary sources.
class _Attribution extends StatelessWidget {

  const _Attribution();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(Insets.xs),
    child: Text(
      'Terrain and boundaries: Natural Earth (India edition)',
      style: TextStyle(fontSize: 9.5, color: Color(0x99CFE0EC)),
    ),
  );
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Insets.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.map_outlined, size: 40, color: Color(0xFF8FA8BC)),
            const SizedBox(height: Insets.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFB9CCDA), fontSize: 15),
            ),
            const SizedBox(height: Insets.lg),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
