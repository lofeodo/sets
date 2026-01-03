import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/workout.dart';
import '../model/session_log.dart';
import '../model/exercise_day_log.dart';

class LocalDb 
{
  static const String _keyWorkouts = 'workouts_v1';
  static const String _keySessions = 'sessions_v1';
  static const String _keyExerciseLogs = 'exercise_logs_v1';
  static const String _keyExerciseDefaults = 'exercise_defaults_v2';

  String exerciseKey(String name) => name.trim().toLowerCase();

  Future<List<Workout>> loadWorkouts() async
  {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyWorkouts);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
  if (decoded is! List) return const [];

  return decoded
    .whereType<Map<String, dynamic>>()
    .map(Workout.fromJson)
    .toList();
  }

  Future<List<ExerciseDayLog>> loadExerciseLogs() async 
  {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyExerciseLogs);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ExerciseDayLog.fromJson)
        .toList();
  }

  Future<void> saveExerciseLogs(List<ExerciseDayLog> logs) async 
  {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(logs.map((l) => l.toJson()).toList());
    await prefs.setString(_keyExerciseLogs, raw);
  }

  Future<ExerciseDayLog?> getExerciseLogForDay({
    required String exerciseName,
    required String dateIso,
  }) async 
  {
    final key = exerciseKey(exerciseName);
    final logs = await loadExerciseLogs();
    for (final l in logs.reversed) {
      if (l.exerciseKey == key && l.dateIso == dateIso) return l;
    }
    return null;
  }

  Future<void> upsertExerciseLog(ExerciseDayLog log) async 
  {
    final logs = await loadExerciseLogs();

    final idx = logs.indexWhere(
      (l) => l.exerciseKey == log.exerciseKey && l.dateIso == log.dateIso,
    );

    final updated = [...logs];
    if (idx == -1) {
      updated.add(log);
    } else {
      updated[idx] = log;
    }

    await saveExerciseLogs(updated);
  }

  Future<void> saveWorkouts(List<Workout> workouts) async
  {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(workouts.map((w) => w.toJson()).toList());
    await prefs.setString(_keyWorkouts, raw);
  }

  Future<List<SessionLog>> loadSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keySessions);
    if (raw == null || raw.isEmpty) return const [];

    final decoded = jsonDecode(raw);
    if (decoded is! List) return const [];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SessionLog.fromJson)
        .toList();
  }

  Future<void> appendSession(SessionLog session) async {
    final sessions = await loadSessions();
    final updated = [...sessions, session];

    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(updated.map((s) => s.toJson()).toList());
    await prefs.setString(_keySessions, raw);
  }

  String _defaultKey(String workoutName, String exerciseName) =>
      '${workoutName.toLowerCase()}|${exerciseName.toLowerCase()}';

  Future<Map<String, double>> loadExerciseDefaults() async 
  {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyExerciseDefaults);
    if (raw == null || raw.isEmpty) return {};

    final decoded = jsonDecode(raw);
    if (decoded is! Map) return {};

    final out = <String, double>{};
    decoded.forEach((k, v) {
      if (k is String && v is num) out[k] = v.toDouble();
    });
    return out;
  }

  Future<void> saveExerciseDefaults(Map<String, double> map) async 
  {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExerciseDefaults, jsonEncode(map));
  }

  Future<double?> getDefaultWeightForExercise(String exerciseName) async 
  {
    final map = await loadExerciseDefaults();
    return map[exerciseKey(exerciseName)];
  }

  Future<void> setDefaultWeightForExercise(String exerciseName, double weight) async 
  {
    final map = await loadExerciseDefaults();
    map[exerciseKey(exerciseName)] = weight;
    await saveExerciseDefaults(map);
  }

  Future<SessionLog?> getSessionForDay({
    required String workoutName,
    required String dateIso,
  }) async {
    final sessions = await loadSessions();
    for (final s in sessions.reversed) {
      if (s.workoutName == workoutName && s.dateIso == dateIso) {
        return s;
      }
    }
    return null;
  }

  Future<void> upsertSession(SessionLog session) async {
    final sessions = await loadSessions();

    final idx = sessions.indexWhere(
      (s) => s.workoutName == session.workoutName && s.dateIso == session.dateIso,
    );

    final updated = [...sessions];
    if (idx == -1) {
      updated.add(session);
    } else {
      updated[idx] = session;
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(updated.map((s) => s.toJson()).toList());
    await prefs.setString(_keySessions, raw);
  }
}