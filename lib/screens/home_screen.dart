import 'package:flutter/material.dart';
import '../utils/transitions.dart';
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
import 'airing_screen.dart';
import 'watchlist_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg = Color(0xFF0a0b0f);
const _bg2 = Color(0xFF111827);
const _bg3 = Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textPrimary = Color(0xFFe2e8f0);
const _textSecondary = Color(0xFF94a3b8);
const _textMuted = Color(0xFF64748b);

const _browseRows = [
  {'label': 'Currently airing', 'query': 'status: RELEASING, sort: POPULARITY_DESC'},
  {'label': 'Trending now', 'query': 'sort: TRENDING_DESC'},
  {'label': 'All time popular', 'query': 'sort: POPULARITY_DESC'},
  {'label': 'Action', 'query': 'genre: "Action", sort: POPULARITY_DESC'},
  {'label': 'Adventure', 'query': 'genre: "Adventure", sort: POPULARITY_DESC'},
  {'label': 'Fantasy', 'query': 'genre: "Fantasy", sort: POPULARITY_DESC'},
  {'label': 'Sci-Fi', 'query': 'genre: "Sci-Fi", sort: POPULARITY_DESC'},
  {'label': 'Romance', 'query': 'genre: "Romance", sort: POPULARITY_DESC'},
  {'label': 'Horror', 'query': 'genre: "Horror", sort: POPULARITY_DESC'},
  {'label': 'Comedy', 'query': 'genre: "Comedy", sort: POPULARITY_DESC'},
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin, WindowListener {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _provider = 'allanime';
  List<AnimeResult> _searchResults = [];
  List<AnilistMedia> _anilistResults = [];
  bool _searching = false;
  String? _searchError;
  final Map<String, List<AnilistMedia>> _browseCache = {};
  final Map<String, String> _browseErrors = {};
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _tabController = TabController(length: 3, vsync: this);
    _loadBrowse();
    windowManager.isMaximized().then((v) => setState(() => _isMaximized = v));
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) UpdateService.checkForUpdates(context);
    });
  }

  @override
  void onWindowMaximize() => setState(() => _isMaximized = true);
  @override
  void onWindowUnmaximize() => setState(() => _isMaximized = false);

  @override
  void dispose() {
    windowManager.removeListener(this);
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
      if (onlyLabel != null && mounted) setState(() => _browseErrors.remove(onlyLabel));
      try {
        final items = await api.fetchBrowseRow(row['query']!);
        if (mounted) setState(() => _browseCache[row['label']!] = items);
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        if (mounted) setState(() => _browseErrors[row['label']!] = e.toString());
      }
    }
  }

  Future<void> _search() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;
    setState(() { _searching = true; _searchError = null; _searchResults = []; _anilistResults = []; });
    try {
      final api = context.read<ApiService>();
      final results = await Future.wait([
        api.search(q, _provider),
        api.anilistSearch(q),
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

  void _openDetail(AnilistMedia media) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DetailScreen(media: media, provider: _provider),
    ));
  }

  void _openDetailByName(String name) async {
    final api = context.read<ApiService>();
    final media = await api.fetchAnilistByName(name);
    if (media != null && mounted) _openDetail(media);
  }

  void _openEpisodes(AnimeResult anime) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => EpisodeScreen(anime: anime),
    ));
  }

  // Featured anime — first item from trending row
  AnilistMedia? get _featured {
    final trending = _browseCache['Trending now'];
    if (trending != null && trending.isNotEmpty) return trending.first;
    final airing = _browseCache['Currently airing'];
    if (airing != null && airing.isNotEmpty) return airing.first;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: DragToMoveArea(
          child: Container(
            height: 48,
            color: _bg3,
            child: Row(
              children: [
                const SizedBox(width: 20),
                const Text('MAGI', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w700,
                  letterSpacing: 5, color: _cyan,
                )),
                const SizedBox(width: 32),
                // Nav tabs
                _NavTab(label: 'BROWSE', active: _tabController.index == 0, onTap: () => setState(() => _tabController.index = 0)),
                _NavTab(label: 'SEARCH', active: _tabController.index == 1, onTap: () => setState(() => _tabController.index = 1)),
                _NavTab(label: 'WATCHLIST', active: _tabController.index == 2, onTap: () => setState(() => _tabController.index = 2)),
                const Spacer(),
                // Right icons
                _IconBtn(icon: Icons.calendar_month_outlined, onTap: () => Navigator.push(context, fadeSlideRoute(AiringScheduleScreen(provider: _provider)))),
                _IconBtn(icon: Icons.settings_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ))),
                Container(width: 1, height: 16, color: _border, margin: const EdgeInsets.symmetric(horizontal: 8)),
                _WinBtn(icon: Icons.remove, onTap: () => windowManager.minimize()),
                _WinBtn(
                  icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
                  onTap: () async {
                    if (_isMaximized) await windowManager.unmaximize();
                    else await windowManager.maximize();
                  },
                ),
                _WinBtn(icon: Icons.close, onTap: () => windowManager.close(), isClose: true),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _BrowseTab(
            featured: _featured,
            browseCache: _browseCache,
            browseErrors: _browseErrors,
            browseRows: _browseRows,
            onCardTap: _openDetail,
            onHistoryTap: _openEpisodes,
            onRetry: (label) => _loadBrowse(onlyLabel: label),
            onFeaturedWatch: () {
              if (_featured != null) _openDetail(_featured!);
            },
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

// --- NAV TAB ---
class _NavTab extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavTab({required this.label, required this.active, required this.onTap});

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(
              color: widget.active ? _cyan : Colors.transparent, width: 2,
            )),
          ),
          child: Text(widget.label, style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, letterSpacing: 2,
            color: widget.active ? _textPrimary : _hovered ? _textPrimary : _textSecondary,
          )),
        ),
      ),
    );
  }
}

// --- ICON BTN ---
class _IconBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  State<_IconBtn> createState() => _IconBtnState();
}

class _IconBtnState extends State<_IconBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30, height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: _hovered ? _bg2 : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, size: 16, color: _hovered ? _cyan : _textMuted),
        ),
      ),
    );
  }
}

// --- WIN BTN ---
class _WinBtn extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isClose;
  const _WinBtn({required this.icon, required this.onTap, this.isClose = false});

  @override
  State<_WinBtn> createState() => _WinBtnState();
}

class _WinBtnState extends State<_WinBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 30, height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.isClose ? const Color(0xFF7f1d1d) : _bg2
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(widget.icon, size: 14,
            color: _hovered
                ? widget.isClose ? const Color(0xFFfca5a5) : _textPrimary
                : _textMuted),
        ),
      ),
    );
  }
}

// --- BROWSE TAB ---
class _BrowseTab extends StatelessWidget {
  final AnilistMedia? featured;
  final Map<String, List<AnilistMedia>> browseCache;
  final Map<String, String> browseErrors;
  final List<Map<String, String>> browseRows;
  final void Function(AnilistMedia) onCardTap;
  final void Function(AnimeResult) onHistoryTap;
  final void Function(String) onRetry;
  final VoidCallback onFeaturedWatch;

  const _BrowseTab({
    required this.featured,
    required this.browseCache,
    required this.browseErrors,
    required this.browseRows,
    required this.onCardTap,
    required this.onHistoryTap,
    required this.onRetry,
    required this.onFeaturedWatch,
  });

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Hero section
        SliverToBoxAdapter(
          child: _HeroSection(media: featured, onWatch: onFeaturedWatch),
        ),

        // Continue watching
        Consumer<HistoryService>(builder: (context, history, _) {
          if (history.entries.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionHeader(title: 'Continue watching'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 82,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
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
                ],
              ),
            ),
          );
        }),

        // Browse rows
        for (final row in browseRows)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionHeader(
                    title: row['label']!,
                    showSeeAll: browseCache.containsKey(row['label']),
                  ),
                  const SizedBox(height: 12),
                  browseErrors.containsKey(row['label'])
                      ? _ErrorRow(onRetry: () => onRetry(row['label']!))
                      : _ScrollableRow(
                          items: browseCache[row['label']] ?? [],
                          loading: !browseCache.containsKey(row['label']),
                          onCardTap: onCardTap,
                        ),
                ],
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 48)),
      ],
    );
  }
}

// --- HERO SECTION ---
class _HeroSection extends StatelessWidget {
  final AnilistMedia? media;
  final VoidCallback onWatch;
  const _HeroSection({required this.media, required this.onWatch});

  @override
  Widget build(BuildContext context) {
    if (media == null) {
      return Container(
        height: 250,
        color: const Color(0xFF0d0f18),
        child: const Center(child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
      );
    }
    final score = media!.averageScore != null
        ? '★ ${(media!.averageScore! / 10).toStringAsFixed(1)}'
        : null;
    final synopsis = media!.description
        ?.replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('\n', ' ')
        .trim();
    final shortSynopsis = synopsis != null && synopsis.length > 160
        ? '${synopsis.substring(0, 160)}...'
        : synopsis;

    return Container(
      color: const Color(0xFF0d0f18),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (media!.status == 'RELEASING')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('CURRENTLY AIRING', style: TextStyle(
                      fontFamily: 'monospace', fontSize: 10, letterSpacing: 3, color: _cyan,
                    )),
                  ),
                Text(media!.title, style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w700, color: _textPrimary, height: 1.2,
                )),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    if (score != null) _HeroBadge(text: score, highlight: true),
                    if (media!.episodes != null) _HeroBadge(text: '${media!.episodes} EP'),
                    if (media!.year != null) _HeroBadge(text: '${media!.year}'),
                    ...media!.genres.take(2).map((g) => _HeroBadge(text: g)),
                  ],
                ),
                if (shortSynopsis != null) ...[
                  const SizedBox(height: 12),
                  Text(shortSynopsis, style: const TextStyle(
                    fontSize: 13, color: _textMuted, height: 1.6,
                  ), maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: onWatch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    decoration: BoxDecoration(
                      color: _cyan,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.play_arrow, color: Color(0xFF0a0b0f), size: 18),
                      SizedBox(width: 6),
                      Text('WATCH NOW', style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
                        color: Color(0xFF0a0b0f), letterSpacing: 1,
                      )),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          if (media!.coverImage != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                media!.coverImage!,
                width: 130, height: 184,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String text;
  final bool highlight;
  const _HeroBadge({required this.text, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlight ? _cyan.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: highlight ? _cyan.withOpacity(0.4) : _border),
      ),
      child: Text(text, style: TextStyle(
        fontFamily: 'monospace', fontSize: 10,
        color: highlight ? _cyan : _textSecondary,
      )),
    );
  }
}

// --- SECTION HEADER ---
class _SectionHeader extends StatelessWidget {
  final String title;
  final bool showSeeAll;
  const _SectionHeader({required this.title, this.showSeeAll = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary)),
        const Spacer(),
        if (showSeeAll)
          Text('SEE ALL →', style: TextStyle(
            fontFamily: 'monospace', fontSize: 10, color: _cyan.withOpacity(0.7), letterSpacing: 1,
          )),
      ],
    );
  }
}

// --- ERROR ROW ---
class _ErrorRow extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRow({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 196,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('LOAD ERROR', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFFd44000))),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: _cyan.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('RETRY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 2)),
            ),
          ),
        ]),
      ),
    );
  }
}

// --- SCROLLABLE ROW ---
class _ScrollableRow extends StatefulWidget {
  final List<AnilistMedia> items;
  final bool loading;
  final void Function(AnilistMedia) onCardTap;
  const _ScrollableRow({required this.items, required this.loading, required this.onCardTap});

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

  void _scroll(double delta) {
    _sc.animateTo(
      (_sc.offset + delta).clamp(0.0, _sc.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
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
          if (!_atStart)
            Positioned(
              left: 0, top: 0, bottom: 0,
              child: GestureDetector(
                onTap: () => _scroll(-400),
                child: Container(
                  width: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight, end: Alignment.centerLeft,
                      colors: [Colors.transparent, _bg.withOpacity(0.9)],
                    ),
                  ),
                  child: const Icon(Icons.chevron_left, color: _cyan, size: 24),
                ),
              ),
            ),
          if (!_atEnd && !widget.loading)
            Positioned(
              right: 0, top: 0, bottom: 0,
              child: GestureDetector(
                onTap: () => _scroll(400),
                child: Container(
                  width: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                      colors: [Colors.transparent, _bg.withOpacity(0.9)],
                    ),
                  ),
                  child: const Icon(Icons.chevron_right, color: _cyan, size: 24),
                ),
              ),
            ),
        ],
      ),
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
    required this.controller, required this.provider,
    required this.results, required this.anilistResults,
    required this.searching, required this.error,
    required this.onProviderChanged, required this.onSearch,
    required this.onResultTap, required this.onAnilistTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasResults = results.isNotEmpty || anilistResults.isNotEmpty;
    return Column(
      children: [
        Container(
          color: _bg3,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _bg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _border),
                ),
                child: Row(children: [
                  const SizedBox(width: 12),
                  const Icon(Icons.search, color: _textMuted, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      style: const TextStyle(fontSize: 13, color: _textPrimary),
                      decoration: const InputDecoration(
                        hintText: 'Search anime...',
                        hintStyle: TextStyle(color: _textMuted, fontSize: 13),
                        border: InputBorder.none, isDense: true,
                      ),
                      onSubmitted: (_) => onSearch(),
                    ),
                  ),
                ]),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _bg2, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: provider, dropdownColor: _bg2,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _textMuted),
                  items: const [
                    DropdownMenuItem(value: 'allanime', child: Text('ALLANIME')),
                    DropdownMenuItem(value: 'animekai', child: Text('ANIMEKAI')),
                  ],
                  onChanged: onProviderChanged,
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onSearch,
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: _cyan, borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('SEARCH', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700,
                    color: Color(0xFF0a0b0f), letterSpacing: 1,
                  )),
                ),
              ),
            ),
          ]),
        ),
        const Divider(color: _border, height: 1),
        Expanded(
          child: searching
              ? const Center(child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
              : error != null
                  ? Center(child: Text('Error: $error', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFd44000))))
                  : !hasResults
                      ? Center(
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.search, color: _textMuted, size: 40),
                            const SizedBox(height: 12),
                            const Text('Search for anime', style: TextStyle(fontSize: 15, color: _textSecondary, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('Results from AniList and $provider', style: const TextStyle(fontSize: 13, color: _textMuted)),
                          ]),
                        )
                      : Row(children: [
                          if (anilistResults.isNotEmpty)
                            SizedBox(
                              width: 220,
                              child: Column(children: [
                                Container(
                                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                                  color: _bg3,
                                  child: const Row(children: [
                                    Text('ANILIST', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted, letterSpacing: 2)),
                                  ]),
                                ),
                                const Divider(color: _border, height: 1),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: anilistResults.length,
                                    itemBuilder: (context, i) {
                                      final m = anilistResults[i];
                                      return InkWell(
                                        onTap: () => onAnilistTap(m),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: const BoxDecoration(
                                            border: Border(bottom: BorderSide(color: _border, width: 0.5)),
                                          ),
                                          child: Row(children: [
                                            if (m.coverImage != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(4),
                                                child: Image.network(m.coverImage!, width: 38, height: 54, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => Container(width: 38, height: 54, color: _bg2)),
                                              )
                                            else Container(width: 38, height: 54, color: _bg2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4))),
                                            const SizedBox(width: 10),
                                            Expanded(child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary, height: 1.3)),
                                                if (m.averageScore != null)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 4),
                                                    child: Text('★ ${(m.averageScore! / 10).toStringAsFixed(1)}',
                                                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan)),
                                                  ),
                                              ],
                                            )),
                                          ]),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ]),
                            ),
                          if (anilistResults.isNotEmpty)
                            const VerticalDivider(color: _border, width: 1),
                          Expanded(
                            child: results.isEmpty
                                ? const Center(child: Text('No provider results', style: TextStyle(fontSize: 13, color: _textMuted)))
                                : Column(children: [
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                                      color: _bg3,
                                      child: Row(children: [
                                        Text(provider.toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted, letterSpacing: 2)),
                                      ]),
                                    ),
                                    const Divider(color: _border, height: 1),
                                    Expanded(
                                      child: GridView.builder(
                                        padding: const EdgeInsets.all(16),
                                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                          maxCrossAxisExtent: 200, childAspectRatio: 1.6, crossAxisSpacing: 8, mainAxisSpacing: 8,
                                        ),
                                        itemCount: results.length,
                                        itemBuilder: (context, i) => AnimeCardWidget(
                                          anime: results[i], onTap: () => onResultTap(results[i].name),
                                        ),
                                      ),
                                    ),
                                  ]),
                          ),
                        ]),
        ),
      ],
    );
  }
}
