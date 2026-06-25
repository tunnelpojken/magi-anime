import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

const _defaultApi = 'http://192.168.0.37:3002';
const _anilistUrl = 'https://graphql.anilist.co';
const _mediaFields = '''
  id idMal title { english romaji native }
  coverImage { large }
  episodes averageScore status seasonYear season
  genres description(asHtml: false)
  trailer { id site }
  relations {
    edges {
      relationType
      node {
        id
        title { english romaji native }
        coverImage { large }
      }
    }
  }
  recommendations(perPage: 8, sort: RATING_DESC) {
    nodes {
      mediaRecommendation {
        id
        title { english romaji native }
        coverImage { large }
        averageScore
        episodes
        status
      }
    }
  }
''';

class ApiService extends ChangeNotifier {
  String _apiBase = _defaultApi;
  String get apiBase => _apiBase;

  ApiService() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _apiBase = prefs.getString('api_base') ?? _defaultApi;
    notifyListeners();
  }

  Future<void> setApiBase(String url) async {
    _apiBase = url.trimRight().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base', _apiBase);
    notifyListeners();
  }

  // --- Anipy API ---
  Future<List<AnimeResult>> search(String query, String provider) async {
    final uri = Uri.parse('$_apiBase/search?q=${Uri.encodeComponent(query)}&provider=$provider');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final results = data['results'] as List? ?? [];
    return results.map((r) => AnimeResult.fromJson(r as Map<String, dynamic>, provider)).toList();
  }

  Future<List<double>> getEpisodes(String id, String provider, String lang) async {
    final uri = Uri.parse('$_apiBase/episodes?id=${Uri.encodeComponent(id)}&provider=$provider&lang=$lang');
    final res = await http.get(uri).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final eps = data['episodes'] as List? ?? [];
    return eps.map((e) => (e as num).toDouble()).toList();
  }

  Future<String> getStreamUrl(String id, double episode, String provider, String lang) async {
    final uri = Uri.parse('$_apiBase/stream?id=${Uri.encodeComponent(id)}&episode=$episode&provider=$provider&lang=$lang');
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['url'] as String;
  }

  String getProxyUrl(String id, double episode, String provider, String lang) {
    return '$_apiBase/proxy?id=${Uri.encodeComponent(id)}&episode=$episode&provider=$provider&lang=$lang';
  }

  Future<List<String>> getProviders() async {
    final uri = Uri.parse('$_apiBase/providers');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return List<String>.from(data['providers'] ?? []);
  }

  // --- AniList API ---
  Future<Map<String, dynamic>> _anilistQuery(String query, [Map<String, dynamic>? variables]) async {
    final res = await http.post(
      Uri.parse(_anilistUrl),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'query': query, 'variables': variables}),
    ).timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    return data['data'] as Map<String, dynamic>;
  }

  Future<List<AnilistMedia>> fetchBrowseRowPaged(String query, {int perPage = 50, int pages = 999}) async {
    final all = <AnilistMedia>[];
    for (int page = 1; page <= pages; page++) {
      try {
        final data = await _anilistQuery('''
          query {
            Page(page: $page, perPage: $perPage) {
              pageInfo { hasNextPage }
              media($query, type: ANIME) { $_mediaFields }
            }
          }
        ''');
        final items = (data['Page']?['media'] as List?) ?? [];
        final parsed = items.where((i) => i != null)
            .map((i) => AnilistMedia.fromJson(i as Map<String, dynamic>))
            .toList();
        all.addAll(parsed);
        // Stop if no more pages
        final hasNextPage = data['Page']?['pageInfo']?['hasNextPage'] as bool? ?? false;
        if (!hasNextPage) break;
        // Small delay to respect AniList rate limit (90 req/min)
        await Future.delayed(const Duration(milliseconds: 700));
      } catch (_) { break; }
    }
    return all;
  }

  Future<List<AnilistMedia>> fetchBrowseRow(String mediaQuery) async {
    final data = await _anilistQuery('''
      query {
        Page(page: 1, perPage: 20) {
          media($mediaQuery, type: ANIME) { $_mediaFields }
        }
      }
    ''');
    final items = (data['Page']?['media'] as List?) ?? [];
    return items.where((i) => i != null).map((i) => AnilistMedia.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<AnilistMedia>> fetchSeasonal(int year, String season) async {
    final data = await _anilistQuery('''
      query {
        Page(page: 1, perPage: 50) {
          media(seasonYear: $year, season: $season, type: ANIME, sort: POPULARITY_DESC) { $_mediaFields }
        }
      }
    ''');
    final items = (data['Page']?['media'] as List?) ?? [];
    return items.where((i) => i != null).map((i) => AnilistMedia.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<Map<String, dynamic>?> fetchSkipTimes(int malId, int episode) async {
    try {
      // Try v1 API which has better coverage
      final uri = Uri.parse('https://api.aniskip.com/v1/skip-times/$malId/$episode?types=op&types=ed');
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['found'] != true) return null;
      final results = data['results'] as List?;
      if (results == null || results.isEmpty) return null;
      final Map<String, dynamic> times = {};
      for (final r in results) {
        final type = r['skipType'] as String?;
        final interval = r['interval'] as Map<String, dynamic>?;
        if (type != null && interval != null) {
          times[type] = {
            'start': (interval['startTime'] as num).toDouble(),
            'end': (interval['endTime'] as num).toDouble(),
          };
        }
      }
      return times.isEmpty ? null : times;
    } catch (e) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAiringSchedule(int from, int to) async {
    final data = await _anilistQuery('''
      query(\$from: Int, \$to: Int) {
        Page(page: 1, perPage: 50) {
          airingSchedules(airingAt_greater: \$from, airingAt_lesser: \$to, sort: TIME) {
            airingAt
            episode
            media {
              id
              title { english romaji }
              coverImage { large }
              averageScore
              status
            }
          }
        }
      }
    ''', {'from': from, 'to': to});
    return List<Map<String, dynamic>>.from(data['Page']?['airingSchedules'] ?? []);
  }

  Future<List<AnilistMedia>> advancedSearch({
    String? query,
    String sort = 'POPULARITY_DESC',
    String? genre,
    String? format,
    String? status,
    String? season,
    int? year,
    int? minScore,
  }) async {
    final filters = <String>[];
    if (query != null && query.isNotEmpty) filters.add('search: "${query.replaceAll('"', '')}"');
    filters.add('sort: [$sort]');
    filters.add('type: ANIME');
    if (genre != null) filters.add('genre: "$genre"');
    if (format != null) filters.add('format: $format');
    if (status != null) filters.add('status: $status');
    if (season != null) filters.add('season: $season');
    if (year != null) filters.add('seasonYear: $year');
    if (minScore != null) filters.add('averageScore_greater: $minScore');

    final data = await _anilistQuery('''
      query {
        Page(page: 1, perPage: 40) {
          media(${filters.join(', ')}) { $_mediaFields }
        }
      }
    ''');
    final items = (data['Page']?['media'] as List?) ?? [];
    return items.where((i) => i != null).map((i) => AnilistMedia.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<List<AnilistMedia>> anilistSearch(String query) async {
    final data = await _anilistQuery('''
      query(\$s: String) {
        Page(page: 1, perPage: 10) {
          media(search: \$s, type: ANIME) { $_mediaFields }
        }
      }
    ''', {'s': query});
    final items = (data['Page']?['media'] as List?) ?? [];
    return items.where((i) => i != null).map((i) => AnilistMedia.fromJson(i as Map<String, dynamic>)).toList();
  }

  Future<AnilistMedia?> fetchAnilistByName(String name) async {
    try {
      final data = await _anilistQuery(
        'query(\$s:String){Media(search:\$s,type:ANIME){$_mediaFields}}',
        {'s': name},
      );
      final media = data['Media'];
      if (media == null) return null;
      return AnilistMedia.fromJson(media as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<AnilistMedia?> fetchAnilistById(int id) async {
    try {
      final data = await _anilistQuery(
        'query(\$id:Int){Media(id:\$id,type:ANIME){$_mediaFields}}',
        {'id': id},
      );
      final media = data['Media'];
      if (media == null) return null;
      return AnilistMedia.fromJson(media as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
