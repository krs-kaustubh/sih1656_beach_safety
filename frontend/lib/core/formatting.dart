import 'package:intl/intl.dart';

import '../models/safety_alert.dart';

/// Formatting helpers so date and unit strings match the designs exactly and
/// live in one place rather than being rebuilt at each call site.
abstract final class Fmt {
  static final _clock = DateFormat('h:mm a');
  static final _tideClock = DateFormat('HH:mm');
  static final _hourOnly = DateFormat('h a');

  /// "6:42 AM" - header pill and alert timestamps.
  static String clock(DateTime time) => _clock.format(time);

  /// "09:45" - tide readout, which the designs show without a meridiem.
  static String tideClock(DateTime time) => _tideClock.format(time);

  /// "11 AM" - endpoints of a time window.
  static String hour(DateTime time) => _hourOnly.format(time);

  /// Trims a trailing ".0" so 2.8 stays "2.8" but 3.0 becomes "3".
  static String number(double value, {int decimals = 1}) {
    final text = value.toStringAsFixed(decimals);
    return text.endsWith('.0') ? text.substring(0, text.length - 2) : text;
  }

  /// UV index is shown as a whole number in the designs.
  static String uv(double value) => value.round().toString();

  /// The meta line under an alert title.
  ///
  /// Two shapes, driven by [SafetyAlert.timeStyle]:
  ///   "Issued 6:15 AM • South Shore"
  ///   "11 AM – 3 PM • Whole Coastline"
  static String alertMeta(SafetyAlert alert) {
    final time = switch (alert.timeStyle) {
      AlertTimeStyle.window when alert.validUntil != null =>
        '${hour(alert.issuedAt)} – ${hour(alert.validUntil!)}',
      _ => 'Issued ${clock(alert.issuedAt)}',
    };
    return alert.zoneLabel.isEmpty ? time : '$time  •  ${alert.zoneLabel}';
  }

  /// "Updated 6:15 AM  ·  Valid until 11:20 AM" on the detail header.
  static String alertValidity(SafetyAlert alert) {
    final updated = 'Updated ${clock(alert.issuedAt)}';
    if (alert.validUntil == null) return updated;
    return '$updated  ·  Valid until ${clock(alert.validUntil!)}';
  }
}
