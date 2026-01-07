// lists workouts + "+" create

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_slidable/flutter_slidable.dart';
import '../providers/workouts_provider.dart';
import 'workout_creation_screen.dart';
import 'record_workout_screen.dart';
import '../widgets/workout_swipe_tile.dart';

class WorkoutsScreen extends ConsumerWidget
{
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref)
  {
    final workoutsAsync = ref.watch(workoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Workouts')),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workouts)
        {
          if (workouts.isEmpty)
          {
            return const Center(child: Text('No workouts yet.'));
          }

          return ListView.separated(
            itemCount: workouts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i)
            {
              final workout = workouts[i];
              return WorkoutSwipeTile(
                workout: workout,
                onOpenDetails: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RecordWorkoutScreen(workoutName: workout.name),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WorkoutCreationScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}