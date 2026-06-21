import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/shimmer.dart';
import 'detail_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFF5a6080);
const _red = Color(0xFFd44000);

const _seasons = ['WINTER', 'SPRING', 'SUMMER', 'FALL'];

class SeasonalScreen extends StatefulWidget {
  final String provider;
  const SeasonalScreen({super.key, required this.provider});

  @override
  State<SeasonalScreen> createState() => _SeasonalScreenState();
}

class _SeasonalScreenState extends State<SeasonalScreen> {
  int _year = DateTime.now().year;
  String _season = _currentSeason();
  List<AnilistMedia> _results = [];
  bool _loading = false;
  String? _error;

  static String _currentSeason() {
    final month = DateTime.now().month;
    if (month <= 3) return 'WINTER';
    if (month <= 6) return 'SPRING';
    if (month <= 9) return 'SUMMER';
    return 'FALL';
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final results = await api.fetchSeasonal(_year, _season);
      setState(() { _results = results; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0a0b0f),
      appBar: AppBar(
        title: const Text('SEASONAL', style: TextStyle(fontFamily: 'monospace', fontSize: 14, color: _cyan, letterSpacing: 4)),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: _textDim), onPressed: () => Navigator.pop(context)),
      ),
      body: Column(
        children: [
          // Season/year picker
          Container(
            color: _bg2,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Year
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: _textDim),
                  onPressed: () { setState(() => _year--); _load(); },
                ),
                Text('$_year', style: const TextStyle(fontFamily: 'monospace', fontSize: 16, color: Color(0xFFc8ccd8), letterSpacing: 2)),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: _textDim),
                  onPressed: () { setState(() => _year++); _load(); },
                ),
                const SizedBox(width: 16),
                // Season buttons
                Expanded(
                  child: Row(
                    children: _seasons.map((s) {
                      final active = s == _season;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () { setState(() => _season = s); _load(); },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: active ? _cyan.withOpacity(0.5) : _border),
                              color: active ? _cyan.withOpacity(0.1) : Colors.transparent,
                            ),
                            child: Text(s.substring(0, 2), textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: active ? _cyan : _textDim, letterSpacing: 1)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: _border, height: 1),

          // Results
          Expanded(
            child: _loading
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 150, childAspectRatio: 0.55, crossAxisSpacing: 10, mainAxisSpacing: 10,
                    ),
                    itemCount: 20,
                    itemBuilder: (_, __) => const ShimmerBrowseCard(),
                  )
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('ERROR: $_error', style: const TextStyle(fontFamily: 'monospace', color: _red, fontSize: 12)),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _load,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.5))),
                            child: const Text('RETRY', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _cyan, letterSpacing: 2)),
                          ),
                        ),
                      ]))
                    : _results.isEmpty
                        ? const Center(child: Text('NO RESULTS', style: TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 12, letterSpacing: 2)))
                        : GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 150, childAspectRatio: 0.55, crossAxisSpacing: 10, mainAxisSpacing: 10,
                            ),
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final m = _results[i];
                              final score = m.averageScore != null ? '★ ${(m.averageScore! / 10).toStringAsFixed(1)}' : null;
                              return GestureDetector(
                                onTap: () => Navigator.push(context, MaterialPageRoute(
                                  builder: (_) => DetailScreen(media: m, provider: widget.provider),
                                )),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: m.coverImage != null
                                          ? Image.network(m.coverImage!, width: double.infinity, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(color: _bg3))
                                          : Container(color: _bg3),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(m.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFc8ccd8), height: 1.3)),
                                    if (score != null)
                                      Text(score, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan)),
                                  ],
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
