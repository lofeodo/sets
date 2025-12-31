// lists workouts + "+" create

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workouts_provider.dart';

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
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: ()
                  {
                    ref.read(workoutsProvider.notifier).deleteWorkout(workout.name);
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddWorkoutDialog(context, ref),
        child: const Icon(Icons.add),
        ),
    );
  }

  Future<void> _showAddWorkoutDialog(BuildContext context, WidgetRef ref) async
  {
    final textController = TextEditingController();

    final name = await showDialog<String?>(
      context: context,
      builder: (context)
      {
        return AlertDialog(
          title: const Text('New workout'),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Workout name'),
            onSubmitted: (_) =>
              Navigator.of(context).pop(textController.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                Navigator.of(context).pop(textController.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (name == null) return;

    final error = await ref.read(workoutsProvider.notifier).addWorkout(name);

    if (!context.mounted) return;
    if (error != null)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
    }
  }
}