// File: lib/alerts/escalation_providers.dart
// Description: Riverpod wiring that watches the selected beach's rating and dispatches an alert through the user's chosen channel when it escalates to high risk.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/beach.dart';
import '../models/risk_level.dart';
import '../settings/app_settings.dart';
import '../settings/settings_providers.dart';
import '../state/providers.dart';
import 'alert_dispatcher.dart';
import 'escalation.dart';

// Overridden in tests with a recording dispatcher.
final alertDispatcherProvider =
    Provider<AlertDispatcher>((ref) => ChannelAlertDispatcher());

// Remembers the last rating seen per beach for the life of the app.
final escalationTrackerProvider = Provider<EscalationTracker>(
  (ref) => EscalationTracker(),
);

// Watches the selected beach and alerts when its rating rises to high.
//
// This runs in the foreground only: it reacts to beach data the app has just
// loaded, so nothing fires while the app is closed. Background delivery would
// need a scheduled worker and a publicly reachable backend.
class EscalationWatcher extends Notifier<RiskLevel?> {
  @override
  RiskLevel? build() {
    // ref.listen, not ref.watch: dispatching an alert is a side effect, and
    // Riverpod forbids those during build. The listener runs after the build
    // settles, which is also when the new rating is actually on screen.
    ref.listen<AsyncValue<Beach>>(selectedBeachProvider, (_, next) {
      final beach = next.value;
      if (beach == null) return;
      state = beach.riskLevel;
      _handle(beach);
    });

    return null;
  }

  void _handle(Beach beach) {
    final tracker = ref.read(escalationTrackerProvider);
    final escalated = tracker.record(beach.id, beach.riskLevel);
    if (!escalated) return;

    final settings = ref.read(settingsProvider);
    if (!settings.canDeliverAlerts) return;

    // Deliberately not awaited: a slow gateway must not stall a rebuild, and
    // a failed send is reported by the dispatcher rather than thrown.
    ref.read(alertDispatcherProvider).send(
          EscalationMessage.forBeach(beach),
          settings,
        );
  }
}

final escalationWatcherProvider =
    NotifierProvider<EscalationWatcher, RiskLevel?>(EscalationWatcher.new);

// Sends a sample alert, so the user can confirm the setup works without
// waiting for the sea to turn dangerous.
Future<bool> sendTestAlert({
  required AlertDispatcher dispatcher,
  required AppSettings settings,
}) {
  if (!settings.canDeliverAlerts) return Future.value(false);

  return dispatcher.send(
    const EscalationMessage(
      title: 'Lehar test alert',
      body: 'Your alerts are set up correctly. This is not a safety warning.',
    ),
    settings,
  );
}
