import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'plot_axis.dart';
import 'plot_spec.dart';
import 'plot_data.dart';
import 'plot_tick_utils.dart';
import '../../theme/app_colors.dart';

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

    // Sort by x for a stable ordering
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));

    final xIsDate = widget.spec.xAxis == PlotAxis.date;
    final yIsDate = widget.spec.yAxis == PlotAxis.date;

    // Build date-index maps for any date axis
    List<DateTime> xDateByIndex = const [];
    List<DateTime> yDateByIndex = const [];

    Map<int, int> xMsToIndex = const {};
    Map<int, int> yMsToIndex = const {};

    if (xIsDate) {
      final xs = sorted.map((p) => p.x.round()).toSet().toList()..sort();
      xDateByIndex = xs.map(DateTime.fromMillisecondsSinceEpoch).toList();
      xMsToIndex = {
        for (int i = 0; i < xs.length; i++) xs[i]: i,
      };
    }

    if (yIsDate) {
      final ys = sorted.map((p) => p.y.round()).toSet().toList()..sort();
      yDateByIndex = ys.map(DateTime.fromMillisecondsSinceEpoch).toList();
      yMsToIndex = {
        for (int i = 0; i < ys.length; i++) ys[i]: i,
      };
    }

    // Build chart spots (date axes become linear indices)
    final spots = sorted.map((p) {
      final xVal = xIsDate ? (xMsToIndex[p.x.round()] ?? 0).toDouble() : p.x;
      final yVal = yIsDate ? (yMsToIndex[p.y.round()] ?? 0).toDouble() : p.y;
      return FlSpot(xVal, yVal);
    }).toList();

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

    // Expand axes to "nice" tick endpoints
    late final double bottomInterval;
    late final double leftInterval;

    // X axis
    if (xIsDate) {
      // Date indices are [0 .. xDateByIndex.length-1]
      minX = 0;
      maxX = max(0, xDateByIndex.length - 1).toDouble();

      bottomInterval = dateTickInterval(xDateByIndex.length);
      // Extend maxX to land exactly on a tick
      maxX = (maxX / bottomInterval).ceilToDouble() * bottomInterval;
    } else {
      final xTicks = buildTicks(minX, maxX, targetTicks: 4);
      if (xTicks.isNotEmpty) {
        minX = xTicks.first;
        maxX = xTicks.last;
      }
      bottomInterval = xTicks.length >= 2 ? (xTicks[1] - xTicks[0]) : niceInterval(minX, maxX);
    }

    // Y axis
    if (yIsDate) {
      minY = 0;
      maxY = max(0, yDateByIndex.length - 1).toDouble();

      leftInterval = dateTickInterval(yDateByIndex.length);
      maxY = (maxY / leftInterval).ceilToDouble() * leftInterval;
    } else {
      final yTicks = buildTicks(minY, maxY, targetTicks: 4);
      if (yTicks.isNotEmpty) {
        minY = yTicks.first;
        maxY = yTicks.last;
      }
      leftInterval = yTicks.length >= 2 ? (yTicks[1] - yTicks[0]) : niceInterval(minY, maxY);
    }

    final yLabels = yIsDate
        ? _yDateTickLabels(minY, maxY, leftInterval, yDateByIndex)
        : _yTickLabels(minY, maxY, leftInterval, formatNum1);

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
                    if (idx < 0 || idx >= xDateByIndex.length) {
                      text = '';
                    } else {
                      text = formatMonthDay(xDateByIndex[idx]);
                    }
                  } else {
                    text = formatNum1(value);
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
                  String text;

                  if (yIsDate) {
                    final idx = value.round();
                    if (idx < 0 || idx >= yDateByIndex.length) {
                      text = '';
                    } else {
                      text = formatMonthDay(yDateByIndex[idx]);
                    }
                  } else {
                    text = formatNum1(value);
                  }

                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(text, style: const TextStyle(fontSize: 11)),
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
                      ? formatMonthDay(xDateByIndex[ts.x.round().clamp(0, xDateByIndex.length - 1)])
                      : formatNum1(ts.x);
                  final yLabel = yIsDate
                    ? formatMonthDay(yDateByIndex[ts.y.round().clamp(0, yDateByIndex.length - 1)])
                    : formatNum1(ts.y);

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
              color: AppColors.accent,
              isCurved: false,
              barWidth: 2,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: AppColors.accent,
                      strokeWidth: 0,
                    );
                  },
                ),
              belowBarData: BarAreaData(show: false),
            ),
          ],
        ),
      ),
    );
  }
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

List<String> _yDateTickLabels(
  double minY,
  double maxY,
  double interval,
  List<DateTime> dateByIndex,
) {
  if (dateByIndex.isEmpty) return const [];

  if (interval <= 0 || minY.isNaN || maxY.isNaN) {
    return [
      formatMonthDay(dateByIndex[minY.round().clamp(0, dateByIndex.length - 1)]),
      formatMonthDay(dateByIndex[maxY.round().clamp(0, dateByIndex.length - 1)]),
    ];
  }

  final start = (minY / interval).floor() * interval;

  final labels = <String>[];
  const maxTicks = 128;

  double v = start;
  int count = 0;

  while (v <= maxY + interval && count < maxTicks) {
    final idx = v.round();
    if (idx >= 0 && idx < dateByIndex.length) {
      labels.add(formatMonthDay(dateByIndex[idx]));
    }
    v += interval;
    count++;
  }

  // Ensure bounds are included (and in-range)
  final minIdx = minY.round();
  final maxIdx = maxY.round();
  if (minIdx >= 0 && minIdx < dateByIndex.length) {
    labels.add(formatMonthDay(dateByIndex[minIdx]));
  }
  if (maxIdx >= 0 && maxIdx < dateByIndex.length) {
    labels.add(formatMonthDay(dateByIndex[maxIdx]));
  }

  return labels.toSet().toList();
}