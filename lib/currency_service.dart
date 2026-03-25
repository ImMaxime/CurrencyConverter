import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyService {
  static const String _baseUrl = 'https://api.exchangerate-api.com/v4/latest';
  static const String _cachePrefix = 'rate_cache_';

  /// Fetches the exchange rate from [base] to [target].
  /// Returns a record with the rate and whether it came from cache.
  Future<({double? rate, bool fromCache})> fetchRate(
      String base, String target) async {
    if (base == target) return (rate: 1.0, fromCache: false);

    try {
      final rate = await _tryFetch(base, target);
      if (rate != null) {
        await _cacheRate(base, target, rate);
        return (rate: rate, fromCache: false);
      }
    } catch (_) {
      // Network or parse error — fall through to cached value.
    }
    final cached = await _getCachedRate(base, target);
    return (rate: cached, fromCache: cached != null);
  }

  Future<void> _cacheRate(String base, String target, double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('$_cachePrefix${base}_$target', rate);
  }

  Future<double?> _tryFetch(String from, String to) async {
    final uri = Uri.parse('$_baseUrl/$from');
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final rates = data['rates'] as Map<String, dynamic>?;
      if (rates != null && rates.containsKey(to)) {
        return (rates[to] as num).toDouble();
      }
    }
    return null;
  }

  Future<double?> _getCachedRate(String base, String target) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_cachePrefix${base}_$target';
    return prefs.containsKey(key) ? prefs.getDouble(key) : null;
  }

  /// Common currency codes for the picker.
  static const List<String> currencies = [
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'CAD',
    'AUD',
    'CHF',
    'CNY',
    'INR',
    'MXN',
    'BRL',
    'KRW',
    'SGD',
    'HKD',
    'NOK',
    'SEK',
    'DKK',
    'NZD',
    'ZAR',
    'TRY',
  ];

  static const Map<String, String> currencyFlags = {
    'USD': '🇺🇸',
    'EUR': '🇪🇺',
    'GBP': '🇬🇧',
    'JPY': '🇯🇵',
    'CAD': '🇨🇦',
    'AUD': '🇦🇺',
    'CHF': '🇨🇭',
    'CNY': '🇨🇳',
    'INR': '🇮🇳',
    'MXN': '🇲🇽',
    'BRL': '🇧🇷',
    'KRW': '🇰🇷',
    'SGD': '🇸🇬',
    'HKD': '🇭🇰',
    'NOK': '🇳🇴',
    'SEK': '🇸🇪',
    'DKK': '🇩🇰',
    'NZD': '🇳🇿',
    'ZAR': '🇿🇦',
    'TRY': '🇹🇷',
  };
}
