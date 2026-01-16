import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/exercise_logs_provider.dart';
import '../providers/local_db_provider.dart';
import '../providers/plot_sessions_provider.dart';
import '../providers/workouts_provider.dart';
import '../model/set_log.dart';
import '../model/exercise_day_log.dart';
import '../ui/confirm_destructive_sheet.dart';

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
  final Map<String, String> _baseline = {};
  final Set<String> _dirtyKeys = {};
  late DateTime _activeDate;
  late final DateTime _today;

  bool _initialized = false;

  bool get _isDirty => _dirtyKeys.isNotEmpty;

  String _k(String date, String exercise, int setIndex, String field) =>
    '$date|$exercise|$setIndex|$field';

  void _updateDirty(String key, String currentValue)
  {
    final base = _baseline[key] ?? '';
    if (currentValue == base)
    {
      _dirtyKeys.remove(key);
    }
    else
    {
      _dirtyKeys.add(key);
    }
  }

  void _captureBaselineFromCurrentControllers()
  {
    _baseline.clear();
    _dirtyKeys.clear();

    for (final dateEntry in _draftsByDate.entries)
    {
      final date = dateEntry.key;
      final perExercise = dateEntry.value;

      for (final exEntry in perExercise.entries)
      {
        final exercise = exEntry.key;
        final sets = exEntry.value;

        for (int i = 0; i < sets.length; i++)
        {
          final d = sets[i];

          _baseline[_k(date, exercise, i, 'w')]  = d.weightController.text.trim();
          _baseline[_k(date, exercise, i, 'fr')] = d.fullRepsController.text.trim();
          _baseline[_k(date, exercise, i, 'pr')] = d.partialRepsController.text.trim();        
        }
      }
    }
  }

  @override
  void initState() 
  {
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
    FocusManager.instance.primaryFocus?.unfocus();
    _stashActiveDrafts();
    _activeDate = _activeDate.subtract(const Duration(days: 1));
    await _loadForDate(workoutName, exercises);
  }

  Future<void> _goNext(String workoutName, List<String> exercises) async 
  {
    if (!_canGoNext) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _stashActiveDrafts();
    _activeDate = _activeDate.add(const Duration(days: 1));
    await _loadForDate(workoutName, exercises);
  }

  // true if this date has ANY sets (either cached drafts or saved in DB)
  bool _dateHasAnyDraftSets(String dateIso) {
    // Check cached drafts first (including current date once stashed)
    final cached = _draftsByDate[dateIso];
    if (cached == null) return false;

    for (final sets in cached.values) {
      if (sets.isNotEmpty) return true;
    }
    return false;
  }

  // checks DB for any sets logged on a date (across all exercises)
  Future<bool> _dateHasAnySavedSets(
    String workoutName,
    List<String> exercises,
    String dateIso,
  ) async {
    final db = ref.read(localDbProvider);

    for (final ex in exercises) {
      final existing = await db.getExerciseLogForDay(
        workoutName: workoutName,
        exerciseName: ex,
        dateIso: dateIso,
      );

      final savedSets = existing?.sets ?? const <SetLog>[];
      if (savedSets.isNotEmpty) return true;
    }
    return false;
  }

  // find nearest previous date with a workout (cached OR saved)
  Future<DateTime?> _findPrevWorkoutDate(String workoutName, List<String> exercises) async {
    final firstDate = DateTime(
      _activeDate.year - 1,
      _activeDate.month,
      _activeDate.day,
    );

    // Make sure current date is cached before searching
    _stashActiveDrafts();

    DateTime d = _activeDate.subtract(const Duration(days: 1));
    while (!d.isBefore(firstDate)) {
      final iso = _dateIso(d);

      if (_dateHasAnyDraftSets(iso)) return d;

      final hasSaved = await _dateHasAnySavedSets(workoutName, exercises, iso);
      if (hasSaved) return d;

      d = d.subtract(const Duration(days: 1));
    }
    return null;
  }

  // find nearest next date with a workout (cached OR saved), up to today
  Future<DateTime?> _findNextWorkoutDate(String workoutName, List<String> exercises) async {
    // Make sure current date is cached before searching
    _stashActiveDrafts();

    DateTime d = _activeDate.add(const Duration(days: 1));
    while (!d.isAfter(_today)) {
      final iso = _dateIso(d);

      if (_dateHasAnyDraftSets(iso)) return d;

      final hasSaved = await _dateHasAnySavedSets(workoutName, exercises, iso);
      if (hasSaved) return d;

      d = d.add(const Duration(days: 1));
    }
    return null;
  }

  Future<void> _jumpToDate(DateTime target, String workoutName, List<String> exercises) async {
    FocusManager.instance.primaryFocus?.unfocus();
    _stashActiveDrafts();
    _activeDate = DateTime(target.year, target.month, target.day);
    await _loadForDate(workoutName, exercises);
  }

  Future<void> _goPrevWorkout(String workoutName, List<String> exercises) async {
    final target = await _findPrevWorkoutDate(workoutName, exercises);
    if (target == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workout found in the previous year.')),
      );
      return;
    }
    await _jumpToDate(target, workoutName, exercises);
  }

  Future<void> _goNextWorkout(String workoutName, List<String> exercises) async {
    if (!_canGoNext) return;

    final target = await _findNextWorkoutDate(workoutName, exercises);

    // If there is no *later* recorded workout date, bring the user to today.
    if (target == null) {
      await _jumpToDate(_today, workoutName, exercises);

      // Optional: a small hint to explain what happened.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No next recorded workout — jumped to today.')),
      );
      return;
    }

    await _jumpToDate(target, workoutName, exercises);
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
        workoutName: workoutName,
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

  double? _defaultWeightForNewSet(String exerciseName) {
    // 1) Prefer today's existing draft weight for THIS exercise
    final setsToday = _drafts[exerciseName];
    if (setsToday != null && setsToday.isNotEmpty) {
      for (int i = setsToday.length - 1; i >= 0; i--) {
        final s = setsToday[i];

        // Skip bodyweight sets
        if (s.isBodyweight) continue;

        // Use the most recent valid weight
        final txt = s.weightController.text.trim();
        final w = double.tryParse(txt);
        if (w != null) return w;
      }
    }

    // 2) Fallback: saved default (your "max weight" logic)
    return _defaults[exerciseName];
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

    return PopScope(
      canPop: !_isDirty,
      onPopInvoked: (didPop) async
      {
        if (didPop) return;

        final ok = await showDestructiveConfirmSheet(
          context, 
          title: 'Discard unfinished changes?', 
          message: 'Any unsaved recording will be cleared.', 
          confirmText: 'Discard',
        );

        if (!ok) return;

        FocusManager.instance.primaryFocus?.unfocus();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${workout.name}'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Close',
            onPressed: () async 
            {
              if (_isDirty)
              {
                final ok = await showDestructiveConfirmSheet(
                  context, 
                  title: 'Discard unfinished changes?', 
                  message: 'Any unsaved recording will be cleared.', 
                  confirmText: 'Discard',
                );
                if (!ok) return;
              }

              FocusManager.instance.primaryFocus?.unfocus();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          actions: [
            if (kDebugMode)
              TextButton(
                onPressed: () => _seedExampleBenchPress(workout.name, workout.exercises),
                child: const Text('Seed'),
              ),
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
                  icon: const Icon(Icons.keyboard_double_arrow_left),
                  tooltip: 'Previous workout',
                  onPressed: () => _goPrevWorkout(workout.name, exercises),
                ),

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

                IconButton(
                  icon: const Icon(Icons.keyboard_double_arrow_right),
                  tooltip: 'Next workout',
                  onPressed: _canGoNext
                      ? () => _goNextWorkout(workout.name, exercises)
                      : null,
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
                      final w = _defaultWeightForNewSet(currentExercise);
                      currentSets.add(SetDraft.withDefaultWeight(w));
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

                final dateIso = _dateIso(_activeDate);
                final keyW  = _k(dateIso, currentExercise, setIndex, 'w');
                final keyFR = _k(dateIso, currentExercise, setIndex, 'fr');
                final keyPR = _k(dateIso, currentExercise, setIndex, 'pr');

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
                                        final d = _defaultWeightForNewSet(currentExercise);
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
                          onChanged: (v) => setState(() => _updateDirty(keyW, v.trim())),
                          enabled: !set.isBodyweight,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Weight'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: set.fullRepsController,
                          onChanged: (v) => setState(() => _updateDirty(keyFR, v.trim())),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Full reps', hintText: '0'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: set.partialRepsController,
                          onChanged: (v) => setState(() => _updateDirty(keyPR, v.trim())),
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
      )
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

  Future<void> _seedExampleBenchPress(String workoutName, List<String> exercises) async {
    const exerciseName = 'Example bench press';

    // 1) Ensure the exercise exists in this workout (so it shows in your pager UI)
    final hasExercise = exercises.any((e) => e.trim().toLowerCase() == exerciseName.toLowerCase());
    if (!hasExercise) {
      final updatedExercises = [...exercises, exerciseName];

      final err = await ref.read(workoutsProvider.notifier).updateWorkout(
        originalName: workoutName,
        rawName: workoutName,
        rawExercises: updatedExercises,
      );

      if (err != null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Seed failed (workout update): $err')),
        );
        return;
      }
    }

    final db = ref.read(localDbProvider);

    // 2) Seed ~6 months history ending today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    const weeks = 26;
    const totalSessions = weeks * 2; // ~2x/week

    // Deterministic-ish schedule: every 3 days
    final dates = <DateTime>[];
    for (int i = 0; i < totalSessions; i++) {
      final daysBack = (totalSessions - 1 - i) * 3;
      dates.add(today.subtract(Duration(days: daysBack)));
    }

    double r25(double x) => (x / 2.5).round() * 2.5;

    for (int i = 0; i < dates.length; i++) {
      final d = dates[i];
      final dateIso = _dateIso(d);

      final t = i / (dates.length - 1); // 0..1 progression

      // Weight progression: ~140 -> ~205, with occasional lighter day
      final baseTop = r25(140 + 65 * t);
      final lightDay = (i % 7 == 0) ? -7.5 : 0.0;
      final top = r25(baseTop + lightDay);

      // Reps: ~9 -> ~5 over time, small oscillation
      final repsBase = (9 - (4 * t)).round().clamp(5, 9);
      final reps = (repsBase + ((i % 5 == 0) ? 1 : 0)).clamp(5, 10);

      // Sets: more volume early, slightly less later
      final setCount = (t < 0.35)
          ? ((i % 4 == 0) ? 5 : 4)
          : ((i % 6 == 0) ? 3 : 4);

      final backoff = r25(top - ((t < 0.5) ? 5.0 : 2.5));

      final sets = <SetLog>[];

      // 1 top set
      sets.add(SetLog(
        isBodyweight: false,
        weight: top,
        fullReps: reps,
        partialReps: 0,
      ));

      // backoff sets (slightly higher reps)
      for (int s = 1; s < setCount; s++) {
        final backoffReps = (reps + 1).clamp(5, 12);
        sets.add(SetLog(
          isBodyweight: false,
          weight: backoff,
          fullReps: backoffReps,
          partialReps: 0,
        ));
      }

      final log = ExerciseDayLog(
        exerciseKey: db.exerciseKey(exerciseName),
        exerciseName: exerciseName,
        dateIso: dateIso,
        workoutKey: db.workoutKey(workoutName),
        workoutName: workoutName,
        sets: sets,
      );

      await db.upsertExerciseLog(log);

      // Update default weight logic you already use (max weight from this log)
      await db.setDefaultWeightForExercise(exerciseName, top);
      _defaults[exerciseName] = top;
    }

    // 3) Refresh providers used by UI + plots
    ref.invalidate(exerciseLogsProvider);
    ref.invalidate(plotSessionsProvider);
    ref.invalidate(workoutsProvider);

    // 4) Reload current date so UI reflects changes immediately
    if (mounted) {
      final workouts = ref.read(workoutsProvider).value ?? const [];
      final idx = workouts.indexWhere((w) => w.name == workoutName);
      if (idx != -1) {
        await _loadForDate(workoutName, workouts[idx].exercises);
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Seeded: Example bench press (6 months).')),
    );
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
          workoutKey: db.workoutKey(workoutName),
          workoutName: workoutName, // metadata
          sets: sets,
        );

        await db.upsertExerciseLog(log);
        ref.invalidate(exerciseLogsProvider);
        ref.invalidate(plotSessionsProvider);

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

    _captureBaselineFromCurrentControllers();

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
    _drafts.clear();

    for (final perDate in _draftsByDate.values)
    {
      for (final sets in perDate.values)
      {
        for (final d in sets)
        {
          d.dispose();
        }
      }
    }
    _draftsByDate.clear();

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