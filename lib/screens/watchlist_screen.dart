import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/watchlist_service.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFF5a6080);

class WatchlistScreen extends StatelessWidget {
  final String provider;
  const WatchlistScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final watchlist = context.watch<WatchlistService>();
    final entries = watchlist.entries;

    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'NO TITLES IN WATCHLIST\nBOOKMARK ANIME FROM THE DETAIL SCREEN',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textDim, letterSpacing: 1, height: 2),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.55,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
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
              Navigator.push(context, MaterialPageRoute(
                builder: (_) => DetailScreen(media: media, provider: provider),
              ));
            }
          },
          onLongPress: () {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: _bg2,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                title: Text(e.title, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CANCEL', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
                  ),
                  TextButton(
                    onPressed: () {
                      context.read<WatchlistService>().remove(e.anilistId);
                      Navigator.pop(context);
                    },
                    child: const Text('REMOVE', style: TextStyle(fontFamily: 'monospace', color: Color(0xFFd44000))),
                  ),
                ],
              ),
            );
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: e.coverImage != null
                    ? Image.network(e.coverImage!, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: _bg3))
                    : Container(color: _bg3),
              ),
              const SizedBox(height: 5),
              Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: Color(0xFFc8ccd8), height: 1.3)),
              if (e.episodes != null)
                Text('${e.episodes} EP', style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim)),
            ],
          ),
        );
      },
    );
  }
}
