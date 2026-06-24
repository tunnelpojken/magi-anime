import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

const _watchlistKey = 'magi_watchlist';

class WatchlistEntry {
  final int anilistId;
  final String title;
  final String? coverImage;
  final int? episodes;
  final String? status;
  final DateTime addedAt;

  WatchlistEntry({
    required this.anilistId,
    required this.title,
    this.coverImage,
    this.episodes,
    this.status,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() => {
    'anilistId': anilistId,
    'title': title,
    'coverImage': coverImage,
    'episodes': episodes,
    'status': status,
    'addedAt': addedAt.millisecondsSinceEpoch,
  };

  factory WatchlistEntry.fromJson(Map<String, dynamic> j) => WatchlistEntry(
    anilistId: j['anilistId'],
    title: j['title'],
    coverImage: j['coverImage'],
    episodes: j['episodes'],
    status: j['status'],
    addedAt: DateTime.fromMillisecondsSinceEpoch(j['addedAt']),
  );

  factory WatchlistEntry.fromMedia(AnilistMedia m) => WatchlistEntry(
    anilistId: m.id,
    title: m.title,
    coverImage: m.coverImage,
    episodes: m.episodes,
    status: m.status,
    addedAt: DateTime.now(),
  );
}

class WatchlistService extends ChangeNotifier {
  List<WatchlistEntry> _entries = [];
  List<WatchlistEntry> get entries => _entries;

  WatchlistService() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_watchlistKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _entries = list.map((e) => WatchlistEntry.fromJson(e as Map<String, dynamic>)).toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_watchlistKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  bool isInWatchlist(int anilistId) => _entries.any((e) => e.anilistId == anilistId);

  Future<void> toggle(AnilistMedia media) async {
    if (isInWatchlist(media.id)) {
      _entries.removeWhere((e) => e.anilistId == media.id);
    } else {
      _entries.insert(0, WatchlistEntry.fromMedia(media));
    }
    await _persist();
    notifyListeners();
  }

  Future<void> remove(int anilistId) async {
    _entries.removeWhere((e) => e.anilistId == anilistId);
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _entries.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_watchlistKey);
    notifyListeners();
  }
}
