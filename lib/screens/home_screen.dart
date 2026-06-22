import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/watchlist_service.dart';
import '../services/update_service.dart';
import '../models/models.dart';
import '../widgets/anime_card.dart';
import '../widgets/browse_card.dart';
import '../widgets/history_card.dart';
import '../widgets/shimmer.dart';
import 'detail_screen.dart';
import 'episode_screen.dart';
import 'settings_screen.dart';
import 'seasonal_screen.dart';
import 'watchlist_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFF5a6080);

const _browseRows = [
  {'label': 'CURRENTLY AIRING', 'query': 'status: RELEASING, sort: POPULARITY_DESC'},
  {'label': 'TRENDING NOW', 'query': 'sort: TRENDING_DESC'},
  {'label': 'ALL TIME POPULAR', 'query': 'sort: POPULARITY_DESC'},
  {'label': 'ACTION', 'query': 'genre: "Action", sort: POPULARITY_DESC'},
  {'label': 'ADVENTURE', 'query': 'genre: "Adventure", sort: POPULARITY_DESC'},
  {'label': 'FANTASY', 'query': 'genre: "Fantasy", sort: POPULARITY_DESC'},
  {'label': 'SCI-FI', 'query': 'genre: "Sci-Fi", sort: POPULARITY_DESC'},
  {'label': 'ROMANCE', 'query': 'genre: "Romance", sort: POPULARITY_DESC'},
  {'label': 'HORROR', 'query': 'genre: "Horror", sort: POPULARITY_DESC'},
  {'label': 'COMEDY', 'query': 'genre: "Comedy", sort: POPULARITY_DESC'},
  {'label': 'SPORTS', 'query': 'genre: "Sports", sort: POPULARITY_DESC'},
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _provider = 'allanime';
  List<AnimeResult> _searchResults = [];
  List<AnilistMedia> _anilistResults = [];
  bool _searching = false;
  String? _searchError;
  final Map<String, List<AnilistMedia>> _browseCache = {};
  final Map<String, String> _browseErrors = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBrowse();
    // Check for updates after a short delay so UI loads first
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) UpdateService.checkForUpdates(context);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBrowse({String? onlyLabel}) async {
    final api = context.read<ApiService>();
    final rows = onlyLabel != null
        ? _browseRows.where((r) => r['label'] == onlyLabel).toList()
        : _browseRows;
    for (final row in rows) {
      if (onlyLabel != null) {
        if (mounted) setState(() => _browseErrors.remove(onlyLabel));
      }
      try {
        final items = await api.fetchBrowseRow(row['query']!);
        if (mounted) setState(() => _browseCache[row['label']!] = items);
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        if (mounted) setState(() => _browseErrors[row['label']!] = e.toString());
      }
    }
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    final provider = _provider;
    setState(() { _searching = true; _searchError = null; _searchResults = []; _anilistResults = []; });
    try {
      final api = context.read<ApiService>();
      // Run both searches in parallel
      final results = await Future.wait([
        api.search(q, provider),
        _searchAnilist(q, api),
      ]);
      setState(() {
        _searchResults = results[0] as List<AnimeResult>;
        _anilistResults = results[1] as List<AnilistMedia>;
        _searching = false;
      });
    } catch (e) {
      setState(() { _searchError = e.toString(); _searching = false; });
    }
  }

  Future<List<AnilistMedia>> _searchAnilist(String q, ApiService api) async {
    try {
      final data = await api.anilistSearch(q);
      return data;
    } catch (_) {
      return [];
    }
  }

  void _openDetail(AnilistMedia media) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DetailScreen(media: media, provider: _provider),
    ));
  }

  void _openDetailByName(String name) async {
    final api = context.read<ApiService>();
    final media = await api.fetchAnilistByName(name);
    if (!mounted) return;
    if (media != null) {
      _openDetail(media);
    } else {
      // No AniList info, go straight to search
      _searchController.text = name;
      _tabController.animateTo(1);
      _search();
    }
  }

  void _openEpisodes(AnimeResult anime) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EpisodeScreen(anime: anime),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: DragToMoveArea(
          child: AppBar(
            toolbarHeight: 44,
            centerTitle: true,
            automaticallyImplyLeading: false,
            title: const Text('MAGI', style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 4,
              color: _cyan,
            )),
            actions: [
              IconButton(
                iconSize: 18,
                icon: const Icon(Icons.remove, color: _textDim),
                onPressed: () => windowManager.minimize(),
              ),
              IconButton(
                iconSize: 18,
                icon: const Icon(Icons.close, color: _textDim),
                onPressed: () => windowManager.close(),
              ),
              const SizedBox(width: 4),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(16),
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  TabBar(
                    controller: _tabController,
                    labelColor: _cyan,
                    unselectedLabelColor: _textDim,
                    indicatorColor: _cyan,
                    tabAlignment: TabAlignment.start,
                    isScrollable: true,
                    labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: 2),
                    tabs: const [Tab(text: 'BROWSE'), Tab(text: 'SEARCH'), Tab(text: 'WATCHLIST')],
                  ),
                  IconButton(
                    iconSize: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    icon: const Icon(Icons.calendar_month, color: _textDim),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => SeasonalScreen(provider: _provider),
                    )),
                  ),
                  IconButton(
                    iconSize: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    icon: const Icon(Icons.settings, color: _textDim),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _BrowseTab(
            browseCache: _browseCache,
            browseErrors: _browseErrors,
            browseRows: _browseRows,
            onCardTap: _openDetail,
            onHistoryTap: _openEpisodes,
            onRetry: (label) => _loadBrowse(onlyLabel: label),
          ),
          _SearchTab(
            controller: _searchController,
            provider: _provider,
            results: _searchResults,
            anilistResults: _anilistResults,
            searching: _searching,
            error: _searchError,
            onProviderChanged: (v) => setState(() => _provider = v!),
            onSearch: _search,
            onResultTap: _openDetailByName,
            onAnilistTap: _openDetail,
          ),
          WatchlistScreen(provider: _provider),
        ],
      ),
    );
  }
}

// --- BROWSE TAB ---
class _BrowseTab extends StatelessWidget {
  final Map<String, List<AnilistMedia>> browseCache;
  final Map<String, String> browseErrors;
  final List<Map<String, String>> browseRows;
  final void Function(AnilistMedia) onCardTap;
  final void Function(AnimeResult) onHistoryTap;
  final void Function(String) onRetry;

  const _BrowseTab({
    required this.browseCache,
    required this.browseErrors,
    required this.browseRows,
    required this.onCardTap,
    required this.onHistoryTap,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Continue watching
        Consumer<HistoryService>(builder: (context, history, _) {
          if (history.entries.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('CONTINUE WATCHING'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 90,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      primary: false,
                      itemCount: history.entries.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final e = history.entries[i];
                        return HistoryCardWidget(
                          entry: e,
                          onTap: () => onHistoryTap(AnimeResult(id: e.id, name: e.name, provider: e.provider)),
                          onRemove: () => context.read<HistoryService>().remove(e.id),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        }),
        // Browse rows
        for (final row in browseRows)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(row['label']!),
                  const SizedBox(height: 12),
                  browseErrors.containsKey(row['label'])
                      ? SizedBox(
                          height: 240,
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              const Text('LOAD ERROR', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFd44000))),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () => onRetry(row['label']!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                  decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.4))),
                                  child: const Text('RETRY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 2)),
                                ),
                              ),
                            ]),
                          ),
                        )
                      : _ScrollableRow(
                          items: browseCache[row['label']] ?? [],
                          loading: !browseCache.containsKey(row['label']),
                          onCardTap: onCardTap,
                        ),
                ],
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// --- SEARCH TAB ---
class _SearchTab extends StatelessWidget {
  final TextEditingController controller;
  final String provider;
  final List<AnimeResult> results;
  final List<AnilistMedia> anilistResults;
  final bool searching;
  final String? error;
  final void Function(String?) onProviderChanged;
  final VoidCallback onSearch;
  final void Function(String) onResultTap;
  final void Function(AnilistMedia) onAnilistTap;

  const _SearchTab({
    required this.controller,
    required this.provider,
    required this.results,
    required this.anilistResults,
    required this.searching,
    required this.error,
    required this.onProviderChanged,
    required this.onSearch,
    required this.onResultTap,
    required this.onAnilistTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasResults = results.isNotEmpty || anilistResults.isNotEmpty;
    return Column(
      children: [
        Container(
          color: _bg2,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFc8ccd8)),
                  decoration: InputDecoration(
                    hintText: 'SEARCH DESIGNATION...',
                    hintStyle: const TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 13),
                    filled: true, fillColor: _bg3,
                    border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                    enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                    focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _cyan), borderRadius: BorderRadius.zero),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  onSubmitted: (_) => onSearch(),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(color: _bg3, border: Border.all(color: _border)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: provider, dropdownColor: _bg2,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textDim),
                    items: const [
                      DropdownMenuItem(value: 'allanime', child: Text('ALLANIME')),
                      DropdownMenuItem(value: 'animekai', child: Text('ANIMEKAI')),
                    ],
                    onChanged: onProviderChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onSearch,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.5))),
                  child: const Text('EXECUTE', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _cyan, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: searching
              ? const Center(child: CircularProgressIndicator(color: _cyan))
              : error != null
                  ? Center(child: Text('ERROR: $error', style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFd44000), fontSize: 12)))
                  : !hasResults
                      ? const Center(child: Text('AWAITING INPUT', style: TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 12, letterSpacing: 2)))
                      : Row(
                          children: [
                            // AniList results panel
                            if (anilistResults.isNotEmpty)
                              SizedBox(
                                width: 200,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                      color: _bg2,
                                      child: const Row(children: [
                                        Text('ANILIST', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim, letterSpacing: 2)),
                                        SizedBox(width: 8),
                                        Expanded(child: Divider(color: _border, height: 1)),
                                      ]),
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: anilistResults.length,
                                        itemBuilder: (context, i) {
                                          final m = anilistResults[i];
                                          return GestureDetector(
                                            onTap: () => onAnilistTap(m),
                                            child: Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: _border, width: 0.5)),
                                              ),
                                              child: Row(children: [
                                                if (m.coverImage != null)
                                                  Image.network(m.coverImage!, width: 40, height: 56, fit: BoxFit.cover,
                                                    errorBuilder: (_, __, ___) => Container(width: 40, height: 56, color: _bg3))
                                                else
                                                  Container(width: 40, height: 56, color: _bg3),
                                                const SizedBox(width: 10),
                                                Expanded(child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontSize: 12, color: Color(0xFFc8ccd8), height: 1.3)),
                                                    if (m.averageScore != null)
                                                      Text('★ ${(m.averageScore! / 10).toStringAsFixed(1)}',
                                                        style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan)),
                                                  ],
                                                )),
                                              ]),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (anilistResults.isNotEmpty)
                              const VerticalDivider(color: _border, width: 1),
                            // Provider results
                            Expanded(
                              child: results.isEmpty
                                  ? const Center(child: Text('NO PROVIDER RESULTS', style: TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 11, letterSpacing: 1)))
                                  : Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                          color: _bg2,
                                          child: Row(children: [
                                            Text(provider.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim, letterSpacing: 2)),
                                            const SizedBox(width: 8),
                                            const Expanded(child: Divider(color: _border, height: 1)),
                                          ]),
                                        ),
                                        Expanded(
                                          child: GridView.builder(
                                            padding: const EdgeInsets.all(12),
                                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                              maxCrossAxisExtent: 200, childAspectRatio: 1.6, crossAxisSpacing: 8, mainAxisSpacing: 8,
                                            ),
                                            itemCount: results.length,
                                            itemBuilder: (context, i) => AnimeCardWidget(
                                              anime: results[i],
                                              onTap: () => onResultTap(results[i].name),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ],
                        ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 11,
          color: _textDim, letterSpacing: 3,
        )),
        const SizedBox(width: 10),
        const Expanded(child: Divider(color: _border, height: 1)),
      ],
    );
  }
}


// --- SCROLLABLE ROW WITH ARROW BUTTONS ---
class _ScrollableRow extends StatefulWidget {
  final List<AnilistMedia> items;
  final bool loading;
  final void Function(AnilistMedia) onCardTap;

  const _ScrollableRow({
    required this.items,
    required this.loading,
    required this.onCardTap,
  });

  @override
  State<_ScrollableRow> createState() => _ScrollableRowState();
}

class _ScrollableRowState extends State<_ScrollableRow> {
  final ScrollController _sc = ScrollController();
  bool _atStart = true;
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    _sc.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
  }

  void _onScroll() {
    if (!_sc.hasClients) return;
    setState(() {
      _atStart = _sc.position.pixels <= 0;
      _atEnd = _sc.position.pixels >= _sc.position.maxScrollExtent;
    });
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  void _scrollLeft() {
    _sc.animateTo(
      (_sc.offset - 400).clamp(0.0, _sc.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _scrollRight() {
    _sc.animateTo(
      (_sc.offset + 400).clamp(0.0, _sc.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          // The list
          widget.loading
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  controller: _sc,
                  itemCount: 10,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => const ShimmerBrowseCard(),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  controller: _sc,
                  itemCount: widget.items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final media = widget.items[i];
                    return BrowseCardWidget(media: media, onTap: () => widget.onCardTap(media));
                  },
                ),
          // Left arrow
          if (!_atStart)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: GestureDetector(
                onTap: _scrollLeft,
                child: Container(
                  width: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [Colors.transparent, const Color(0xFF0a0b0f).withOpacity(0.9)],
                    ),
                  ),
                  child: const Icon(Icons.chevron_left, color: _cyan, size: 28),
                ),
              ),
            ),
          // Right arrow
          if (!_atEnd && !widget.loading)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: GestureDetector(
                onTap: _scrollRight,
                child: Container(
                  width: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Colors.transparent, const Color(0xFF0a0b0f).withOpacity(0.9)],
                    ),
                  ),
                  child: const Icon(Icons.chevron_right, color: _cyan, size: 28),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
