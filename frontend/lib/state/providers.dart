import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/beach_repository.dart';
import '../data/mock_beach_repository.dart';
import '../models/beach.dart';
import '../models/safety_alert.dart';

/// The single switch between mock and live data.
///
/// To go live, return an `ApiBeachRepository` here instead — no widget or model
/// changes are required.
final repositoryProvider = Provider<BeachRepository>(
  (ref) => MockBeachRepository(),
);

/// All beaches, used by the search sheet.
final beachesProvider = FutureProvider<List<Beach>>(
  (ref) => ref.watch(repositoryProvider).getBeaches(),
);

/// Which beach the Home and Alerts tabs are showing.
///
/// Null means "not chosen yet", which [selectedBeachProvider] resolves to the
/// first available beach.
class SelectedBeachId extends Notifier<int?> {
  @override
  int? build() => null;

  void select(int id) => state = id;
}

final selectedBeachIdProvider =
    NotifierProvider<SelectedBeachId, int?>(SelectedBeachId.new);

/// The currently displayed beach.
final selectedBeachProvider = FutureProvider<Beach>((ref) async {
  final beaches = await ref.watch(beachesProvider.future);
  if (beaches.isEmpty) {
    throw const BeachRepositoryException('No beaches are available.');
  }
  final selectedId = ref.watch(selectedBeachIdProvider);
  return beaches.where((b) => b.id == selectedId).firstOrNull ?? beaches.first;
});

/// Alerts for the selected beach, most severe first.
final alertsProvider = FutureProvider<List<SafetyAlert>>((ref) async {
  final beach = await ref.watch(selectedBeachProvider.future);
  return ref.watch(repositoryProvider).getAlerts(beach.id);
});

/// Free-text filter for the beach search field.
class BeachSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void update(String value) => state = value;
  void clear() => state = '';
}

final beachSearchQueryProvider =
    NotifierProvider<BeachSearchQuery, String>(BeachSearchQuery.new);

/// Beaches matching the current search query.
final filteredBeachesProvider = Provider<AsyncValue<List<Beach>>>((ref) {
  final query = ref.watch(beachSearchQueryProvider).trim().toLowerCase();
  return ref.watch(beachesProvider).whenData((beaches) {
    if (query.isEmpty) return beaches;
    return beaches
        .where((b) =>
            b.name.toLowerCase().contains(query) ||
            b.region.toLowerCase().contains(query))
        .toList(growable: false);
  });
});

/// Pull-to-refresh: drops cached data so every dependent provider refetches.
Future<void> refreshAll(WidgetRef ref) async {
  ref.invalidate(beachesProvider);
  await ref.read(selectedBeachProvider.future);
}
