// lists workouts + "+" create

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
          return ReorderableListView.builder(
            buildDefaultDragHandles: false,
            itemCount: workouts.length,
            onReorder: (oldIndex, newIndex) {
              if (newIndex > oldIndex) newIndex -= 1;

              ref.read(workoutsProvider.notifier).reorderWorkouts(oldIndex, newIndex);
            },
            itemBuilder: (context, i) {
              final workout = workouts[i];

              return Column(
                key: ValueKey(workout.name),
                children: [
                  WorkoutSwipeTile(
                    workout: workout,
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_handle),
                    ),
                    onOpenDetails: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => RecordWorkoutScreen(workoutName: workout.name),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
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