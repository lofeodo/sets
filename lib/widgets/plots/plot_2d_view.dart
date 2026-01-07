import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'plot_axis.dart';
import 'plot_spec.dart';
import 'plot_data.dart';

class Plot2DView extends StatelessWidget {
  final PlotSpec spec;
  final PlotData data;

  const Plot2DView({
    super.key,
    required this.spec,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final points = data.points2D ?? const <PlotPoint2D>[];

    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No data yet for this selection.',
          textAlign: TextAlign.center,
        ),
      );
    }

    // Sort by x so the line renders properly.
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));

    final spots = sorted.map((p) => FlSpot(p.x, p.y)).toList();

    // Compute bounds (fl_chart can do it, but explicit bounds helps titles + stability).
    double minX = spots.first.x, maxX = spots.first.x;
    double minY = spots.first.y, maxY = spots.first.y;

    for (final s in spots) {
      if (s.x < minX) minX = s.x;
      if (s.x > maxX) maxX = s.x;
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }

    if (minX == maxX) {
      minX -= 1;
      maxX += 1;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    final xIsDate = spec.xAxis == PlotAxis.date;

    return Padding(
      padding: const EdgeInsets.all(8),
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,

          // Grid + border
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),

          // Axis titles
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

            bottomTitles: AxisTitles(
              axisNameWidget: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(spec.xAxis.label),
              ),
              axisNameSize: 28,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: _niceInterval(minX, maxX, targetTicks: 4),
                getTitlesWidget: (value, meta) {
                  final text = xIsDate ? _fmtDateFromMs(value) : _fmtNum(value);
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(text, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),

            leftTitles: AxisTitles(
              axisNameWidget: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(spec.yAxis.label),
              ),
              axisNameSize: 32,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: _niceInterval(minY, maxY, targetTicks: 4),
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(_fmtNum(value), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),

          // Touch interaction + tooltips
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((ts) {
                  final xLabel = xIsDate ? _fmtDateFromMs(ts.x) : _fmtNum(ts.x);
                  final yLabel = _fmtNum(ts.y);
                  return LineTooltipItem(
                    '$xLabel\n$yLabel',
                    const TextStyle(fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),

          // Data
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: false,
              barWidth: 2,
              dotData: FlDotData(show: true),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pick a reasonable interval so you don't get 100 labels.
/// For date axis, your x values are big (ms since epoch), so we ensure interval behaves.
double _niceInterval(double min, double max, {required int targetTicks}) {
  final range = (max - min).abs();
  if (range == 0) return 1;

  final raw = range / targetTicks;
  final mag = _pow10((raw.log10()).floor());

  // Try 1, 2, 5 * magnitude
  final candidates = [1 * mag, 2 * mag, 5 * mag, 10 * mag];

  double best = candidates.first;
  double bestDiff = double.infinity;

  for (final c in candidates) {
    final ticks = range / c;
    final diff = (ticks - targetTicks).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = c;
    }
  }

  return best;
}

double _pow10(int exp) {
  double v = 1;
  for (int i = 0; i < exp; i++) v *= 10;
  return v;
}

extension on double {
  double log10() => (this <= 0) ? 0 : (log(this) / ln10);
}

String _fmtNum(double v) {
  final av = v.abs();
  if (av >= 1000) return v.toStringAsFixed(0);
  if (av >= 100) return v.toStringAsFixed(1);
  if (av >= 10) return v.toStringAsFixed(2);
  return v.toStringAsFixed(3);
}

String _fmtDateFromMs(double ms) {
  final dt = DateTime.fromMillisecondsSinceEpoch(ms.round());
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final m = months[dt.month - 1];
  return '$m ${dt.day}';
}