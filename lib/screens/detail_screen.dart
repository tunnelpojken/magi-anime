import 'package:flutter/material.dart';
import '../utils/transitions.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/watchlist_service.dart';
import 'episode_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF111827);
const _bg3 = Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFFcbd5e1);

class DetailScreen extends StatelessWidget {
  final AnilistMedia media;
  final String provider;

  const DetailScreen({super.key, required this.media, required this.provider});

  void _watch(BuildContext context) async {
    final api = context.read<ApiService>();
    final history = context.read<HistoryService>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _cyan)),
    );
    try {
      final results = await api.search(media.title, provider);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results found on provider')));
        return;
      }
      final anime = results.first;
      final saved = history.getEntry(anime.id);
      final screen = EpisodeScreen(anime: anime, anilistMedia: media, autoPlay: saved?.episode ?? 1.0, autoPlayResume: saved?.progress);
      Navigator.push(context, fadeSlideRoute(screen));
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _openRelation(BuildContext context, AnilistRelation rel) async {
    final api = context.read<ApiService>();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _cyan)),
    );
    try {
      final full = await api.fetchAnilistById(rel.id);
      if (!context.mounted) return;
      Navigator.pop(context);
      if (full != null) {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => DetailScreen(media: full, provider: provider),
        ));
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final score = media.averageScore != null ? '★ ${(media.averageScore! / 10).toStringAsFixed(1)}' : null;
    final synopsis = media.description?.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('\n', ' ').trim();
    final relevantRelations = media.relations.where((r) =>
      ['SEQUEL', 'PREQUEL', 'SIDE_STORY', 'SPIN_OFF', 'PARENT', 'ALTERNATIVE'].contains(r.relationType)
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0a0b0f),
      appBar: AppBar(
        title: Text(media.title, style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: _cyan), overflow: TextOverflow.ellipsis),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _textDim), onPressed: () => Navigator.pop(context)),
        actions: [
          Consumer<WatchlistService>(builder: (context, watchlist, _) {
            final inList = watchlist.isInWatchlist(media.id);
            return IconButton(
              icon: Icon(inList ? Icons.bookmark : Icons.bookmark_border, color: inList ? _cyan : _textDim),
              onPressed: () => watchlist.toggle(media),
              tooltip: inList ? 'Remove from watchlist' : 'Add to watchlist',
            );
          }),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover + info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (media.coverImage != null)
                    ClipRect(child: Image.network(media.coverImage!, width: 140, height: 200, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder()))
                  else _placeholder(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(media.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFFc8ccd8))),
                        if (media.titleRomaji != null && media.titleRomaji != media.title)
                          Padding(padding: const EdgeInsets.only(top: 4),
                            child: Text(media.titleRomaji!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _textDim))),
                        const SizedBox(height: 12),
                        Wrap(spacing: 8, runSpacing: 6, children: [
                          if (score != null) _badge(score, highlight: true),
                          if (media.episodes != null) _badge('${media.episodes} EP'),
                          if (media.year != null) _badge('${media.year}'),
                          if (media.season != null) _badge(media.season!),
                          if (media.status != null) _badge(media.status!.replaceAll('_', ' ')),
                        ]),
                        const SizedBox(height: 12),
                        if (media.genres.isNotEmpty)
                          Wrap(spacing: 6, runSpacing: 6, children: media.genres.map((g) => _genreChip(g)).toList()),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => _watch(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.5))),
                            child: const Text('▶  WATCH', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _cyan, letterSpacing: 2)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Synopsis
            if (synopsis != null && synopsis.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Text(synopsis, style: const TextStyle(fontSize: 13, color: _textDim, height: 1.7)),
              ),

            // Related anime
            if (relevantRelations.isNotEmpty) ...[
              const Divider(color: _border, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _sectionLabel('RELATED'),
              ),
              SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  itemCount: relevantRelations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final rel = relevantRelations[i];
                    return GestureDetector(
                      onTap: () => _openRelation(context, rel),
                      child: SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            rel.coverImage != null
                                ? Image.network(rel.coverImage!, width: 110, height: 110, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 110, height: 110, color: _bg3))
                                : Container(width: 110, height: 110, color: _bg3),
                            const SizedBox(height: 4),
                            Text(rel.relationType.replaceAll('_', ' '),
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: _cyan, letterSpacing: 1)),
                            Text(rel.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFc8ccd8), height: 1.3)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Recommendations
            if (media.recommendations.isNotEmpty) ...[
            if (media.recommendations.isNotEmpty) ...[
              const Divider(color: _border, height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: _sectionLabel('YOU MIGHT ALSO LIKE'),
              ),
              SizedBox(
                height: 220,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                  itemCount: media.recommendations.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final rec = media.recommendations[i];
                    return GestureDetector(
                      onTap: () => Navigator.push(context, fadeSlideRoute(
                        DetailScreen(media: rec, provider: provider),
                      )),
                      child: SizedBox(
                        width: 110,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              children: [
                                rec.coverImage != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.network(rec.coverImage!, width: 110, height: 154, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(width: 110, height: 154, color: _bg3)))
                                    : Container(width: 110, height: 154, color: _bg3, decoration: BoxDecoration(borderRadius: BorderRadius.circular(6))),
                                if (rec.averageScore != null)
                                  Positioned(
                                    top: 6, right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xE50a0b0f),
                                        borderRadius: BorderRadius.circular(3),
                                        border: Border.all(color: _cyan.withOpacity(0.4)),
                                      ),
                                      child: Text('★ ${(rec.averageScore! / 10).toStringAsFixed(1)}',
                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: _cyan)),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(rec.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFcbd5e1), height: 1.3)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
              const Divider(color: _border, height: 1),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('TRAILER'),
                    const SizedBox(height: 10),
                    _YoutubeThumb(videoId: media.trailerId!),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 140, height: 200, color: _bg3,
    child: const Center(child: Text('NO IMG', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim))),
  );

  Widget _sectionLabel(String text) => Row(children: [
    Text(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _textDim, letterSpacing: 3)),
    const SizedBox(width: 10),
    const Expanded(child: Divider(color: _border, height: 1)),
  ]);

  Widget _badge(String text, {bool highlight = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(border: Border.all(color: highlight ? _cyan.withOpacity(0.5) : _border)),
    child: Text(text, style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: highlight ? _cyan : _textDim, letterSpacing: 1)),
  );

  Widget _genreChip(String genre) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(color: _bg3, border: Border.all(color: _border)),
    child: Text(genre, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim)),
  );
}

class _YoutubeThumb extends StatelessWidget {
  final String videoId;
  const _YoutubeThumb({required this.videoId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Trailer: https://www.youtube.com/watch?v=$videoId')),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.network('https://img.youtube.com/vi/$videoId/mqdefault.jpg',
            width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(height: 180, color: _bg3,
              child: const Center(child: Text('TRAILER UNAVAILABLE', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _textDim))))),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: _cyan, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: _cyan.withOpacity(0.4), blurRadius: 20)],
            ),
            child: const Icon(Icons.play_arrow, color: Colors.black, size: 28),
          ),
        ],
      ),
    );
  }
}
