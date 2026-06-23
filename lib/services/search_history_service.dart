import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _key = 'magi_search_history';
const _max = 10;

class SearchHistoryService extends ChangeNotifier {
  List<String> _history = [];
  List<String> get history => _history;

  SearchHistoryService() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _history = List<String>.from(jsonDecode(raw));
      notifyListeners();
    }
  }

  Future<void> add(String query) async {
    query = query.trim();
    if (query.isEmpty) return;
    _history.remove(query);
    _history.insert(0, query);
    if (_history.length > _max) _history = _history.sublist(0, _max);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_history));
    notifyListeners();
  }

  Future<void> remove(String query) async {
    _history.remove(query);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_history));
    notifyListeners();
  }

  Future<void> clear() async {
    _history = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    notifyListeners();
  }
}
