import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/search_history_service.dart';
import '../utils/transitions.dart';
import 'detail_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg = Color(0xFF0a0b0f);
const _bg2 = Color(0xFF111827);
const _bg3 = Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textPrimary = Color(0xFFe2e8f0);
const _textSecondary = Color(0xFFcbd5e1);
const _textMuted = Color(0xFFcbd5e1);
const _red = Color(0xFFd44000);

const _genres = [
  'Action', 'Adventure', 'Comedy', 'Drama', 'Fantasy', 'Horror',
  'Mecha', 'Music', 'Mystery', 'Psychological', 'Romance', 'Sci-Fi',
  'Slice of Life', 'Sports', 'Supernatural', 'Thriller',
];

const _formats = ['TV', 'MOVIE', 'OVA', 'ONA', 'SPECIAL', 'MUSIC'];
const _statuses = ['RELEASING', 'FINISHED', 'NOT_YET_RELEASED', 'CANCELLED'];
const _seasons = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];
const _sorts = [
  {'label': 'Popularity', 'value': 'POPULARITY_DESC'},
  {'label': 'Score', 'value': 'SCORE_DESC'},
  {'label': 'Trending', 'value': 'TRENDING_DESC'},
  {'label': 'Newest', 'value': 'START_DATE_DESC'},
  {'label': 'Oldest', 'value': 'START_DATE'},
  {'label': 'Episodes', 'value': 'EPISODES_DESC'},
];

class SearchScreen extends StatefulWidget {
  final String provider;
  const SearchScreen({super.key, required this.provider});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  String _sort = 'POPULARITY_DESC';
  String? _genre;
  String? _format;
  String? _status;
  String? _season;
  int? _year;
  int? _minScore;
  final _yearController = TextEditingController();

  List<AnilistMedia> _results = [];
  bool _searching = false;
  String? _error;
  bool _showFilters = false;

  @override
  void dispose() {
    _searchController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    setState(() { _searching = true; _error = null; });

    final history = context.read<SearchHistoryService>();
    if (q.isNotEmpty) await history.add(q);

    try {
      final api = context.read<ApiService>();
      final results = await api.advancedSearch(
        query: q.isEmpty ? null : q,
        sort: _sort,
        genre: _genre,
        format: _format,
        status: _status,
        season: _season,
        year: _year,
        minScore: _minScore,
      );
      setState(() { _results = results; _searching = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _searching = false; });
    }
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        margin: const EdgeInsets.only(right: 6, bottom: 6),
        decoration: BoxDecoration(
          color: selected ? _cyan.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: selected ? _cyan.withOpacity(0.5) : _border),
        ),
        child: Text(label, style: TextStyle(
          fontFamily: 'monospace', fontSize: 10,
          color: selected ? _cyan : _textMuted,
          letterSpacing: 1,
        )),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<SearchHistoryService>();
    final historyList = history.history;

    return Column(
      children: [
          // Search bar
          Container(
            color: _bg3,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: _bg2, borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _border),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 12),
                    const Icon(Icons.search, color: _textMuted, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(fontSize: 13, color: _textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Search anime...',
                          hintStyle: TextStyle(color: _textMuted, fontSize: 13),
                          border: InputBorder.none, isDense: true,
                        ),
                        onSubmitted: (_) => _search(),
                      ),
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close, size: 16, color: _textMuted),
                        onPressed: () { _searchController.clear(); setState(() {}); },
                      ),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _showFilters = !_showFilters),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  height: 42, width: 42,
                  decoration: BoxDecoration(
                    color: _showFilters ? _cyan.withOpacity(0.15) : _bg2,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _showFilters ? _cyan.withOpacity(0.5) : _border),
                  ),
                  child: Icon(Icons.tune, size: 18, color: _showFilters ? _cyan : _textMuted),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _search,
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(color: _cyan, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Text('GO', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF0a0b0f), letterSpacing: 1,
                  ))),
                ),
              ),
            ]),
          ),

          // Filters panel
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _showFilters ? Container(
              color: _bg3,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sort
                  const Text('SORT BY', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _textMuted, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Wrap(
                    children: _sorts.map((s) => _filterChip(
                      s['label']!, _sort == s['value'],
                      () => setState(() => _sort = s['value']!),
                    )).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Genre
                  const Text('GENRE', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _textMuted, letterSpacing: 2)),
                  const SizedBox(height: 6),
                  Wrap(
                    children: _genres.map((g) => _filterChip(
                      g, _genre == g,
                      () => setState(() => _genre = _genre == g ? null : g),
                    )).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Format + Status + Season in a row
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('FORMAT', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _textMuted, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        Wrap(children: _formats.map((f) => _filterChip(
                          f, _format == f,
                          () => setState(() => _format = _format == f ? null : f),
                        )).toList()),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('SEASON', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _textMuted, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        Wrap(children: _seasons.map((s) => _filterChip(
                          s, _season == s,
                          () => setState(() => _season = _season == s ? null : s),
                        )).toList()),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 10),

                  // Year + Min Score
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('YEAR', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _textMuted, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        Container(
                          height: 36,
                          decoration: BoxDecoration(color: _bg2, borderRadius: BorderRadius.circular(6), border: Border.all(color: _border)),
                          child: TextField(
                            controller: _yearController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textPrimary),
                            decoration: const InputDecoration(
                              hintText: 'e.g. 2024',
                              hintStyle: TextStyle(fontFamily: 'monospace', color: _textMuted, fontSize: 12),
                              border: InputBorder.none, isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (v) => _year = int.tryParse(v),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('MIN SCORE', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _textMuted, letterSpacing: 2)),
                        const SizedBox(height: 6),
                        Wrap(children: [60, 70, 75, 80, 85, 90].map((score) => _filterChip(
                          '${(score / 10).toStringAsFixed(0)}+', _minScore == score,
                          () => setState(() => _minScore = _minScore == score ? null : score),
                        )).toList()),
                      ]),
                    ),
                  ]),

                  // Clear filters
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setState(() {
                      _genre = null; _format = null; _status = null;
                      _season = null; _year = null; _minScore = null;
                      _sort = 'POPULARITY_DESC'; _yearController.clear();
                    }),
                    child: Text('CLEAR ALL FILTERS', style: TextStyle(
                      fontFamily: 'monospace', fontSize: 10, color: _red.withOpacity(0.8), letterSpacing: 1,
                    )),
                  ),
                ],
              ),
            ) : const SizedBox.shrink(),
          ),

          const Divider(color: _border, height: 1),

          // Search history or results
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
                : _error != null
                    ? Center(child: Text('Error: $_error', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _red)))
                    : _results.isEmpty && _searchController.text.isEmpty
                        ? _SearchHistory(
                            history: historyList,
                            onTap: (q) {
                              _searchController.text = q;
                              _search();
                            },
                            onRemove: (q) => history.remove(q),
                            onClear: () => history.clear(),
                          )
                        : _results.isEmpty
                            ? const Center(child: Text('No results found', style: TextStyle(fontSize: 14, color: _textMuted)))
                            : GridView.builder(
                                padding: const EdgeInsets.all(16),
                                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 160, childAspectRatio: 0.55,
                                  crossAxisSpacing: 12, mainAxisSpacing: 12,
                                ),
                                itemCount: _results.length,
                                itemBuilder: (context, i) {
                                  final m = _results[i];
                                  final score = m.averageScore != null
                                      ? '★ ${(m.averageScore! / 10).toStringAsFixed(1)}' : null;
                                  return GestureDetector(
                                    onTap: () => Navigator.push(context, fadeSlideRoute(
                                      DetailScreen(media: m, provider: widget.provider),
                                    )),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Stack(children: [
                                            m.coverImage != null
                                                ? ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: Image.network(m.coverImage!, width: double.infinity, fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Container(color: _bg2)))
                                                : Container(decoration: BoxDecoration(color: _bg2, borderRadius: BorderRadius.circular(6))),
                                            if (score != null)
                                              Positioned(top: 6, right: 6,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xE50a0b0f),
                                                    borderRadius: BorderRadius.circular(3),
                                                    border: Border.all(color: _cyan.withOpacity(0.4)),
                                                  ),
                                                  child: Text(score, style: const TextStyle(fontFamily: 'monospace', fontSize: 9, color: _cyan)),
                                                )),
                                          ]),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary, height: 1.3)),
                                        if (m.episodes != null)
                                          Text('${m.episodes} EP', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted)),
                                      ],
                                    ),
                                  );
                                },
                              ),
          ),
        ],
      );
  }
}

class _SearchHistory extends StatelessWidget {
  final List<String> history;
  final void Function(String) onTap;
  final void Function(String) onRemove;
  final VoidCallback onClear;

  const _SearchHistory({required this.history, required this.onTap, required this.onRemove, required this.onClear});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return const Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.history, color: _textMuted, size: 40),
          SizedBox(height: 12),
          Text('No recent searches', style: TextStyle(fontSize: 14, color: _textMuted)),
        ]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            const Text('RECENT SEARCHES', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted, letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: onClear,
              child: const Text('CLEAR ALL', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _red, letterSpacing: 1)),
            ),
          ]),
        ),
        const Divider(color: _border, height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, i) => InkWell(
              onTap: () => onTap(history[i]),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border, width: 0.5))),
                child: Row(children: [
                  const Icon(Icons.history, size: 16, color: _textMuted),
                  const SizedBox(width: 12),
                  Expanded(child: Text(history[i], style: const TextStyle(fontSize: 14, color: _textPrimary))),
                  IconButton(
                    icon: const Icon(Icons.close, size: 14, color: _textMuted),
                    onPressed: () => onRemove(history[i]),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
