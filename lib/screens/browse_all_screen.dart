import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/anime_preview_sheet.dart';

const _cyan = Color(0xFF00d4d4);
const _bg = Color(0xFF0a0b0f);
const _bg2 = Color(0xFF111827);
const _bg3 = Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textPrimary = Color(0xFFe2e8f0);
const _textMuted = Color(0xFF94a3b8);

class BrowseAllScreen extends StatefulWidget {
  final String label;
  final String query;
  final List<AnilistMedia> initialItems;
  final String provider;

  const BrowseAllScreen({
    super.key,
    required this.label,
    required this.query,
    required this.initialItems,
    required this.provider,
  });

  @override
  State<BrowseAllScreen> createState() => _BrowseAllScreenState();
}

class _BrowseAllScreenState extends State<BrowseAllScreen> {
  List<AnilistMedia> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _items = widget.initialItems;
    _fetchAll();
  }

  Future<void> _fetchAll() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final results = await api.fetchBrowseRowPaged(widget.query);
      if (mounted) setState(() { _items = results; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg3,
        title: Row(children: [
          Text(widget.label.toUpperCase(), style: const TextStyle(
            fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 3,
          )),
          if (_loading) ...[
            const SizedBox(width: 12),
            const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
          ],
          if (!_loading)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text('${_items.length} titles', style: const TextStyle(
                fontFamily: 'monospace', fontSize: 10, color: _textMuted, letterSpacing: 1,
              )),
            ),
        ]),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _error != null
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Error: $_error', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFef4444))),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _fetchAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.4)), borderRadius: BorderRadius.circular(6)),
                  child: const Text('RETRY', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _cyan)),
                ),
              ),
            ]))
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 150, childAspectRatio: 0.52,
                crossAxisSpacing: 12, mainAxisSpacing: 12,
              ),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final media = _items[i];
                final score = media.averageScore != null
                    ? '★ ${(media.averageScore! / 10).toStringAsFixed(1)}' : null;
                return GestureDetector(
                  onTap: () => showAnimePreview(context, media, widget.provider),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(children: [
                          media.coverImage != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.network(media.coverImage!, width: double.infinity, fit: BoxFit.cover,
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
                      Text(media.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _textPrimary, height: 1.3)),
                      if (media.episodes != null)
                        Text('${media.episodes} EP',
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
