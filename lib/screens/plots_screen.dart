import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/sessions_provider.dart';
import '../providers/workouts_provider.dart';
import '../widgets/plots/plot_axis.dart';
import '../widgets/plots/plot_spec.dart';
import '../widgets/plots/plot_view.dart';
import '../widgets/plots/plot_data_builder.dart';

enum AxisOption { date, weight, reps, sets }

PlotAxis _toPlotAxis(AxisOption a) {
  switch (a) {
    case AxisOption.date:
      return PlotAxis.date;
    case AxisOption.weight:
      return PlotAxis.weight;
    case AxisOption.reps:
      return PlotAxis.reps;
    case AxisOption.sets:
      return PlotAxis.sets;
  }
}

extension AxisOptionLabel on AxisOption {
  String get label {
    switch (this) {
      case AxisOption.date:
        return 'Date';
      case AxisOption.weight:
        return 'Weight';
      case AxisOption.reps:
        return 'Reps';
      case AxisOption.sets:
        return 'Sets';
    }
  }

  String get key => name; // 'date', 'weight', ...
  static AxisOption? fromKey(String? k) {
    if (k == null) return null;
    for (final v in AxisOption.values) {
      if (v.name == k) return v;
    }
    return null;
  }
}

class PlotsScreen extends ConsumerStatefulWidget {
  const PlotsScreen({super.key});

  @override
  ConsumerState<PlotsScreen> createState() => _PlotsScreenState();
}

class _PlotsScreenState extends ConsumerState<PlotsScreen> {
  static const String _prefsKeyAxes = 'plot_axes_v1';

  String? _selectedExercise;

  AxisOption? _xAxis;
  AxisOption? _yAxis;
  AxisOption? _zAxis; // null means "None" (2D)

  bool _loadedPrefs = false;

  @override
  void initState() {
    super.initState();
    _loadAxesPrefs();
  }

  List<AxisOption> _availableOptionsFor(String which) {
    final used = <AxisOption>{};

    if (which != 'x' && _xAxis != null) used.add(_xAxis!);
    if (which != 'y' && _yAxis != null) used.add(_yAxis!);
    if (which != 'z' && _zAxis != null) used.add(_zAxis!);

    return AxisOption.values
        .where((opt) => !used.contains(opt))
        .toList();
  }

  Future<void> _loadAxesPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKeyAxes);
    if (raw == null || raw.isEmpty) {
      setState(() => _loadedPrefs = true);
      return;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        setState(() => _loadedPrefs = true);
        return;
      }

      setState(() {
        _selectedExercise = decoded['exercise'] as String?;
        _xAxis = AxisOptionLabel.fromKey(decoded['x'] as String?);
        _yAxis = AxisOptionLabel.fromKey(decoded['y'] as String?);
        _zAxis = AxisOptionLabel.fromKey(decoded['z'] as String?);
        _loadedPrefs = true;
      });

      // Make sure uniqueness constraint holds even if prefs were weird.
      _enforceUniqueAxes();
    } catch (_) {
      setState(() => _loadedPrefs = true);
    }
  }

  Future<void> _saveAxesPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, String?>{
      'exercise': _selectedExercise,
      'x': _xAxis?.key,
      'y': _yAxis?.key,
      'z': _zAxis?.key,
    };
    await prefs.setString(_prefsKeyAxes, jsonEncode(payload));
  }

  void _enforceUniqueAxes() {
    // Enforce uniqueness among non-null axes (X, Y must be non-null for a meaningful plot).
    // If duplicates exist, we clear the "later" ones in a consistent order: Z, then Y.
    final used = <AxisOption>{};

    AxisOption? norm(AxisOption? v) => v;

    // X
    if (norm(_xAxis) != null) used.add(_xAxis!);

    // Y
    if (norm(_yAxis) != null) {
      if (used.contains(_yAxis)) _yAxis = null;
      else used.add(_yAxis!);
    }

    // Z (allowed to be null)
    if (norm(_zAxis) != null) {
      if (used.contains(_zAxis)) _zAxis = null;
      else used.add(_zAxis!);
    }
  }

  void _setAxis({
    required String which, // 'x' | 'y' | 'z'
    required AxisOption? value,
  }) {
    setState(() {
      if (which == 'x') _xAxis = value;
      if (which == 'y') _yAxis = value;
      if (which == 'z') _zAxis = value; // null means "None"
      _enforceUniqueAxes();
    });

    // Persist immediately (no need to await)
    _saveAxesPrefs();
  }

  @override
  Widget build(BuildContext context) {
    final workoutsAsync = ref.watch(workoutsProvider);
    final sessionsAsync = ref.watch(sessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Plots')),
      body: workoutsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (workouts) {
          final exerciseNames = <String>{};
          for (final w in workouts) {
            exerciseNames.addAll(w.exercises);
          }
          final exercises = exerciseNames.toList()..sort();

          if (_selectedExercise != null &&
              !exerciseNames.contains(_selectedExercise)) {
            _selectedExercise = null;
          }

          final is2DReady =
              _selectedExercise != null && _xAxis != null && _yAxis != null;
          final is3DReady = is2DReady && _zAxis != null;

          final portraitWidth = MediaQuery.of(context).size.width;

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Exercise selector
                  DropdownButtonFormField<String>(
                    value: _selectedExercise,
                    decoration: const InputDecoration(
                      labelText: 'Exercise',
                      border: OutlineInputBorder(),
                    ),
                    items: exercises
                        .map(
                          (name) => DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() => _selectedExercise = v);
                      _saveAxesPrefs();
                    },
                  ),

                  const SizedBox(height: 16),

                  // Axis selectors
                  Row(
                    children: [
                      Expanded(
                        child: _AxisDropdown(
                          label: 'X axis',
                          value: _xAxis,
                          options: _availableOptionsFor('x'),
                          allowNone: false,
                          onChanged: (v) => _setAxis(which: 'x', value: v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AxisDropdown(
                          label: 'Y axis',
                          value: _yAxis,
                          options: _availableOptionsFor('y'),
                          allowNone: false,
                          onChanged: (v) => _setAxis(which: 'y', value: v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AxisDropdown(
                          label: 'Z axis',
                          value: _zAxis,
                          options: _availableOptionsFor('z'),
                          allowNone: true,
                          onChanged: (v) => _setAxis(which: 'z', value: v),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Square plot placeholder
                  Center(
                    child: SizedBox(
                      width: portraitWidth,
                      height: portraitWidth,
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: (!is2DReady)
                            ? const Text(
                                'Select an exercise and choose X and Y axes.\n(Optional: choose Z for 3D.)',
                                textAlign: TextAlign.center,
                              )
                            : sessionsAsync.when(
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Center(child: Text('Error: $e')),
                                data: (sessions) {
                                  final spec = PlotSpec(
                                    exercise: _selectedExercise!, // safe because is2DReady
                                    xAxis: _toPlotAxis(_xAxis!),
                                    yAxis: _toPlotAxis(_yAxis!),
                                    zAxis: _zAxis == null ? null : _toPlotAxis(_zAxis!),
                                  );

                                  final data = PlotDataBuilder.build(
                                    spec: spec,
                                    sessions: sessions,
                                  );

                                  return PlotView(spec: spec, data: data);
                                },
                              ),

                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AxisDropdown extends StatelessWidget {
  final String label;
  final AxisOption? value;
  final List<AxisOption> options;
  final bool allowNone;
  final ValueChanged<AxisOption?> onChanged;

  const _AxisDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.allowNone,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<AxisOption>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: [
        if (allowNone)
          const DropdownMenuItem<AxisOption>(
            value: null,
            child: Text('None'),
          ),
        ...options.map((opt) {
          return DropdownMenuItem<AxisOption>(
            value: opt,
            enabled: true,
            child: Text(opt.label),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}
