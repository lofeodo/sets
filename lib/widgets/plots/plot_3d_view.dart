import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'plot_axis.dart';
import 'plot_data.dart';
import 'plot_spec.dart';

/// Pure Flutter “fake 3D” scatter plot.
///
/// - No native plugins
/// - Drag to rotate (yaw + pitch)
/// - No zoom / pan
/// - Minimal dark theme using AppColors
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
  double _yaw = -0.9;
  double _pitch = 0.55;

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

  void _rebuildCache() {
    final raw = widget.data.points3D ?? const <PlotPoint3D>[];
    if (raw.isEmpty) {
      _pts = const [];
      return;
    }

    final xVals = raw.map((p) => p.x).toList();
    final yVals = raw.map((p) => p.y).toList();
    final zVals = raw.map((p) => p.z).toList();

    // Date axes should be mapped to linear indices before rendering.
    final xMapped = _maybeMapDateToIndex(widget.spec.xAxis, xVals);
    final yMapped = _maybeMapDateToIndex(widget.spec.yAxis, yVals);
    final zMapped = _maybeMapDateToIndex(widget.spec.zAxis!, zVals);

    final xs = _normalizeToUnit(xMapped);
    final ys = _normalizeToUnit(yMapped);
    final zs = _normalizeToUnit(zMapped);

    _pts = List<_Vec3>.generate(
      raw.length,
      (i) => _Vec3(xs[i], ys[i], zs[i]),
      growable: false,
    );
  }

  void _handleDrag(DragUpdateDetails d) {
    setState(() {
      _yaw += d.delta.dx * 0.01;
      _pitch += -d.delta.dy * 0.01;
      _pitch = _pitch.clamp(-1.2, 1.2);
    });
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

    return GestureDetector(
      onPanUpdate: _handleDrag,
      child: RepaintBoundary(
        // IMPORTANT: force the painter to fill the available square
        child: SizedBox.expand(
          child: CustomPaint(
            painter: _Scatter3DPainter(
              points: _pts,
              yaw: _yaw,
              pitch: _pitch,
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

  const _Scatter3DPainter({
    required this.points,
    required this.yaw,
    required this.pitch,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surface,
    );

    // Border outline (subtle)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..color = AppColors.textSecondary.withOpacity(0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;
    final half = math.min(size.width, size.height) * 0.5;

    // Keep it comfortably inside your square container.
    final scale = half * 0.78;
    const camDist = 3.2;

    final cyaw = math.cos(yaw);
    final syaw = math.sin(yaw);
    final cp = math.cos(pitch);
    final sp = math.sin(pitch);

    _Vec3 rot(_Vec3 v) {
      // yaw (Y axis)
      final x1 = v.x * cyaw + v.z * syaw;
      final y1 = v.y;
      final z1 = -v.x * syaw + v.z * cyaw;

      // pitch (X axis)
      final x2 = x1;
      final y2 = y1 * cp - z1 * sp;
      final z2 = y1 * sp + z1 * cp;

      return _Vec3(x2, y2, z2);
    }

    Offset proj(_Vec3 v) {
      final denom = (camDist - v.z).clamp(0.35, 1000.0);
      final p = 1.0 / denom;
      return Offset(
        cx + v.x * scale * p,
        cy - v.y * scale * p,
      );
    }

    // Axes paint
    final axisPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.85)
      ..strokeWidth = 1.25
      ..isAntiAlias = true;

    // Wireframe cube paint (gives immediate 3D structure)
    final boxPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.35)
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    void line3(_Vec3 a, _Vec3 b, Paint p) {
      final ra = rot(a);
      final rb = rot(b);
      canvas.drawLine(proj(ra), proj(rb), p);
    }

    // 3D cube from [-1,1]^3
    const double s = 1.05;
    const corners = <_Vec3>[
      _Vec3(-s, -s, -s),
      _Vec3(s, -s, -s),
      _Vec3(s, s, -s),
      _Vec3(-s, s, -s),
      _Vec3(-s, -s, s),
      _Vec3(s, -s, s),
      _Vec3(s, s, s),
      _Vec3(-s, s, s),
    ];

    // back face
    line3(corners[0], corners[1], boxPaint);
    line3(corners[1], corners[2], boxPaint);
    line3(corners[2], corners[3], boxPaint);
    line3(corners[3], corners[0], boxPaint);

    // front face
    line3(corners[4], corners[5], boxPaint);
    line3(corners[5], corners[6], boxPaint);
    line3(corners[6], corners[7], boxPaint);
    line3(corners[7], corners[4], boxPaint);

    // connectors
    line3(corners[0], corners[4], boxPaint);
    line3(corners[1], corners[5], boxPaint);
    line3(corners[2], corners[6], boxPaint);
    line3(corners[3], corners[7], boxPaint);

    // Axes (through origin)
    line3(const _Vec3(-1.2, 0, 0), const _Vec3(1.2, 0, 0), axisPaint); // X
    line3(const _Vec3(0, -1.2, 0), const _Vec3(0, 1.2, 0), axisPaint); // Y
    line3(const _Vec3(0, 0, -1.2), const _Vec3(0, 0, 1.2), axisPaint); // Z

    // Depth-sort points back-to-front
    final rotated = points.map(rot).toList(growable: false);
    final indices = List<int>.generate(rotated.length, (i) => i)
      ..sort((a, b) => rotated[a].z.compareTo(rotated[b].z));

    for (final i in indices) {
      final v = rotated[i];

      // Subtle depth cue
      final depthT = ((v.z + 1.5) / 3.0).clamp(0.0, 1.0);
      final alpha = (0.45 + 0.55 * depthT).clamp(0.0, 1.0);
      final radius = (2.2 + 1.2 * depthT).clamp(1.8, 3.8);

      final paint = Paint()
        ..color = AppColors.textPrimary.withOpacity(alpha)
        ..isAntiAlias = true;

      canvas.drawCircle(proj(v), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _Scatter3DPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.points != points;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
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

List<double> _normalizeToUnit(List<double> values) {
  double mn = values.first;
  double mx = values.first;

  for (final v in values) {
    if (v < mn) mn = v;
    if (v > mx) mx = v;
  }

  final range = mx - mn;
  if (range == 0) {
    // If all values are identical, put them all on the origin of that axis.
    // (Other axes can still separate points.)
    return List<double>.filled(values.length, 0.0);
  }

  return values.map((v) => ((v - mn) / range) * 2.0 - 1.0).toList();
}

@immutable
class _Vec3 {
  final double x;
  final double y;
  final double z;

  const _Vec3(this.x, this.y, this.z);
}
