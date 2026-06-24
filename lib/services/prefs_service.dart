import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrefsService extends ChangeNotifier {
  bool _compactCards = false;
  bool _showScoreBadge = true;
  bool _showEpisodeCount = true;

  bool get compactCards => _compactCards;
  bool get showScoreBadge => _showScoreBadge;
  bool get showEpisodeCount => _showEpisodeCount;

  PrefsService() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _compactCards = prefs.getBool('compact_cards') ?? false;
    _showScoreBadge = prefs.getBool('show_score_badge') ?? true;
    _showEpisodeCount = prefs.getBool('show_episode_count') ?? true;
    notifyListeners();
  }

  Future<void> setCompactCards(bool v) async {
    _compactCards = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('compact_cards', v);
    notifyListeners();
  }

  Future<void> setShowScoreBadge(bool v) async {
    _showScoreBadge = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_score_badge', v);
    notifyListeners();
  }

  Future<void> setShowEpisodeCount(bool v) async {
    _showEpisodeCount = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_episode_count', v);
    notifyListeners();
  }

  Future<String> exportHistory(List<Map<String, dynamic>> entries) async {
    final json = jsonEncode(entries);
    final dir = await _getExportDir();
    final file = File('$dir/magi_history_${DateTime.now().millisecondsSinceEpoch}.json');
    await file.writeAsString(json);
    return file.path;
  }

  Future<String> _getExportDir() async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    return '$home/Downloads';
  }

  Future<List<Map<String, dynamic>>?> importHistory(String path) async {
    try {
      final file = File(path);
      final content = await file.readAsString();
      final data = jsonDecode(content) as List;
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }
}
