import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_beach_repository.dart';
import '../data/beach_repository.dart';
import '../models/beach.dart';
import '../models/safety_alert.dart';
import '../settings/settings_providers.dart';

/// The single switch between live and mock data.
///
/// Live by default. To demo without a running service, return a
/// `MockBeachRepository()` here instead — no widget or model changes needed.
///
/// The base URL resolves per platform and can be overridden at build time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.5:8000
final repositoryProvider = Provider<BeachRepository>((ref) {
  final repository = ApiBeachRepository();
  ref.onDispose(repository.dispose);
  return repository;
});

/// All beaches, used by the search sheet.
final beachesProvider = FutureProvider<List<Beach>>(
  (ref) => ref.watch(repositoryProvider).getBeaches(),
);

/// Which beach the Home and Alerts tabs are showing.
///
/// Starts at the user's configured default; null means "not chosen", which
/// [selectedBeachProvider] resolves to the first beach the backend lists.
class SelectedBeachId extends Notifier<int?> {
  @override
  int? build() => ref.read(settingsProvider).defaultBeachId;

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

/// Alerts for the selected beach, most severe first, honouring the user's
/// severity filter.
///
/// The filter hides advisories the user has chosen not to see; it never
/// promotes or reorders them, so the most serious warning is always first.
final alertsProvider = FutureProvider<List<SafetyAlert>>((ref) async {
  final beach = await ref.watch(selectedBeachProvider.future);
  final alerts = await ref.watch(repositoryProvider).getAlerts(beach.id);
  final filter = ref.watch(settingsProvider).alertFilter;
  return alerts
      .where((a) => filter.allows(a.riskLevel))
      .toList(growable: false);
});

/// Every alert for the selected beach, ignoring the severity filter. Used
/// where hiding one would be misleading rather than helpful.
final unfilteredAlertsProvider = FutureProvider<List<SafetyAlert>>((ref) async {
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
