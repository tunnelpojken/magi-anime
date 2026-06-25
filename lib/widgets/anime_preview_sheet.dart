import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/watchlist_service.dart';
import '../utils/transitions.dart';
import '../screens/detail_screen.dart';
import '../screens/episode_screen.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF111827);
const _bg3 = Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textPrimary = Color(0xFFe2e8f0);
const _textSecondary = Color(0xFF94a3b8);
const _textMuted = Color(0xFF64748b);

void showAnimePreview(BuildContext context, AnilistMedia media, String provider) {
  Navigator.of(context).push(PageRouteBuilder(
    opaque: false,
    barrierDismissible: true,
    barrierColor: Colors.black38,
    pageBuilder: (_, __, ___) => _AnimePreviewSlider(media: media, provider: provider),
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  ));
}

class _AnimePreviewSlider extends StatefulWidget {
  final AnilistMedia media;
  final String provider;
  const _AnimePreviewSlider({required this.media, required this.provider});

  @override
  State<_AnimePreviewSlider> createState() => _AnimePreviewSliderState();
}

class _AnimePreviewSliderState extends State<_AnimePreviewSlider>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _slide = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _ctrl.reverse();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: _close,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            Positioned(
              right: 0, top: 0, bottom: 0,
              width: 380,
              child: GestureDetector(
                onTap: () {},
                child: SlideTransition(
                  position: _slide,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _bg2,
                      border: Border(left: BorderSide(color: _border, width: 1)),
                    ),
                    child: _AnimePreviewContent(
                      media: widget.media,
                      provider: widget.provider,
                      onClose: _close,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimePreviewContent extends StatelessWidget {
  final AnilistMedia media;
  final String provider;
  final VoidCallback onClose;
  const _AnimePreviewContent({required this.media, required this.provider, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final inList = watchlist.isInWatchlist(media.id);
    final score = media.averageScore != null
        ? '★ ${(media.averageScore! / 10).toStringAsFixed(1)}' : null;
    final synopsis = media.description
        ?.replaceAll(RegExp(r'<[^>]+>'), '')
        .replaceAll('\n', ' ')
        .trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cover image as header banner
        if (media.coverImage != null)
          Stack(children: [
            ShaderMask(
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, _bg2],
                stops: const [0.5, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Image.network(
                media.coverImage!,
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 220, color: _bg3),
              ),
            ),
            Positioned(
              top: 12, right: 12,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: _bg2.withOpacity(0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.close, size: 16, color: _textMuted),
                ),
              ),
            ),
          ])
        else
          Container(
            height: 80,
            color: _bg3,
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: onClose,
                  child: const Icon(Icons.close, size: 18, color: _textMuted),
                ),
              ),
            ),
          ),

        // Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(media.title, style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _textPrimary, height: 1.2,
                )),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (score != null) _Badge(score, highlight: true),
                  if (media.episodes != null) _Badge('${media.episodes} EP'),
                  if (media.year != null) _Badge('${media.year}'),
                  if (media.status == 'RELEASING') _Badge('AIRING'),
                  ...media.genres.take(4).map((g) => _Badge(g)),
                ]),
                if (synopsis != null && synopsis.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(synopsis, style: const TextStyle(
                    fontSize: 13, color: _textMuted, height: 1.65,
                  ), maxLines: 8, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 20),

                // Action buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _watch(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _cyan, borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.play_arrow, color: Color(0xFF0a0b0f), size: 18),
                          SizedBox(width: 6),
                          Text('WATCH', style: TextStyle(
                            fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.w700,
                            color: Color(0xFF0a0b0f), letterSpacing: 1,
                          )),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => watchlist.toggle(media),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: inList ? _cyan.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: inList ? _cyan.withOpacity(0.5) : _border),
                      ),
                      child: Icon(
                        inList ? Icons.bookmark : Icons.bookmark_border,
                        color: inList ? _cyan : _textMuted, size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      final nav = Navigator.of(context);
                      onClose();
                      nav.push(fadeSlideRoute(
                        DetailScreen(media: media, provider: provider),
                      ));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _border),
                      ),
                      child: const Text('MORE', style: TextStyle(
                        fontFamily: 'monospace', fontSize: 11, color: _textSecondary, letterSpacing: 1,
                      )),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _watch(BuildContext context) async {
    final api = context.read<ApiService>();
    final history = context.read<HistoryService>();
    // Capture navigator before any async gap
    final rootNav = Navigator.of(context, rootNavigator: true);
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: _cyan)));
    try {
      final results = await api.search(media.title, provider);
      rootNav.pop(); // dismiss loading
      if (results.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No results found')));
        return;
      }
      final anime = results.first;
      final saved = history.getEntry(anime.id);
      // Close panel first, then push episode screen on root navigator
      onClose();
      await Future.delayed(const Duration(milliseconds: 320));
      rootNav.push(fadeSlideRoute(
        EpisodeScreen(anime: anime, anilistMedia: media, autoPlay: saved?.episode ?? 1.0, autoPlayResume: saved?.progress),
      ));
    } catch (e) {
      rootNav.pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final bool highlight;
  const _Badge(this.text, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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
