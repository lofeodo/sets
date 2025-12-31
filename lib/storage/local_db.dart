import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/workout.dart';

class LocalDb 
{
  static const String _keyWorkouts = 'workouts_v1';

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
}