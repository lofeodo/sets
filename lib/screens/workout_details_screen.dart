import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workouts_provider.dart';

class WorkoutDetailsScreen extends ConsumerWidget
{
  const WorkoutDetailsScreen({
    super.key,
    required this.workoutName,
  });

  final String workoutName;

  @override
  Widget build(BuildContext context, WidgetRef ref)
  {
    final workoutsAsync = ref.watch(workoutsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(workoutName)),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workouts) {
          final idx = workouts.indexWhere((w) => w.name == workoutName);
          if (idx == -1)
          {
            return const Center(child: Text('Workout not found.'));
          }

          final workout = workouts[idx];
          final exercises = workout.exercises;

          if (workout is _MissingWorkout) 
          {
            return const Center(child: Text('Workout not found.'));
          }

          if (exercises.isEmpty)
          {
            return const Center(child: Text('No exercises.'));
          }

          return ListView.separated(
            itemCount: exercises.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i){
              return ListTile(
                title: Text(exercises[i]),
              );
            },
          );
        },
      ),
    );
  }
}

class _MissingWorkout {
  const _MissingWorkout();
  List<String> get exercises => const [];
}