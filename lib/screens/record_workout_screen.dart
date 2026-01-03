import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workouts_provider.dart';
import '../model/session_log.dart';
import '../model/set_log.dart';
import '../model/exercise_day_log.dart';

class RecordWorkoutScreen extends ConsumerStatefulWidget {
  const RecordWorkoutScreen({
    super.key,
    required this.workoutName,
  });

  final String workoutName;

  @override
  ConsumerState<RecordWorkoutScreen> createState() => _RecordWorkoutScreenState();
}

class _RecordWorkoutScreenState extends ConsumerState<RecordWorkoutScreen> {
  int _exerciseIndex = 0;

  final Map<String, List<SetDraft>> _drafts = {};
  final Map<String, double?> _defaults = {};
  final Map<String, Map<String, List<SetDraft>>> _draftsByDate = {};
  final Map<String, int> _exerciseIndexByDate = {};
  late DateTime _activeDate;
  late final DateTime _today;

  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _today = DateTime(now.year, now.month, now.day);
    _activeDate = _today;
  }

  bool get _canGoPrev => true; // always can go back
  bool get _canGoNext => !_activeDate.isAtSameMomentAs(_today);
  String get _activeIso => _dateIso(_activeDate);

  Future<void> _goPrev(String workoutName, List<String> exercises) async 
  {
    _stashActiveDrafts();
    _activeDate = _activeDate.subtract(const Duration(days: 1));
    await _loadForDate(workoutName, exercises);
  }

  Future<void> _goNext(String workoutName, List<String> exercises) async 
  {
    if (!_canGoNext) return;
    _stashActiveDrafts();
    _activeDate = _activeDate.add(const Duration(days: 1));
    await _loadForDate(workoutName, exercises);
  }

  Future<void> _loadForDate(String workoutName, List<String> exercises) async {
    // 1) If we already have this date in cache, restore it and exit.
    if (_draftsByDate.containsKey(_activeIso)) {
      _restoreDraftsForActiveDate(exercises: exercises);
      if (mounted) setState(() {});
      return;
    }

    final db = ref.read(localDbProvider);
    final dateIso = _activeIso;

    // 2) Dispose current controllers + clear active drafts
    for (final sets in _drafts.values) {
      for (final d in sets) {
        d.dispose();
      }
    }
    _drafts.clear();

    // 3) Load per-exercise defaults + logs for this date
    for (final ex in exercises) {
      _defaults[ex] = await db.getDefaultWeightForExercise(ex);

      final existing = await db.getExerciseLogForDay(
        exerciseName: ex,
        dateIso: dateIso,
      );

      final savedSets = existing?.sets ?? const <SetLog>[];
      if (savedSets.isNotEmpty) {
        _drafts[ex] = savedSets.map(SetDraft.fromSetLog).toList();
      } else {
        _drafts[ex] = <SetDraft>[]; // ✅ blank date => no sets by default
      }
    }

    // Clamp exercise index
    if (exercises.isNotEmpty) {
      _exerciseIndex = _exerciseIndex.clamp(0, exercises.length - 1);
    } else {
      _exerciseIndex = 0;
    }

    // 4) Cache what we loaded so scrolling away/back preserves state
    _stashActiveDrafts();

    if (mounted) setState(() {});
  }

  String _dateIso(DateTime d) 
  {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> _pickDate(String workoutName, List<String> exercises) async 
  {
    final picked = await showDatePicker(
      context: context,
      initialDate: _activeDate,
      firstDate: DateTime(2000, 1, 1),
      lastDate: _today, // keep consistent with arrow behavior
    );

    if (picked == null) return;

    final normalized = DateTime(picked.year, picked.month, picked.day);

    if (normalized == _activeDate) return;

    setState(() 
    {
      _activeDate = normalized;
    });

    await _loadForDate(workoutName, exercises);
  }

  void _stashActiveDrafts()
  {
    final copied = <String, List<SetDraft>>{};
    _drafts.forEach((exercise, sets)
    {
      copied[exercise] = sets.map((s) => s.clone()).toList();
    });

    _draftsByDate[_activeIso] = copied;
    _exerciseIndexByDate[_activeIso] = _exerciseIndex;
  }

  void _restoreDraftsForActiveDate({required List<String> exercises})
  {
    final cached = _draftsByDate[_activeIso];
    if (cached == null) return;

    for (final sets in _drafts.values) {
      for (final d in sets) {
        d.dispose();
      }
    }
    _drafts.clear();

    for (final ex in exercises) {
      final sets = cached[ex] ?? <SetDraft>[];
      _drafts[ex] = sets.map((s) => s.clone()).toList();
    }

    _exerciseIndex = (_exerciseIndexByDate[_activeIso] ?? 0)
      .clamp(0, exercises.length - 1);
  }

  void _clearAllCachedDrafts() {
    for (final sets in _drafts.values) {
      for (final d in sets) {
        d.dispose();
      }
    }
    _drafts.clear();

    for (final perDate in _draftsByDate.values) {
      for (final sets in perDate.values) {
        for (final d in sets) {
          d.dispose();
        }
      }
    }
    _draftsByDate.clear();
    _exerciseIndexByDate.clear();
  }

  @override
  Widget build(BuildContext context) 
  {
    final workouts = ref.watch(workoutsProvider).value ?? const [];
    final idx = workouts.indexWhere((w) => w.name == widget.workoutName);

    if (idx == -1) 
    {
      return const Scaffold(body: Center(child: Text('Workout not found.')));
    }

    final workout = workouts[idx];
    final exercises = workout.exercises;

    if (exercises.isEmpty) 
    {
      return const Scaffold(body: Center(child: Text('Workout has no exercises.')));
    }

    if (!_initialized) 
    {
      _initialized = true;
      _loadForDate(workout.name, exercises);
    }

    final currentExercise = exercises[_exerciseIndex];
    final currentSets = _drafts.putIfAbsent(currentExercise, () => <SetDraft>[]);

    return Scaffold(
      appBar: AppBar(
        title: Text('Record • ${workout.name}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () {
            _clearAllCachedDrafts();
            Navigator.of(context).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => _saveAll(workout.name),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _goPrev(workout.name, exercises),
                tooltip: 'Previous day',
              ),
              Expanded(
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _pickDate(workout.name, exercises),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Text(
                        _dateIso(_activeDate),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _canGoNext ? () => _goNext(workout.name, exercises) : null,
                tooltip: 'Next day',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Exercise pager header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _exerciseIndex > 0
                    ? () => setState(() => _exerciseIndex--)
                    : null,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      currentExercise,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_exerciseIndex + 1} / ${exercises.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _exerciseIndex < exercises.length - 1
                    ? () => setState(() => _exerciseIndex++)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Add set row
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Sets',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                tooltip: 'Add set',
                onPressed: () {
                  setState(() {
                    currentSets.add(
                      SetDraft.withDefaultWeight(_defaults[currentExercise]),
                    );
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (currentSets.isEmpty)
            const Text('No sets yet. Tap + to add one.')
          else
            ...currentSets.asMap().entries.map((entry) {
              final setIndex = entry.key;
              final set = entry.value;

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Bodyweight'),
                              value: set.isBodyweight,
                              onChanged: (v) {
                                setState(() {
                                  set.isBodyweight = v;
                                  if (v) {
                                    set.weightController.text = '';
                                  } else {
                                    // Restore default if empty
                                    if (set.weightController.text.trim().isEmpty) {
                                      final d = _defaults[currentExercise];
                                      if (d != null) {
                                        set.weightController.text = d.toString();
                                      }
                                    }
                                  }
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Remove set',
                            onPressed: () {
                              setState(() => currentSets.removeAt(setIndex));
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: set.weightController,
                        enabled: !set.isBodyweight,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Weight'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: set.fullRepsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Full reps', hintText: '0'),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: set.partialRepsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(labelText: 'Partial reps', hintText: '0'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _initForWorkout(String workoutName, List<String> exercises) async {
    final db = ref.read(localDbProvider);
    final today = _dateIso(_activeDate);

    // Load today's existing session (if any)
    final existing = await db.getSessionForDay(
      workoutName: workoutName,
      dateIso: today,
    );

    for (final ex in exercises) {
      _defaults[ex] = await db.getDefaultWeightForExercise(ex);

      // If we already logged today, use those sets
      final savedSets = existing?.byExercise[ex] ?? const <SetLog>[];
      if (savedSets.isNotEmpty) {
        _drafts[ex] = savedSets.map(SetDraft.fromSetLog).toList();
      } else {
        _drafts.putIfAbsent(ex, () => <SetDraft>[]);
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveAll(String workoutName) async {
    // Ensure current active date edits are included
    _stashActiveDrafts();

    final db = ref.read(localDbProvider);

    // Save every cached date
    for (final dateEntry in _draftsByDate.entries) {
      final dateIso = dateEntry.key; // YYYY-MM-DD
      final perExerciseDrafts = dateEntry.value; // exerciseName -> List<SetDraft>

      for (final exEntry in perExerciseDrafts.entries) {
        final exerciseName = exEntry.key;
        final drafts = exEntry.value;

        // Convert UI drafts to SetLog (empty list allowed)
        final sets = drafts.map((d) => d.toSetLog()).toList();

        final log = ExerciseDayLog(
          exerciseKey: db.exerciseKey(exerciseName),
          exerciseName: exerciseName,
          dateIso: dateIso,
          workoutName: workoutName, // metadata
          sets: sets,
        );

        await db.upsertExerciseLog(log);

        // Update default weight for this exercise = max weight used in this log
        double? maxWeight;
        for (final s in sets) {
          if (!s.isBodyweight && s.weight != null) {
            if (maxWeight == null || s.weight! > maxWeight) {
              maxWeight = s.weight;
            }
          }
        }
        if (maxWeight != null) {
          await db.setDefaultWeightForExercise(exerciseName, maxWeight);
          _defaults[exerciseName] = maxWeight; // keep in-memory defaults in sync
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    // Dispose controllers we created
    for (final sets in _drafts.values) {
      for (final d in sets) {
        d.dispose();
      }
    }
    super.dispose();
  }
}

class SetDraft {
  bool isBodyweight;
  final TextEditingController weightController;
  final TextEditingController fullRepsController;
  final TextEditingController partialRepsController;

  SetDraft({
    required this.isBodyweight,
    required this.weightController,
    required this.fullRepsController,
    required this.partialRepsController,
  });

  SetDraft clone() {
    return SetDraft(
      isBodyweight: isBodyweight,
      weightController: TextEditingController(text: weightController.text),
      fullRepsController: TextEditingController(text: fullRepsController.text),
      partialRepsController: TextEditingController(text: partialRepsController.text),
    );
  }

  factory SetDraft.fromSetLog(SetLog log) {
    return SetDraft(
      isBodyweight: log.isBodyweight,
      weightController: TextEditingController(
        text: (log.isBodyweight || log.weight == null) ? '' : log.weight.toString(),
      ),
      fullRepsController: TextEditingController(text: log.fullReps.toString()),
      partialRepsController: TextEditingController(text: log.partialReps.toString()),
    );
  }

  factory SetDraft.withDefaultWeight(double? defaultWeight) {
    return SetDraft(
      isBodyweight: false,
      weightController: TextEditingController(
        text: defaultWeight == null ? '' : defaultWeight.toString(),
      ),
      fullRepsController: TextEditingController(text: ''),
      partialRepsController: TextEditingController(text: ''),
    );
  }

  SetLog toSetLog() {
    int parseIntOrZero(String s) {
      final t = s.trim();
      if (t.isEmpty) return 0;
      return int.tryParse(t) ?? 0;
    }

    final full = parseIntOrZero(fullRepsController.text);
    final partial = parseIntOrZero(partialRepsController.text);
    final weight = double.tryParse(weightController.text.trim());

    return SetLog(
      isBodyweight: isBodyweight,
      weight: isBodyweight ? null : weight,
      fullReps: full,
      partialReps: partial,
    );
  }

  void dispose() {
    weightController.dispose();
    fullRepsController.dispose();
    partialRepsController.dispose();
  }
}