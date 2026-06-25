import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/update_service.dart';
import '../services/health_service.dart';
import '../services/prefs_service.dart';
import '../models/models.dart';
import '../widgets/browse_card.dart';
import '../widgets/history_card.dart';
import '../widgets/shimmer.dart';
import '../widgets/anime_preview_sheet.dart';
import '../utils/transitions.dart';
import 'detail_screen.dart';
import 'episode_screen.dart';
import 'settings_screen.dart';
import 'airing_screen.dart';
import 'watchlist_screen.dart';
import 'search_screen.dart';
import 'browse_all_screen.dart';

const _cyan =    Color(0xFF00d4d4);
const _orange =  Color(0xFFf97316);
const _bg =      Color(0xFF080c18);
const _bg2 =     Color(0xFF0d1220);
const _bg3 =     Color(0xFF0a0e1c);
const _border =  Color(0xFF151d30);
const _textPrimary =   Color(0xFFf1f5f9);
const _textSecondary = Color(0xFF94a3b8);
const _textMuted =     Color(0xFF4a6080);

const _browseRows = [
  {'label': 'Currently airing',  'query': 'status: RELEASING, sort: POPULARITY_DESC'},
  {'label': 'Trending now',      'query': 'sort: TRENDING_DESC'},
  {'label': 'All time popular',  'query': 'sort: POPULARITY_DESC'},
  {'label': 'Top rated',         'query': 'sort: SCORE_DESC'},
  {'label': 'Action',            'query': 'genre: "Action", sort: POPULARITY_DESC'},
  {'label': 'Adventure',         'query': 'genre: "Adventure", sort: POPULARITY_DESC'},
  {'label': 'Fantasy',           'query': 'genre: "Fantasy", sort: POPULARITY_DESC'},
  {'label': 'Sci-Fi',            'query': 'genre: "Sci-Fi", sort: POPULARITY_DESC'},
  {'label': 'Romance',           'query': 'genre: "Romance", sort: POPULARITY_DESC'},
  {'label': 'Horror',            'query': 'genre: "Horror", sort: POPULARITY_DESC'},
  {'label': 'Comedy',            'query': 'genre: "Comedy", sort: POPULARITY_DESC'},
  {'label': 'Drama',             'query': 'genre: "Drama", sort: POPULARITY_DESC'},
  {'label': 'Slice of Life',     'query': 'genre: "Slice of Life", sort: POPULARITY_DESC'},
  {'label': 'Mystery',           'query': 'genre: "Mystery", sort: POPULARITY_DESC'},
  {'label': 'Psychological',     'query': 'genre: "Psychological", sort: POPULARITY_DESC'},
  {'label': 'Supernatural',      'query': 'genre: "Supernatural", sort: POPULARITY_DESC'},
  {'label': 'Mecha',             'query': 'genre: "Mecha", sort: POPULARITY_DESC'},
  {'label': 'Sports',            'query': 'genre: "Sports", sort: POPULARITY_DESC'},
  {'label': 'Music',             'query': 'genre: "Music", sort: POPULARITY_DESC'},
  {'label': 'Thriller',          'query': 'genre: "Thriller", sort: POPULARITY_DESC'},
  {'label': 'Isekai',            'query': 'tag: "Isekai", sort: POPULARITY_DESC'},
];

enum _NavItem { home, search, browse, watchlist, airing, settings }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WindowListener {
  bool _sidebarOpen = true;
  _NavItem _nav = _NavItem.home;
  bool _isMaximized = false;
  String _provider = 'allanime';
  final Map<String, List<AnilistMedia>> _browseCache = {};
  final Map<String, String> _browseErrors = {};

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.isMaximized().then((v) => setState(() => _isMaximized = v));
    _loadBrowse();
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
        await Future.delayed(const Duration(milliseconds: 150));
      } catch (e) {
        if (mounted) setState(() => _browseErrors[row['label']!] = e.toString());
      }
    }
  }

  void _openDetail(AnilistMedia media) => showAnimePreview(context, media, _provider);

  void _openEpisodes(AnimeResult anime) => Navigator.push(
    context, fadeSlideRoute(EpisodeScreen(anime: anime)));

  AnilistMedia? get _featured {
    final t = _browseCache['Trending now'];
    if (t != null && t.length > 2) return t[2];
    if (t != null && t.isNotEmpty) return t.last;
    final a = _browseCache['Currently airing'];
    if (a != null && a.isNotEmpty) return a.first;
    return null;
  }

  Widget _buildNav() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      width: _sidebarOpen ? 200 : 0,
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: 0,
          maxWidth: 200,
          child: SizedBox(
            width: 200,
            child: Container(
              color: _bg3,
          child: Column(
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: const BoxDecoration(color: _cyan,
                      borderRadius: BorderRadius.all(Radius.circular(2))),
                    child: ClipPath(
                      clipper: _HexClipper(),
                      child: Container(color: _cyan),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('MAGI', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 15, fontWeight: FontWeight.w700,
                    letterSpacing: 5, color: _cyan,
                  )),
                ]),
              ),
              // Nav items
              Expanded(
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(children: [
                      _NavButton(_NavItem.home,     Icons.home_outlined,          'HOME',      _nav, (v) => setState(() => _nav = v)),
                      _NavButton(_NavItem.search,   Icons.search,                  'SEARCH',    _nav, (v) => setState(() => _nav = v)),
                      _NavButton(_NavItem.browse,   Icons.grid_view_outlined,      'BROWSE',    _nav, (v) => setState(() => _nav = v)),
                      _NavButton(_NavItem.watchlist,Icons.bookmark_outline,        'WATCHLIST', _nav, (v) => setState(() => _nav = v)),
                      _NavButton(_NavItem.airing,   Icons.calendar_month_outlined, 'AIRING',    _nav, (v) => setState(() => _nav = v)),
                      _NavButton(_NavItem.settings, Icons.settings_outlined,       'SETTINGS',  _nav, (v) {
                        Navigator.push(context, fadeSlideRoute(const SettingsScreen()));
                      }),
                    ]),
                  ),
                  // Continue watching in sidebar
                  Consumer<HistoryService>(builder: (context, history, _) {
                    if (history.entries.isEmpty) return const SizedBox.shrink();
                    return Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                          decoration: const BoxDecoration(border: Border(
                            top: BorderSide(color: _border),
                            bottom: BorderSide(color: _border),
                          )),
                          child: Row(children: [
                            Container(width: 2, height: 10, color: _cyan),
                            const SizedBox(width: 6),
                            const Text('CONTINUE', style: TextStyle(
                              fontFamily: 'monospace', fontSize: 8,
                              color: _textSecondary, letterSpacing: 2,
                            )),
                          ]),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: history.entries.length,
                            itemBuilder: (context, i) {
                              final e = history.entries[i];
                              return GestureDetector(
                                onTap: () => _openEpisodes(AnimeResult(id: e.id, name: e.name, provider: e.provider)),
                                child: Stack(children: [
                                  Container(
                                    margin: const EdgeInsets.fromLTRB(10, 2, 10, 2),
                                    padding: const EdgeInsets.fromLTRB(10, 8, 24, 8),
                                    decoration: BoxDecoration(
                                      color: _bg2,
                                      border: Border(left: BorderSide(color: _cyan.withOpacity(0.4), width: 2)),
                                    ),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: _textPrimary, height: 1.2)),
                                      const SizedBox(height: 3),
                                      Row(children: [
                                        Text('EP ${e.episode.toInt()}', style: const TextStyle(
                                          fontFamily: 'monospace', fontSize: 9, color: _cyan,
                                        )),
                                        if (e.progress != null) ...[
                                          const SizedBox(width: 8),
                                          Expanded(child: LinearProgressIndicator(
                                            value: 0.4,
                                            backgroundColor: _border,
                                            valueColor: const AlwaysStoppedAnimation(_cyan),
                                            minHeight: 2,
                                          )),
                                        ],
                                      ]),
                                    ]),
                                  ),
                                  Positioned(
                                    top: 4, right: 12,
                                    child: GestureDetector(
                                      onTap: () => context.read<HistoryService>().remove(e.id),
                                      child: Container(
                                        width: 16, height: 16,
                                        decoration: BoxDecoration(
                                          color: _bg,
                                          border: Border.all(color: _border),
                                        ),
                                        child: const Icon(Icons.close, size: 10, color: _textSecondary),
                                      ),
                                    ),
                                  ),
                                ]),
                              );
                            },
                          ),
                        ),
                      ]),
                    );
                  }),
                ]),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: _border))),
                child: const Text('NERV CENTRAL DOGMA\nTERMINAL SYSTEM',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 8, color: _textMuted, letterSpacing: 1, height: 1.8)),
              ),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: _bg3,
        border: Border(bottom: BorderSide(color: _border)),
      ),
      child: DragToMoveArea(
        child: Row(children: [
          // Sidebar toggle
          GestureDetector(
            onTap: () => setState(() => _sidebarOpen = !_sidebarOpen),
            child: Container(
              width: 50, height: 50,
              color: Colors.transparent,
              child: Icon(
                _sidebarOpen ? Icons.menu_open : Icons.menu,
                color: _sidebarOpen ? _cyan : _textMuted, size: 20,
              ),
            ),
          ),
          // Search bar
          Container(
            height: 30, width: 240,
            decoration: BoxDecoration(
              color: _bg2, borderRadius: BorderRadius.circular(2),
              border: Border.all(color: _border),
            ),
            child: Row(children: [
              const SizedBox(width: 10),
              const Icon(Icons.search, color: _textMuted, size: 14),
              const SizedBox(width: 6),
              const Expanded(child: Text('SEARCH ANIME...', style: TextStyle(
                fontFamily: 'monospace', fontSize: 10, color: _textMuted, letterSpacing: 1,
              ))),
            ]),
          ),
          const Spacer(),
          // Health dot
          Consumer<HealthService>(builder: (context, health, _) {
            final color = switch (health.status) {
              ServerHealth.healthy =>   const Color(0xFF22c55e),
              ServerHealth.unhealthy => const Color(0xFFef4444),
              ServerHealth.unknown =>   _textMuted,
            };
            return Tooltip(
              message: switch (health.status) {
                ServerHealth.healthy =>   'Server online',
                ServerHealth.unhealthy => 'Server offline',
                ServerHealth.unknown =>   'Checking...',
              },
              child: GestureDetector(
                onTap: () => context.read<HealthService>().refresh(),
                child: Row(children: [
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text('ONLINE', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: color, letterSpacing: 2)),
                ]),
              ),
            );
          }),
          const SizedBox(width: 16),
          // Window controls
          _WinBtn(icon: Icons.remove, onTap: () => windowManager.minimize()),
          _WinBtn(icon: _isMaximized ? Icons.filter_none : Icons.crop_square,
            onTap: () async {
              if (_isMaximized) await windowManager.unmaximize();
              else await windowManager.maximize();
            }),
          _WinBtn(icon: Icons.close, onTap: () => windowManager.close(), isClose: true),
          const SizedBox(width: 6),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    switch (_nav) {
      case _NavItem.home:
        return _HomeBody(
          browseCache: _browseCache,
          browseErrors: _browseErrors,
          browseRows: _browseRows,
          featured: _featured,
          provider: _provider,
          onCardTap: _openDetail,
          onHistoryTap: _openEpisodes,
          onRetry: (l) => _loadBrowse(onlyLabel: l),
          onFeaturedWatch: () { if (_featured != null) _openDetail(_featured!); },
        );
      case _NavItem.search:
        return SearchScreen(provider: _provider);
      case _NavItem.browse:
        return _BrowseAllBody(
          browseCache: _browseCache,
          browseRows: _browseRows,
          provider: _provider,
          onCardTap: _openDetail,
          onRetry: (l) => _loadBrowse(onlyLabel: l),
          browseErrors: _browseErrors,
        );
      case _NavItem.watchlist:
        return WatchlistScreen(provider: _provider);
      case _NavItem.airing:
        return AiringScheduleScreen(provider: _provider);
      case _NavItem.settings:
        return const SettingsScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        _buildTopBar(),
        Expanded(
          child: Row(children: [
            _buildNav(),
            if (_sidebarOpen)
              Container(width: 1, color: _border),
            Expanded(child: _buildBody()),
          ]),
        ),
      ]),
    );
  }
}

// --- SIDEBAR BUTTON ---
class _NavButton extends StatefulWidget {
  final _NavItem item, current;
  final IconData icon;
  final String label;
  final void Function(_NavItem) onTap;
  const _NavButton(this.item, this.icon, this.label, this.current, this.onTap);

  @override
  State<_NavButton> createState() => _NavButtonState();
}

class _NavButtonState extends State<_NavButton> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.item == widget.current;
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.item),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: active ? _cyan.withOpacity(0.1) : _hov ? Colors.white.withOpacity(0.03) : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border(left: BorderSide(
              color: active ? _cyan : Colors.transparent, width: 2,
            )),
          ),
          child: Row(children: [
            Icon(widget.icon, size: 18, color: active ? _cyan : const Color(0xFF6b8aaa)),
            const SizedBox(width: 12),
            Text(widget.label, style: TextStyle(
              fontFamily: 'monospace', fontSize: 10, letterSpacing: 2,
              color: active ? _textPrimary : const Color(0xFF6b8aaa), fontWeight: FontWeight.w600,
            )),
          ]),
        ),
      ),
    );
  }
}

// --- HOME BODY: hero + 3 curated rows ---
class _HomeBody extends StatelessWidget {
  final Map<String, List<AnilistMedia>> browseCache;
  final Map<String, String> browseErrors;
  final List<Map<String, String>> browseRows;
  final AnilistMedia? featured;
  final String provider;
  final void Function(AnilistMedia) onCardTap;
  final void Function(AnimeResult) onHistoryTap;
  final void Function(String) onRetry;
  final VoidCallback onFeaturedWatch;

  const _HomeBody({
    required this.browseCache, required this.browseErrors, required this.browseRows,
    required this.featured, required this.provider, required this.onCardTap,
    required this.onHistoryTap, required this.onRetry, required this.onFeaturedWatch,
  });

  static const _homeRows = [
    {'label': 'Currently airing', 'query': 'status: RELEASING, sort: POPULARITY_DESC'},
    {'label': 'Trending now',     'query': 'sort: TRENDING_DESC'},
    {'label': 'Top rated',        'query': 'sort: SCORE_DESC'},
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final mosaicH = (constraints.maxHeight * 0.52).clamp(360.0, 480.0);
      return Column(children: [
        // Hero mosaic — capped at reasonable width
        SizedBox(
          height: mosaicH,
          child: _MosaicGrid(
            browseCache: browseCache,
            featured: featured,
            provider: provider,
            onCardTap: onCardTap,
            onFeaturedWatch: onFeaturedWatch,
          ),
        ),
        const Divider(color: _border, height: 1),
        // 3 curated rows
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              for (int i = 0; i < _homeRows.length; i++) ...[
                if (i > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    child: Row(children: [
                      Expanded(child: Container(height: 1, color: _border)),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        child: CustomPaint(size: const Size(16, 8), painter: _DiagLinePainter()),
                      ),
                      Expanded(child: Container(height: 1, color: _border)),
                    ]),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _RowHeader(
                      _homeRows[i]['label']!,
                      browseCache.containsKey(_homeRows[i]['label']) ? () => Navigator.push(
                        context, fadeSlideRoute(BrowseAllScreen(
                          label: _homeRows[i]['label']!,
                          query: _homeRows[i]['query']!,
                          initialItems: browseCache[_homeRows[i]['label']]!,
                          provider: provider,
                        ))) : null,
                      null,
                    ),
                    const SizedBox(height: 10),
                    browseErrors.containsKey(_homeRows[i]['label'])
                        ? _ErrorRow(onRetry: () => onRetry(_homeRows[i]['label']!))
                        : _CategoryGrid(
                            items: browseCache[_homeRows[i]['label']] ?? [],
                            loading: !browseCache.containsKey(_homeRows[i]['label']),
                            onCardTap: onCardTap,
                            flipped: i.isOdd,
                          ),
                  ]),
                ),
              ],
            ],
          ),
        ),
      ]);
    });
  }
}

// --- MOSAIC GRID ---
class _MosaicGrid extends StatelessWidget {
  final Map<String, List<AnilistMedia>> browseCache;
  final AnilistMedia? featured;
  final String provider;
  final void Function(AnilistMedia) onCardTap;
  final VoidCallback onFeaturedWatch;

  const _MosaicGrid({
    required this.browseCache, required this.featured, required this.provider,
    required this.onCardTap, required this.onFeaturedWatch,
  });

  @override
  Widget build(BuildContext context) {
    final trending = browseCache['Trending now'] ?? [];
    final airing   = browseCache['Currently airing'] ?? [];
    final popular  = browseCache['All time popular'] ?? [];

    AnilistMedia? pick(List<AnilistMedia> list, int i) =>
        list.length > i ? list[i] : null;

    final c1 = pick(trending, 0);
    final c2 = pick(airing, 0);
    final c3 = pick(trending, 1);
    final c4 = pick(airing, 1);
    final c5 = pick(popular, 0);
    final c6 = pick(popular, 1);

    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      // LEFT COLUMN (22%)
      Flexible(flex: 22, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Flexible(flex: 38, child: _MosaicCard(
          media: c1, tag: 'TRENDING', accent: _cyan,
          clip: _MosaicClip.topLeft,
          onTap: c1 != null ? () => onCardTap(c1) : null,
        )),
        const SizedBox(height: 2),
        Flexible(flex: 62, child: _MosaicCard(
          media: c2, tag: 'AIRING', accent: _cyan,
          clip: _MosaicClip.bottomLeft,
          onTap: c2 != null ? () => onCardTap(c2) : null,
        )),
      ])),
      const SizedBox(width: 2),
      // HERO CENTER (42%)
      Flexible(flex: 42, child: _HeroCard(media: featured, onWatch: onFeaturedWatch)),
      const SizedBox(width: 2),
      // RIGHT COLUMN (36%)
      Flexible(flex: 36, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Flexible(flex: 38, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(flex: 60, child: _MosaicCard(
            media: c3, tag: 'TRENDING', accent: _cyan,
            clip: _MosaicClip.topRight,
            onTap: c3 != null ? () => onCardTap(c3) : null,
          )),
          const SizedBox(width: 2),
          Flexible(flex: 40, child: _MosaicCard(
            media: c4, tag: 'AIRING', accent: _cyan,
            onTap: c4 != null ? () => onCardTap(c4) : null,
          )),
        ])),
        const SizedBox(height: 2),
        Flexible(flex: 62, child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Flexible(flex: 60, child: _MosaicCard(
            media: c5, tag: 'POPULAR', accent: _orange,
            clip: _MosaicClip.bottomLeft,
            onTap: c5 != null ? () => onCardTap(c5) : null,
          )),
          const SizedBox(width: 2),
          Flexible(flex: 40, child: _MosaicCard(
            media: c6, tag: 'TOP', accent: _orange,
            clip: _MosaicClip.bottomRight,
            onTap: c6 != null ? () => onCardTap(c6) : null,
          )),
        ])),
      ])),
    ]);
  }
}

// --- HERO CARD ---
class _HeroCard extends StatefulWidget {
  final AnilistMedia? media;
  final VoidCallback onWatch;
  const _HeroCard({required this.media, required this.onWatch});

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final score = media?.averageScore != null
        ? '★ ${(media!.averageScore! / 10).toStringAsFixed(1)}' : null;
    final synopsis = media?.description
        ?.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('\n', ' ').trim();
    final short = synopsis != null && synopsis.length > 180
        ? '${synopsis.substring(0, 180)}...' : synopsis;

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: Container(
        decoration: BoxDecoration(color: _bg2,
          border: Border.all(color: _hov ? _cyan.withOpacity(0.3) : _border)),
        child: Stack(fit: StackFit.expand, children: [
          // Full bleed cover image
          if (media?.coverImage != null)
            Image.network(media!.coverImage!, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox()),
          // Dark gradient so text is readable
          Container(decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight, end: Alignment.centerLeft,
              colors: [Colors.transparent, Color(0xDD080c18)],
              stops: [0.3, 0.85],
            ),
          )),
          // Content pinned bottom-left
          Positioned(bottom: 0, left: 0, right: 0,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: 340,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.4))),
                  child: const Text('FEATURED', style: TextStyle(
                    fontFamily: 'monospace', fontSize: 8, color: _cyan, letterSpacing: 3,
                  )),
                ),
                const SizedBox(height: 10),
                Text(media?.title ?? 'Loading...', style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary,
                  letterSpacing: 0.5, height: 1.15, fontFamily: 'monospace',
                ), maxLines: 2, overflow: TextOverflow.ellipsis),
                if (short != null) ...[
                  const SizedBox(height: 8),
                  Text(short, style: const TextStyle(fontSize: 11, color: _textSecondary, height: 1.55),
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 12),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (score != null) _Tag(score, highlight: true),
                  if (media?.episodes != null) _Tag('${media!.episodes} EP'),
                  ...?media?.genres.take(2).map((g) => _Tag(g)),
                ]),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: widget.onWatch,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                    color: _cyan,
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.play_arrow, color: _bg, size: 16),
                      SizedBox(width: 6),
                      Text('WATCH NOW', style: TextStyle(
                        fontFamily: 'monospace', fontSize: 10, fontWeight: FontWeight.w700,
                        color: _bg, letterSpacing: 2,
                      )),
                    ]),
                  ),
                ),
              ]),
              ),
            ),
          ),
          // Corner clip decoration (placeholder)
          Positioned(top: 0, right: 0,
            child: Container(width: 0, height: 0,
              decoration: BoxDecoration(border: Border.fromBorderSide(BorderSide.none)))),
        ]),
      ),
    );
  }
}

// --- MOSAIC CARD ---
class _MosaicCard extends StatefulWidget {
  final AnilistMedia? media;
  final String tag;
  final Color? accent;
  final VoidCallback? onTap;
  final _MosaicClip clip;
  const _MosaicCard({this.media, required this.tag, this.accent, this.onTap, this.clip = _MosaicClip.none});

  @override
  State<_MosaicCard> createState() => _MosaicCardState();
}

enum _MosaicClip { none, topLeft, topRight, bottomLeft, bottomRight }

class _AngularClipper extends CustomClipper<Path> {
  final _MosaicClip clip;
  const _AngularClipper(this.clip);

  @override
  Path getClip(Size s) {
    const c = 18.0; // cut size
    final p = Path();
    switch (clip) {
      case _MosaicClip.topLeft:
        p.moveTo(c, 0); p.lineTo(s.width, 0); p.lineTo(s.width, s.height);
        p.lineTo(0, s.height); p.lineTo(0, c); p.close();
      case _MosaicClip.topRight:
        p.moveTo(0, 0); p.lineTo(s.width - c, 0); p.lineTo(s.width, c);
        p.lineTo(s.width, s.height); p.lineTo(0, s.height); p.close();
      case _MosaicClip.bottomLeft:
        p.moveTo(0, 0); p.lineTo(s.width, 0); p.lineTo(s.width, s.height);
        p.lineTo(c, s.height); p.lineTo(0, s.height - c); p.close();
      case _MosaicClip.bottomRight:
        p.moveTo(0, 0); p.lineTo(s.width, 0); p.lineTo(s.width, s.height - c);
        p.lineTo(s.width - c, s.height); p.lineTo(0, s.height); p.close();
      case _MosaicClip.none:
        p.addRect(Rect.fromLTWH(0, 0, s.width, s.height));
    }
    return p;
  }

  @override
  bool shouldReclip(_AngularClipper old) => old.clip != clip;
}

class _MosaicCardState extends State<_MosaicCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final media = widget.media;
    final accent = widget.accent ?? _cyan;
    final score = media?.averageScore != null
        ? '★ ${(media!.averageScore! / 10).toStringAsFixed(1)}' : null;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _bg2,
        border: Border.all(color: _hov ? accent.withOpacity(0.5) : _border),
      ),
      child: Stack(fit: StackFit.expand, children: [
        if (media?.coverImage != null)
          Image.network(media!.coverImage!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox()),
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xEE080c18)],
            stops: [0.25, 1.0],
          ),
        )),
        Positioned(top: 0, right: 0,
          child: Container(width: 22, height: 22,
            decoration: BoxDecoration(border: Border(
              top: BorderSide(color: accent.withOpacity(0.8), width: 2),
              right: BorderSide(color: accent.withOpacity(0.8), width: 2),
            )))),
        if (score != null)
          Positioned(top: 7, left: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              color: const Color(0xCC080c18),
              child: Text(score, style: TextStyle(
                fontFamily: 'monospace', fontSize: 9, color: accent,
              )),
            )),
        Positioned(bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min, children: [
              Text(widget.tag, style: TextStyle(
                fontFamily: 'monospace', fontSize: 8,
                color: accent, letterSpacing: 2,
              )),
              const SizedBox(height: 3),
              Text(media?.title ?? '', style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: _textPrimary, height: 1.2,
              ), maxLines: 2, overflow: TextOverflow.ellipsis),
            ]),
          )),
      ]),
    );

    if (widget.clip != _MosaicClip.none) {
      card = ClipPath(clipper: _AngularClipper(widget.clip), child: card);
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}

// --- TAG BADGE ---
class _Tag extends StatelessWidget {
  final String text;
  final bool highlight;
  const _Tag(this.text, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: highlight ? _cyan.withOpacity(0.1) : Colors.transparent,
        border: Border.all(color: highlight ? _cyan.withOpacity(0.4) : _border),
      ),
      child: Text(text, style: TextStyle(
        fontFamily: 'monospace', fontSize: 9,
        color: highlight ? _cyan : _textSecondary, letterSpacing: 1,
      )),
    );
  }
}

// --- ROW HEADER ---
class _RowHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  final String? count;
  const _RowHeader(this.title, this.onSeeAll, this.count);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      // Cyan left accent
      Container(width: 2, height: 16, color: _cyan),
      const SizedBox(width: 8),
      // Bracket open
      const Text('[', style: TextStyle(
        fontFamily: 'monospace', fontSize: 13, color: _cyan, fontWeight: FontWeight.w300,
      )),
      const SizedBox(width: 4),
      Text(title.toUpperCase(), style: const TextStyle(
        fontFamily: 'monospace', fontSize: 10, color: _textPrimary,
        letterSpacing: 3, fontWeight: FontWeight.w700,
      )),
      const SizedBox(width: 4),
      const Text(']', style: TextStyle(
        fontFamily: 'monospace', fontSize: 13, color: _cyan, fontWeight: FontWeight.w300,
      )),
      if (count != null) ...[
        const SizedBox(width: 8),
        Text(count!, style: const TextStyle(
          fontFamily: 'monospace', fontSize: 9, color: _textMuted,
        )),
      ],
      const Spacer(),
      if (onSeeAll != null)
        GestureDetector(
          onTap: onSeeAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(color: _cyan.withOpacity(0.3)),
            ),
            child: Text('SEE ALL →', style: TextStyle(
              fontFamily: 'monospace', fontSize: 8,
              color: _cyan.withOpacity(0.8), letterSpacing: 1,
            )),
          ),
        ),
    ]);
  }
}

// --- ERROR ROW ---
class _ErrorRow extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorRow({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('LOAD ERROR', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFFef4444))),
        const SizedBox(height: 10),
        GestureDetector(onTap: onRetry,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.4))),
            child: const Text('RETRY', style: TextStyle(fontFamily: 'monospace', fontSize: 9, color: _cyan, letterSpacing: 2)),
          )),
      ])),
    );
  }
}

// --- SCROLLABLE ROW ---
class _ScrollRow extends StatefulWidget {
  final List<AnilistMedia> items;
  final bool loading;
  final void Function(AnilistMedia) onCardTap;
  const _ScrollRow({required this.items, required this.loading, required this.onCardTap});

  @override
  State<_ScrollRow> createState() => _ScrollRowState();
}

class _ScrollRowState extends State<_ScrollRow> {
  final ScrollController _sc = ScrollController();
  bool _atStart = true, _atEnd = false;

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (!_sc.hasClients) return;
      setState(() {
        _atStart = _sc.position.pixels <= 0;
        _atEnd = _sc.position.pixels >= _sc.position.maxScrollExtent;
      });
    });
  }

  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  void _scroll(double d) => _sc.animateTo(
    (_sc.offset + d).clamp(0.0, _sc.position.maxScrollExtent),
    duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 242,
      child: Stack(clipBehavior: Clip.hardEdge, children: [
        widget.loading
            ? ListView.separated(
                scrollDirection: Axis.horizontal, controller: _sc,
                itemCount: 10, separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, __) => const ShimmerBrowseCard())
            : ListView.separated(
                scrollDirection: Axis.horizontal, controller: _sc,
                itemCount: widget.items.length, separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => BrowseCardWidget(
                  media: widget.items[i], onTap: () => widget.onCardTap(widget.items[i]))),
        if (!_atStart)
          Positioned(left: 0, top: 0, bottom: 0,
            child: GestureDetector(onTap: () => _scroll(-400),
              child: Container(width: 32,
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.centerRight, end: Alignment.centerLeft,
                  colors: [Colors.transparent, _bg.withOpacity(0.9)])),
                child: const Icon(Icons.chevron_left, color: _cyan, size: 20)))),
        if (!_atEnd && !widget.loading)
          Positioned(right: 0, top: 0, bottom: 0,
            child: GestureDetector(onTap: () => _scroll(400),
              child: Container(width: 32,
                decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                  colors: [Colors.transparent, _bg.withOpacity(0.9)])),
                child: const Icon(Icons.chevron_right, color: _cyan, size: 20)))),
      ]),
    );
  }
}

// --- CATEGORY GRID ---
class _CategoryGrid extends StatelessWidget {
  final List<AnilistMedia> items;
  final bool loading;
  final void Function(AnilistMedia) onCardTap;
  final bool flipped; // alternate large card side

  const _CategoryGrid({
    required this.items, required this.loading,
    required this.onCardTap, this.flipped = false,
  });

  @override
  Widget build(BuildContext context) {
    const smallH = 108.0;
    const largeH = smallH * 2 + 4;
    const gap    = 3.0;

    if (loading) {
      return Container(
        height: largeH,
        color: _bg2.withOpacity(0.3),
        child: const Center(child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(color: _cyan, strokeWidth: 1.5),
        )),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    final large = items[0];
    final small = items.skip(1).take(6).toList();

    final largeCard = Flexible(
      flex: 3,
      child: _GridCard(
        media: large, isLarge: true,
        onTap: () => onCardTap(large),
      ),
    );

    final smallGrid = Flexible(
      flex: 7,
      child: Column(children: [
        Expanded(child: Row(children: [
          for (int i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(child: small.length > i
                ? _GridCard(media: small[i], isLarge: false, onTap: () => onCardTap(small[i]))
                : Container(color: _bg2.withOpacity(0.3))),
          ],
        ])),
        const SizedBox(height: gap),
        Expanded(child: Row(children: [
          for (int i = 3; i < 6; i++) ...[
            if (i > 3) const SizedBox(width: gap),
            Expanded(child: small.length > i
                ? _GridCard(media: small[i], isLarge: false, onTap: () => onCardTap(small[i]))
                : Container(color: _bg2.withOpacity(0.3))),
          ],
        ])),
      ]),
    );

    return SizedBox(
      height: largeH,
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: flipped
          ? [smallGrid, const SizedBox(width: gap), largeCard]
          : [largeCard, const SizedBox(width: gap), smallGrid],
      ),
    );
  }
}

class _GridCard extends StatefulWidget {
  final AnilistMedia media;
  final bool isLarge;
  final VoidCallback onTap;
  const _GridCard({required this.media, required this.isLarge, required this.onTap});

  @override
  State<_GridCard> createState() => _GridCardState();
}

class _GridCardState extends State<_GridCard> {
  bool _hov = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.isLarge ? _cyan : _cyan;
    final score = widget.media.averageScore != null
        ? '★ ${(widget.media.averageScore! / 10).toStringAsFixed(1)}' : null;

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: _bg2,
        border: Border.all(color: _hov ? _cyan.withOpacity(0.5) : _border),
      ),
      child: Stack(fit: StackFit.expand, children: [
        // Cover
        if (widget.media.coverImage != null)
          Image.network(widget.media.coverImage!, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox()),
        // Gradient
        Container(decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.transparent, Color(0xEE080c18)],
            stops: [0.35, 1.0],
          ),
        )),
        // Score top-right
        if (score != null)
          Positioned(top: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              color: const Color(0xCC080c18),
              child: Text(score, style: const TextStyle(
                fontFamily: 'monospace', fontSize: 9, color: _cyan,
              )),
            )),
        // Corner accent top-right
        Positioned(top: 0, right: 0,
          child: Container(width: 16, height: 16,
            decoration: BoxDecoration(border: Border(
              top: BorderSide(color: accent.withOpacity(0.7), width: 2),
              right: BorderSide(color: accent.withOpacity(0.7), width: 2),
            )))),
        // Title at bottom
        Positioned(bottom: 0, left: 0, right: 0,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              widget.media.title,
              maxLines: widget.isLarge ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: widget.isLarge ? 13 : 10,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
                height: 1.2,
              ),
            ),
          )),
        // Status badge for large card
        if (widget.isLarge && widget.media.status == 'RELEASING')
          Positioned(top: 8, left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              color: _cyan.withOpacity(0.15),
              child: const Text('AIRING', style: TextStyle(
                fontFamily: 'monospace', fontSize: 8, color: _cyan, letterSpacing: 1,
              )),
            )),
      ]),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(onTap: widget.onTap, child: card),
    );
  }
}

// --- BROWSE ALL BODY: horizontal scroll rows per category ---
class _BrowseAllBody extends StatelessWidget {
  final Map<String, List<AnilistMedia>> browseCache;
  final Map<String, String> browseErrors;
  final List<Map<String, String>> browseRows;
  final String provider;
  final void Function(AnilistMedia) onCardTap;
  final void Function(String) onRetry;

  const _BrowseAllBody({
    required this.browseCache, required this.browseErrors, required this.browseRows,
    required this.provider, required this.onCardTap, required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 32),
      children: [
        for (int i = 0; i < browseRows.length; i++)
          _BrowseSection(
            label: browseRows[i]['label']!,
            items: browseCache[browseRows[i]['label']] ?? [],
            loading: !browseCache.containsKey(browseRows[i]['label']),
            error: browseErrors[browseRows[i]['label']],
            onCardTap: onCardTap,
            onRetry: () => onRetry(browseRows[i]['label']!),
            onSeeAll: browseCache.containsKey(browseRows[i]['label'])
                ? () => Navigator.push(context, fadeSlideRoute(BrowseAllScreen(
                    label: browseRows[i]['label']!,
                    query: browseRows[i]['query']!,
                    initialItems: browseCache[browseRows[i]['label']]!,
                    provider: provider,
                  )))
                : null,
          ),
      ],
    );
  }
}

class _BrowseSection extends StatefulWidget {
  final String label;
  final List<AnilistMedia> items;
  final bool loading;
  final String? error;
  final void Function(AnilistMedia) onCardTap;
  final VoidCallback onRetry;
  final VoidCallback? onSeeAll;

  const _BrowseSection({
    required this.label, required this.items, required this.loading,
    required this.onCardTap, required this.onRetry,
    this.error, this.onSeeAll,
  });

  @override
  State<_BrowseSection> createState() => _BrowseSectionState();
}

class _BrowseSectionState extends State<_BrowseSection> {
  final ScrollController _sc = ScrollController();
  bool _atStart = true, _atEnd = false;

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (!_sc.hasClients) return;
      setState(() {
        _atStart = _sc.position.pixels <= 0;
        _atEnd = _sc.position.pixels >= _sc.position.maxScrollExtent;
      });
    });
  }

  @override
  void dispose() { _sc.dispose(); super.dispose(); }

  void _scroll(double d) => _sc.animateTo(
    (_sc.offset + d).clamp(0.0, _sc.position.maxScrollExtent),
    duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        child: _RowHeader(widget.label, widget.onSeeAll, null),
      ),
      // Scroll row
      if (widget.error != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _ErrorRow(onRetry: widget.onRetry),
        )
      else
        SizedBox(
          height: 240,
          child: Stack(clipBehavior: Clip.hardEdge, children: [
            widget.loading
                ? ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal, controller: _sc,
                    itemCount: 10, separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, __) => Container(
                      width: 130, color: _bg2,
                      margin: const EdgeInsets.only(bottom: 2),
                    ))
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal, controller: _sc,
                    itemCount: widget.items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (_, i) => BrowseCardWidget(
                      media: widget.items[i],
                      onTap: () => widget.onCardTap(widget.items[i]),
                    )),
            if (!_atStart)
              Positioned(left: 0, top: 0, bottom: 0,
                child: GestureDetector(onTap: () => _scroll(-400),
                  child: Container(width: 40,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.centerRight, end: Alignment.centerLeft,
                      colors: [Colors.transparent, _bg.withOpacity(0.95)])),
                    child: const Icon(Icons.chevron_left, color: _cyan, size: 20)))),
            if (!_atEnd && !widget.loading)
              Positioned(right: 0, top: 0, bottom: 0,
                child: GestureDetector(onTap: () => _scroll(400),
                  child: Container(width: 40,
                    decoration: BoxDecoration(gradient: LinearGradient(
                      begin: Alignment.centerLeft, end: Alignment.centerRight,
                      colors: [Colors.transparent, _bg.withOpacity(0.95)])),
                    child: const Icon(Icons.chevron_right, color: _cyan, size: 20)))),
          ]),
        ),
      // Thin separator line
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(height: 1, color: _border),
      ),
    ]);
  }
}

// --- DIAGONAL LINE PAINTER ---
class _DiagLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00d4d4).withOpacity(0.4)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, 0), paint);
  }
  @override bool shouldRepaint(_) => false;
}

// --- HEX CLIPPER ---
class _HexClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final p = Path();
    final w = size.width; final h = size.height;
    p.moveTo(w * 0.5, 0);
    p.lineTo(w, h * 0.25);
    p.lineTo(w, h * 0.75);
    p.lineTo(w * 0.5, h);
    p.lineTo(0, h * 0.75);
    p.lineTo(0, h * 0.25);
    p.close();
    return p;
  }
  @override bool shouldReclip(_) => false;
}

// --- WIN BTN ---
class _WinBtn extends StatefulWidget {
  final IconData icon; final VoidCallback onTap; final bool isClose;
  const _WinBtn({required this.icon, required this.onTap, this.isClose = false});
  @override State<_WinBtn> createState() => _WinBtnState();
}
class _WinBtnState extends State<_WinBtn> {
  bool _hov = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hov = true),
      onExit: (_) => setState(() => _hov = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 28, height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          decoration: BoxDecoration(
            color: _hov ? (widget.isClose ? const Color(0xFF7f1d1d) : _bg2) : Colors.transparent,
          ),
          child: Icon(widget.icon, size: 13,
            color: _hov ? (widget.isClose ? const Color(0xFFfca5a5) : _textPrimary) : _textMuted),
        ),
      ),
    );
  }
}
