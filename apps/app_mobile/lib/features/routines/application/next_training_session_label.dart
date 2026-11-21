import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Presentational interpretation of a projected workout date.
///
/// A weekday marked as available for training does not prove the next
/// *projected session* occurs today. Use that session's actual date instead.
/// The program projector remains the authority; this helper never changes
/// rotation, dates, completions or saved training data.
class NextTrainingSessionLabel {
  const NextTrainingSessionLabel._();

  static String forSchedule({
    required DateTime? scheduledDate,
    required bool isFlexible,
    required DateTime now,
  }) {
    if (isFlexible) {
      return 'Rotación flexible · sin día obligatorio';
    }

    // An older/unscheduled continuous program can still provide a next
    // routine ID. Do not imply it has a concrete date.
    if (scheduledDate == null) {
      return 'Próxima sesión · fecha por definir';
    }

    final localDate = scheduledDate.toLocal();
    final localNow = now.toLocal();
    if (DateUtils.isSameDay(localDate, localNow)) {
      return 'Sesión programada para hoy';
    }
    return 'Próximo día: ${DateFormat('EEE d MMM', 'es').format(localDate)}';
  }
}
