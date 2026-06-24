import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import '../services/history_service.dart';
import '../services/watchlist_service.dart';
import '../services/search_history_service.dart';
import '../services/prefs_service.dart';

const _cyan = Color(0xFF00d4d4);
const _bg =   Color(0xFF0a0b0f);
const _bg2 =  Color(0xFF111827);
const _bg3 =  Color(0xFF0d0f18);
const _border = Color(0xFF1e2130);
const _textPrimary = Color(0xFFe2e8f0);
const _textMuted = Color(0xFF64748b);
const _red = Color(0xFFef4444);

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiController;
  bool _saved = false;
  bool _testing = false;
  String? _testResult;
  String? _exportPath;
  String? _statusMsg;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    _apiController = TextEditingController(text: api.apiBase);
  }

  @override
  void dispose() {
    _apiController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final api = context.read<ApiService>();
    await api.setApiBase(_apiController.text.trim());
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _test() async {
    setState(() { _testing = true; _testResult = null; });
    try {
      final api = context.read<ApiService>();
      final providers = await api.getProviders();
      setState(() {
        _testResult = 'CONNECTED — providers: ${providers.join(', ')}';
        _testing = false;
      });
    } catch (e) {
      setState(() { _testResult = 'FAILED: $e'; _testing = false; });
    }
  }

  void _showStatus(String msg) {
    setState(() => _statusMsg = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _statusMsg = null);
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await _confirm('Clear all watch history?');
    if (!confirmed) return;
    if (!mounted) return;
    await context.read<HistoryService>().clearAll();
    _showStatus('Watch history cleared');
  }

  Future<void> _clearWatchlist() async {
    final confirmed = await _confirm('Clear entire watchlist?');
    if (!confirmed) return;
    if (!mounted) return;
    await context.read<WatchlistService>().clearAll();
    _showStatus('Watchlist cleared');
  }

  Future<void> _clearSearchHistory() async {
    await context.read<SearchHistoryService>().clear();
    _showStatus('Search history cleared');
  }

  Future<void> _exportHistory() async {
    final history = context.read<HistoryService>();
    final prefs = context.read<PrefsService>();
    final entries = history.entries.map((e) => {
      'id': e.id,
      'name': e.name,
      'provider': e.provider,
      'episode': e.episode,
      'lang': e.lang,
      'progressMs': e.progress?.inMilliseconds,
    }).toList();
    final path = await prefs.exportHistory(entries);
    _showStatus('Exported to $path');
  }

  Future<bool> _confirm(String message) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        content: Text(message, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _textPrimary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL', style: TextStyle(fontFamily: 'monospace', color: _textMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM', style: TextStyle(fontFamily: 'monospace', color: _red))),
        ],
      ),
    ) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PrefsService>();

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg3,
        title: const Text('SETTINGS', style: TextStyle(
          fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 4,
        )),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _textMuted),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [

          // API SERVER
          _sectionLabel('API SERVER'),
          const SizedBox(height: 12),
          TextField(
            controller: _apiController,
            style: const TextStyle(fontFamily: 'monospace', color: _textPrimary),
            decoration: InputDecoration(
              hintText: 'http://192.168.0.37:3002',
              hintStyle: const TextStyle(fontFamily: 'monospace', color: _textMuted, fontSize: 13),
              filled: true, fillColor: _bg2,
              border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
              enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
              focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _cyan), borderRadius: BorderRadius.zero),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          Row(children: [
            _btn(_saved ? '✓ SAVED' : 'SAVE', _save, color: _saved ? Colors.green : _cyan),
            const SizedBox(width: 12),
            _btn('TEST CONNECTION', _test, loading: _testing, color: _textMuted),
          ]),
          if (_testResult != null) ...[
            const SizedBox(height: 10),
            Text(_testResult!, style: TextStyle(
              fontFamily: 'monospace', fontSize: 11,
              color: _testResult!.startsWith('CONNECTED') ? _cyan : _red,
            )),
          ],

          _divider(),

          // DISPLAY
          _sectionLabel('DISPLAY'),
          const SizedBox(height: 12),
          _toggle('Compact card mode', 'Smaller cards, more per row', prefs.compactCards,
              (v) => prefs.setCompactCards(v)),
          _toggle('Show score badges', 'Star rating overlay on cards', prefs.showScoreBadge,
              (v) => prefs.setShowScoreBadge(v)),
          _toggle('Show episode count', 'Episode count below card title', prefs.showEpisodeCount,
              (v) => prefs.setShowEpisodeCount(v)),

          _divider(),

          // DATA MANAGEMENT
          _sectionLabel('DATA'),
          const SizedBox(height: 12),
          _actionBtn('Export watch history', Icons.upload, _exportHistory),
          const SizedBox(height: 8),
          _actionBtn('Clear watch history', Icons.history, _clearHistory, danger: true),
          const SizedBox(height: 8),
          _actionBtn('Clear watchlist', Icons.bookmark_remove, _clearWatchlist, danger: true),
          const SizedBox(height: 8),
          _actionBtn('Clear search history', Icons.search_off, _clearSearchHistory, danger: true),

          if (_statusMsg != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _cyan.withOpacity(0.08),
                border: Border.all(color: _cyan.withOpacity(0.3)),
              ),
              child: Text(_statusMsg!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: _cyan)),
            ),
          ],

          _divider(),

          // ABOUT
          _sectionLabel('ABOUT'),
          const SizedBox(height: 12),
          FutureBuilder<String>(
            future: getMagiVersion(),
            builder: (context, snap) {
              final version = snap.data ?? '...';
              return Text('MAGI // ANIME TERMINAL\nv$version',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textMuted, height: 1.8));
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text, style: const TextStyle(
    fontFamily: 'monospace', fontSize: 10, color: _textMuted, letterSpacing: 3,
  ));

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: Divider(color: _border),
  );

  Widget _btn(String label, VoidCallback onTap, {bool loading = false, Color color = _cyan}) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(border: Border.all(color: color.withOpacity(0.5))),
        child: loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
            : Text(label, style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: color, letterSpacing: 1)),
      ),
    );
  }

  Widget _toggle(String title, String subtitle, bool value, void Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: _bg2, border: Border.all(color: _border)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _textPrimary)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textMuted)),
        ])),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: _cyan,
          inactiveTrackColor: _border,
        ),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon, VoidCallback onTap, {bool danger = false}) {
    final color = danger ? _red : _cyan;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _bg2, border: Border.all(color: _border),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: color.withOpacity(0.8)),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 13, color: danger ? _red.withOpacity(0.9) : _textPrimary)),
          const Spacer(),
          Icon(Icons.chevron_right, size: 16, color: _textMuted),
        ]),
      ),
    );
  }
}
