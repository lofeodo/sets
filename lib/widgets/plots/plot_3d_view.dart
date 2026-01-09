import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'plot_axis.dart';
import 'plot_data.dart';
import 'plot_spec.dart';

class Plot3DView extends StatefulWidget {
  final PlotSpec spec;
  final PlotData data;

  const Plot3DView({
    super.key,
    required this.spec,
    required this.data,
  });

  @override
  State<Plot3DView> createState() => _Plot3DViewState();
}

class _Plot3DViewState extends State<Plot3DView> {
  // Drag to rotate
  double _yaw = -0.9;
  double _pitch = 0.55;

  // World cube side length (plot space will be [0, axisLen] on each axis)
  static const double _axisLen = 1.0;

  // Cached points in plot-space [0, axisLen]
  List<_Vec3> _pts = const [];

  @override
  void initState() {
    super.initState();
    _rebuildCache();
  }

  @override
  void didUpdateWidget(covariant Plot3DView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.data.points3D != widget.data.points3D ||
        oldWidget.spec.exercise != widget.spec.exercise ||
        oldWidget.spec.xAxis != widget.spec.xAxis ||
        oldWidget.spec.yAxis != widget.spec.yAxis ||
        oldWidget.spec.zAxis != widget.spec.zAxis) {
      _rebuildCache();
    }
  }

  void _handleDrag(DragUpdateDetails d) {
    setState(() {
      _yaw += d.delta.dx * 0.01;
      _pitch += d.delta.dy * 0.01;
      _pitch = _pitch.clamp(-1.2, 1.2);
    });
  }

  void _rebuildCache() {
    final raw = widget.data.points3D ?? const <PlotPoint3D>[];
    if (raw.isEmpty) {
      _pts = const [];
      return;
    }

    final xVals = raw.map((p) => p.x).toList();
    final yVals = raw.map((p) => p.y).toList();
    final zVals = raw.map((p) => p.z).toList();

    // Date axes should be mapped to linear indices BEFORE rendering.
    final xMapped = _maybeMapDateToIndex(widget.spec.xAxis, xVals);
    final yMapped = _maybeMapDateToIndex(widget.spec.yAxis, yVals);
    final zMapped = _maybeMapDateToIndex(widget.spec.zAxis!, zVals);

    // Normalize into [0,1] so there are no “negative” plot values
    final xs = _normalize01(xMapped);
    final ys = _normalize01(yMapped);
    final zs = _normalize01(zMapped);

    _pts = List<_Vec3>.generate(
      raw.length,
      (i) => _Vec3(
        xs[i] * _axisLen,
        ys[i] * _axisLen,
        zs[i] * _axisLen,
      ),
      growable: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_pts.isEmpty) {
      return const Center(
        child: Text(
          'No 3D data yet for this selection.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final textStyle = Theme.of(context).textTheme.labelMedium!;
    return GestureDetector(
      onPanUpdate: _handleDrag,
      child: RepaintBoundary(
        child: SizedBox.expand(

          child: CustomPaint(
            painter: _Scatter3DPainter(
              points: _pts,
              yaw: _yaw,
              pitch: _pitch,
              axisLen: _axisLen,
              xLabel: widget.spec.xAxis.label,
              yLabel: widget.spec.yAxis.label,
              zLabel: widget.spec.zAxis!.label,
              labelStyle: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Scatter3DPainter extends CustomPainter {
  final List<_Vec3> points;
  final double yaw;
  final double pitch;
  final double axisLen;

  final String xLabel;
  final String yLabel;
  final String zLabel;
  final TextStyle labelStyle;

  const _Scatter3DPainter({
    required this.points,
    required this.yaw,
    required this.pitch,
    required this.axisLen,
    required this.xLabel,
    required this.yLabel,
    required this.zLabel,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surface,
    );

    // Optional subtle border (NOT cube outline)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = AppColors.textSecondary.withOpacity(0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    canvas.save();
    canvas.clipRect(Offset.zero & size);

    const pad = 6.0;

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    // Camera distance for perspective
    const camDist = 3.2;

    final cyaw = math.cos(yaw);
    final syaw = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    // Center the cube for rotation, but keep axes defined in [0..axisLen]
    final half = axisLen * 0.5;
    _Vec3 centerShift(_Vec3 v) => _Vec3(v.x - half, v.y - half, v.z - half);

    _Vec3 rot(_Vec3 v) {
      // yaw around Y
      final x1 = v.x * cyaw + v.z * syaw;
      final y1 = v.y;
      final z1 = -v.x * syaw + v.z * cyaw;

      // pitch around X
      final x2 = x1;
      final y2 = y1 * cp - z1 * sp;
      final z2 = y1 * sp + z1 * cp;

      return _Vec3(x2, y2, z2);
    }

    // Project to an unscaled 2D plane (we compute scale to fill screen)
    _Proj2 projRaw(_Vec3 v) {
      final denom = (camDist - v.z).clamp(0.35, 1000.0);
      final p = 1.0 / denom;
      return _Proj2(v.x * p, v.y * p, v.z);
    }

    // Compute bounds of the rotated cube so we can scale to fill available space.
    final cubeCorners = <_Vec3>[
      _Vec3(0, 0, 0),
      _Vec3(axisLen, 0, 0),
      _Vec3(axisLen, axisLen, 0),
      _Vec3(0, axisLen, 0),
      _Vec3(0, 0, axisLen),
      _Vec3(axisLen, 0, axisLen),
      _Vec3(axisLen, axisLen, axisLen),
      _Vec3(0, axisLen, axisLen),
    ].map((v) => rot(centerShift(v))).toList(growable: false);

    double minX = double.infinity, maxX = -double.infinity;
    double minY = double.infinity, maxY = -double.infinity;

    for (final c in cubeCorners) {
      final pr = projRaw(c);
      if (pr.x < minX) minX = pr.x;
      if (pr.x > maxX) maxX = pr.x;
      if (pr.y < minY) minY = pr.y;
      if (pr.y > maxY) maxY = pr.y;
    }

    final spanX = (maxX - minX).clamp(1e-6, 1e9);
    final spanY = (maxY - minY).clamp(1e-6, 1e9);

    final scale = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );

    final midX = (minX + maxX) * 0.5;
    final midY = (minY + maxY) * 0.5;

    Offset toScreen(_Vec3 v) {
      final pr = projRaw(v);
      final sx = cx + (pr.x - midX) * scale;
      final sy = cy - (pr.y - midY) * scale; // invert y
      return Offset(sx, sy);
    }

    // Axes (origin at the cube corner corresponding to min values)
    // We draw axes along +X, +Y, +Z from (0,0,0) in plot-space.
    final axisPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.85)
      ..strokeWidth = 1.25
      ..isAntiAlias = true;

    void line3(_Vec3 a, _Vec3 b, Paint p) {
      final ra = rot(centerShift(a));
      final rb = rot(centerShift(b));
      canvas.drawLine(toScreen(ra), toScreen(rb), p);
    }

    // Origin corner and axes
    const o = _Vec3(0, 0, 0);
    line3(o, _Vec3(axisLen, 0, 0), axisPaint); // X
    line3(o, _Vec3(0, axisLen, 0), axisPaint); // Y
    line3(o, _Vec3(0, 0, axisLen), axisPaint); // Z

    // Axis labels (slightly offset outward)
    const labelPad = 10.0;

    final xEnd = toScreen(rot(centerShift(_Vec3(axisLen, 0, 0))));
    final yEnd = toScreen(rot(centerShift(_Vec3(0, axisLen, 0))));
    final zEnd = toScreen(rot(centerShift(_Vec3(0, 0, axisLen))));

    _drawLabel(
      canvas,
      xLabel,
      xEnd + const Offset(labelPad, 0),
      Alignment.centerLeft,
    );

    _drawLabel(
      canvas,
      yLabel,
      yEnd + const Offset(0, -labelPad),
      Alignment.bottomCenter,
    );

    _drawLabel(
      canvas,
      zLabel,
      zEnd + const Offset(labelPad, -labelPad),
      Alignment.bottomLeft,
    );

    // Points (depth-sort back-to-front)
    final rotatedPoints = points.map((p) => rot(centerShift(p))).toList(growable: false);
    final indices = List<int>.generate(rotatedPoints.length, (i) => i)
      ..sort((a, b) => rotatedPoints[a].z.compareTo(rotatedPoints[b].z));

    for (final i in indices) {
      final v = rotatedPoints[i];

      // Depth cue: subtle fade + size change
      // v.z roughly within [-axisLen/2, axisLen/2] after centering
      final depthT = ((v.z + half) / axisLen).clamp(0.0, 1.0);

      final alpha = (0.45 + 0.55 * depthT).clamp(0.0, 1.0);
      final radius = (2.2 + 1.3 * depthT).clamp(1.8, 4.2);

      final paint = Paint()
        ..color = AppColors.accent.withOpacity(alpha)
        ..isAntiAlias = true;

      canvas.drawCircle(toScreen(v), radius, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Scatter3DPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.axisLen != axisLen ||
        oldDelegate.points != points ||
        oldDelegate.xLabel != xLabel ||
        oldDelegate.yLabel != yLabel ||
        oldDelegate.zLabel != zLabel ||
        oldDelegate.labelStyle != labelStyle;
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position,
    Alignment align,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    final offset = position -
        Offset(
          painter.width * (align.x + 1) / 2,
          painter.height * (align.y + 1) / 2,
        );

    painter.paint(canvas, offset);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

List<double> _maybeMapDateToIndex(PlotAxis axis, List<double> values) {
  if (axis != PlotAxis.date) return values;

  final unique = values.toSet().toList()..sort();
  final indexOf = <double, int>{};
  for (int i = 0; i < unique.length; i++) {
    indexOf[unique[i]] = i;
  }
  return values.map((v) => (indexOf[v] ?? 0).toDouble()).toList();
}

List<double> _normalize01(List<double> values) {
  double mn = values.first;
  double mx = values.first;

  for (final v in values) {
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }

  final range = mx - mn;
  if (range == 0) {
    return List<double>.filled(values.length, 0.0);
  }

  return values.map((v) => (v - mn) / range).toList(); // [0,1]
}

@immutable
class _Vec3 {
  final double x;
  final double y;
  final double z;

  const _Vec3(this.x, this.y, this.z);
}

class _Proj2 {
  final double x;
  final double y;
  final double z;
  const _Proj2(this.x, this.y, this.z);
}