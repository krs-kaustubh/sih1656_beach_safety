// File: lib/alerts/escalation.dart
// Description: Pure logic deciding when a beach's change in risk rating is worth alerting the user about, independent of how the alert is delivered.

import '../models/risk_level.dart';

// An ordering for risk levels, so two ratings can be compared.
//
// RiskLevel deliberately has no natural ordering of its own — it is a display
// vocabulary — so the rank lives here, next to the only code that needs it.
int _rank(RiskLevel level) => switch (level) {
      RiskLevel.low => 0,
      RiskLevel.moderate => 1,
      RiskLevel.high => 2,
    };

// Whether a move from [previous] to [current] should alert the user.
//
// Only escalation to high counts. Three cases are deliberately silent:
//
//  * No previous rating. The first reading after launch is not a change, and
//    treating it as one would fire an alert every cold start on a beach that
//    has been dangerous all day.
//  * De-escalation. Conditions improving is good news, not an alert.
//  * Staying at high. Re-firing on every refresh would train the user to
//    ignore the alert, which is the opposite of what it is for.
//
// A jump straight from low to high alerts, even though the user never saw
// moderate: the point is the arrival at dangerous, not the step size.
bool shouldAlert({
  required RiskLevel? previous,
  required RiskLevel current,
}) {
  if (previous == null) return false;
  if (current != RiskLevel.high) return false;
  return _rank(current) > _rank(previous);
}

// Tracks the last rating seen per beach, so escalation can be detected across
// refreshes. Keyed by beach id because the user can switch beaches, and each
// one's history has to stay its own.
class EscalationTracker {
  final Map<int, RiskLevel> _lastSeen = {};

  // Records [current] for [beachId] and reports whether it escalated.
  //
  // Always records, including when it returns false, so the *next* call
  // compares against what was actually last seen.
  bool record(int beachId, RiskLevel current) {
    final previous = _lastSeen[beachId];
    _lastSeen[beachId] = current;
    return shouldAlert(previous: previous, current: current);
  }

  RiskLevel? lastSeen(int beachId) => _lastSeen[beachId];

  void reset() => _lastSeen.clear();
}
