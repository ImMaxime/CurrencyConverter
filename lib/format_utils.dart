/// Formats [value] in a compact, human-readable style.
///
/// Examples: `1234.5` → `1.2k`, `2500000` → `2.5M`, `42.1` → `42.10`.
/// Approximate values are prefixed with `~`.
String formatCompactAmount(double value) {
  if (value >= 1000000) {
    final d = value / 1000000;
    final exact = (value % 1000000) < 0.5;
    final s = d >= 10 ? d.toStringAsFixed(0) : d.toStringAsFixed(1);
    return exact ? '${s}M' : '~${s}M';
  }
  if (value >= 10000) {
    final d = value / 1000;
    final exact = (value % 1000) < 0.5;
    final s = d.toStringAsFixed(0);
    return exact ? '${s}k' : '~${s}k';
  }
  if (value >= 1000) {
    final d = value / 1000;
    final exact = (value % 1000) < 0.5;
    final s = d.toStringAsFixed(1);
    return exact ? '${s}k' : '~${s}k';
  }
  if (value >= 100) {
    final rounded = double.parse(value.toStringAsFixed(1));
    final approx = (value - rounded).abs() > 0.05;
    return approx ? '~${value.toStringAsFixed(1)}' : value.toStringAsFixed(1);
  }
  return value.toStringAsFixed(2);
}

/// Formats an integer [value] in compact style.
///
/// Examples: `1000` → `1k`, `1500000` → `~1.5M`, `42` → `42`.
String formatCompactInt(int value) {
  if (value >= 1000000) {
    final d = value / 1000000;
    if (value % 1000000 == 0) return '${d.toStringAsFixed(0)}M';
    return '~${d.toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    final d = value / 1000;
    if (value % 1000 == 0) return '${d.toStringAsFixed(0)}k';
    return '~${d.toStringAsFixed(1)}k';
  }
  return '$value';
}
