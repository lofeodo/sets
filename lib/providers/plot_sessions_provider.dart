import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../model/exercise_day_log.dart';
import '../model/session_log.dart';
import 'exercise_logs_provider.dart';

final plotSessionsProvider = FutureProvider<List<SessionLog>>((ref) async {
  final logs = await ref.watch(exerciseLogsProvider.future);

  final map = <String, SessionLog>{}; // "$workout|$date"

  for (final log in logs) {
    final key = '${log.workoutName}|${log.dateIso}';
    final existing = map[key];

    if (existing == null) {
      map[key] = SessionLog(
        workoutName: log.workoutName,
        dateIso: log.dateIso,
        byExercise: { log.exerciseName: [...log.sets] },
      );
    } else {
      final list = existing.byExercise.putIfAbsent(log.exerciseName, () => []);
      list.addAll(log.sets);
    }
  }

  final sessions = map.values.toList();
  sessions.sort((a, b) => a.dateIso.compareTo(b.dateIso));
  return sessions;
});