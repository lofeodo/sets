import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/local_db_provider.dart';
import '../providers/workouts_provider.dart';
import '../model/workout.dart';
import '../ui/add_exercise_sheet.dart';
import '../ui/confirm_destructive_sheet.dart';

class WorkoutCreationScreen extends ConsumerStatefulWidget 
{
  const WorkoutCreationScreen({
    super.key,
    this.initialWorkout, // null = create, non-null = edit
  });

  final Workout? initialWorkout;

  bool get isEdit => initialWorkout != null;

  @override
  ConsumerState<WorkoutCreationScreen> createState() => _WorkoutCreationScreenState();
}

class _WorkoutCreationScreenState extends ConsumerState<WorkoutCreationScreen> {
  late final TextEditingController _workoutNameController;
  late final List<String> _exercises;
  List<String> _exerciseSuggestions = const [];
  bool _loadingExerciseSuggestions = false;

  @override
  void initState() 
  {
    super.initState();
    _workoutNameController = TextEditingController(
      text: widget.initialWorkout?.name ?? '',
    );
    _exercises = [...(widget.initialWorkout?.exercises ?? const <String>[])];
    _loadExerciseSuggestions();
  }

  Future<void> _loadExerciseSuggestions() async 
  {
    setState(() => _loadingExerciseSuggestions = true);

    final db = ref.read(localDbProvider);
    final list = await db.getAllExerciseNames();

    if (!mounted) return;
    setState(() {
      _exerciseSuggestions = list;
      _loadingExerciseSuggestions = false;
    });
  }

  @override
  void dispose() {
    _workoutNameController.dispose();
    super.dispose();
  }

  bool get _isDirty
  {
    final name = _workoutNameController.text.trim();
    final initial = widget.initialWorkout;

    // Create mode
    if (initial == null)
    {
      return name.isNotEmpty || _exercises.isNotEmpty;
    }

    // Edit mode
    final initialName = initial.name.trim();
    final initialExercises = initial.exercises.map((e) => e.trim()).toList();

    if (name != initialName) return true;
    if (_exercises.length != initialExercises.length) return true;

    for (int i = 0; i < _exercises.length; i++)
    {
      if (_exercises[i].trim() != initialExercises[i]) return true;
    }

    return false;
  }

  Future<void> _save() async 
  {
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

  Future<void> _addExerciseSheet() async
  {
    final alreadyAddedKeys = _exercises.map((e) => e.toLowerCase()).toSet();

    final name = await showAddExerciseSheet(
      context,
      suggestions: _exerciseSuggestions,
      alreadyAddedKeysLower: alreadyAddedKeys,
      loadingSuggestions: _loadingExerciseSuggestions
    );

    if (!mounted) return;

    if (name == null) return;

    setState(() => _exercises.add(name));
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEdit ? 'Edit workout' : 'New workout';

    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async
      {
        if (didPop) return;

        final ok = await showDestructiveConfirmSheet(
          context, 
          title: 'Discard changes?', 
          message: 'You have unsaved changes to this workout.', 
          confirmText: 'Discard',
        );

        if (ok && context.mounted)
        {
          Navigator.of(context).pop();
        }
      },
      child:Scaffold(
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
              textCapitalization: TextCapitalization.sentences,
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
                  onPressed: _addExerciseSheet,
                  icon: const Icon(Icons.add),
                  tooltip: 'Add exercise',
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_exercises.isEmpty)
              const Text('Add at least one exercise.')
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                buildDefaultDragHandles: false,
                itemCount: _exercises.length,
                onReorder: (oldIndex, newIndex)
                {
                  setState(()
                  {
                    if (newIndex > oldIndex) newIndex -= 1;
                    final item = _exercises.removeAt(oldIndex);
                    _exercises.insert(newIndex, item);
                  });
                },
                itemBuilder: (context, index)
                {
                  final name = _exercises[index];

                  return Card(
                    key: ValueKey(name),
                    child: ListTile(
                      title: Text(name),

                      // drag handle on the left
                      leading: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),

                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _exercises.removeAt(index)),
                      )
                    )
                  );
                },
              ),
          ],
        ),
      )
    );
  }
}