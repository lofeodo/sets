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

    return Padding(
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        painter: _Plot2DPainter(
          points: points,
          xLabel: spec.xAxis.label,
          yLabel: spec.yAxis.label,
          xIsDate: spec.xAxis == PlotAxis.date,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _Plot2DPainter extends CustomPainter {
  final List<PlotPoint2D> points;
  final String xLabel;
  final String yLabel;
  final bool xIsDate;

  _Plot2DPainter({
    required this.points,
    required this.xLabel,
    required this.yLabel,
    required this.xIsDate,
  });

  static const double _padLeft = 52;
  static const double _padBottom = 44;
  static const double _padTop = 16;
  static const double _padRight = 12;

  static const int _xTicks = 4;
  static const int _yTicks = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      _padLeft,
      _padTop,
      (size.width - _padLeft - _padRight).clamp(0, double.infinity),
      (size.height - _padTop - _padBottom).clamp(0, double.infinity),
    );

    // Border
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRect(rect, borderPaint);

    // Bounds
    double minX = points.first.x;
    double maxX = points.first.x;
    double minY = points.first.y;
    double maxY = points.first.y;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (minX == maxX) {
      minX -= 1;
      maxX += 1;
    }
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }

    // Map data -> pixel
    Offset toPixel(PlotPoint2D p) {
      final nx = (p.x - minX) / (maxX - minX);
      final ny = (p.y - minY) / (maxY - minY);

      final px = rect.left + nx * rect.width;
      final py = rect.bottom - ny * rect.height;

      return Offset(px, py);
    }

    // Sort by x for line plot
    final sorted = [...points]..sort((a, b) => a.x.compareTo(b.x));
    final mapped = sorted.map(toPixel).toList();

    // Line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(mapped.first.dx, mapped.first.dy);
    for (int i = 1; i < mapped.length; i++) {
      path.lineTo(mapped[i].dx, mapped[i].dy);
    }
    canvas.drawPath(path, linePaint);

    // Points
    final pointPaint = Paint()..style = PaintingStyle.fill;
    for (final m in mapped) {
      canvas.drawCircle(m, 3, pointPaint);
    }

    // Ticks (x and y)
    _drawXTicks(canvas, rect, minX, maxX);
    _drawYTicks(canvas, rect, minY, maxY);

    // Axis labels
    _drawText(
      canvas,
      text: xLabel,
      at: Offset(rect.center.dx, size.height - 16),
      align: TextAlign.center,
    );

    _drawRotatedText(
      canvas,
      text: yLabel,
      at: Offset(14, rect.center.dy),
    );
  }

  void _drawXTicks(Canvas canvas, Rect rect, double minX, double maxX) {
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final ticks = _linspace(minX, maxX, _xTicks);

    for (final t in ticks) {
      final nx = (t - minX) / (maxX - minX);
      final x = rect.left + nx * rect.width;

      // tick mark
      canvas.drawLine(
        Offset(x, rect.bottom),
        Offset(x, rect.bottom + 4),
        tickPaint,
      );

      final label = xIsDate ? _fmtDateFromMs(t) : _fmtNum(t);

      // label under tick
      _drawText(
        canvas,
        text: label,
        at: Offset(x, rect.bottom + 14),
        align: TextAlign.center,
      );
    }
  }

  void _drawYTicks(Canvas canvas, Rect rect, double minY, double maxY) {
    final tickPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final ticks = _linspace(minY, maxY, _yTicks);

    for (final t in ticks) {
      final ny = (t - minY) / (maxY - minY);
      final y = rect.bottom - ny * rect.height;

      // tick mark
      canvas.drawLine(
        Offset(rect.left - 4, y),
        Offset(rect.left, y),
        tickPaint,
      );

      final label = _fmtNum(t);

      // label left of tick
      _drawText(
        canvas,
        text: label,
        at: Offset(6, y),
        align: TextAlign.left,
      );
    }
  }

  List<double> _linspace(double a, double b, int n) {
    if (n <= 1) return [a];
    final out = <double>[];
    final step = (b - a) / (n - 1);
    for (int i = 0; i < n; i++) {
      out.add(a + step * i);
    }
    return out;
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

  void _drawText(
    Canvas canvas, {
    required String text,
    required Offset at,
    required TextAlign align,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
      maxLines: 1,
      ellipsis: '…',
    )..layout();

    final dx = align == TextAlign.center ? at.dx - tp.width / 2 : at.dx;
    tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
  }

  void _drawRotatedText(
    Canvas canvas, {
    required String text,
    required Offset at,
  }) {
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(-3.141592653589793 / 2); // -pi/2

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
      ellipsis: '…',
    )..layout();

    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _Plot2DPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.xLabel != xLabel ||
        oldDelegate.yLabel != yLabel ||
        oldDelegate.xIsDate != xIsDate;
  }
}