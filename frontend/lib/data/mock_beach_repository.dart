// File: lib/data/mock_beach_repository.dart
// Description: In-memory mock implementation of BeachRepository with configurable artificial latency for testing and demo modes.

import '../models/beach.dart';
import '../models/safety_alert.dart';
import 'beach_repository.dart';
import 'mock_data.dart';

// In-memory repository backed by MockData with simulated latency for loading states.
class MockBeachRepository implements BeachRepository {
  MockBeachRepository({this.latency = const Duration(milliseconds: 350)});

  final Duration latency;


  late final List<Beach> _beaches = MockData.beaches();
  late final List<SafetyAlert> _alerts = MockData.alerts();

  Future<T> _delayed<T>(T value) async {
    await Future<void>.delayed(latency);
    return value;
  }

  @override
  Future<List<Beach>> getBeaches() => _delayed(List.unmodifiable(_beaches));

  @override
  Future<Beach> getBeach(int id) async {
    final beach = _beaches.where((b) => b.id == id).firstOrNull;
    if (beach == null) {
      throw BeachRepositoryException('Beach $id was not found.');
    }
    return _delayed(beach);
  }

  @override
  Future<List<SafetyAlert>> getAlerts(int beachId) {
    final matching = _alerts.where((a) => a.beachId == beachId).toList()
      ..sort((a, b) => b.riskLevel.index.compareTo(a.riskLevel.index));
    return _delayed(List.unmodifiable(matching));
  }

  @override
  Future<SafetyAlert?> getAlert(String alertId) =>
      _delayed(_alerts.where((a) => a.id == alertId).firstOrNull);
}
