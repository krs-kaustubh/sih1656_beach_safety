import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/risk_theme.dart';
import '../../state/providers.dart';

/// Bottom sheet for picking a beach.
///
/// Selecting one writes to [selectedBeachIdProvider], which re-drives Home and
/// Alerts together.
class BeachSearchSheet extends ConsumerStatefulWidget {
  const BeachSearchSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const BeachSearchSheet(),
      );

  @override
  ConsumerState<BeachSearchSheet> createState() => _BeachSearchSheetState();
}

class _BeachSearchSheetState extends ConsumerState<BeachSearchSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start from a clean query each time the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(beachSearchQueryProvider.notifier).clear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(filteredBeachesProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFF10222E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.panel)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(Insets.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: Insets.lg),
                TextField(
                  controller: _controller,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (value) =>
                      ref.read(beachSearchQueryProvider.notifier).update(value),
                  decoration: InputDecoration(
                    hintText: 'Search beaches',
                    hintStyle: const TextStyle(color: Colors.white54),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Radii.field),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: Insets.md),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                  ),
                  child: switch (results) {
                    AsyncData(:final value) when value.isEmpty => const Padding(
                        padding: EdgeInsets.symmetric(vertical: Insets.xxl),
                        child: Center(
                          child: Text(
                            'No beaches match that search.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                    AsyncData(:final value) => ListView.builder(
                        shrinkWrap: true,
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          final beach = value[index];
                          final accent = RiskTheme.accentFor(
                            beach.riskLevel,
                            onDark: true,
                          );
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: accent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              beach.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              beach.region,
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                            // Colour alone must not carry the rating, so the
                            // risk is spelled out beside the dot.
                            trailing: Text(
                              beach.riskLevel.shortLabel,
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            onTap: () {
                              ref.read(selectedBeachIdProvider.notifier).select(
                                  beach.id);
                              Navigator.of(context).pop();
                            },
                          );
                        },
                      ),
                    AsyncError() => const Padding(
                        padding: EdgeInsets.symmetric(vertical: Insets.xxl),
                        child: Center(
                          child: Text(
                            'Could not load beaches.',
                            style: TextStyle(color: Colors.white60),
                          ),
                        ),
                      ),
                    _ => const Padding(
                        padding: EdgeInsets.symmetric(vertical: Insets.xxl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
