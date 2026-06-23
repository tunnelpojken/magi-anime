import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../utils/transitions.dart';
import 'detail_screen.dart';

const _cyan = Color(0xFF00d4d4);
const _bg = Color(0xFF0a0b0f);
const _bg2 = Color(0xFF111827);
const _bg3 = Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textPrimary = Color(0xFFe2e8f0);
const _textSecondary = Color(0xFF94a3b8);
const _textMuted = Color(0xFF475569);

class AiringScheduleScreen extends StatefulWidget {
  final String provider;
  const AiringScheduleScreen({super.key, required this.provider});

  @override
  State<AiringScheduleScreen> createState() => _AiringScheduleScreenState();
}

class _AiringScheduleScreenState extends State<AiringScheduleScreen> {
  final List<Map<String, dynamic>> _schedule = [];
  bool _loading = true;
  String? _error;
  int _selectedDay = 0; // 0 = today

  final List<String> _dayNames = ['Today', 'Tomorrow', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final now = DateTime.now();
      // Get airing schedule for next 7 days
      final weekStart = now.millisecondsSinceEpoch ~/ 1000;
      final weekEnd = weekStart + 7 * 24 * 60 * 60;

      final data = await api.fetchAiringSchedule(weekStart, weekEnd);
      setState(() { _schedule.clear(); _schedule.addAll(data); _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  List<Map<String, dynamic>> get _todayItems {
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day)
        .add(Duration(days: _selectedDay));
    final dayEnd = dayStart.add(const Duration(days: 1));
    return _schedule.where((item) {
      final time = DateTime.fromMillisecondsSinceEpoch(
          (item['airingAt'] as int) * 1000);
      return time.isAfter(dayStart) && time.isBefore(dayEnd);
    }).toList()
      ..sort((a, b) => (a['airingAt'] as int).compareTo(b['airingAt'] as int));
  }

  List<String> get _weekDayLabels {
    final now = DateTime.now();
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return List.generate(7, (i) {
      if (i == 0) return 'Today';
      if (i == 1) return 'Tomorrow';
      final day = now.add(Duration(days: i));
      return days[day.weekday - 1];
    });
  }

  @override
  Widget build(BuildContext context) {
    final labels = _weekDayLabels;
    final items = _todayItems;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg3,
        title: const Text('AIRING SCHEDULE', style: TextStyle(
          fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 3,
        )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Day selector
          Container(
            color: _bg3,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: List.generate(7, (i) {
                final active = i == _selectedDay;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: active ? _cyan.withOpacity(0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: active ? _cyan.withOpacity(0.5) : _border),
                      ),
                      child: Text(labels[i],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'monospace', fontSize: 10,
                          color: active ? _cyan : _textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const Divider(color: _border, height: 1),

          // Schedule list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
                : _error != null
                    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text('Error: $_error', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFd44000))),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _loadSchedule,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: _cyan.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('RETRY', style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _cyan)),
                          ),
                        ),
                      ]))
                    : items.isEmpty
                        ? const Center(child: Text('No episodes airing', style: TextStyle(fontSize: 14, color: _textMuted)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: items.length,
                            itemBuilder: (context, i) {
                              final item = items[i];
                              final media = item['media'] as Map<String, dynamic>;
                              final title = (media['title'] as Map)['english'] ??
                                  (media['title'] as Map)['romaji'] ?? 'Unknown';
                              final cover = (media['coverImage'] as Map?)?['large'] as String?;
                              final ep = item['episode'] as int;
                              final airingAt = DateTime.fromMillisecondsSinceEpoch((item['airingAt'] as int) * 1000);
                              final timeStr = '${airingAt.hour.toString().padLeft(2, '0')}:${airingAt.minute.toString().padLeft(2, '0')}';
                              final isPast = airingAt.isBefore(DateTime.now());

                              return InkWell(
                                onTap: () async {
                                  final api = context.read<ApiService>();
                                  final mediaId = media['id'] as int;
                                  final full = await api.fetchAnilistById(mediaId);
                                  if (full != null && mounted) {
                                    Navigator.push(context, fadeSlideRoute(
                                      DetailScreen(media: full, provider: widget.provider),
                                    ));
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  decoration: const BoxDecoration(
                                    border: Border(bottom: BorderSide(color: _border, width: 0.5)),
                                  ),
                                  child: Row(children: [
                                    // Time
                                    SizedBox(
                                      width: 44,
                                      child: Text(timeStr, style: TextStyle(
                                        fontFamily: 'monospace', fontSize: 12,
                                        color: isPast ? _textMuted : _cyan,
                                        fontWeight: FontWeight.w600,
                                      )),
                                    ),
                                    const SizedBox(width: 12),
                                    // Cover
                                    if (cover != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(cover, width: 36, height: 50, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(width: 36, height: 50, color: _bg2)),
                                      )
                                    else
                                      Container(width: 36, height: 50, color: _bg2, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4))),
                                    const SizedBox(width: 14),
                                    // Info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(title, style: TextStyle(
                                            fontSize: 14, fontWeight: FontWeight.w500,
                                            color: isPast ? _textSecondary : _textPrimary,
                                          ), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          const SizedBox(height: 3),
                                          Text('Episode $ep', style: const TextStyle(
                                            fontFamily: 'monospace', fontSize: 11, color: _textMuted,
                                          )),
                                        ],
                                      ),
                                    ),
                                    if (isPast)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: _cyan.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: _cyan.withOpacity(0.3)),
                                        ),
                                        child: const Text('AIRED', style: TextStyle(
                                          fontFamily: 'monospace', fontSize: 9, color: _cyan, letterSpacing: 1,
                                        )),
                                      ),
                                  ]),
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
