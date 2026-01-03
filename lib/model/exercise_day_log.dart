import 'set_log.dart';

class ExerciseDayLog 
{
  final String exerciseKey;   // normalized (lowercase)
  final String exerciseName;  // display
  final String dateIso;       // YYYY-MM-DD

  final String workoutKey;    // normalized (lowercase workout name)
  final String workoutName;   // display

  final List<SetLog> sets;

  const ExerciseDayLog({
    required this.exerciseKey,
    required this.exerciseName,
    required this.dateIso,
    required this.workoutKey,
    required this.workoutName,
    required this.sets,
  });

  Map<String, dynamic> toJson() => {
        'exerciseKey': exerciseKey,
        'exerciseName': exerciseName,
        'dateIso': dateIso,
        'workoutKey': workoutKey,
        'workoutName': workoutName,
        'sets': sets.map((s) => s.toJson()).toList(),
      };

  factory ExerciseDayLog.fromJson(Map<String, dynamic> json) 
  {
    final rawSets = json['sets'];

    final workoutName = (json['workoutName'] as String?) ?? '';
    final workoutKey =
        (json['workoutKey'] as String?) ?? workoutName.trim().toLowerCase();

    return ExerciseDayLog(
      exerciseKey: json['exerciseKey'] as String,
      exerciseName: (json['exerciseName'] as String?) ?? (json['exerciseKey'] as String),
      dateIso: json['dateIso'] as String,
      workoutKey: workoutKey,
      workoutName: workoutName,
      sets: (rawSets is List)
          ? rawSets.whereType<Map<String, dynamic>>().map(SetLog.fromJson).toList()
          : const [],
    );
  }
}