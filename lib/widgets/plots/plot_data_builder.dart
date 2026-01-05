// lib/widgets/plots/plot_data_builder.dart

import '../../model/session_log.dart';
import '../../model/set_log.dart';

import 'plot_axis.dart';
import 'plot_spec.dart';
import 'plot_data.dart';

class PlotDataBuilder {
  /// Build PlotData from real session logs using per-day aggregation:
  /// - weight: max weight that day
  /// - reps: max reps among sets at that max weight that day
  /// - sets: number of sets that day
  /// - date: day timestamp (ms since epoch)
  ///
  /// One point per day.
  static PlotData build({
    required PlotSpec spec,
    required List<SessionLog> sessions,
  }) {
    // Map: normalized day -> all sets for the exercise on that day
    final Map<DateTime, List<SetLog>> perDaySets = {};

    for (final session in sessions) {
      final day = _parseAndNormalizeDay(session.dateIso);

      final setsForExercise = session.byExercise[spec.exercise];
      if (setsForExercise == null || setsForExercise.isEmpty) continue;

      perDaySets.putIfAbsent(day, () => []);
      perDaySets[day]!.addAll(setsForExercise);
    }

    final days = perDaySets.keys.toList()..sort();

    if (spec.is2D) {
      final points = <PlotPoint2D>[];

      for (final day in days) {
        final sets = perDaySets[day]!;
        final x = _axisValue(spec.xAxis, day, sets);
        final y = _axisValue(spec.yAxis, day, sets);

        if (x != null && y != null) {
          points.add(PlotPoint2D(x, y));
        }
      }

      return PlotData.twoD(points);
    } else {
      final points = <PlotPoint3D>[];

      for (final day in days) {
        final sets = perDaySets[day]!;
        final x = _axisValue(spec.xAxis, day, sets);
        final y = _axisValue(spec.yAxis, day, sets);
        final z = _axisValue(spec.zAxis!, day, sets);

        if (x != null && y != null && z != null) {
          points.add(PlotPoint3D(x, y, z));
        }
      }

      return PlotData.threeD(points);
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Parses YYYY-MM-DD and normalizes to year/month/day (no time component).
  static DateTime _parseAndNormalizeDay(String dateIso) {
    // DateTime.parse("2025-12-31") is valid and yields midnight local/UTC depending on implementation,
    // but we normalize again to be safe/consistent.
    final dt = DateTime.parse(dateIso);
    return DateTime(dt.year, dt.month, dt.day);
  }

  static double? _axisValue(
    PlotAxis axis,
    DateTime day,
    List<SetLog> sets,
  ) {
    switch (axis) {
      case PlotAxis.date:
        return day.millisecondsSinceEpoch.toDouble();

      case PlotAxis.weight:
        return _maxWeight(sets);

      case PlotAxis.reps:
        return _maxRepsAtMaxWeight(sets);

      case PlotAxis.sets:
        return sets.isEmpty ? null : sets.length.toDouble();
    }
  }

  /// Maximum weight lifted that day.
  static double? _maxWeight(List<SetLog> sets) {
    double? max;

    for (final s in sets) {
      final w = s.weight;
      if (w == null) continue;

      if (max == null || w > max) {
        max = w;
      }
    }

    return max;
  }

  /// Among the sets that use the max weight, take the maximum reps.
  static double? _maxRepsAtMaxWeight(List<SetLog> sets) {
    // Step 1: find max weight (ignoring nulls)
    double? maxWeight;

    for (final s in sets) {
      final w = s.weight;
      if (w == null) continue;

      if (maxWeight == null || w > maxWeight) {
        maxWeight = w;
      }
    }

    if (maxWeight == null) return null;

    // Step 2: among sets at max weight, find max reps
    int maxReps = 0;

    for (final s in sets) {
      if (s.weight == maxWeight) {
        if (s.fullReps > maxReps) {
          maxReps = s.fullReps;
        }
      }
    }

    return maxReps.toDouble();
  }
}