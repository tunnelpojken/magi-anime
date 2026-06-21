import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

const _historyKey = 'magi_history';
const _maxHistory = 20;

class HistoryService extends ChangeNotifier {
  List<HistoryEntry> _entries = [];
  List<HistoryEntry> get entries => _entries;

  HistoryService() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List;
      _entries = list.map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>)).toList();
      _entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> save(String id, String name, String provider, double episode, String lang, {Duration? progress}) async {
    _entries.removeWhere((e) => e.id == id);
    _entries.insert(0, HistoryEntry(
      id: id, name: name, provider: provider,
      episode: episode, lang: lang, timestamp: DateTime.now(),
      progress: progress,
    ));
    if (_entries.length > _maxHistory) _entries = _entries.sublist(0, _maxHistory);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  HistoryEntry? getEntry(String id) {
    try {
      return _entries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}
