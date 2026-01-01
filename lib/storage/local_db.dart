import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/workout.dart';
import '../model/session_log.dart';
import '../model/set_log.dart';

class LocalDb 
{
  static const String _keyWorkouts = 'workouts_v1';
  static const String _keySessions = 'sessions_v1';
  static const String _keyExerciseDefaults = 'exercise_defaults_v1';

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

  Future<Map<String, double>> loadExerciseDefaults() async {
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

  Future<void> saveExerciseDefaults(Map<String, double> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyExerciseDefaults, jsonEncode(map));
  }

  Future<double?> getDefaultWeight(String workoutName, String exerciseName) async {
    final map = await loadExerciseDefaults();
    return map[_defaultKey(workoutName, exerciseName)];
  }

  Future<void> setDefaultWeight(
    String workoutName,
    String exerciseName,
    double weight,
  ) async {
    final map = await loadExerciseDefaults();
    map[_defaultKey(workoutName, exerciseName)] = weight;
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