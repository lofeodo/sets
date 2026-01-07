import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workouts_provider.dart';
import 'workout_creation_screen.dart';
import 'record_workout_screen.dart';

class WorkoutDetailsScreen extends ConsumerWidget {
  const WorkoutDetailsScreen({
    super.key,
    required this.workoutName,
  });

  final String workoutName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutsAsync = ref.watch(workoutsProvider);

    return workoutsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        body: Center(child: Text('Error: $e')),
      ),
      data: (workouts) {
        final idx = workouts.indexWhere((w) => w.name == workoutName);
        if (idx == -1) {
          return const Scaffold(
            body: Center(child: Text('Workout not found.')),
          );
        }

        final workout = workouts[idx];
        final exercises = workout.exercises;

        return Scaffold(
          appBar: AppBar(
            title: Text(workout.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutCreationScreen(initialWorkout: workout),
                    ),
                  );
                },
              ),
            ],
          ),
          body: exercises.isEmpty
              ? const Center(child: Text('No exercises.'))
              : ListView.separated(
                  itemCount: exercises.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => ListTile(
                    title: Text(exercises[i]),
                  ),
                ),
          floatingActionButton: FloatingActionButton(
            child: const Icon(Icons.fiber_manual_record),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RecordWorkoutScreen(workoutName: workout.name),
                ),
              );
            },
          ),
        );
      },
    );
  }
}