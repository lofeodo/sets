import 'set_log.dart';

class ExerciseDayLog 
{
  final String exerciseKey; // normalized (lowercased) name
  final String exerciseName; // display name (as typed first time)
  final String dateIso; // YYYY-MM-DD
  final String? workoutName; // optional metadata
  final List<SetLog> sets;

  const ExerciseDayLog({
    required this.exerciseKey,
    required this.exerciseName,
    required this.dateIso,
    required this.sets,
    this.workoutName,
  });

  Map<String, dynamic> toJson() => {
        'exerciseKey': exerciseKey,
        'exerciseName': exerciseName,
        'dateIso': dateIso,
        'workoutName': workoutName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseDayLog.fromJson(Map<String, dynamic> json) 
  {
    final rawSets = json['sets'];
    return ExerciseDayLog(
      exerciseKey: json['exerciseKey'] as String,
      exerciseName: (json['exerciseName'] as String?) ?? (json['exerciseKey'] as String),
      dateIso: json['dateIso'] as String,
      workoutName: json['workoutName'] as String?,
      sets: (rawSets is List)
          ? rawSets.whereType<Map<String, dynamic>>().map(SetLog.fromJson).toList()
          : const [],
    );
  }
}