import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SkipInterval {
  final double start;
  final double end;
  const SkipInterval({required this.start, required this.end});

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
  factory SkipInterval.fromJson(Map<String, dynamic> j) =>
      SkipInterval(start: (j['start'] as num).toDouble(), end: (j['end'] as num).toDouble());
}

class AnimeSkipTimes {
  final SkipInterval? intro;
  final SkipInterval? outro;
  const AnimeSkipTimes({this.intro, this.outro});

  Map<String, dynamic> toJson() => {
    if (intro != null) 'op': intro!.toJson(),
    if (outro != null) 'ed': outro!.toJson(),
  };

  factory AnimeSkipTimes.fromJson(Map<String, dynamic> j) => AnimeSkipTimes(
    intro: j['op'] != null ? SkipInterval.fromJson(j['op']) : null,
    outro: j['ed'] != null ? SkipInterval.fromJson(j['ed']) : null,
  );

  // Convert to the format used by _skipTimes in episode_screen
  Map<String, dynamic> toEpisodeFormat() => {
    if (intro != null) 'op': {'start': intro!.start, 'end': intro!.end},
    if (outro != null) 'ed': {'start': outro!.start, 'end': outro!.end},
  };
}

class SkipTimesService extends ChangeNotifier {
  static const _key = 'custom_skip_times';
  // Map of "malId_episode" -> AnimeSkipTimes
  final Map<String, AnimeSkipTimes> _times = {};

  SkipTimesService() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        _times[entry.key] = AnimeSkipTimes.fromJson(entry.value as Map<String, dynamic>);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(
      _times.map((k, v) => MapEntry(k, v.toJson()))
    ));
  }

  String _keyFor(int malId, int episode) => '${malId}_$episode';

  AnimeSkipTimes? get(int malId, int episode) => _times[_keyFor(malId, episode)];

  Future<void> save(int malId, int episode, {SkipInterval? intro, SkipInterval? outro}) async {
    final key = _keyFor(malId, episode);
    final existing = _times[key];
    _times[key] = AnimeSkipTimes(
      intro: intro ?? existing?.intro,
      outro: outro ?? existing?.outro,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> remove(int malId, int episode) async {
    _times.remove(_keyFor(malId, episode));
    await _persist();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _times.clear();
    await _persist();
    notifyListeners();
  }

  bool has(int malId, int episode) => _times.containsKey(_keyFor(malId, episode));
}
