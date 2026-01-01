import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workouts_provider.dart';

class CreateWorkoutScreen extends ConsumerStatefulWidget
{
  const CreateWorkoutScreen({super.key});

  @override
  ConsumerState<CreateWorkoutScreen> createState() => _CreateWorkoutScreenState();
}

class _CreateWorkoutScreenState extends ConsumerState<CreateWorkoutScreen>
{
  final _workoutNameController = TextEditingController();
  final List<String> _exercises = [];

  @override
  void dispose()
  {
    _workoutNameController.dispose();
    super.dispose();
  }

  Future<void> _addExerciseDialog() async
  {
    final controller = TextEditingController();

    final result = await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add exercise'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Exercise name'),
          onSubmitted: (_) => Navigator.of(context).pop(controller.text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == null) return;

    final name = result.trim();
    if (name.isEmpty) return;

    final exists = _exercises.any((e) => e.toLowerCase() == name.toLowerCase());
    if (exists)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Exercise already added.')),
      );
      return;
    }

    setState(() => _exercises.add(name));
  }

  Future<void> _saveWorkout() async
  {
    final error = await ref.read(workoutsProvider.notifier).addWorkout(
      rawName: _workoutNameController.text,
      rawExercises: _exercises,
    );

    if (!mounted) return;

    if (error != null)
    {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New workout'),
        actions: [
          TextButton(
            onPressed: _saveWorkout,
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _workoutNameController,
            decoration: const InputDecoration(
              labelText: 'Workout name',
              hintText: 'e.g. Push',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Exercises',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                onPressed: _addExerciseDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Add exercise',
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_exercises.isEmpty)
            const Text('Add at least one exercise.')
          else
            ..._exercises.asMap().entries.map((entry)
            {
              final index = entry.key;
              final name = entry.value;
              return Card(
                child: ListTile(
                  title: Text(name),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _exercises.removeAt(index)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}