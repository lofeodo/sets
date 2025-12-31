import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/local_db.dart';
import '../model/workout.dart';


// provide the local database (persistence layer)
final localDbProvider = Provider<LocalDb>((ref) => LocalDb());

// expose the list of workouts to the ui (loading/error/data)
final workoutsProvider = 
  StateNotifierProvider<WorkoutsController, AsyncValue<List<Workout>>>((ref) => WorkoutsController(ref.read(localDbProvider)),
  );

class WorkoutsController extends StateNotifier<AsyncValue<List<Workout>>>
{
  WorkoutsController(this._db) : super(const AsyncValue.loading())
  {
    _init();
  }

  final LocalDb _db;

  Future<void> _init() async
  {
    try
    {
      final workouts = await _db.loadWorkouts();
      state = AsyncValue.data(workouts);
    }
    catch (e, st)
    {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> addWorkout(String rawName) async
  {
    final name = rawName.trim();
    if (name.isEmpty) return 'Name cannot be empty.';

    final current = state.value ?? const [];
    final exists = current.any(
      (w) => w.name.toLowerCase() == name.toLowerCase(),
      );

    if (exists) return 'Workout name must be unique.';

    final updated = [...current, Workout(name: name)];
    state = AsyncValue.data(updated);

    await _db.saveWorkouts(updated);
    return null;
  }

  Future<void> deleteWorkout(String name) async
  {
    final current = state.value ?? const [];
    final updated = current.where((w) => w.name != name).toList();
    state = AsyncValue.data(updated);
    await _db.saveWorkouts(updated);
  }
}