import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'plot_axis.dart';
import 'plot_spec.dart';
import 'plot_data.dart';
import 'plot_tick_utils.dart';

class Plot2DView extends StatefulWidget {
  final PlotSpec spec;
  final PlotData data;

  const Plot2DView({
    super.key,
    required this.spec,
    required this.data,
  });

  @override
  State<Plot2DView> createState() => _Plot2DViewState();
}

class _Plot2DViewState extends State<Plot2DView> {
  @override
  Widget build(BuildContext context) {
    final points = widget.data.points2D ?? const <PlotPoint2D>[];

    if (points.isEmpty) {
      return const Center(
        child: Text(
          'No data yet for this selection.',
          textAlign: TextAlign.center,
        ),
      );
    }

    // Sort by x (x is ms since epoch when xAxis == date)
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));

    final xIsDate = widget.spec.xAxis == PlotAxis.date;

    // --- Key fix: if x is date, use a linear index for the chart's x-coordinate ---
    late final List<FlSpot> spots;
    late final List<DateTime> dateByIndex;

    if (xIsDate) {
      dateByIndex = sorted
          .map((p) => DateTime.fromMillisecondsSinceEpoch(p.x.round()))
          .toList();

      spots = List.generate(
        sorted.length,
        (i) => FlSpot(i.toDouble(), sorted[i].y),
      );
    } else {
      dateByIndex = const [];
      spots = sorted.map((p) => FlSpot(p.x, p.y)).toList();
    }

    // Compute bounds
    double minX = spots.first.x, maxX = spots.first.x;
    double minY = spots.first.y, maxY = spots.first.y;

    for (final s in spots) {
      if (s.x < minX) minX = s.x;
      if (s.x > maxX) maxX = s.x;
      if (s.y < minY) minY = s.y;
      if (s.y > maxY) maxY = s.y;
    }

    // Avoid degenerate ranges
    if (minX == maxX) {
      minX -= 1;
      maxX += 1;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    // Tick intervals
    final bottomInterval = xIsDate
        ? _dateTickInterval(spots.length) // linear index ticks
        : niceInterval(minX, maxX, targetTicks: 4);

    final leftInterval = niceInterval(minY, maxY, targetTicks: 4);
    final yLabels = _yTickLabels(minY, maxY, leftInterval, _fmtNum);
    final leftReserved = _measureMaxLabelWidth(
      context,
      yLabels,
      fontSize: 11,
      extraPadding: 10,
    );


    return Padding(
      padding: EdgeInsets.zero,
      child: LineChart(
        LineChartData(
          minX: minX,
          maxX: maxX,
          minY: minY,
          maxY: maxY,

          gridData: FlGridData(show: true),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
              width: 1
            )
          ),

          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),

            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: bottomInterval,
                getTitlesWidget: (value, meta) {
                  String text;

                  if (xIsDate) {
                    final idx = value.round();
                    if (idx < 0 || idx >= dateByIndex.length) {
                      return const SizedBox.shrink();
                    }
                    text = _fmtDate(dateByIndex[idx]);
                  } else {
                    text = _fmtNum(value);
                  }

                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(text, style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),

            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: leftReserved,
                interval: leftInterval,
                getTitlesWidget: (value, meta) {
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(_fmtNum(value), style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),

          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((ts) {
                  final xLabel = xIsDate
                      ? _fmtDate(dateByIndex[ts.x.round().clamp(0, dateByIndex.length - 1)])
                      : _fmtNum(ts.x);
                  final yLabel = _fmtNum(ts.y);

                  return LineTooltipItem(
                    '$xLabel\n$yLabel',
                    const TextStyle(fontSize: 12),
                  );
                }).toList();
              },
            ),
          ),

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

/// For date-as-index x-axis: pick an interval that yields ~6 labels max.
double _dateTickInterval(int n) {
  if (n <= 1) return 1;
  if (n <= 6) return 1;
  if (n <= 12) return 2;
  if (n <= 20) return 3;
  return (n / 6).ceilToDouble();
}

String _fmtNum(double v) => v.toStringAsFixed(1);

String _fmtDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

double _measureMaxLabelWidth(
  BuildContext context,
  List<String> labels, {
  double fontSize = 11,
  double extraPadding = 10,
}) {
  final style = Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: fontSize)
      ?? TextStyle(fontSize: fontSize);

  double maxWidth = 0;

  for (final t in labels) {
    final tp = TextPainter(
      text: TextSpan(text: t, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    if (tp.width > maxWidth) maxWidth = tp.width;
  }

  return maxWidth + extraPadding;
}

List<String> _yTickLabels(
  double minY,
  double maxY,
  double interval,
  String Function(double) fmt,
) {
  if (interval <= 0 || minY.isNaN || maxY.isNaN) {
    return [fmt(minY), fmt(maxY)];
  }

  final start = (minY / interval).floor() * interval;

  final labels = <String>[];
  const maxTicks = 64;

  double v = start;
  int count = 0;

  while (v <= maxY + interval && count < maxTicks) {
    if (v >= minY - 1e-9 && v <= maxY + 1e-9) {
      labels.add(fmt(v));
    }
    v += interval;
    count++;
  }

  labels.add(fmt(minY));
  labels.add(fmt(maxY));

  return labels.toSet().toList();
}