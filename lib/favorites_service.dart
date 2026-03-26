import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CurrencyPair {
  final String from;
  final String to;

  const CurrencyPair({required this.from, required this.to});

  Map<String, dynamic> toJson() => {'from': from, 'to': to};

  factory CurrencyPair.fromJson(Map<String, dynamic> json) =>
      CurrencyPair(from: json['from'] as String, to: json['to'] as String);

  @override
  bool operator ==(Object other) =>
      other is CurrencyPair && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class FavoritesService {
  static const _favoritesKey = 'favorites_v1';
  static const _recentsKey = 'recent_searches_v1';
  static const _maxRecents = 10;

  Future<List<CurrencyPair>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_favoritesKey) ?? [];
    return raw
        .map(
            (e) => CurrencyPair.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<bool> isFavorite(String from, String to) async {
    final favorites = await getFavorites();
    return favorites.contains(CurrencyPair(from: from, to: to));
  }

  Future<void> toggleFavorite(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getFavorites();
    final pair = CurrencyPair(from: from, to: to);
    if (favorites.contains(pair)) {
      favorites.remove(pair);
    } else {
      favorites.add(pair);
    }
    await prefs.setStringList(
      _favoritesKey,
      favorites.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<List<CurrencyPair>> getRecents() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_recentsKey) ?? [];
    return raw
        .map(
            (e) => CurrencyPair.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> addRecent(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = await getRecents();
    final pair = CurrencyPair(from: from, to: to);
    recents.removeWhere((p) => p == pair);
    recents.insert(0, pair);
    if (recents.length > _maxRecents) recents.removeLast();
    await prefs.setStringList(
      _recentsKey,
      recents.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> removeRecent(String from, String to) async {
    final prefs = await SharedPreferences.getInstance();
    final recents = await getRecents();
    recents.removeWhere((p) => p == CurrencyPair(from: from, to: to));
    await prefs.setStringList(
      _recentsKey,
      recents.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
