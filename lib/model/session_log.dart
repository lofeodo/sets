import 'set_log.dart';

class SessionLog {
  final String workoutName;
  final String dateIso; // e.g. 2025-12-31
  final Map<String, List<SetLog>> byExercise; // exercise -> list of sets

  const SessionLog({
    required this.workoutName,
    required this.dateIso,
    required this.byExercise,
  });

  Map<String, dynamic> toJson() => {
        'workoutName': workoutName,
        'dateIso': dateIso,
        'byExercise': byExercise.map(
          (k, v) => MapEntry(k, v.map((s) => s.toJson()).toList()),
        ),
      };

  factory SessionLog.fromJson(Map<String, dynamic> json) {
    final raw = json['byExercise'];
    final Map<String, List<SetLog>> parsed = {};

    if (raw is Map<String, dynamic>) {
      for (final entry in raw.entries) {
        final list = entry.value;
        if (list is List) {
          parsed[entry.key] = list
              .whereType<Map<String, dynamic>>()
              .map(SetLog.fromJson)
              .toList();
        }
      }
    }

    return SessionLog(
      workoutName: json['workoutName'] as String,
      dateIso: json['dateIso'] as String,
      byExercise: parsed,
    );
  }
}