import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/watchlist_service.dart';
import '../services/api_service.dart';
import '../utils/transitions.dart';
import 'detail_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF111827);
const _bg3 = Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFF64748b);
const _textPrimary = Color(0xFFe2e8f0);
const _green = Color(0xFF22c55e);

class WatchlistScreen extends StatefulWidget {
  final String provider;
  const WatchlistScreen({super.key, required this.provider});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showContextMenu(BuildContext context, WatchlistEntry e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(e.title, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan),
          overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
          ),
          TextButton(
            onPressed: () {
              context.read<WatchlistService>().markFinished(e.anilistId, !e.finished);
              Navigator.pop(context);
            },
            child: Text(e.finished ? 'MOVE TO WATCHING' : 'MARK FINISHED',
              style: const TextStyle(fontFamily: 'monospace', color: _green)),
          ),
          TextButton(
            onPressed: () {
              context.read<WatchlistService>().remove(e.anilistId);
              Navigator.pop(context);
            },
            child: const Text('REMOVE', style: TextStyle(fontFamily: 'monospace', color: Color(0xFFef4444))),
          ),
        ],
      ),
    );
  }

  Widget _grid(BuildContext context, List<WatchlistEntry> entries) {
    if (entries.isEmpty) {
      return const Center(
        child: Text('NOTHING HERE YET', style: TextStyle(
          fontFamily: 'monospace', fontSize: 12, color: _textDim, letterSpacing: 2,
        )),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150, childAspectRatio: 0.55,
        crossAxisSpacing: 10, mainAxisSpacing: 10,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        return GestureDetector(
          onTap: () async {
            final api = context.read<ApiService>();
            showDialog(context: context, barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator(color: _cyan)));
            final media = await api.fetchAnilistById(e.anilistId);
            if (!context.mounted) return;
            Navigator.pop(context);
            if (media != null) {
              Navigator.push(context, fadeSlideRoute(DetailScreen(media: media, provider: widget.provider)));
            }
          },
          onLongPress: () => _showContextMenu(context, e),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(children: [
                  e.coverImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(e.coverImage!, width: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: _bg3)))
                      : Container(color: _bg3, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4))),
                  if (e.finished)
                    Positioned(
                      top: 6, right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: _green.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text('✓', style: TextStyle(fontSize: 10, color: Colors.white)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 5),
              Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: _textPrimary, height: 1.3)),
              if (e.episodes != null)
                Text('${e.episodes} EP', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim)),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final watching = watchlist.entries.where((e) => !e.finished).toList();
    final finished = watchlist.entries.where((e) => e.finished).toList();

    return Column(
      children: [
        Container(
          color: _bg3,
          child: TabBar(
            controller: _tabs,
            labelColor: _cyan,
            unselectedLabelColor: _textDim,
            indicatorColor: _cyan,
            labelStyle: const TextStyle(fontFamily: 'monospace', fontSize: 11, letterSpacing: 2),
            tabs: [
              Tab(text: 'WATCHING (${watching.length})'),
              Tab(text: 'FINISHED (${finished.length})'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _grid(context, watching),
              _grid(context, finished),
            ],
          ),
        ),
      ],
    );
  }
}
