class AnimeResult {
  final String id;
  final String name;
  final String provider;

  AnimeResult({required this.id, required this.name, required this.provider});

  factory AnimeResult.fromJson(Map<String, dynamic> json, String provider) {
    return AnimeResult(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      provider: provider,
    );
  }
}

class AnilistMedia {
  final int id;
  final int? idMal;
  final String title;
  final String? titleRomaji;
  final String? coverImage;
  final String? description;
  final int? episodes;
  final int? averageScore;
  final String? status;
  final int? year;
  final String? season;
  final List<String> genres;
  final String? trailerId;
  final List<AnilistRelation> relations;

  AnilistMedia({
    required this.id,
    this.idMal,
    required this.title,
    this.titleRomaji,
    this.coverImage,
    this.description,
    this.episodes,
    this.averageScore,
    this.status,
    this.year,
    this.season,
    required this.genres,
    this.trailerId,
    this.relations = const [],
  });

  factory AnilistMedia.fromJson(Map<String, dynamic> json) {
    final title = json['title'] as Map<String, dynamic>?;
    final coverImage = json['coverImage'] as Map<String, dynamic>?;
    final trailer = json['trailer'] as Map<String, dynamic>?;
    final relationsData = json['relations'] as Map<String, dynamic>?;
    final edges = relationsData?['edges'] as List? ?? [];
    return AnilistMedia(
      id: json['id'] ?? 0,
      idMal: json['idMal'] as int?,
      title: title?['english'] ?? title?['romaji'] ?? title?['native'] ?? 'Unknown',
      titleRomaji: title?['romaji'],
      coverImage: coverImage?['large'],
      description: json['description'],
      episodes: json['episodes'],
      averageScore: json['averageScore'],
      status: json['status'],
      year: json['seasonYear'],
      season: json['season'],
      genres: List<String>.from(json['genres'] ?? []),
      trailerId: (trailer != null && trailer['site'] == 'youtube') ? trailer['id'] as String? : null,
      relations: edges.map((e) => AnilistRelation.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }
}

class AnilistRelation {
  final String relationType;
  final int id;
  final String title;
  final String? coverImage;

  AnilistRelation({
    required this.relationType,
    required this.id,
    required this.title,
    this.coverImage,
  });

  factory AnilistRelation.fromJson(Map<String, dynamic> json) {
    final node = json['node'] as Map<String, dynamic>? ?? {};
    final title = node['title'] as Map<String, dynamic>?;
    final cover = node['coverImage'] as Map<String, dynamic>?;
    return AnilistRelation(
      relationType: json['relationType'] ?? '',
      id: node['id'] ?? 0,
      title: title?['english'] ?? title?['romaji'] ?? title?['native'] ?? 'Unknown',
      coverImage: cover?['large'],
    );
  }
}

class HistoryEntry {
  final String id;
  final String name;
  final String provider;
  final double episode;
  final String lang;
  final DateTime timestamp;
  final Duration? progress;

  HistoryEntry({
    required this.id,
    required this.name,
    required this.provider,
    required this.episode,
    required this.lang,
    required this.timestamp,
    this.progress,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'provider': provider,
    'episode': episode,
    'lang': lang,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'progressMs': progress?.inMilliseconds,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'],
    name: json['name'],
    provider: json['provider'],
    episode: (json['episode'] as num).toDouble(),
    lang: json['lang'],
    timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
    progress: json['progressMs'] != null
        ? Duration(milliseconds: json['progressMs'] as int)
        : null,
  );
}
