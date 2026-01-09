import 'dart:math' as math;

/// Returns a "nice" interval size for ticks, similar to what you use in Plot2D.
/// targetTicks is how many tick *segments* you roughly want.
double niceInterval(double min, double max, {int targetTicks = 4}) {
  final range = (max - min).abs();
  if (range == 0) return 1;

  final raw = range / targetTicks;
  final mag = _pow10((log10(raw)).floor());

  final candidates = <double>[1 * mag, 2 * mag, 5 * mag, 10 * mag];

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

/// Builds tick values from a nice interval.
/// Includes both ends (snapped to interval) and returns ascending list.
List<double> buildTicks(double min, double max, {int targetTicks = 4}) {
  if (min == max) return [min];

  final step = niceInterval(min, max, targetTicks: targetTicks);

  final lo = (math.min(min, max) / step).floor() * step;
  final hi = (math.max(min, max) / step).ceil() * step;

  final out = <double>[];
  for (double v = lo; v <= hi + step * 0.5; v += step) {
    out.add(v);
  }
  return out;
}

String formatTick(double v) {
  // Simple, readable formatting (you can tweak later)
  if (v.abs() >= 1000) return v.toStringAsFixed(0);
  if (v.abs() >= 100) return v.toStringAsFixed(0);
  if (v.abs() >= 10) return v.toStringAsFixed(1);
  return v.toStringAsFixed(2);
}

double log10(double x) => (x <= 0) ? 0 : (math.log(x) / math.ln10);

double _pow10(int exp) {
  double v = 1;
  for (int i = 0; i < exp; i++) v *= 10;
  return v;
}

/// For date-as-index axes: pick an interval that yields ~6 labels max.
double dateTickInterval(int n) {
  if (n <= 1) return 1;
  if (n <= 6) return 1;
  if (n <= 12) return 2;
  if (n <= 20) return 3;
  return (n / 6).ceilToDouble();
}

/// Format a DateTime like Plot2D: "Aug 9"
String formatMonthDay(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}';
}

/// Format milliseconds since epoch into "Aug 9"
/// (Useful for plot data where dates are stored as epoch ms doubles)
String formatEpochMsMonthDay(double epochMs) {
  final dt = DateTime.fromMillisecondsSinceEpoch(epochMs.round());
  return formatMonthDay(dt);
}

/// Match Plot2D number format: 1 decimal place
String formatNum1(double v) => v.toStringAsFixed(1);