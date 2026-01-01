import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workouts_provider.dart';
import '../model/workout.dart';

class WorkoutFormScreen extends ConsumerStatefulWidget {
  const WorkoutFormScreen({
    super.key,
    this.initialWorkout, // null = create, non-null = edit
  });

  final Workout? initialWorkout;

  bool get isEdit => initialWorkout != null;

  @override
  ConsumerState<WorkoutFormScreen> createState() => _WorkoutFormScreenState();
}

class _WorkoutFormScreenState extends ConsumerState<WorkoutFormScreen> {
  late final TextEditingController _workoutNameController;
  late final List<String> _exercises;

  @override
  void initState() {
    super.initState();
    _workoutNameController = TextEditingController(
      text: widget.initialWorkout?.name ?? '',
    );
    _exercises = [...(widget.initialWorkout?.exercises ?? const <String>[])];
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final notifier = ref.read(workoutsProvider.notifier);

    final error = widget.isEdit
        ? await notifier.updateWorkout(
            originalName: widget.initialWorkout!.name,
            rawName: _workoutNameController.text,
            rawExercises: _exercises,
          )
        : await notifier.addWorkout(
            rawName: _workoutNameController.text,
            rawExercises: _exercises,
          );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _addExerciseDialog() async {
    final controller = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void tryAdd() {
              final name = controller.text.trim();
              if (name.isEmpty) {
                setDialogState(() => errorText = 'Name cannot be empty.');
                return;
              }
              final exists = _exercises.any(
                (e) => e.toLowerCase() == name.toLowerCase(),
              );
              if (exists) {
                setDialogState(() => errorText = 'Exercise already added.');
                return;
              }
              setState(() => _exercises.add(name));
              Navigator.of(dialogContext).pop();
            }

            return AlertDialog(
              title: const Text('Add exercise'),
              content: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Exercise name',
                  errorText: errorText,
                ),
                onSubmitted: (_) => tryAdd(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: tryAdd,
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Edit workout' : 'New workout';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(
            onPressed: _save,
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
            ..._exercises.asMap().entries.map((entry) {
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