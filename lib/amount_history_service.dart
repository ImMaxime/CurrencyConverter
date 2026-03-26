import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists a per-currency-pair history of amounts the user has researched.
///
/// Amounts are stored as plain strings (double values) under a key that
/// combines the from/to currency codes, e.g. `amount_history_v1_USD_EUR`.
class AmountHistoryService {
  static const _maxEntries = 8;

  String _key(String from, String to) => 'amount_history_v1_${from}_$to';

  /// Returns the stored history for [from]→[to], most-recent first.
  Future<List<double>> getHistory(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key(from, to)) ?? [];
    final result = <double>[];
    for (final e in raw) {
      final v = double.tryParse(e);
      if (v != null) result.add(v);
    }
    return result;
  }

  /// Adds [amount] to the history for [from]→[to].
  ///
  /// Duplicates are removed first so each value appears only once.
  /// The list is capped at [_maxEntries].
  Future<void> addAmount(String from, String to, double amount) async {
    if (amount <= 0) return;
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory(from, to);
    history.removeWhere((a) => a == amount);
    history.insert(0, amount);
    if (history.length > _maxEntries) history.removeLast();
    await prefs.setStringList(
      _key(from, to),
      history.map((a) => a.toString()).toList(),
    );
  }

  /// Removes all history entries for [from]→[to].
  Future<void> clearHistory(String from, String to) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(from, to));
    } catch (e, stack) {
      debugPrint('AmountHistoryService: clearHistory failed: $e\n$stack');
    }
  }
}
