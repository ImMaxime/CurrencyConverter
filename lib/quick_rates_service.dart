import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists custom quick-rate amounts per currency pair.
///
/// When the user saves custom amounts they replace the default [10, 50, 100, 250]
/// for that pair.  Amounts are stored sorted from highest to lowest.
class QuickRatesService {
  static const defaultAmounts = [250, 100, 50, 10];
  static const _maxEntries = 8;

  String _key(String from, String to) => 'quick_rates_v1_${from}_$to';

  /// Returns saved amounts for [from]→[to], highest first.
  /// Falls back to [defaultAmounts] when nothing is saved.
  Future<List<int>> getAmounts(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(from, to));
    if (raw == null || raw.isEmpty) return List.of(defaultAmounts);
    final result = <int>[];
    for (final e in raw) {
      final v = int.tryParse(e);
      if (v != null && v > 0) result.add(v);
    }
    if (result.isEmpty) return List.of(defaultAmounts);
    result.sort((a, b) => b.compareTo(a));
    return result;
  }

  /// Saves a custom amount for [from]→[to].
  /// Merges with existing amounts, deduplicates, caps at [_maxEntries],
  /// and sorts highest-first.
  Future<void> addAmount(String from, String to, int amount) async {
    if (amount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await getAmounts(from, to);
    current.removeWhere((a) => a == amount);
    current.insert(0, amount);
    current.sort((a, b) => b.compareTo(a));
    if (current.length > _maxEntries) current.removeLast();
    await prefs.setStringList(
      _key(from, to),
      current.map((a) => a.toString()).toList(),
    );
  }

  /// Removes a single amount from the saved quick rates for [from]→[to].
  Future<void> removeAmount(String from, String to, int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(from, to));
    if (raw == null || raw.isEmpty) return;
    final current = <int>[];
    for (final e in raw) {
      final v = int.tryParse(e);
      if (v != null && v > 0) current.add(v);
    }
    current.removeWhere((a) => a == amount);
    if (current.isEmpty) {
      await prefs.remove(_key(from, to));
    } else {
      current.sort((a, b) => b.compareTo(a));
      await prefs.setStringList(
        _key(from, to),
        current.map((a) => a.toString()).toList(),
      );
    }
  }

  /// Resets to defaults by removing the saved key.
  Future<void> resetToDefaults(String from, String to) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(from, to));
    } catch (e, stack) {
      debugPrint('QuickRatesService: resetToDefaults failed: $e\n$stack');
    }
  }

  /// Returns true if the pair has custom (non-default) amounts saved.
  Future<bool> hasCustomAmounts(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(from, to));
    return raw != null && raw.isNotEmpty;
  }
}
