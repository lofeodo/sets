// lists workouts + "+" create

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workouts_provider.dart';
import 'workout_form_screen.dart';
import 'workout_details_screen.dart';

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
              return ListTile(
                title: Text(workout.name),
                subtitle: Text('${workout.exercises.length} exercises'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: ()
                  {
                    ref.read(workoutsProvider.notifier).deleteWorkout(workout.name);
                  },
                ),
                onTap: () 
                {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WorkoutDetailsScreen(workoutName: workout.name),
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
            MaterialPageRoute(builder: (_) => const WorkoutFormScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}