import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'plot_axis.dart';
import 'plot_data.dart';
import 'plot_spec.dart';
import 'plot_tick_utils.dart';

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

  // Pinch zoom: 1.0 == "fits perfectly within the frame"
  static const double _minZoom = 0.8;
  static const double _maxZoom = 3.0; // reachable in one pinch, not insane

  double _zoom = _minZoom;
  double _zoomStart = _minZoom;

  // World cube side length (plot space will be [0, axisLen] on each axis)
  static const double _axisLen = 0.8;

  // Cached points in plot-space [0, axisLen]
  List<_Vec3> _pts = const [];
  int? _selectedPointIndex;

  double _xMin = 0, _xMax = 1;
  double _yMin = 0, _yMax = 1;
  double _zMin = 0, _zMax = 1;

  Map<int, String> _xDateLabels = const {};
  Map<int, String> _yDateLabels = const {};
  Map<int, String> _zDateLabels = const {};

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

    // Date axes should be mapped to linear indices BEFORE rendering.
    final xMapped = _maybeMapDateToIndex(widget.spec.xAxis, xVals);
    final yMapped = _maybeMapDateToIndex(widget.spec.yAxis, yVals);
    final zMapped = _maybeMapDateToIndex(widget.spec.zAxis!, zVals);

    _xDateLabels = _buildDateIndexLabels(widget.spec.xAxis, xVals);
    _yDateLabels = _buildDateIndexLabels(widget.spec.yAxis, yVals);
    _zDateLabels = _buildDateIndexLabels(widget.spec.zAxis!, zVals);

    _xMin = xMapped.reduce(math.min);
    _xMax = xMapped.reduce(math.max);

    _yMin = yMapped.reduce(math.min);
    _yMax = yMapped.reduce(math.max);

    _zMin = zMapped.reduce(math.min);
    _zMax = zMapped.reduce(math.max);

    // Avoid division-by-zero in tick placement if range collapses
    if (_xMin == _xMax) { _xMin -= 1; _xMax += 1; }
    if (_yMin == _yMax) { _yMin -= 1; _yMax += 1; }
    if (_zMin == _zMax) { _zMin -= 1; _zMax += 1; }

    // ---- Expand axis bounds to the "outermost nice tick" ----
    final xTicks = buildTicks(_xMin, _xMax, targetTicks: 4);
    if (xTicks.isNotEmpty) {
      _xMin = xTicks.first;
      _xMax = xTicks.last;
    }

    final yTicks = buildTicks(_yMin, _yMax, targetTicks: 4);
    if (yTicks.isNotEmpty) {
      _yMin = yTicks.first;
      _yMax = yTicks.last;
    }

    final zTicks = buildTicks(_zMin, _zMax, targetTicks: 4);
    if (zTicks.isNotEmpty) {
      _zMin = zTicks.first;
      _zMax = zTicks.last;
    }

    // Normalize into [0,1] using the (possibly expanded) bounds
    final xs = _normalize01WithBounds(xMapped, _xMin, _xMax);
    final ys = _normalize01WithBounds(yMapped, _yMin, _yMax);
    final zs = _normalize01WithBounds(zMapped, _zMin, _zMax);

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

  int? _pickNearestPoint({
    required Offset localPos,
    required Size size,
    required double maxDistPx,
  }) {
    if (_pts.isEmpty) return null;

    // Must match painter constants/logic
    const pad = 6.0;
    const camDist = 3.2;

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    final cyaw = math.cos(_yaw);
    final syaw = math.sin(_yaw);
    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);

    final half = _axisLen * 0.5;
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

    _Proj2 projRaw(_Vec3 v) {
      final denom = camDist - (v.z / _axisLen);
      final p = 1.0 / denom;
      return _Proj2(v.x * p, v.y * p, v.z);
    }

    // Compute bounds of the rotated cube for fit-to-frame scaling (same as painter)
    final cubeCorners = <_Vec3>[
      _Vec3(0, 0, 0),
      _Vec3(_axisLen, 0, 0),
      _Vec3(_axisLen, _axisLen, 0),
      _Vec3(0, _axisLen, 0),
      _Vec3(0, 0, _axisLen),
      _Vec3(_axisLen, 0, _axisLen),
      _Vec3(_axisLen, _axisLen, _axisLen),
      _Vec3(0, _axisLen, _axisLen),
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

    final fitScale = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );

    // IMPORTANT: must match painter (painter uses fitScale * zoom)
    final scale = fitScale * _zoom;

    final midX = (minX + maxX) * 0.5;
    final midY = (minY + maxY) * 0.5;

    Offset toScreen(_Vec3 v) {
      final pr = projRaw(v);
      final sx = cx + (pr.x - midX) * scale;
      final sy = cy - (pr.y - midY) * scale;
      return Offset(sx, sy);
    }

    int? bestIdx;
    double bestD2 = maxDistPx * maxDistPx;

    for (int i = 0; i < _pts.length; i++) {
      final rp = rot(centerShift(_pts[i]));
      final s = toScreen(rp);
      final d2 = (s - localPos).distanceSquared;
      if (d2 < bestD2) {
        bestD2 = d2;
        bestIdx = i;
      }
    }

    return bestIdx;
  }

  Offset? _screenPosForPointIndex(int idx, Size size) {
    if (idx < 0 || idx >= _pts.length) return null;

    // MUST match painter math (including zoom)
    const pad = 6.0;
    const camDist = 3.2;

    final cx = size.width * 0.5;
    final cy = size.height * 0.5;

    final cyaw = math.cos(_yaw);
    final syaw = math.sin(_yaw);
    final cp = math.cos(_pitch);
    final sp = math.sin(_pitch);

    final half = _axisLen * 0.5;
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

    _Proj2 projRaw(_Vec3 v) {
      final denom = camDist - (v.z / _axisLen);
      final p = 1.0 / denom;
      return _Proj2(v.x * p, v.y * p, v.z);
    }

    // Compute fit bounds from rotated cube corners (same as painter)
    final cubeCorners = <_Vec3>[
      _Vec3(0, 0, 0),
      _Vec3(_axisLen, 0, 0),
      _Vec3(_axisLen, _axisLen, 0),
      _Vec3(0, _axisLen, 0),
      _Vec3(0, 0, _axisLen),
      _Vec3(_axisLen, 0, _axisLen),
      _Vec3(_axisLen, _axisLen, _axisLen),
      _Vec3(0, _axisLen, _axisLen),
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

    final fitScale = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );

    final scale = fitScale * _zoom; // <-- critical for correct positioning when zoomed

    final midX = (minX + maxX) * 0.5;
    final midY = (minY + maxY) * 0.5;

    Offset toScreen(_Vec3 v) {
      final pr = projRaw(v);
      final sx = cx + (pr.x - midX) * scale;
      final sy = cy - (pr.y - midY) * scale;
      return Offset(sx, sy);
    }

    final rp = rot(centerShift(_pts[idx]));
    return toScreen(rp);
  }

  Widget _buildTooltipOverlay(Size size) {
    final idx = _selectedPointIndex!;
    final p = _pts[idx];

    String fmtAxis({
      required String label,
      required double coord, // in plot-space [0..axisLen]
      required double min,
      required double max,
      required Map<int, String> dateLabels,
    }) {
      final v = min + (coord / _axisLen) * (max - min);

      // Date axis if dateLabels provided; use nearest index label
      if (dateLabels.isNotEmpty) {
        final k = v.round();
        final s = dateLabels[k];
        return '$label: ${s ?? ''}';
      }

      return '$label: ${formatTick(v)}';
    }

    final lines = <String>[
      fmtAxis(
        label: widget.spec.xAxis.label,
        coord: p.x,
        min: _xMin,
        max: _xMax,
        dateLabels: _xDateLabels,
      ),
      fmtAxis(
        label: widget.spec.yAxis.label,
        coord: p.y,
        min: _yMin,
        max: _yMax,
        dateLabels: _yDateLabels,
      ),
      fmtAxis(
        label: widget.spec.zAxis!.label,
        coord: p.z,
        min: _zMin,
        max: _zMax,
        dateLabels: _zDateLabels,
      ),
    ];

    final pos = _screenPosForPointIndex(idx, size) ?? Offset(size.width / 2, size.height / 2);

    // Tooltip placement (simple clamp)
    const tooltipH = 78.0;
    const margin = 8.0;

    double left = pos.dx + 12;
    double top = pos.dy - 12;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, constraints) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;

              final w = box.size.width;
              final h = box.size.height;

              double newLeft = left;
              double newTop = top;

              if (newLeft + w > size.width - margin) {
                newLeft = size.width - margin - w;
              }
              if (newLeft < margin) newLeft = margin;

              if (newTop < margin) {
                newTop = pos.dy + 12; // flip below
              }
              if (newTop + h > size.height - margin) {
                newTop = size.height - margin - h;
              }

              if (newLeft != left || newTop != top) {
                // trigger reposition
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  // force rebuild with updated position
                  setState(() {});
                });
              }
            });

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3A46),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  height: 1.25,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(lines[0]),
                    Text(lines[1]),
                    Text(lines[2]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
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
      behavior: HitTestBehavior.opaque,

      onScaleStart: (details) {
        _zoomStart = _zoom;
      },

      onScaleUpdate: (details) {
        setState(() {
          // 1-finger = rotate (stable, uses incremental delta each update)
          if (details.pointerCount == 1) {
            const rotSpeed = 0.01;
            _yaw += details.focalPointDelta.dx * rotSpeed;
            _pitch += details.focalPointDelta.dy * rotSpeed;
            _pitch = _pitch.clamp(-1.2, 1.2);
            return;
          }

          // 2+ fingers = zoom (scale is relative to gesture start)
          final nextZoom = (_zoomStart * details.scale).clamp(_minZoom, _maxZoom);
          _zoom = nextZoom;
        });
      },

      onLongPressStart: (d) {
        // Size of the plot widget
        final box = context.findRenderObject() as RenderBox;
        final size = box.size;

        final idx = _pickNearestPoint(
          localPos: d.localPosition,
          size: size,
          maxDistPx: 90, // pick radius in pixels
        );

        setState(() => _selectedPointIndex = idx);
      },

      onLongPressMoveUpdate: (d) {
        final box = context.findRenderObject() as RenderBox;
        final size = box.size;

        final idx = _pickNearestPoint(
          localPos: d.localPosition,
          size: size,
          maxDistPx: 90,
        );

        setState(() => _selectedPointIndex = idx);
      },

      onLongPressEnd: (_) {
        setState(() => _selectedPointIndex = null);
      },

      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(constraints.maxWidth, constraints.maxHeight);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _Scatter3DPainter(
                      points: _pts,
                      yaw: _yaw,
                      pitch: _pitch,
                      zoom: _zoom,
                      axisLen: _axisLen,
                      selectedIndex: _selectedPointIndex, // keep existing
                      xLabel: widget.spec.xAxis.label,
                      yLabel: widget.spec.yAxis.label,
                      zLabel: widget.spec.zAxis!.label,
                      labelStyle: textStyle,
                      xMin: _xMin,
                      xMax: _xMax,
                      yMin: _yMin,
                      yMax: _yMax,
                      zMin: _zMin,
                      zMax: _zMax,
                      xDateLabels: _xDateLabels,
                      yDateLabels: _yDateLabels,
                      zDateLabels: _zDateLabels,
                    ),
                  ),
                ),

                // Tooltip overlay
                if (_selectedPointIndex != null)
                  _buildTooltipOverlay(size),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Scatter3DPainter extends CustomPainter {
  final List<_Vec3> points;
  final int? selectedIndex;
  final double yaw;
  final double pitch;
  final double zoom;
  final double axisLen;
  final double xMin, xMax;
  final double yMin, yMax;
  final double zMin, zMax;

  final String xLabel;
  final String yLabel;
  final String zLabel;
  final TextStyle labelStyle;
  final Map<int, String> xDateLabels;
  final Map<int, String> yDateLabels;
  final Map<int, String> zDateLabels;

  const _Scatter3DPainter({
    required this.points,
    required this.selectedIndex,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.axisLen,
    required this.xLabel,
    required this.yLabel,
    required this.zLabel,
    required this.labelStyle,
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
    required this.zMin,
    required this.zMax,
    required this.xDateLabels,
    required this.yDateLabels,
    required this.zDateLabels,
  });

  String _labelForTick({
    required bool axisIsDate,
    required double tickValue,
    required double axisMin,
    required double axisMax,
    required Map<int, String> dateLabels,
  }) {
    if (!axisIsDate) return formatTick(tickValue);

    final idx = tickValue.round();
    return dateLabels[idx] ?? "";
    
  }

  @override
  void paint(Canvas canvas, Size size) {
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

    final fitScale = math.min(
      (size.width - 2 * pad) / spanX,
      (size.height - 2 * pad) / spanY,
    );

    // 1.0 = fit perfectly, >1 zoom in
    final scale = fitScale * zoom;

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

    // ---- Inner face outlines (the 3 far faces of the cube) ----
    final facePaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.45)
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    // Far corner (max,max,max)
    final a = axisLen;

    // Face at x = max (YZ plane): (a,0,0) -> (a,a,0) -> (a,a,a) -> (a,0,a)
    line3(_Vec3(a, 0, 0), _Vec3(a, a, 0), facePaint);
    line3(_Vec3(a, 0, a), _Vec3(a, 0, 0), facePaint);

    // Face at y = max (XZ plane): (0,a,0) -> (a,a,0) -> (a,a,a) -> (0,a,a)
    line3(_Vec3(0, a, 0), _Vec3(a, a, 0), facePaint);
    line3(_Vec3(0, a, a), _Vec3(0, a, 0), facePaint);

    // Face at z = max (XY plane): (0,0,a) -> (a,0,a) -> (a,a,a) -> (0,a,a)
    line3(_Vec3(0, 0, a), _Vec3(a, 0, a), facePaint);
    line3(_Vec3(0, a, a), _Vec3(0, 0, a), facePaint);

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

    // ── Ticks ─────────────────────────────────────────────────────────────

    final tickPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.6)
      ..strokeWidth = 1
      ..isAntiAlias = true;

    // Tick size in world space (small)
    final tickSize = axisLen * 0.04;

    // Helper: place a tick line + label for a point on an axis
    void drawTick({
      required _Vec3 axisPoint, // point ON the axis in plot-space
      required _Vec3 tickDir,   // direction for tick mark (small)
      required String label,
    }) {
      final a = toScreen(rot(centerShift(axisPoint)));
      final b = toScreen(rot(centerShift(_Vec3(
        axisPoint.x + tickDir.x,
        axisPoint.y + tickDir.y,
        axisPoint.z + tickDir.z,
      ))));

      canvas.drawLine(a, b, tickPaint);

      final tp = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      // Offset label slightly away from the tick end
      tp.paint(canvas, b + const Offset(4, 0) - Offset(0, tp.height / 2));
    }

    // Build nice ticks in DATA SPACE (real values)
    List<double> _clampTicks(double min, double max) {
      const eps = 1e-9;
      final raw = buildTicks(min, max, targetTicks: 4);

      // Keep only ticks inside [min, max]
      final out = raw.where((v) => v >= min - eps && v <= max + eps).toList();

      // Ensure we include the max tick exactly (nice ticks sometimes miss it after filtering)
      if (!out.any((v) => (v - max).abs() <= eps)) out.add(max);

      out.sort();
      return out;
    }

    final xTicks = _clampTicks(xMin, xMax);
    final yTicks = _clampTicks(yMin, yMax);
    final zTicks = _clampTicks(zMin, zMax);

    double _tickToAxisPos(double v, double min, double max) {
      final d = max - min;
      if (d.abs() < 1e-9) return 0.0;
      final t = (v - min) / d;
      return axisLen * t;
    }

    // ---- Grid lines on inner faces (aligned to ticks) ----
    final gridPaint = Paint()
      ..color = AppColors.textSecondary.withOpacity(0.18)
      ..strokeWidth = 1.0
      ..isAntiAlias = true;

    // Precompute tick positions in axis space
    final xTickPos = xTicks.map((v) => _tickToAxisPos(v, xMin, xMax)).toList();
    final yTickPos = yTicks.map((v) => _tickToAxisPos(v, yMin, yMax)).toList();
    final zTickPos = zTicks.map((v) => _tickToAxisPos(v, zMin, zMax)).toList();

    // Helper: skip boundary lines (0 and a) to avoid doubling edges
    bool _isInner(double p) => p > 1e-6 && p < a - 1e-6;

    // ---- Grid faces at the ORIGIN side: x=0, y=0, z=0 ----

    // Face x = 0 (YZ plane): lines parallel to Z for each Y tick, and parallel to Y for each Z tick
    for (final y in yTickPos) {
      if (_isInner(y)) line3(_Vec3(0, y, 0), _Vec3(0, y, a), gridPaint);
    }
    for (final z in zTickPos) {
      if (_isInner(z)) line3(_Vec3(0, 0, z), _Vec3(0, a, z), gridPaint);
    }

    // Face y = 0 (XZ plane): lines parallel to Z for each X tick, and parallel to X for each Z tick
    for (final x in xTickPos) {
      if (_isInner(x)) line3(_Vec3(x, 0, 0), _Vec3(x, 0, a), gridPaint);
    }
    for (final z in zTickPos) {
      if (_isInner(z)) line3(_Vec3(0, 0, z), _Vec3(a, 0, z), gridPaint);
    }

    // Face z = 0 (XY plane): lines parallel to Y for each X tick, and parallel to X for each Y tick
    for (final x in xTickPos) {
      if (_isInner(x)) line3(_Vec3(x, 0, 0), _Vec3(x, a, 0), gridPaint);
    }
    for (final y in yTickPos) {
      if (_isInner(y)) line3(_Vec3(0, y, 0), _Vec3(a, y, 0), gridPaint);
    }

    // X axis ticks: along +X from origin
    for (final v in xTicks) {
      if (v <= xMin + 1e-9) continue; // skip origin tick to avoid clutter
      final t = (v - xMin) / (xMax - xMin); // 0..1
      final p = _Vec3(axisLen * t, 0, 0);
      drawTick(
        axisPoint: p,
        tickDir: _Vec3(0, -tickSize, 0),
        label: _labelForTick(
          axisIsDate: xDateLabels.isNotEmpty,
          tickValue: v,
          axisMin: xMin,
          axisMax: xMax,
          dateLabels: xDateLabels,
        ),
      );
    }

    // Y axis ticks: along +Y
    for (final v in yTicks) {
      if (v <= yMin + 1e-9) continue;
      final t = (v - yMin) / (yMax - yMin);
      final p = _Vec3(0, axisLen * t, 0);
      drawTick(
        axisPoint: p,
        tickDir: _Vec3(-tickSize, 0, 0),
        label: _labelForTick(
          axisIsDate: yDateLabels.isNotEmpty,
          tickValue: v,
          axisMin: yMin,
          axisMax: yMax,
          dateLabels: yDateLabels,
        ),
      );
    }

    // Z axis ticks: along +Z
    for (final v in zTicks) {
      if (v <= zMin + 1e-9) continue;
      final t = (v - zMin) / (zMax - zMin);
      final p = _Vec3(0, 0, axisLen * t);
      drawTick(
        axisPoint: p,
        tickDir: _Vec3(tickSize, 0, 0),
        label: _labelForTick(
          axisIsDate: zDateLabels.isNotEmpty,
          tickValue: v,
          axisMin: zMin,
          axisMax: zMax,
          dateLabels: zDateLabels,
        ),
      );
    }

    // ── Projected 2D point clouds on the three origin faces (x=0, y=0, z=0) ──
    // Draw these BEFORE the real 3D points so they appear behind.
    final projPaint = Paint()
      ..color = AppColors.textPrimary.withOpacity(0.1)
      ..isAntiAlias = true;

    const projRadius = 1.8;

    void drawProjectedPoint(_Vec3 p) {
      final rp = rot(centerShift(p));
      canvas.drawCircle(toScreen(rp), projRadius, projPaint);
    }

    // NOTE: `points` are in plot-space [0..axisLen]. We project by "dropping" one coordinate.
    for (final p in points) {
      // On face x = 0 (YZ plane)
      drawProjectedPoint(_Vec3(0, p.y, p.z));

      // On face y = 0 (XZ plane)
      drawProjectedPoint(_Vec3(p.x, 0, p.z));

      // On face z = 0 (XY plane)
      drawProjectedPoint(_Vec3(p.x, p.y, 0));
    }

    // Points (depth-sort back-to-front)
    final rotatedPoints = points.map((p) => rot(centerShift(p))).toList(growable: false);
    final indices = List<int>.generate(rotatedPoints.length, (i) => i)
      ..sort((a, b) => rotatedPoints[a].z.compareTo(rotatedPoints[b].z));

    for (final i in indices) {
      if (selectedIndex != null && i == selectedIndex) continue;

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

        // ---- Selected point: oversized + orthogonal guide lines to axes ----
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length) {
      final p = points[selectedIndex!];

      final guidePaint = Paint()
        ..color = AppColors.accent.withOpacity(0.95)
        ..strokeWidth = 4.0
        ..isAntiAlias = true;

      // We draw guides to the ORIGIN-side faces you currently use (x=0, y=0, z=0),
      // then along that face to the corresponding axis.

      // X axis: drop to z=0 face (XY), then to x-axis line (y=0,z=0)
      final xFace = _Vec3(p.x, p.y, 0);
      final xAxis = _Vec3(p.x, 0, 0);

      // Y axis: drop to x=0 face (YZ), then to y-axis line (x=0,z=0)
      final yFace = _Vec3(0, p.y, p.z);
      final yAxis = _Vec3(0, p.y, 0);

      // Z axis: drop to y=0 face (XZ), then to z-axis line (x=0,y=0)
      final zFace = _Vec3(p.x, 0, p.z);
      final zAxis = _Vec3(0, 0, p.z);

      // Segment 1: point -> face
      line3(p, xFace, guidePaint);
      line3(p, yFace, guidePaint);
      line3(p, zFace, guidePaint);

      // Segment 2: face -> axis
      line3(xFace, xAxis, guidePaint);
      line3(yFace, yAxis, guidePaint);
      line3(zFace, zAxis, guidePaint);

      // Draw the selected point last (slightly larger)
      final rp = rot(centerShift(p));
      final sp = toScreen(rp);
      canvas.drawCircle(
        sp,
        7.0,
        Paint()
          ..color = AppColors.accent
          ..isAntiAlias = true,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Scatter3DPainter oldDelegate) {
    return oldDelegate.yaw != yaw ||
        oldDelegate.pitch != pitch ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.zoom != zoom ||
        oldDelegate.axisLen != axisLen ||
        oldDelegate.points != points ||
        oldDelegate.xLabel != xLabel ||
        oldDelegate.yLabel != yLabel ||
        oldDelegate.zLabel != zLabel ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.xMin != xMin ||
        oldDelegate.xMax != xMax ||
        oldDelegate.yMin != yMin ||
        oldDelegate.yMax != yMax ||
        oldDelegate.zMin != zMin ||
        oldDelegate.zMax != zMax;
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

List<double> _normalize01WithBounds(List<double> values, double mn, double mx) {
  final range = mx - mn;
  if (range == 0) {
    return List<double>.filled(values.length, 0.0);
  }

  return values.map((v) {
    final t = (v - mn) / range;
    // Clamp just in case floating error or values slightly outside due to "nice" expansion.
    if (t < 0) return 0.0;
    if (t > 1) return 1.0;
    return t;
  }).toList();
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

Map<int, String> _buildDateIndexLabels(PlotAxis axis, List<double> rawValues) {
  if (axis != PlotAxis.date) return const {};

  final unique = rawValues.toSet().toList()..sort();

  final map = <int, String>{};
  for (int i = 0; i < unique.length; i++) {
    map[i] = formatEpochMsMonthDay(unique[i]); // from plot_tick_utils.dart
  }
  return map;
}