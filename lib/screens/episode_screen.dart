import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/history_service.dart';
import '../services/cast_service.dart';

const _cyan = Color(0xFF00d4d4);
const _bg2 = Color(0xFF0f1117);
const _bg3 = Color(0xFF151720);
const _border = Color(0xFF1e2130);
const _textDim = Color(0xFF5a6080);
const _red = Color(0xFFd44000);

class EpisodeScreen extends StatefulWidget {
  final AnimeResult anime;
  const EpisodeScreen({super.key, required this.anime});

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> with WidgetsBindingObserver {
  List<double> _episodes = [];
  List<double> _filtered = [];
  bool _loading = true;
  String? _error;
  String _lang = 'sub';
  double? _playingEp;
  bool _loadingStream = false;
  final _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late final Player _player;
  late final VideoController _videoController;
  bool _playerReady = false;

  // Overlay controls
  bool _showOverlay = false;
  Timer? _overlayTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _isPlaying = false;
  double _volume = 100;
  bool _isFullscreen = false;
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _playSub;
  StreamSubscription? _completeSub;

  // Next episode
  bool _showNextEpPrompt = false;
  int _nextEpCountdown = 5;
  Timer? _nextEpTimer;

  // Progress
  Timer? _progressTimer;
  Duration _lastSavedPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _player = Player();
    _videoController = VideoController(_player);
    _setupPlayerListeners();
    _loadEpisodes();
    _searchController.addListener(_filterEpisodes);
  }

  void _setupPlayerListeners() {
    _posSub = _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _durSub = _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _playSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    _completeSub = _player.stream.completed.listen((completed) {
      if (completed && mounted) _onEpisodeComplete();
    });
  }

  void _onEpisodeComplete() {
    if (_playingEp == null) return;
    final idx = _episodes.indexOf(_playingEp!);
    if (idx < 0 || idx >= _episodes.length - 1) return;
    final nextEp = _episodes[idx + 1];
    setState(() { _showNextEpPrompt = true; _nextEpCountdown = 5; });
    _nextEpTimer?.cancel();
    _nextEpTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _nextEpCountdown--);
      if (_nextEpCountdown <= 0) {
        t.cancel();
        setState(() => _showNextEpPrompt = false);
        _playEpisode(nextEp);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _player.pause();
      _saveCurrentProgress();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _progressTimer?.cancel();
    _overlayTimer?.cancel();
    _nextEpTimer?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _completeSub?.cancel();
    _saveCurrentProgress();
    _player.pause();
    _player.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 5), (_) => _saveCurrentProgress());
  }

  Future<void> _saveCurrentProgress() async {
    if (_playingEp == null || !mounted) return;
    final pos = _player.state.position;
    if (pos == _lastSavedPosition || pos.inSeconds < 3) return;
    _lastSavedPosition = pos;
    final history = context.read<HistoryService>();
    await history.save(widget.anime.id, widget.anime.name, widget.anime.provider, _playingEp!, _lang, progress: pos);
  }

  void _toggleOverlay() {
    setState(() => _showOverlay = !_showOverlay);
    if (_showOverlay) {
      _overlayTimer?.cancel();
      _overlayTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showOverlay = false);
      });
    }
  }

  void _keepOverlay() {
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showOverlay = false);
    });
  }

  Future<void> _toggleFullscreen() async {
    _isFullscreen = !_isFullscreen;
    if (_isFullscreen) {
      await windowManager.setFullScreen(true);
    } else {
      await windowManager.setFullScreen(false);
    }
    setState(() {});
    _keepOverlay();
  }

  Future<void> _loadEpisodes() async {
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final eps = await api.getEpisodes(widget.anime.id, widget.anime.provider, _lang);
      setState(() { _episodes = eps; _filtered = eps; _loading = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkAutoResume());
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _filterEpisodes() {
    final q = _searchController.text.trim();
    setState(() {
      if (q.isEmpty) {
        _filtered = _episodes;
      } else {
        final n = double.tryParse(q);
        _filtered = _episodes.where((ep) {
          if (n != null) return ep == n || ep.toInt() == n.toInt();
          return ep.toString().contains(q);
        }).toList();
      }
    });
  }

  void _checkAutoResume() {
    final history = context.read<HistoryService>();
    final saved = history.getEntry(widget.anime.id);
    if (saved == null) return;

    final hasProgress = saved.progress != null && saved.progress!.inSeconds > 5;
    // Only suggest next episode if watched past 85% (~20min of 24min episode)
    final nearComplete = saved.progress != null && saved.progress!.inSeconds > (24 * 60 * 0.85);

    final nextIdx = _episodes.indexWhere((e) => e > saved.episode);
    final nextEp = (nearComplete && nextIdx >= 0) ? _episodes[nextIdx] : null;
    final resumeEp = nextEp ?? saved.episode;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _bg2,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        title: Text(
          nextEp != null ? 'CONTINUE TO EP ${resumeEp.toInt()}?' : 'RESUME EP ${resumeEp.toInt()}?',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 1),
        ),
        content: Text(
          nextEp != null ? 'Last watched EP ${saved.episode.toInt()}. Play next?'
              : hasProgress ? 'Resume from ${_fmt(saved.progress!)}?' : 'Resume from beginning?',
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: _textDim),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: const Text('BROWSE', style: TextStyle(fontFamily: 'monospace', color: _textDim))),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _playEpisode(resumeEp, resumeFrom: nextEp == null && hasProgress ? saved.progress : null);
            },
            child: const Text('PLAY', style: TextStyle(fontFamily: 'monospace', color: _cyan))),
        ],
      ),
    );
  }

  void _jumpToNextUnwatched() {
    final history = context.read<HistoryService>();
    final saved = history.getEntry(widget.anime.id);
    final lastEp = saved?.episode ?? 0;
    final nextUnwatched = _episodes.firstWhere((e) => e > lastEp, orElse: () => _episodes.first);
    _playEpisode(nextUnwatched);
  }

  void _showCastDialog() async {
    final cast = context.read<CastService>();
    await cast.startScan();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Consumer<CastService>(
        builder: (context, cast, _) => AlertDialog(
          backgroundColor: _bg2,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: Row(children: [
            const Text('CAST TO DEVICE', style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan, letterSpacing: 1)),
            const Spacer(),
            if (cast.scanning) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
          ]),
          content: SizedBox(
            width: 300,
            child: cast.devices.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('NO DEVICES FOUND\nMake sure Chromecast is on the same network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: _textDim, height: 1.8)),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: cast.devices.map((d) => ListTile(
                      leading: Icon(Icons.cast, color: cast.connectedDevice == d ? _cyan : _textDim),
                      title: Text(d.name, style: TextStyle(
                        fontFamily: 'monospace', fontSize: 12,
                        color: cast.connectedDevice == d ? _cyan : const Color(0xFFc8ccd8),
                      )),
                      onTap: () async {
                        await cast.connect(d);
                        if (_playingEp != null && mounted) {
                          final api = context.read<ApiService>();
                          final url = api.getProxyUrl(widget.anime.id, _playingEp!, widget.anime.provider, _lang);
                          await cast.cast(url, '${widget.anime.name} EP ${_playingEp!.toInt()}');
                          _player.pause();
                        }
                        if (mounted) Navigator.pop(context);
                      },
                    )).toList(),
                  ),
          ),
          actions: [
            if (cast.isConnected)
              TextButton(
                onPressed: () { cast.disconnect(); Navigator.pop(context); },
                child: const Text('DISCONNECT', style: TextStyle(fontFamily: 'monospace', color: _red)),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE', style: TextStyle(fontFamily: 'monospace', color: _textDim)),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  Future<void> _playEpisode(double ep, {Duration? resumeFrom}) async {
    setState(() { _loadingStream = true; _playingEp = ep; _playerReady = false; _showNextEpPrompt = false; });
    _progressTimer?.cancel();
    _nextEpTimer?.cancel();
    _lastSavedPosition = Duration.zero;
    final api = context.read<ApiService>();
    final cast = context.read<CastService>();
    final history = context.read<HistoryService>();
    final proxyUrl = api.getProxyUrl(widget.anime.id, ep, widget.anime.provider, _lang);
    final title = '${widget.anime.name} EP ${ep.toInt()}';

    try {
      // If casting, send to Chromecast instead of local player
      if (cast.isConnected) {
        await cast.cast(proxyUrl, title);
        await history.save(widget.anime.id, widget.anime.name, widget.anime.provider, ep, _lang);
        if (mounted) setState(() { _loadingStream = false; _playerReady = false; });
        _scrollToEpisode(ep);
        return;
      }

      // Local playback
      await _player.open(Media(proxyUrl));
      if (resumeFrom != null && resumeFrom.inSeconds > 3) {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) await _player.seek(resumeFrom);
      }
      await history.save(widget.anime.id, widget.anime.name, widget.anime.provider, ep, _lang);
      if (mounted) setState(() { _loadingStream = false; _playerReady = true; });
      _startProgressTimer();
      _scrollToEpisode(ep);
    } catch (e) {
      if (mounted) {
        setState(() { _loadingStream = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _scrollToEpisode(double ep) {
    final idx = _filtered.indexOf(ep);
    if (idx < 0 || !_scrollController.hasClients) return;
    final offset = (idx * 49.0).clamp(0.0, _scrollController.position.maxScrollExtent);
    _scrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.space:
        _isPlaying ? _player.pause() : _player.play();
        _toggleOverlay();
        break;
      case LogicalKeyboardKey.arrowRight:
        _player.seek(_position + const Duration(seconds: 10));
        _keepOverlay();
        break;
      case LogicalKeyboardKey.arrowLeft:
        _player.seek(_position - const Duration(seconds: 10));
        _keepOverlay();
        break;
      case LogicalKeyboardKey.arrowUp:
        setState(() => _volume = (_volume + 10).clamp(0, 100));
        _player.setVolume(_volume);
        _keepOverlay();
        break;
      case LogicalKeyboardKey.arrowDown:
        setState(() => _volume = (_volume - 10).clamp(0, 100));
        _player.setVolume(_volume);
        _keepOverlay();
        break;
      case LogicalKeyboardKey.keyF:
        _toggleFullscreen();
        break;
      case LogicalKeyboardKey.escape:
        if (_isFullscreen) _toggleFullscreen();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryService>();
    final cast = context.watch<CastService>();
    final saved = history.getEntry(widget.anime.id);
    final lastEp = saved?.episode;
    final screenH = MediaQuery.of(context).size.height;

    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKeyEvent: _handleKey,
      child: PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            if (_isFullscreen) windowManager.setFullScreen(false);
            _progressTimer?.cancel();
            _saveCurrentProgress();
            _player.pause();
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0a0b0f),
          appBar: _isFullscreen ? null : AppBar(
            title: Text(widget.anime.name, style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: _cyan), overflow: TextOverflow.ellipsis),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: _textDim),
              onPressed: () { _progressTimer?.cancel(); _saveCurrentProgress(); _player.pause(); Navigator.pop(context); },
            ),
          ),
          body: _isFullscreen
              ? Stack(
                  children: [
                    Container(
                      color: Colors.black,
                      child: GestureDetector(
                        onTap: _toggleOverlay,
                        child: Video(controller: _videoController, controls: NoVideoControls),
                      ),
                    ),
                    if (_showOverlay)
                      _PlayerOverlay(
                        position: _position,
                        duration: _duration,
                        isPlaying: _isPlaying,
                        volume: _volume,
                        onPlayPause: () { _isPlaying ? _player.pause() : _player.play(); _keepOverlay(); },
                        onSeek: (v) { _player.seek(Duration(seconds: (v * _duration.inSeconds).round())); _keepOverlay(); },
                        onVolume: (v) { setState(() => _volume = v); _player.setVolume(v); _keepOverlay(); },
                        onSkipBack: () { _player.seek(_position - const Duration(seconds: 10)); _keepOverlay(); },
                        onSkipForward: () { _player.seek(_position + const Duration(seconds: 10)); _keepOverlay(); },
                        onCast: _showCastDialog,
                        isCasting: cast.isConnected,
                        onFullscreen: _toggleFullscreen,
                        isFullscreen: _isFullscreen,
                      ),
                    if (_showNextEpPrompt)
                      _NextEpPrompt(
                        countdown: _nextEpCountdown,
                        onPlay: () {
                          _nextEpTimer?.cancel();
                          setState(() => _showNextEpPrompt = false);
                          final idx = _episodes.indexOf(_playingEp!);
                          if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]);
                        },
                        onCancel: () { _nextEpTimer?.cancel(); setState(() => _showNextEpPrompt = false); },
                      ),
                  ],
                )
              : Column(
            children: [
              // Video player with overlay
              if (_playingEp != null)
                SizedBox(
                  height: screenH * 0.65,
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.black,
                        child: _loadingStream
                            ? const Center(child: CircularProgressIndicator(color: _cyan))
                            : GestureDetector(
                                onTap: _toggleOverlay,
                                child: Video(
                                  controller: _videoController,
                                  controls: NoVideoControls,
                                ),
                              ),
                      ),
                      // Controls overlay
                      if (_showOverlay && !_loadingStream)
                        _PlayerOverlay(
                          position: _position,
                          duration: _duration,
                          isPlaying: _isPlaying,
                          volume: _volume,
                          onPlayPause: () { _isPlaying ? _player.pause() : _player.play(); _keepOverlay(); },
                          onSeek: (v) { _player.seek(Duration(seconds: (v * _duration.inSeconds).round())); _keepOverlay(); },
                          onVolume: (v) { setState(() => _volume = v); _player.setVolume(v); _keepOverlay(); },
                          onSkipBack: () { _player.seek(_position - const Duration(seconds: 10)); _keepOverlay(); },
                          onSkipForward: () { _player.seek(_position + const Duration(seconds: 10)); _keepOverlay(); },
                          onCast: _showCastDialog,
                          isCasting: cast.isConnected,
                          onFullscreen: _toggleFullscreen,
                          isFullscreen: _isFullscreen,
                        ),
                      // Next episode prompt
                      if (_showNextEpPrompt)
                        _NextEpPrompt(
                          countdown: _nextEpCountdown,
                          onPlay: () {
                            _nextEpTimer?.cancel();
                            setState(() => _showNextEpPrompt = false);
                            final idx = _episodes.indexOf(_playingEp!);
                            if (idx >= 0 && idx < _episodes.length - 1) _playEpisode(_episodes[idx + 1]);
                          },
                          onCancel: () { _nextEpTimer?.cancel(); setState(() => _showNextEpPrompt = false); },
                        ),
                    ],
                  ),
                ),

              // Lang toggle
              Container(
                color: _bg2,
                child: Row(children: [_langBtn('SUB', 'sub'), _langBtn('DUB', 'dub')]),
              ),
              const Divider(color: _border, height: 1),

              // Episode list header with jump to next unwatched
              Container(
                color: _bg2,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    if (_episodes.length > 20)
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFc8ccd8)),
                          decoration: InputDecoration(
                            hintText: 'JUMP TO EPISODE...',
                            hintStyle: const TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 12),
                            filled: true, fillColor: _bg3, isDense: true,
                            prefixIcon: const Icon(Icons.search, color: _textDim, size: 16),
                            border: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                            enabledBorder: OutlineInputBorder(borderSide: const BorderSide(color: _border), borderRadius: BorderRadius.zero),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: _cyan), borderRadius: BorderRadius.zero),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _jumpToNextUnwatched,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.4))),
                        child: const Text('NEXT UNWATCHED', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 1)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: _border, height: 1),

              // Episode list
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: _cyan))
                    : _error != null
                        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Text('ERROR: $_error', style: const TextStyle(fontFamily: 'monospace', color: _red, fontSize: 12)),
                            const SizedBox(height: 16),
                            GestureDetector(onTap: _loadEpisodes,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(border: Border.all(color: _cyan.withOpacity(0.5))),
                                child: const Text('RETRY', style: TextStyle(fontFamily: 'monospace', fontSize: 12, color: _cyan, letterSpacing: 2)),
                              )),
                          ]))
                        : _filtered.isEmpty
                            ? const Center(child: Text('NO EPISODES FOUND', style: TextStyle(fontFamily: 'monospace', color: _textDim, fontSize: 12, letterSpacing: 2)))
                            : ListView.builder(
                                controller: _scrollController,
                                itemCount: _filtered.length,
                                itemExtent: 49,
                                itemBuilder: (context, i) {
                                  final ep = _filtered[i];
                                  final isWatched = lastEp != null && ep < lastEp;
                                  final isCurrent = lastEp != null && ep == lastEp;
                                  final isPlaying = ep == _playingEp;
                                  final progress = isCurrent ? saved?.progress : null;
                                  return _EpisodeItem(
                                    episode: ep,
                                    isWatched: isWatched,
                                    isCurrent: isCurrent,
                                    isPlaying: isPlaying,
                                    progress: progress,
                                    onTap: () => _playEpisode(ep, resumeFrom: isCurrent ? saved?.progress : null),
                                  );
                                },
                              ),
              ),
            ],
          ), // end Column (non-fullscreen)
        ),
      ),
    );
  }

  Widget _langBtn(String label, String value) {
    final active = _lang == value;
    return Expanded(
      child: GestureDetector(
        onTap: () { setState(() => _lang = value); _loadEpisodes(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _cyan.withOpacity(0.1) : Colors.transparent,
            border: Border(bottom: BorderSide(color: active ? _cyan : Colors.transparent, width: 2)),
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            fontFamily: 'monospace', fontSize: 11, color: active ? _cyan : _textDim, letterSpacing: 2,
          )),
        ),
      ),
    );
  }
}

// --- PLAYER OVERLAY ---
class _PlayerOverlay extends StatelessWidget {
  final Duration position;
  final Duration duration;
  final bool isPlaying;
  final double volume;
  final VoidCallback onPlayPause;
  final ValueChanged<double> onSeek;
  final ValueChanged<double> onVolume;
  final VoidCallback onSkipBack;
  final VoidCallback onSkipForward;
  final VoidCallback onCast;
  final bool isCasting;
  final VoidCallback onFullscreen;
  final bool isFullscreen;

  const _PlayerOverlay({
    required this.position,
    required this.duration,
    required this.isPlaying,
    required this.volume,
    required this.onPlayPause,
    required this.onSeek,
    required this.onVolume,
    required this.onSkipBack,
    required this.onSkipForward,
    required this.onCast,
    required this.isCasting,
    required this.onFullscreen,
    required this.isFullscreen,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = duration.inSeconds > 0 ? position.inSeconds / duration.inSeconds : 0.0;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Seek bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(children: [
              Text(_fmt(position), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70)),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                    activeTrackColor: const Color(0xFF00d4d4),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: const Color(0xFF00d4d4),
                    overlayColor: const Color(0xFF00d4d4).withOpacity(0.2),
                  ),
                  child: Slider(value: progress.clamp(0.0, 1.0), onChanged: onSeek),
                ),
              ),
              Text(_fmt(duration), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.white70)),
            ]),
          ),
          // Controls row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(children: [
              // Skip back
              IconButton(
                icon: const Icon(Icons.replay_10, color: Colors.white, size: 28),
                onPressed: onSkipBack,
              ),
              // Play/Pause
              IconButton(
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: const Color(0xFF00d4d4), size: 36),
                onPressed: onPlayPause,
              ),
              // Skip forward
              IconButton(
                icon: const Icon(Icons.forward_10, color: Colors.white, size: 28),
                onPressed: onSkipForward,
              ),
              const Spacer(),
              // Cast button
              IconButton(
                icon: Icon(Icons.cast, color: isCasting ? const Color(0xFF00d4d4) : Colors.white54, size: 20),
                onPressed: onCast,
                tooltip: isCasting ? 'Casting' : 'Cast to device',
              ),
              // Volume
              const Icon(Icons.volume_up, color: Colors.white54, size: 16),
              SizedBox(
                width: 80,
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: Colors.white70,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                    overlayColor: Colors.white12,
                  ),
                  child: Slider(value: volume / 100, onChanged: (v) => onVolume(v * 100)),
                ),
              ),
              // Fullscreen button
              IconButton(
                icon: Icon(
                  isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  color: Colors.white70, size: 22,
                ),
                onPressed: onFullscreen,
                tooltip: isFullscreen ? 'Exit fullscreen (F)' : 'Fullscreen (F)',
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// --- NEXT EPISODE PROMPT ---
class _NextEpPrompt extends StatelessWidget {
  final int countdown;
  final VoidCallback onPlay;
  final VoidCallback onCancel;

  const _NextEpPrompt({required this.countdown, required this.onPlay, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 80,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0f1117).withOpacity(0.95),
          border: Border.all(color: const Color(0xFF00d4d4).withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('NEXT EPISODE IN', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF5a6080), letterSpacing: 2)),
            Text('$countdown', style: const TextStyle(fontFamily: 'monospace', fontSize: 32, color: Color(0xFF00d4d4), height: 1)),
            const SizedBox(height: 10),
            Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                onTap: onCancel,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF1e2130))),
                  child: const Text('CANCEL', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF5a6080), letterSpacing: 1)),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onPlay,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF00d4d4).withOpacity(0.5))),
                  child: const Text('PLAY NOW', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: Color(0xFF00d4d4), letterSpacing: 1)),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

// --- EPISODE ITEM ---
class _EpisodeItem extends StatelessWidget {
  final double episode;
  final bool isWatched;
  final bool isCurrent;
  final bool isPlaying;
  final Duration? progress;
  final VoidCallback onTap;

  const _EpisodeItem({
    required this.episode, required this.isWatched, required this.isCurrent,
    required this.isPlaying, required this.onTap, this.progress,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    const totalSecs = 24 * 60;
    final progressPct = (progress != null && progress!.inSeconds > 0)
        ? (progress!.inSeconds / totalSecs).clamp(0.0, 1.0) : null;

    return InkWell(
      onTap: onTap,
      child: Stack(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isPlaying ? _cyan.withOpacity(0.1) : isCurrent ? _cyan.withOpacity(0.05) : Colors.transparent,
            border: const Border(bottom: BorderSide(color: _border, width: 0.5)),
          ),
          child: Row(children: [
            SizedBox(width: 32,
              child: Text(episode.toInt().toString().padLeft(2, '0'), style: TextStyle(
                fontFamily: 'monospace', fontSize: 11,
                color: isPlaying ? _cyan : isCurrent ? _cyan : isWatched ? _cyan.withOpacity(0.4) : _textDim,
              ))),
            Text('Episode ${episode.toInt()}', style: TextStyle(
              fontFamily: 'monospace', fontSize: 13,
              color: isWatched ? _textDim.withOpacity(0.5) : const Color(0xFFc8ccd8),
            )),
            const Spacer(),
            if (isPlaying)
              const Text('▶ PLAYING', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 1))
            else if (isCurrent && progress != null && progress!.inSeconds > 5)
              Text(_fmt(progress!), style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 1))
            else if (isCurrent)
              const Text('CONTINUE', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _cyan, letterSpacing: 1))
            else
              const Text('▶ PLAY', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: _textDim, letterSpacing: 1)),
          ]),
        ),
        if (progressPct != null)
          Positioned(bottom: 0, left: 0, right: 0,
            child: LinearProgressIndicator(value: progressPct, minHeight: 2,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(_cyan))),
      ]),
    );
  }
}
